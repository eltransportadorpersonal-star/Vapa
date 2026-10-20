import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
Deno.serve(async (req) => {
  if(req.method!=='POST') return new Response('Method not allowed',{status:405});
  // Mercado Pago: validate x-signature HMAC SHA256 over id/request-id/ts before trusting notification.
  const secret=Deno.env.get('MP_WEBHOOK_SECRET');
  if(!secret) return new Response('Webhook secret not configured',{status:503});
  const sig=req.headers.get('x-signature')||'', requestId=req.headers.get('x-request-id')||'';
  const ts=sig.match(/(?:^|,)ts=([^,]+)/)?.[1], v1=sig.match(/(?:^|,)v1=([a-f0-9]+)/i)?.[1];
  const url=new URL(req.url); const payload=await req.json().catch(()=>({}));
  
const id = String(
  url.searchParams.get("data.id") ||
  payload?.data?.id ||
  ""
);
  
if (
  !/^[0-9]+$/.test(id) ||
  !ts ||
  !v1 ||
  !requestId ||
  !/^[0-9]+$/.test(ts)
) {
  return new Response("Invalid signature", {
    status: 401,
  });
}
  
  if(Math.abs(Date.now()-Number(ts)*1000)>300000) return new Response('Expired signature',{status:401});
  
const signatureId = id.toLowerCase();

const manifest =
  `id:${signatureId};request-id:${requestId};ts:${ts};`;
  const key=await crypto.subtle.importKey('raw',new TextEncoder().encode(secret),{name:'HMAC',hash:'SHA-256'},false,['sign']);
  const bytes=new Uint8Array(await crypto.subtle.sign('HMAC',key,new TextEncoder().encode(manifest)));
  const expected=Array.from(bytes).map(x=>x.toString(16).padStart(2,'0')).join('');
  
  let signatureDiff = expected.length ^ v1.length;

  const maxLength = Math.max(expected.length, v1.length);

  for (let i = 0; i < maxLength; i++) {
    signatureDiff |=
      (expected.charCodeAt(i) || 0) ^
      (v1.charCodeAt(i) || 0);
  }

  if (signatureDiff !== 0) {
    return new Response("Invalid signature", {
      status: 401,
    });
  }
  if(payload.type!=='payment' && url.searchParams.get('type')!=='payment') return new Response('ok');
  const token=Deno.env.get('MP_ACCESS_TOKEN')!;
  const response=await fetch(`https://api.mercadopago.com/v1/payments/${encodeURIComponent(id)}`,{headers:{Authorization:`Bearer ${token}`}});
  if(!response.ok) return new Response('Payment lookup failed',{status:502});
  const payment=await response.json();
  if(payment.status!=='approved'||payment.currency_id!=='CLP') return new Response('ok');
  const admin=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
 
  const approvedAt = payment.date_approved;

  if (
    !approvedAt ||
    Number.isNaN(Date.parse(approvedAt))
  ) {
    console.error("Invalid payment approval date");
    return new Response(
      "Invalid payment approval date",
      { status: 502 }
    );
  }

  
  const reservationId = String(
    payment.external_reference ?? ""
  );

  const uuidPattern =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

  if (!uuidPattern.test(reservationId)) {
    console.error("Invalid reservation reference");
    return new Response(
      "Invalid reservation reference",
      { status: 422 }
    );
  }
const { data, error } = await admin.rpc(
    "vapa_verify_payment_v2",
    {
     p_reservation: reservationId,
      p_payment_id: String(payment.id),
      p_amount: Number(payment.transaction_amount),
      p_approved_at: approvedAt,
    }
  );

  if (error) {
    console.error("Payment verification failed", error.message);
    return new Response(
      "Database update failed",
      { status: 500 }
    );
  }

  
  console.log("Payment verification result:", {
    result: data,
    payment_id: String(payment.id),
    reservation_id: reservationId,
  });
return new Response('ok');
});
