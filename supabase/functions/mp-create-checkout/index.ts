import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
Deno.serve(async (req) => {
  const headers = {'Content-Type':'application/json','Access-Control-Allow-Origin':Deno.env.get('SITE_ORIGIN') || 'https://vapa.netlify.app','Access-Control-Allow-Headers':'authorization, apikey, content-type'};
  if(req.method==='OPTIONS') return new Response('',{headers});
  if(req.method!=='POST') return new Response('Method not allowed',{status:405,headers});
  try {
    const auth=req.headers.get('Authorization'); if(!auth?.startsWith('Bearer ')) throw Error('Debes iniciar sesión');
    const url=Deno.env.get('SUPABASE_URL')!, anon=Deno.env.get('SUPABASE_ANON_KEY')!, service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const client=createClient(url,anon,{global:{headers:{Authorization:auth}}});
    const {data:{user},error}=await client.auth.getUser(); if(error||!user) throw Error('Sesión inválida');
    const {reservation_id}=await req.json();
    const admin=createClient(url,service);
    const {data:r,error:re}=await admin.from('reservations').select('id,user_id,status,expires_at,amount').eq('id',reservation_id).single();
    if(re||!r||r.user_id!==user.id||r.status!=='pending_payment'||new Date(r.expires_at).getTime()<=Date.now()) throw Error('Reserva no disponible para pago');
    const token=Deno.env.get('MP_ACCESS_TOKEN'); if(!token) throw Error('Falta configurar Mercado Pago');
    const base=Deno.env.get('SITE_ORIGIN')||'https://vapa.netlify.app';
    const response=await fetch('https://api.mercadopago.com/checkout/preferences',{method:'POST',headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json','X-Idempotency-Key':`vapa-${r.id}`},body:JSON.stringify({items:[{title:'Reserva VAPA',quantity:1,currency_id:'CLP',unit_price:Number(r.amount)}],external_reference:r.id,notification_url:`${url}/functions/v1/mp-webhook`,back_urls:{success:base,failure:base,pending:base},auto_return:'approved',expires:true,expiration_date_to:new Date(r.expires_at).toISOString()})});
    const pref=await response.json(); if(!response.ok||!pref.id) throw Error('No se pudo crear preferencia de pago');
    return new Response(JSON.stringify({checkout_url:pref.sandbox_init_point||pref.init_point,preference_id:pref.id}),{headers});
  } catch(e){return new Response(JSON.stringify({error:String(e?.message||e)}),{status:400,headers});}
});
