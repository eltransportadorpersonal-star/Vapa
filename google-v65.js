/* VAPA V65 Google Maps: requires /api/maps-config from Netlify Functions */
(async()=>{
const status=()=>document.getElementById('v56RouteStatus');
let map, directions, service, markers=[], selected={A:null,B:null,C:null}, timers={}, requests={};
const money=n=>'$'+Math.round(n).toLocaleString('es-CL');
function msg(t){if(status())status().textContent=t}
try{
 const response=await fetch('/.netlify/functions/maps-config',{cache:'no-store'});
 if(!response.ok)throw Error('No se pudo obtener la configuración de Google Maps. Publica V65 mediante un despliegue con Netlify Functions.');
 const {key}=await response.json();if(!key)throw Error('Falta GOOGLE_MAPS_API_KEY en Netlify.');
 await new Promise((resolve,reject)=>{window.vapaGoogleReady=resolve;const s=document.createElement('script');s.src='https://maps.googleapis.com/maps/api/js?key='+encodeURIComponent(key)+'&callback=vapaGoogleReady&v=weekly&loading=async';s.onerror=()=>reject(Error('No se pudo cargar Google Maps'));document.head.append(s)});
 const {Map}=await google.maps.importLibrary('maps');
 const {AdvancedMarkerElement}=await google.maps.importLibrary('marker').catch(()=>({}));
 const places=await google.maps.importLibrary('places');
 const {DirectionsService,DirectionsRenderer}=await google.maps.importLibrary('routes');
 map=new Map(document.getElementById('v56RouteMap'),{center:{lat:-33.45,lng:-70.65},zoom:11,mapTypeControl:false,streetViewControl:false});
 service=new DirectionsService();directions=new DirectionsRenderer({map,suppressMarkers:false});
 const mapReady=()=>true;
 window.v64MapReady=mapReady;
 window.v64GoFare=()=>{document.getElementById('v55FarePanel')?.scrollIntoView({behavior:'smooth',block:'start'});setTimeout(()=>{google.maps.event.trigger(map,'resize');document.getElementById('v55PointA')?.focus({preventScroll:true})},250)};
 function pins(){directions.setDirections({routes:[]});markers.forEach(m=>m.setMap(null));markers=[];const bounds=new google.maps.LatLngBounds();for(const k of ['A','C','B']){if(k==='C'&&!document.getElementById('v55HasC').checked)continue;const p=selected[k];if(!p)continue;markers.push(new google.maps.Marker({map,position:p.position,label:k,title:p.label}));bounds.extend(p.position)}if(!bounds.isEmpty())map.fitBounds(bounds)}
 function quote(){window.v56Quote=null;const hasC=document.getElementById('v55HasC').checked;if(!selected.A||!selected.B||(hasC&&!selected.C)){document.getElementById('v55FareResult').textContent='Selecciona direcciones verificadas para cotizar.';pins();return}msg('Calculando recorrido con Google Maps…');const req={origin:selected.A.position,destination:selected.B.position,travelMode:google.maps.TravelMode.DRIVING};if(hasC)req.waypoints=[{location:selected.C.position,stopover:true}];service.route(req,(result,code)=>{if(code!=='OK'||!result?.routes?.length){msg('Google Maps no pudo calcular la ruta ('+code+'). Comprueba que Directions API esté habilitada.');document.getElementById('v55FareResult').textContent='Ruta no disponible';return}const legs=result.routes[0].legs,km=legs.reduce((a,l)=>a+l.distance.value,0)/1000,mins=legs.reduce((a,l)=>a+l.duration.value,0)/60,base=1500+km*450+mins*120,total=Math.round(base*1.15/100)*100;window.v56Quote={a:selected.A.label,b:selected.B.label,c:hasC?selected.C.label:'',km,mins,base,total};document.getElementById('v55FareResult').textContent='Distancia: '+km.toFixed(1)+' km · Duración: '+Math.round(mins)+' min · TOTAL VAPA: '+money(total)+' CLP';msg('✓ Recorrido calculado. Tarifa referencial pendiente de confirmación.');markers.forEach(m=>m.setMap(null));markers=[];directions.setDirections(result)})}
 async function suggest(k){const input=document.getElementById('v55Point'+k),box=document.getElementById('v64Suggest'+k),q=input.value.trim();box.replaceChildren();if(q.length<3)return;const seq=requests[k]=(requests[k]||0)+1;box.textContent='Buscando direcciones…';try{const {suggestions}=await places.AutocompleteSuggestion.fetchAutocompleteSuggestions({input:q,locationBias:{center:{lat:-33.45,lng:-70.65},radius:65000},includedRegionCodes:['cl'],language:'es'});if(seq!==requests[k])return;box.replaceChildren();if(!suggestions?.length){box.textContent='Sin coincidencias. Escribe calle, número y comuna.';return}for(const item of suggestions){if(!item.placePrediction)continue;const b=document.createElement('button');b.type='button';b.className='v64-choice';b.textContent='⌖ '+item.placePrediction.text.toString();b.onclick=async()=>{try{const place=item.placePrediction.toPlace();await place.fetchFields({fields:['location','formattedAddress']});if(!place.location)throw Error('Sin coordenadas');selected[k]={position:place.location,label:place.formattedAddress||b.textContent};input.value=selected[k].label;input.dataset.verified='true';box.replaceChildren();msg('✓ Dirección '+k+' verificada con Google Maps');pins();quote()}catch(e){msg('No se pudo validar la dirección: '+e.message)}};box.append(b)}}catch(e){if(seq===requests[k])box.textContent='Error al consultar direcciones de Google: '+e.message}}
 }
 for(const k of ['A','B','C']){const old=document.getElementById('v55Point'+k);const input=old.cloneNode(true);old.replaceWith(input);input.addEventListener('input',()=>{selected[k]=null;input.dataset.verified='false';window.v56Quote=null;clearTimeout(timers[k]);requests[k]=(requests[k]||0)+1;msg('Selecciona una sugerencia para verificar la dirección '+k);document.getElementById('v55FareResult').textContent='Esperando direcciones verificadas…';pins();timers[k]=setTimeout(()=>suggest(k),300)})}
 const toggle=document.getElementById('v55HasC');toggle.addEventListener('change',()=>{if(!toggle.checked){selected.C=null;document.getElementById('v55PointC').value=''}quote()});
 window.v55CalculateFare=quote;
 window.v56ScheduleQuote=quote;
 window.v56CalculateRoute=quote;
 window.v64ShowPins=pins;
 msg('Google Maps listo. Escribe una dirección y selecciona una sugerencia.');
}catch(e){msg('Google Maps no disponible: '+e.message);console.error('VAPA Google Maps:',e)}
})();
