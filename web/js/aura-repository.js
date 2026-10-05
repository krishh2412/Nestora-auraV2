import { auraApi } from "./aura-api-client.js";

function normalizeProfileKey(profileKey){
  const map=window.AuraProfileAliases || {
    forge:"krish",
    krish:"krish",
    krishna:"krish",
    bloom:"varshini",
    varshini:"varshini"
  };
  const key=String(profileKey||"").trim().toLowerCase();
  return map[key] || key;
}

function assertProfile(profileKey){
  const key=normalizeProfileKey(profileKey);
  const profiles=window.fitnessProfiles;
  if(!profiles){
    throw new Error("Aura runtime not ready: window.fitnessProfiles is unavailable.");
  }
  const p=profiles[key];
  if(!p){
    throw new Error(`UI profile not found: ${key}`);
  }
  return {key,p};
}

function stableUuid(key){
  const storageKey=`aura.uuid:${key}`;
  let id=localStorage.getItem(storageKey);
  if(!id){
    id=crypto.randomUUID();
    localStorage.setItem(storageKey,id);
  }
  return id;
}

function normalizeItems(items=[]){
  return items.map((x,i)=>{
    if(Array.isArray(x)){
      return {
        name:x[0]||"",
        prescription:x[1]||"",
        equipment:null,
        notes:null,
        sort_order:i
      };
    }
    return {
      name:x?.name||"",
      prescription:x?.prescription||"",
      equipment:x?.equipment||null,
      notes:x?.notes||null,
      metadata:x?.metadata||{},
      sort_order:x?.sort_order ?? i
    };
  });
}

function getFamilyMemberId(key){
  return window.AURA_MEMBER_MAP?.[key] || null;
}

function getPregnancyEnabled(key){
  const family=window.familyProfiles;
  if(!Array.isArray(family)) return false;
  return !!family.find(x=>String(x.id).toLowerCase()===key)?.pregnancyEnabled;
}

export async function ensureAuraProfile(profileKey){
  const {key,p}=assertProfile(profileKey);
  const id=stableUuid(`profile:${key}`);

  const result=await auraApi("profile.upsert",{
    id,
    familyMemberId:getFamilyMemberId(key),
    owner:
  key === "krish"
    ? "Krishna"
    : key === "varshini"
      ? "Varshini"
      : p.owner || key,
    name:`${p.owner||key} Wellness`,
    profileType:
      key==="varshini" && /postpartum/i.test(p.stage||"")
        ? "postpartum"
        : "standard_adult",
    pregnancyEnabled:getPregnancyEnabled(key),
    postpartumEnabled:key==="varshini" && /postpartum/i.test(p.stage||""),
    status:"active",
    preferences:{
      stage:p.stage||null,
      goal:p.goal||null,
      location:p.location||null,
      equipment:p.equipment||null,
      days:Number(p.days||0),
      duration:Number(p.duration||0),
      style:p.style||null,
      cardio:p.cardio||null,
      experience:p.experience||null,
      limitations:p.limitations||null,
      clearance:p.clearance||null
    },
    motivationConfig:window.motivationState?.[key] || {},
    privacyConfig:{
      health_data_private:true,
      recovery_journal_private:true
    }
  });

  return result.id;
}

export async function saveCurrentPlan(profileKey,options={}){
  const {key,p}=assertProfile(profileKey);

  if(!p.generated){
    throw new Error("Generate the plan before syncing.");
  }

  if(typeof window.ensurePlanSchedule==="function"){
    window.ensurePlanSchedule(key);
  }
  if(typeof window.ensureMultiSessionModel==="function"){
    window.ensureMultiSessionModel(key);
  }

  const datedDays=(p.plan||[]).filter(d=>d?.date);
  if(!datedDays.length){
    throw new Error("No dated plan days found. Assign dates before syncing.");
  }

  const profileId=await ensureAuraProfile(key);
  const planId=stableUuid(`plan:${key}:current`);

  const dates=datedDays.map(d=>d.date).filter(Boolean).sort();

  await auraApi("plan.upsert",{
    id:planId,
    profileId,
    name:options.name || `${p.owner||key} - ${p.goal||p.stage||"Fitness Plan"}`,
    planType:
      key==="varshini" && /postpartum/i.test(p.stage||"")
        ? "postpartum_recovery"
        : "fitness",
    goal:p.goal||p.stage||null,
    startDate:options.startDate||dates[0]||null,
    endDate:options.endDate||dates[dates.length-1]||null,
    status:"active",
    nutritionConfig:window.nutritionPlans?.[key] || {},
    motivationConfig:window.motivationState?.[key] || {},
    metadata:{
      ui_source:"Aura Family",
      profile_key:key,
      time_bound:!!(options.startDate&&options.endDate)
    }
  });

  let saved=0;

  for(let di=0;di<datedDays.length;di++){
    const day=datedDays[di];
    const sessions=Array.isArray(day.sessions)?day.sessions:[];

    for(let si=0;si<sessions.length;si++){
      const s=sessions[si];

      const sessionId =
        s.id && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(s.id)
          ? s.id
          : stableUuid(`session:${key}:${day.date}:${si}:${s.title||"session"}`);

      await auraApi("session.upsert",{
        profileId,
        planId,
        syncNestora:options.syncNestora!==false,
        session:{
          id:sessionId,
          date:day.date,
          day_label:day.day || `Day ${di+1}`,
          title:s.title || `Session ${si+1}`,
          session_type:s.type || "workout",
          start_time:s.time || null,
          duration_minutes:Number(s.duration||p.duration||30),
          location:p.location||null,
          status:s.status||"planned",
          metadata:{
            profile_key:key,
            stage:p.stage||null,
            cardio:p.cardio||null
          },
          warmups:normalizeItems(s.warmups),
          workout:normalizeItems(s.workout),
          cooldown:normalizeItems(s.cooldown)
        }
      });
      saved++;
    }
  }

  return {profileKey:key,profileId,planId,sessionsSaved:saved};
}

window.AuraRepository={
  normalizeProfileKey,
  ensureAuraProfile,
  saveCurrentPlan
};

console.log("[Aura] repository ready",Object.keys(window.fitnessProfiles||{}));
