
import { createClient } from
  "https://esm.sh/@supabase/supabase-js@2";

function respond(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}

Deno.serve(async (req) => {
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

  // Primera protección: JWT de Supabase.
  const authorization = req.headers.get("Authorization") ?? "";
  const suppliedToken = authorization.replace(/^Bearer\s+/i, "");

  if (suppliedToken !== serviceKey) {
    return respond({ error: "Unauthorized" }, 401);
  }

  // Segunda protección: secreto exclusivo del programador.
  const suppliedSecret = req.headers.get("x-refund-cron-secret") ?? "";

  if (suppliedSecret.length !== cronSecret.length) {
    return respond({ error: "Unauthorized" }, 401);
  }

  let diff = 0;
  for (let i = 0; i < cronSecret.length; i++) {
    diff |= suppliedSecret.charCodeAt(i) ^ cronSecret.charCodeAt(i);
  }

  if (diff !== 0) {
    return respond({ error: "Unauthorized" }, 401);
  }

  const db = createClient(url, serviceKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  const { data: reservations, error } = await db
    .from("reservations")
    .select("id,amount,mp_payment_id,refund_status")
    .eq("status", "rejected")
    .eq("payment_status", "paid")
    .eq("refund_status", "pending")
    .not("mp_payment_id", "is", null)
    .limit(20);

  if (error) {
    console.error("Refund lookup failed", error.message);
    return respond({ error: "Refund lookup failed" }, 500);
  }

  const results = [];

  for (const reservation of reservations ?? []) {
    try {
      const response = await fetch(
        `https://api.mercadopago.com/v1/payments/${
          encodeURIComponent(reservation.mp_payment_id)
        }`,
        {
          headers: {
            Authorization: `Bearer ${mpToken}`,
          },
        }
      );

      if (!response.ok) {
        results.push({
          reservation_id: reservation.id,
          ready: false,
          reason: "Payment lookup failed",
        });
        continue;
      }

      const payment = await response.json();

      const valid =
        payment.status === "approved" &&
        payment.currency_id === "CLP" &&
        String(payment.external_reference) === reservation.id &&
        Number(payment.transaction_amount) === reservation.amount;

      results.push({
        reservation_id: reservation.id,
        ready: valid,
        payment_status: payment.status,
        amount_matches:
          Number(payment.transaction_amount) === reservation.amount,
      });
    } catch {
      results.push({
        reservation_id: reservation.id,
        ready: false,
        reason: "Payment lookup error",
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
