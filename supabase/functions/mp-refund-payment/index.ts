import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

function respond(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}

function constantTimeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") {
    return respond({ error: "Method not allowed" }, 405);
  }

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const mpToken = Deno.env.get("MP_ACCESS_TOKEN");
  const cronSecret = Deno.env.get("REFUND_CRON_SECRET");

  if (!url || !serviceKey || !mpToken || !cronSecret) {
    console.error("Missing server configuration");
    return respond({ error: "Missing configuration" }, 500);
  }

  const authorization = req.headers.get("Authorization") ?? "";
  const suppliedToken = authorization.replace(/^Bearer\s+/i, "");
  const suppliedSecret = req.headers.get("x-refund-cron-secret") ?? "";

  if (
    !constantTimeEqual(suppliedToken, serviceKey) ||
    !constantTimeEqual(suppliedSecret, cronSecret)
  ) {
    return respond({ error: "Unauthorized" }, 401);
  }

  const db = createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: reservations, error } = await db
    .from("reservations")
    .select("id,amount,mp_payment_id,refund_status")
    .eq("status", "rejected")
    .eq("payment_status", "paid")
    .eq("refund_status", "pending")
    .not("mp_payment_id", "is", null)
    .order("id", { ascending: true })
    .limit(20);

  if (error) {
    console.error("Refund lookup failed", error.message);
    return respond({ error: "Refund lookup failed" }, 500);
  }

  const results: Record<string, unknown>[] = [];

  for (const reservation of reservations ?? []) {
    // Diagnostic identifier only. It is NOT sent to Mercado Pago in dry_run.
    const idempotencyKey = `vapa-refund-${reservation.id}`;
    const base = {
      reservation_id: reservation.id,
      idempotency_key: idempotencyKey,
    };

    try {
      const paymentId = encodeURIComponent(String(reservation.mp_payment_id));
      const paymentResponse = await fetch(
        `https://api.mercadopago.com/v1/payments/${paymentId}`,
        { headers: { Authorization: `Bearer ${mpToken}` } },
      );

      if (!paymentResponse.ok) {
        results.push({
          ...base,
          ready: false,
          reason: "Payment lookup failed",
          http_status: paymentResponse.status,
        });
        continue;
      }

      const payment = await paymentResponse.json();
      const amountMatches =
        Number(payment.transaction_amount) === Number(reservation.amount);
      const paymentMatches =
        String(payment.id) === String(reservation.mp_payment_id) &&
        payment.currency_id === "CLP" &&
        String(payment.external_reference) === String(reservation.id) &&
        amountMatches;

      if (!paymentMatches) {
        results.push({
          ...base,
          ready: false,
          reason: "Payment details mismatch",
          payment_status: payment.status,
          amount_matches: amountMatches,
        });
        continue;
      }

      if (
        payment.status === "refunded" ||
        payment.status === "partially_refunded"
      ) {
        results.push({
          ...base,
          ready: false,
          payment_status: payment.status,
          reason: "Payment already refunded or partially refunded - reconciliation required",
        });
        continue;
      }

      const embeddedRefunds = Array.isArray(payment.refunds)
        ? payment.refunds
        : [];
      if (embeddedRefunds.length > 0) {
        results.push({
          ...base,
          ready: false,
          payment_status: payment.status,
          reason: "Existing refund in payment data - reconciliation required",
          refund_count: embeddedRefunds.length,
        });
        continue;
      }

      // Read-only diagnostic. Verify this endpoint and response in test mode
      // before relying on it. Any failure blocks readiness; no refund is issued.
      const refundsResponse = await fetch(
        `https://api.mercadopago.com/v1/payments/${paymentId}/refunds`,
        { headers: { Authorization: `Bearer ${mpToken}` } },
      );

      if (!refundsResponse.ok) {
        results.push({
          ...base,
          ready: false,
          reason: "Refund history lookup failed",
          http_status: refundsResponse.status,
        });
        continue;
      }

      const refundHistory: unknown = await refundsResponse.json();
      if (!Array.isArray(refundHistory)) {
        results.push({
          ...base,
          ready: false,
          reason: "Unexpected refund history response",
        });
        continue;
      }

      if (refundHistory.length > 0) {
        results.push({
          ...base,
          ready: false,
          reason: "Previous refund detected - reconciliation required",
          refund_count: refundHistory.length,
        });
        continue;
      }

      results.push({
        ...base,
        ready: payment.status === "approved",
        payment_status: payment.status,
        amount_matches: amountMatches,
        reason: payment.status === "approved"
          ? "Diagnostic checks passed; no refund attempted"
          : "Payment not approved",
      });
    } catch (err) {
      console.error(
        "Refund diagnostic error",
        reservation.id,
        err instanceof Error ? err.message : "Unknown error",
      );
      results.push({
        ...base,
        ready: false,
        reason: "Payment or refund lookup error",
      });
    }
  }

  return respond({
    mode: "dry_run",
    pending_refunds: reservations?.length ?? 0,
    checked: results.length,
    results,
    refunds_executed: 0,
    message: "Diagnostic only. No refunds executed.",
  });
});
