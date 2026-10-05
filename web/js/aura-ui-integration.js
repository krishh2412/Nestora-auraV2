import { saveCurrentPlan } from "./aura-repository.js";

function normalize(key){
  return window.AuraRepository?.normalizeProfileKey
    ? window.AuraRepository.normalizeProfileKey(key)
    : ({forge:"krish",bloom:"varshini",krishna:"krish"}[String(key||"").toLowerCase()]||key);
}

window.pushPlanCalendarToNestora=async function(profileKey){
  const key=normalize(profileKey);
  try{
    if(typeof window.toast==="function") window.toast("Saving Aura plan and syncing calendar…");

    const result=await saveCurrentPlan(key,{syncNestora:true});
    console.log("[Aura] saved in aura schema and bridged to Nestora",result);

    if(window.auraPlanCalendars?.[key]){
      window.auraPlanCalendars[key].synced=true;
      window.auraPlanCalendars[key].events?.forEach?.(e=>e.synced=true);
    }

    if(typeof window.renderGeneratedPlan==="function"){
      window.renderGeneratedPlan(key);
    }

    if(typeof window.toast==="function"){
      window.toast(`${result.sessionsSaved} session(s) saved. Nestora Calendar updated.`);
    }
    return result;
  }catch(error){
    console.error("[Aura] Save/sync failed",error);
    if(typeof window.toast==="function"){
      window.toast(`Aura sync failed: ${error.message}`);
    }else{
      alert(`Aura sync failed: ${error.message}`);
    }
    throw error;
  }
};

console.log("[Aura] separated-schema integration active");
