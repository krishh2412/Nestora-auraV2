const pending=new Map();

function handler(){
  return window.webkit?.messageHandlers?.auraHealth||null;
}

export function healthKitAvailable(){
  return !!handler();
}

export function callHealthKit(action,payload={}){
  const native=handler();
  if(!native){
    return Promise.reject(new Error(
      "HealthKit needs the Aura iOS companion app. A normal browser/PWA cannot read Apple Health directly."
    ));
  }

  const requestId=crypto.randomUUID();
  return new Promise((resolve,reject)=>{
    pending.set(requestId,{resolve,reject});
    native.postMessage({requestId,action,payload});

    setTimeout(()=>{
      if(pending.has(requestId)){
        pending.delete(requestId);
        reject(new Error("HealthKit request timed out."));
      }
    },20000);
  });
}

window.AuraNativeHealthResponse=function(response){
  const req=pending.get(response?.requestId);
  if(!req) return;
  pending.delete(response.requestId);
  response.ok ? req.resolve(response.data) : req.reject(new Error(response.error||"HealthKit error"));
};

window.AuraHealthKit={
  available:healthKitAvailable,
  authorize(profileId,dataTypes){return callHealthKit("authorize",{profileId,dataTypes});},
  read(profileId,dataTypes,sinceISO){return callHealthKit("readSnapshot",{profileId,dataTypes,sinceISO});}
};
