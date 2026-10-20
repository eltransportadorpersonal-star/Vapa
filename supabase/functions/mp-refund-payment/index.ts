import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

/** VAPA V80: Refund diagnostics only. This function NEVER creates refunds. */
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
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return respond({ error: "Method not allowed" }, 405);

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

  if (!constantTimeEqual(suppliedToken, serviceKey) ||
      !constantTimeEqual(suppliedSecret, cronSecret)) {
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
    // Stable identifier for future refund attempts; NOT sent to Mercado Pago yet.
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
        results.push({ ...base, ready: false, reason: "Payment lookup failed", http_status: paymentResponse.status });
        continue;
      }

      const payment = await paymentResponse.json();
      const amountMatches = Number(payment.transaction_amount) === Number(reservation.amount);
      const paymentMatches =
        String(payment.id) === String(reservation.mp_payment_id) &&
        payment.currency_id === "CLP" &&
        String(payment.external_reference) === reservation.id &&
        amountMatches;

      if (!paymentMatches) {
        results.push({ ...base, ready: false, reason: "Payment details mismatch", payment_status: payment.status, amount_matches: amountMatches });
        continue;
      }
