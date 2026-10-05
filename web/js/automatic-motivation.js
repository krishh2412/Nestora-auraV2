export class AutomaticMotivationEngine{
  evaluate(input={}){
    const c={
      energy:7,
      recoveryMode:false,
      postpartum:false,
      streak:0,
      misses:0,
      completedToday:false,
      identity:"",
      familyImpact:"",
      minimumVersion:"Do the smallest useful version.",
      ...input
    };

    if(c.recoveryMode || (c.postpartum && c.energy<=5)){
      return {priority:"recovery",tone:"supportive",
        message:`Recovery is the action today. ${c.minimumVersion}`};
    }
    if(c.misses>=2){
      return {priority:"recommit",tone:"firm",
        message:`Do not let two misses become the new pattern. ${c.minimumVersion}`};
    }
    if([7,14,21,30,60,90].includes(c.streak)){
      return {priority:"milestone",tone:"celebrate",
        message:c.familyImpact
          ?`${c.streak} days. You are reinforcing why this matters: ${c.familyImpact}`
          :`${c.streak} days of consistency. Protect the system tomorrow.`};
    }
    if(!c.completedToday){
      return {priority:"action",tone:"challenge",
        message:c.identity
          ?`Act like the person you said you want to become: ${c.identity}`
          :"Start the first planned action now."};
    }
    return {priority:"maintain",tone:"steady",
      message:"Keep the chain moving. Today's action is enough."};
  }
}
window.AutomaticMotivationEngine=new AutomaticMotivationEngine();
