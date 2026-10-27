/* VAPA V81: cálculo informativo. La comisión definitiva debe calcularse en el servidor. */
(function(global){
  'use strict';
  const FIRST_YEAR_BPS=1000, LATER_BPS=1500;
  function calculate(grossCLP, registeredAt, chargedAt=new Date()) {
    if(!Number.isSafeInteger(grossCLP)||grossCLP<0) throw Error('Monto CLP inválido');
    const start=new Date(registeredAt), charged=new Date(chargedAt);
    if(!Number.isFinite(start.getTime())||!Number.isFinite(charged.getTime())||charged<start) throw Error('Fechas inválidas');
    const anniversary=new Date(start.getTime());
    anniversary.setUTCFullYear(anniversary.getUTCFullYear()+1);
    const rateBps=charged<anniversary?FIRST_YEAR_BPS:LATER_BPS;
    const platformCLP=Math.round(grossCLP*rateBps/10000);
    return Object.freeze({grossCLP,rateBps,platformCLP,providerCLP:grossCLP-platformCLP,processorFeeCLP:null,settlementStatus:'not_verified'});
  }
  global.VapaCommissions=Object.freeze({calculate});
})(typeof window!=='undefined'?window:globalThis);
