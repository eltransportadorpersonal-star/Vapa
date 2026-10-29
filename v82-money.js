/* V82: lectura de liquidaciones confirmadas. Sin datos inventados ni operaciones financieras desde el navegador. */
async function v82LoadMoney(){
 const status=document.getElementById('v82MoneyStatus'),list=document.getElementById('v82Movements');
 for(const id of ['v82Available','v82Pending','v82Month'])document.getElementById(id).textContent='—';
 list.replaceChildren();status.textContent='Consultando movimientos…';
 try{
  const db=typeof vapaDb==='function'?vapaDb():null;
  if(!db)throw Error('No hay conexión a Supabase.');
  const {data:{user},error:authError}=await db.auth.getUser();
  if(authError||!user)throw Error('Inicia sesión para ver tus movimientos.');
  const {data,error}=await db.from('v82_provider_settlements').select('id,gross_clp,provider_clp,platform_clp,processor_fee_clp,status,created_at,paid_at').eq('provider_id',user.id).order('created_at',{ascending:false}).limit(100);
  if(error)throw Error('El módulo de liquidaciones aún no está configurado o no se puede consultar.');
  const rows=data||[];const money=n=>'$'+n.toLocaleString('es-CL');
  const total=state=>rows.filter(x=>x.status===state).reduce((a,x)=>a+x.provider_clp,0);
  document.getElementById('v82Available').textContent=money(total('available'));
  document.getElementById('v82Pending').textContent=money(total('pending'));
  const now=new Date();const month=rows.filter(x=>x.status==='paid'&&x.paid_at&&new Date(x.paid_at).getUTCFullYear()===now.getUTCFullYear()&&new Date(x.paid_at).getUTCMonth()===now.getUTCMonth()).reduce((a,x)=>a+x.provider_clp,0);
  document.getElementById('v82Month').textContent=money(month);
  status.textContent=rows.length?'Últimos '+rows.length+' movimientos (hasta 100).':'Todavía no hay movimientos registrados.';
  for(const r of rows){const div=document.createElement('div');div.className='v82-row';const label=document.createElement('span');const strong=document.createElement('strong');strong.textContent=money(r.provider_clp);const detail=document.createElement('small');detail.textContent=new Date(r.created_at).toLocaleDateString('es-CL')+' · '+({pending:'Por recibir',available:'Disponible',paid:'Pagado',refunded:'Devuelto',disputed:'En revisión'}[r.status]||r.status);label.append(strong,detail);const fee=document.createElement('span');fee.textContent='Comisión VAPA: '+money(r.platform_clp);div.append(label,fee);list.append(div)}
 }catch(e){status.textContent=e.message;}
}
