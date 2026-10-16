import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
Deno.serve(async (req) => {
  if(req.method!=='POST') return new Response('Method not allowed',{status:405});
  // Mercado Pago: validate x-signature HMAC SHA256 over id/request-id/ts before trusting notification.
  const secret=Deno.env.get('MP_WEBHOOK_SECRET');
  if(!secret) return new Response('Webhook secret not configured',{status:503});
  const sig=req.headers.get('x-signature')||'', requestId=req.headers.get('x-request-id')||'';
  const ts=sig.match(/(?:^|,)ts=([^,]+)/)?.[1], v1=sig.match(/(?:^|,)v1=([a-f0-9]+)/i)?.[1];
  const url=new URL(req.url); const payload=await req.json().catch(()=>({}));
  const id=String(url.searchParams.get('data.id')||payload?.data?.id||'').toLowerCase();
  if(!id||!ts||!v1||!requestId||!/^[0-9]+$/.test(ts)) return new Response('Invalid signature',{status:401});
  if(Math.abs(Date.now()-Number(ts)*1000)>300000) return new Response('Expired signature',{status:401});
  const manifest=`id:${id};request-id:${requestId};ts:${ts};`;
  const key=await crypto.subtle.importKey('raw',new TextEncoder().encode(secret),{name:'HMAC',hash:'SHA-256'},false,['sign']);
  const bytes=new Uint8Array(await crypto.subtle.sign('HMAC',key,new TextEncoder().encode(manifest)));
  const expected=Array.from(bytes).map(x=>x.toString(16).padStart(2,'0')).join('');
  if(expected.length!==v1.length||![...expected].every((c,i)=>c===v1[i])) return new Response('Invalid signature',{status:401});
  if(payload.type!=='payment' && url.searchParams.get('type')!=='payment') return new Response('ok');
  const token=Deno.env.get('MP_ACCESS_TOKEN')!;
  const response=await fetch(`https://api.mercadopago.com/v1/payments/${encodeURIComponent(id)}`,{headers:{Authorization:`Bearer ${token}`}});
  if(!response.ok) return new Response('Payment lookup failed',{status:502});
  const payment=await response.json();
  if(payment.status!=='approved'||payment.currency_id!=='CLP') return new Response('ok');
  const admin=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const {error}=await admin.rpc('v46_mark_payment_verified',{p_reservation:payment.external_reference,p_payment_id:String(payment.id),p_amount:Number(payment.transaction_amount)});
  if(error) return new Response('Database update failed',{status:500});
  return new Response('ok');
});
