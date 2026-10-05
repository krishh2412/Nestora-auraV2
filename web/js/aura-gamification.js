(function(){
const S={profile:'krish',xp:0,level:1,streak:0,hard:false,quests:[],unlocked:[]};
const KEY='aura.v2.game';
function load(){try{Object.assign(S,JSON.parse(localStorage.getItem(KEY)||'{}'))}catch{}; seed();}
function save(){localStorage.setItem(KEY,JSON.stringify(S));}
function seed(){const today=new Date().toISOString().slice(0,10); if(S.questDate!==today){S.questDate=today;S.quests=[
 {key:'workout',title:'Complete today’s planned movement',xp:50,done:false,cat:'Fitness'},
 {key:'habits',title:'Complete all priority habits',xp:35,done:false,cat:'Discipline'},
 {key:'checkin',title:'Complete your daily check-in',xp:20,done:false,cat:'Recovery'},
 {key:'minimum',title:'Do one minimum version instead of skipping',xp:15,done:false,cat:'Consistency'}]; save();}}
function levelNeed(){return Math.max(100,S.level*S.level*100)}
function render(){
 const host=document.getElementById('p-today'); if(!host)return;
 let el=document.getElementById('auraQuestBoard'); if(!el){el=document.createElement('div');el.id='auraQuestBoard'; const hero=host.querySelector('.hero'); hero?.insertAdjacentElement('afterend',el)}
 const pct=Math.min(100,Math.round((S.xp/levelNeed())*100));
 el.innerHTML=`<div class="section aura-v2-title">Daily quests</div><div class="aura-v2-grid"><div class="card aura-v2-questcard"><div class="aura-v2-level"><div><div class="eyebrow">Level ${S.level} · ${S.streak} day streak</div><h2>${S.xp} XP</h2></div><button class="btn ${S.hard?'primary':'ghost'}" id="auraHard">${S.hard?'Hard Mode ON':'Hard Mode'}</button></div><div class="progress"><i style="width:${pct}%"></i></div><p class="small">${Math.max(0,levelNeed()-S.xp)} XP to next level</p><div class="list aura-v2-quests">${S.quests.map((q,i)=>`<div class="row"><button class="check ${q.done?'done':''}" data-q="${i}">${q.done?'✓':''}</button><div><h4>${q.title}</h4><p>${q.cat} · +${q.xp}${S.hard?' × 1.5':''} XP</p></div><span class="status ${q.done?'good':'warn'}">${q.done?'done':'quest'}</span></div>`).join('')}</div></div><div class="card aura-v2-card"><div class="eyebrow">Motivational card</div><div class="aura-v2-cardart">DISCIPLINE</div><h3>Win the next action.</h3><p class="copy">You do not need a perfect day. Complete the next meaningful action and protect the streak.</p><div class="section" style="margin-top:18px">Achievements</div><div class="aura-v2-ach">${achievements().map(a=>`<div class="${a.on?'on':''}"><b>${a.icon}</b><span>${a.name}</span></div>`).join('')}</div></div></div>`;
 el.querySelectorAll('[data-q]').forEach(b=>b.addEventListener('click',()=>toggle(+b.dataset.q)));
 el.querySelector('#auraHard')?.addEventListener('click',()=>{S.hard=!S.hard;save();render()});
}
function achievements(){return [
 {name:'First Step',icon:'01',on:S.xp>=20},{name:'Momentum',icon:'07',on:S.streak>=7},{name:'Level 2',icon:'02',on:S.level>=2},{name:'500 XP',icon:'500',on:S.xp>=500},{name:'Hard Mode',icon:'H',on:S.hard},{name:'66 Days',icon:'66',on:S.streak>=66}
]}
async function toggle(i){const q=S.quests[i];if(!q)return; const was=q.done;q.done=!q.done; const earn=Math.round(q.xp*(S.hard?1.5:1));S.xp=Math.max(0,S.xp+(q.done?earn:-earn)); while(S.xp>=S.level*S.level*100)S.level++; save();render();
 try{const repo=window.AuraRepository, api=window.AuraAPI;if(repo?.ensureAuraProfile&&api?.call){const profileId=await repo.ensureAuraProfile(S.profile);const snap=await api.call('quest.toggle',{profileId,questKey:q.key,title:q.title,category:q.cat,xp:earn,completed:q.done,questDate:S.questDate,metadata:{hardMode:S.hard}}); if(snap){S.xp=Number(snap.xp??S.xp);S.level=Number(snap.level??S.level);S.streak=Number(snap.streak??S.streak);save();render();}}}catch(e){console.warn('[Aura] Quest saved locally; cloud sync pending:',e.message)}
}
function css(){const st=document.createElement('style');st.textContent=`.aura-v2-grid{display:grid;grid-template-columns:1.35fr .65fr;gap:12px}.aura-v2-level{display:flex;align-items:center;justify-content:space-between;gap:12px}.aura-v2-cardart{height:118px;border-radius:14px;margin:12px 0;display:flex;align-items:flex-end;padding:14px;font:800 28px/1 sans-serif;letter-spacing:-1px;background:radial-gradient(circle at 70% 20%,rgba(255,176,65,.28),transparent 38%),linear-gradient(145deg,#15110c,#080808);border:1px solid rgba(255,181,69,.25)}.aura-v2-ach{display:grid;grid-template-columns:repeat(3,1fr);gap:7px}.aura-v2-ach div{min-height:64px;border:1px solid var(--line2);border-radius:12px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:4px;opacity:.35}.aura-v2-ach div.on{opacity:1;border-color:rgba(255,190,80,.45);background:rgba(255,190,80,.06)}.aura-v2-ach b{font:700 14px "JetBrains Mono"}.aura-v2-ach span{font-size:8px;color:var(--muted)}@media(max-width:760px){.aura-v2-grid{grid-template-columns:1fr}.aura-v2-questcard,.aura-v2-card{padding:14px}.aura-v2-title{margin-top:18px}}`;document.head.appendChild(st)}
function init(){css();load();render();window.AuraGame={state:S,render,toggle};}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',()=>setTimeout(init,80));else setTimeout(init,80);
})();
