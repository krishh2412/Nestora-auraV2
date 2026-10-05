function getConfig(){
  const c=window.AURA_CONFIG||{};
  if(!c.familyId || c.familyId.startsWith("PASTE_")){
    throw new Error("Aura config: familyId is missing.");
  }
  if(!c.apiUrl || !/^https:\/\//i.test(c.apiUrl)){
    throw new Error("Aura config: apiUrl is missing/invalid.");
  }
  return c;
}

async function getAccessToken(){
  try{
    const auth=window.supabase?.auth;
    if(!auth?.getSession) return null;
    const {data}=await auth.getSession();
    return data?.session?.access_token||null;
  }catch{
    return null;
  }
}

export async function auraApi(operation,payload={}){
  const c=getConfig();
  const token=await getAccessToken();
  const headers={"content-type":"application/json"};

  if(token){
    headers.authorization=`Bearer ${token}`;
  }else if(c.localDevToken && !c.localDevToken.startsWith("PASTE_")){
    headers["x-aura-dev-token"]=c.localDevToken;
  }else{
    throw new Error("Aura config: no authenticated session or localDevToken.");
  }

  const response=await fetch(c.apiUrl,{
    method:"POST",
    headers,
    body:JSON.stringify({operation,familyId:c.familyId,payload})
  });

  const raw=await response.text();
  let body={};
  try{ body=raw?JSON.parse(raw):{}; }catch{ body={error:raw}; }

  if(!response.ok || !body.ok){
    const message=body?.error || `Aura API HTTP ${response.status}`;
    throw new Error(message);
  }
  return body.result;
}

window.AuraAPI={call:auraApi};
console.log("[Aura] API client ready");
