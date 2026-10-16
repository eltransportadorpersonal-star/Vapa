exports.handler=async()=>{
 const key=process.env.GOOGLE_MAPS_API_KEY;
 return {statusCode:key?200:503,headers:{'Content-Type':'application/json','Cache-Control':'no-store','Access-Control-Allow-Origin':'https://vapa.netlify.app'},body:JSON.stringify(key?{key}:{error:'GOOGLE_MAPS_API_KEY no configurada'})};
};
