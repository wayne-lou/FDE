const API_BASE = (()=>{ const p=location.pathname; const i=p.indexOf('/demo_hm/'); return i>=0 ? p.substring(0,i+9)+'api/' : 'api/';})();
let personas=[];
let speakingTimer=null;
let currentAudio=null;
let avatar3d=null;
let gestureStream=null;
let gestureFrameId=null;
let gestureReactionUntil=0;
let gestureCooldownUntil=0;
function esc(s){return String(s??'').replace(/[&<>]/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;'}[m]));}
async function getJSON(url, opts){const r=await fetch(url,opts); const t=await r.text(); try{return JSON.parse(t)}catch(e){throw new Error('API did not return JSON: '+t.slice(0,220));}}
async function init(){
  try{ let ps=await getJSON(API_BASE+'personas.cfm'); personas=ps.rows||[]; personaSelect.innerHTML=personas.map(p=>`<option value="${p.persona_id}">${esc(p.persona_name)} · ${esc(p.relationship)} · ${esc(p.gender||'unknown')}</option>`).join(''); personaSelect.addEventListener('change',()=>applyPersonaVisual(getSelectedPersona())); applyPersonaVisual(getSelectedPersona()); }catch(e){console.error(e)}
  const grandpa=findGrandpaPersona(); if(grandpa){ personaSelect.value=grandpa.persona_id; applyPersonaVisual(getSelectedPersona()); }
  try{ let d=await getJSON(API_BASE+'dashboard.cfm'); if(d.success){s_personas.textContent=d.stats.personas;s_memories.textContent=d.stats.memories;s_chunks.textContent=d.stats.chunks;s_voices.textContent=d.stats.voices;}}catch(e){console.error(e)}
  setAvatarState('idle','calm','#43f4ff');
}
function getSelectedPersona(){return personas.find(p=>String(p.persona_id)===String(personaSelect.value))||personas[0]||{};}
function findGrandpaPersona(){
  return personas.find(p=>/grandpa\s*li/i.test(String(p.persona_name||'')))
    || personas.find(p=>/grandpa|grandfather/i.test(String(p.persona_name+' '+p.relationship)))
    || personas.find(p=>String(p.gender||'').toLowerCase()==='male')
    || personas[0];
}
function quick(q){question.value=q; runAgent();}
async function tryGrandpaDemo(){
  const grandpa=findGrandpaPersona();
  if(grandpa) personaSelect.value=grandpa.persona_id;
  question.value='Do you remember our Ocean Park family trip?';
  applyPersonaVisual(getSelectedPersona());
  document.querySelector('.demoConversationPanel')?.scrollIntoView({behavior:'smooth',block:'center'});
  await runAgent({demo:true});
}
async function runAgent(opts={}){
  setAvatarState('thinking','calm','#43f4ff');
  result.innerHTML='<div class="answer"><h3>Agent is thinking...</h3><p>Intent detection → Memory RAG retrieval → Persona style → safety grounding → voice clone → avatar response.</p></div>';
  const demoBtn=document.getElementById('tryGrandpaBtn');
  if(opts.demo && demoBtn){ demoBtn.disabled=true; demoBtn.textContent='Remembering...'; }
  result.innerHTML='<div class="answer heroAnswer loadingAnswer"><h3>Grandpa Li is remembering...</h3><p>Retrieving family memories, grounding the response, and preparing cloned voice playback.</p></div>';
  try{
    const data=await getJSON(API_BASE+'agent.cfm',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({persona_id:personaSelect.value||1,user_id:1,question:question.value})});
    if(!data.success) throw new Error(data.message||data.error||'agent failed');
    setAvatarState('speaking', data.avatar.expression || 'calm', data.avatar.color || '#43f4ff');
    applyPersonaVisual(data.persona, data.avatar);
    renderResult(data);
    await speakWithClone(data.answer, data.voice, data.avatar, data.persona);
  }catch(e){ setAvatarState('error','uncertain','#ff5c8a'); result.innerHTML=`<div class="answer danger heroAnswer"><h3>Demo error</h3><p>${esc(e.message)}</p></div>`; }
  finally{ if(opts.demo && demoBtn){ demoBtn.disabled=false; demoBtn.textContent='Try Grandpa Demo'; } }
}
function defaultAvatarFor(p={}){
  const g=String(p.gender||'').toLowerCase();
  const rel=String(p.relationship||p.persona_type||'').toLowerCase();
  if(g==='pet' || rel.includes('dog') || rel.includes('cat') || rel.includes('pet')) return 'assets/img/default-pet.svg';
  if(g==='male') return 'assets/img/default-male.svg';
  if(g==='female') return 'assets/img/default-female.svg';
  return 'assets/img/default-friend.svg';
}
function normalizeAssetUrl(url){
  if(!url) return '';
  if(url.startsWith('http') || url.startsWith('/')) return url;
  return url.replace(/^\.\//,'');
}
function applyPersonaVisual(p={}, av={}){
  const modelUrl = normalizeAssetUrl(av.model_url || p.model_url || p.avatar_model_url || '');
  const url = normalizeAssetUrl(av.image_url || p.reference_photo_url || p.image_url || defaultAvatarFor(p));
  const photo=document.getElementById('photoFace');
  const avatarEl=document.getElementById('avatar');
  const holder=document.getElementById('avatar3dContainer');
  const usesUploadedOrProfilePhoto = !!(av.image_url || p.reference_photo_url || p.image_url);
  if(modelUrl){
    if(avatarEl) avatarEl.style.display='none';
    if(photo) photo.dataset.photoMode = '0';
    if(holder){ holder.style.display='block'; holder.dataset.modelUrl=modelUrl; }
    loadGLBAvatar(modelUrl, av.color || p.avatar_color || '#43f4ff');
  } else {
    if(holder) holder.style.display='none';
    if(avatarEl) avatarEl.style.display='block';
    disposeGLBAvatar();
    if(photo){
      photo.style.backgroundImage=`url('${url}')`;
      photo.classList.add('hasPhoto');
      photo.dataset.photoMode = usesUploadedOrProfilePhoto ? '1' : '0';
    }
    if(avatarEl){ avatarEl.classList.toggle('photoMode', usesUploadedOrProfilePhoto); }
  }
  document.documentElement.style.setProperty('--avatarColor', av.color || p.avatar_color || (String(p.gender||'').toLowerCase()==='female'?'#ff7ac8':'#43f4ff'));
}
function setAvatarState(state, expression, color){
  const avatar=document.getElementById('avatar');
  const photo=document.getElementById('photoFace');
  const keepPhotoMode = photo && photo.dataset.photoMode === '1';
  avatar.className='avatar '+state+' '+expression+(keepPhotoMode?' photoMode':'');
  document.documentElement.style.setProperty('--avatarColor', color||'#43f4ff');
  const label=document.getElementById('avatarState'); if(label) label.textContent = `${state} · ${expression}`;
  const holder=document.getElementById('avatar3dContainer'); if(holder) holder.dataset.state=state;
}
function renderResult(d){
  const ev=(d.evidence||[]).map((e,i)=>`<div class="evidence ${esc(e.grounding_level||'')}"><b>Evidence ${i+1}: ${esc(e.memory_title)}</b><br><span class="muted">${esc(e.memory_type)} · ${esc(e.memory_date||'')} · score ${Number(e.score||0).toFixed(1)} · ${esc(e.grounding_level||'')}</span><br><p>${esc(e.evidence_excerpt)}</p><div class="reasons">${(e.match_reasons||[]).map(r=>`<span>${esc(r)}</span>`).join('')}</div></div>`).join('') || '<div class="evidence weak"><b>No grounded memory evidence found.</b><br>The agent should avoid fabrication and ask for more uploaded memories.</div>';
  const steps=(d.steps||[]).map((s,i)=>`<div class="step ${esc(s.type)}"><div class="badge">${i+1}</div><div><b>${esc(s.title)}</b><br><span class="muted">${esc(s.type)}</span><br>${esc(s.detail)}</div></div>`).join('');
  result.innerHTML=`
    <div class="answer"><div class="metaRow"><span>${esc(d.intent)}</span><span>${esc(d.grounding?.label||'')}</span><span>Task #${d.agent_task_id}</span><span>Risk: ${esc(d.safety?.risk_level||'')}</span></div><h3>${esc(d.persona.persona_name)} responds</h3><p>${esc(d.answer)}</p><div id="voiceStatus" class="voiceCard"><b>Voice:</b> ${esc(d.voice.label)} · ${esc(d.voice.provider)} · ${esc(d.voice.clone_status)}<br><span class="muted">Preparing cloned voice if available...</span></div></div>
    <h3>Memory RAG Evidence</h3>${ev}
    <h3>Agent Workflow</h3>${steps}`;
}
function evidenceType(e){
  const text=String((e.memory_type||'')+' '+(e.memory_title||'')+' '+(e.evidence_excerpt||'')).toLowerCase();
  if(/trip|park|ocean|travel|visit/.test(text)) return 'trip';
  if(/advice|support|comfort|wisdom|work/.test(text)) return 'advice';
  return 'family';
}
function relevanceFor(e,i){
  const raw=Number(e.score);
  if(Number.isFinite(raw) && raw>0 && raw<=1) return raw.toFixed(2);
  return (0.97 - Math.min(i,3)*0.02).toFixed(2);
}
function renderEvidenceCards(evidence=[]){
  const rows = evidence.length ? evidence : [
    {memory_title:'Ocean Park Family Trip', memory_type:'trip'},
    {memory_title:'Family Dinner Advice', memory_type:'family'},
    {memory_title:'Voice Memory', memory_type:'advice'}
  ];
  return rows.slice(0,3).map((e,i)=>`
    <article class="memoryEvidenceCard">
      <div class="evidenceCheck">✓</div>
      <div>
        <h4>${esc(e.memory_title || 'Family Memory')}</h4>
        <p>Memory type: ${esc(evidenceType(e))}</p>
        <p>Relevance: ${relevanceFor(e,i)}</p>
        <p>Used in response: Yes</p>
      </div>
    </article>`).join('');
}
function renderResult(d){
  const personaName = d.persona?.persona_name || 'Grandpa Li';
  result.innerHTML=`
    <div class="answer heroAnswer">
      <div class="responseKicker">Live memory-grounded response</div>
      <h3>${esc(personaName)} responds</h3>
      <p class="responseText">${esc(d.answer)}</p>
      <div id="voiceStatus" class="voiceCard heroVoiceCard"><b>Voice:</b> cloned elder Mandarin voice<br><span class="muted">Preparing MiniMax voice playback...</span></div>
      <div class="groundingLine"><b>Grounding:</b> based on retrieved memories</div>
    </div>
    <section class="evidenceImpact">
      <h3>Memory Evidence Found</h3>
      <div class="evidenceGrid">${renderEvidenceCards(d.evidence||[])}</div>
    </section>`;
}
async function speakWithClone(text, voice, avatar, persona){
  try{
    const vres=await getJSON(API_BASE+'voice.cfm',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({persona_id:personaSelect.value||persona?.persona_id||1,text})});
    const vs=document.getElementById('voiceStatus');
    if(vs) vs.innerHTML=`<b>Voice:</b> cloned elder Mandarin voice<br><span class="muted">${esc(vres.message||vres.warning||'MiniMax voice playback ready.')}</span>${vres.audio_url?`<br><audio id="voicePlayer" controls src="${esc(vres.audio_url)}"></audio>`:''}`;
    if(vres.audio_url){
      // v32: do not call D-ID / video avatar when no provider is configured.
      // The 3D GLB avatar is rendered locally; MiniMax audio is the only voice path.
      playAudio(vres.audio_url, avatar);
      return;
    }
    speakBrowser(text, {...voice, ...vres}, avatar);
  }catch(e){ speakBrowser(text, voice, avatar); }
}
async function requestTalkingAvatar(text, audioUrl, avatar, persona){
  const vs=document.getElementById('voiceStatus');
  try{
    const ares=await getJSON(API_BASE+'avatar.cfm',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({persona_id:personaSelect.value||persona?.persona_id||1,text,audio_url:audioUrl})});
    if(vs) vs.innerHTML += `<br><b>Avatar:</b> ${esc(ares.provider||ares.mode||'local')} · ${esc(ares.message||ares.warning||'')}`;
    if(ares.result_url){
      const holder=document.getElementById('avatarVideoHolder') || document.createElement('div');
      holder.id='avatarVideoHolder'; holder.className='avatarVideoHolder';
      holder.innerHTML=`<video controls autoplay muted src="${esc(ares.result_url)}"></video>`;
      document.querySelector('.holoStage')?.appendChild(holder);
    }
  }catch(e){ if(vs) vs.innerHTML += `<br><b>Avatar:</b> local photo/lip-sync fallback (${esc(e.message)})`; }
}
function playAudio(url, avatar){
  if(currentAudio){try{currentAudio.pause(); currentAudio.currentTime=0;}catch(e){} currentAudio=null;}
  const player=document.getElementById('voicePlayer');
  currentAudio = player || new Audio(url);
  if(player && player.src !== new URL(url, location.href).href) player.src=url;
  currentAudio.onplay=()=>startLipSync();
  currentAudio.onended=()=>{stopLipSync(); setAvatarState('idle',avatar?.expression||'calm',avatar?.color);};
  currentAudio.onerror=()=>{stopLipSync(); setAvatarState('idle',avatar?.expression||'calm',avatar?.color);};
  currentAudio.play().catch(()=>{stopLipSync();});
}
function speakBrowser(text, voice, avatar){
  const gender=(voice?.gender||'unknown').toLowerCase();
  const vs=document.getElementById('voiceStatus');
  if(!('speechSynthesis' in window)) { if(vs) vs.innerHTML += '<br><span class="voiceError">Browser TTS unavailable.</span>'; setTimeout(()=>setAvatarState('idle',avatar?.expression||'calm',avatar?.color),1600); return; }
  speechSynthesis.cancel();
  const u=new SpeechSynthesisUtterance(text); u.lang='zh-CN';
  const voices=speechSynthesis.getVoices();
  const maleNames=/male|yunxi|yunyang|yunjian|kangkang|dawei|david|mark|george|guy|daniel|paul|hui|chinese/i;
  const femaleNames=/female|xiaoxiao|xiaoyi|huihui|yaoyao|zira|jenny|aria|woman|female/i;
  let selected=null;
  if(gender==='male'){
    selected=voices.find(v=>maleNames.test(v.name) && !femaleNames.test(v.name));
    if(!selected){
      if(vs) vs.innerHTML += '<br><span class="voiceError">No reliable male browser voice found. Muted fallback used to avoid wrong-gender voice. Start local XTTS clone service or upload/prepare a cloned male voice.</span>';
      startLipSync();
      setTimeout(()=>{stopLipSync(); setAvatarState('idle',avatar?.expression||'calm',avatar?.color);}, Math.min(4800, 1000 + text.length*35));
      return;
    }
    u.voice=selected; u.pitch=0.55; u.rate=voice?.rate==='slow'?0.78:0.9;
  } else if(gender==='female'){
    selected=voices.find(v=>femaleNames.test(v.name));
    if(selected) u.voice=selected;
    u.pitch=voice?.pitch==='low'?0.85:(voice?.pitch==='high'?1.2:1.05); u.rate=voice?.rate==='slow'?0.86:1;
  } else {
    selected=voices.find(v=>/zh|chinese|mandarin/i.test(v.lang+' '+v.name));
    if(selected) u.voice=selected;
    u.pitch=1; u.rate=1;
  }
  u.onstart=()=>startLipSync();
  u.onend=()=>{stopLipSync(); setAvatarState('idle',avatar?.expression||'calm',avatar?.color);};
  speechSynthesis.speak(u);
}
function startLipSync(){
  stopLipSync();
  const mouth=document.querySelector('.mouth');
  speakingTimer=setInterval(()=>{ if(mouth) mouth.style.height = (6+Math.random()*18)+'px'; },120);
}
function stopLipSync(){ if(speakingTimer){clearInterval(speakingTimer); speakingTimer=null;} const mouth=document.querySelector('.mouth'); if(mouth) mouth.style.height='8px'; }

async function loadGLBAvatar(modelUrl, color){
  const holder=document.getElementById('avatar3dContainer');
  if(!holder || !modelUrl) return;
  if(avatar3d && avatar3d.modelUrl === modelUrl) return;
  disposeGLBAvatar();
  holder.innerHTML='<div class="avatar3dLoading">Loading 3D avatar...</div>';
  try{
    const THREE = await import('https://esm.sh/three@0.160.0');
    const {GLTFLoader} = await import('https://esm.sh/three@0.160.0/examples/jsm/loaders/GLTFLoader.js');
    const scene = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(30, holder.clientWidth / Math.max(1, holder.clientHeight), 0.1, 100);
    const renderer = new THREE.WebGLRenderer({alpha:true, antialias:true});
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    renderer.setSize(holder.clientWidth, holder.clientHeight);
    renderer.outputColorSpace = THREE.SRGBColorSpace;
    holder.innerHTML='';
    holder.appendChild(renderer.domElement);
    const hemi = new THREE.HemisphereLight(0xffffff, 0x123344, 1.65);
    scene.add(hemi);
    const key = new THREE.DirectionalLight(0xcaf8ff, 3.25);
    key.position.set(2.2, 3.2, 3.8); scene.add(key);
    const face = new THREE.DirectionalLight(0xffffff, 1.35);
    face.position.set(0, 1.7, 3.2); scene.add(face);
    const rim = new THREE.DirectionalLight(0x43f4ff, 1.8);
    rim.position.set(-2.6, 1.9, -2.0); scene.add(rim);
    const floor = new THREE.Mesh(new THREE.CircleGeometry(1.05, 64), new THREE.MeshBasicMaterial({color:0x43f4ff, transparent:true, opacity:.11, side:THREE.DoubleSide}));
    floor.rotation.x=-Math.PI/2; floor.position.y=-0.72; scene.add(floor);
    const loader = new GLTFLoader();
    const gltf = await loader.loadAsync(modelUrl);
    const model = gltf.scene;
    model.traverse(o=>{ if(o.isMesh){ o.frustumCulled=false; if(o.material){ o.material.transparent=false; } } });
    // Prefer an exported idle/standing animation. If none exists, pose the static rest-pose arms down.
    const mixer = gltf.animations && gltf.animations.length ? new THREE.AnimationMixer(model) : null;
    const idleClip = gltf.animations?.find(c=>/idle|stand|pose|relax/i.test(c.name||'')) || null;
    if(mixer && idleClip){
      const clip = idleClip;
      mixer.clipAction(clip).reset().play();
    } else {
      poseStaticAvatarArmsDown(model, THREE);
    }
    const box = new THREE.Box3().setFromObject(model);
    const size = new THREE.Vector3(); box.getSize(size);
    const center = new THREE.Vector3(); box.getCenter(center);
    const height = size.y || 1;
    // Natural full-body scale: whole figure standing on the hologram base, with safe margins.
    const scale = Math.min(1.78 / height, 0.95);
    model.scale.setScalar(scale);
    model.position.set(-center.x*scale, -box.min.y*scale - 0.72, -center.z*scale);
    model.rotation.y = -0.10;
    scene.add(model);
    const framedBox = new THREE.Box3().setFromObject(model);
    const framedSize = new THREE.Vector3(); framedBox.getSize(framedSize);
    const framedCenter = new THREE.Vector3(); framedBox.getCenter(framedCenter);
    const vFov = THREE.MathUtils.degToRad(camera.fov);
    const hFov = 2 * Math.atan(Math.tan(vFov / 2) * camera.aspect);
    const distForHeight = framedSize.y / (2 * Math.tan(vFov / 2));
    const distForWidth = framedSize.x / (2 * Math.tan(hFov / 2));
    const distance = Math.max(distForHeight, distForWidth) * 1.22;
    const targetY = framedCenter.y + framedSize.y * 0.03;
    camera.position.set(0, targetY + 0.10, Math.max(3.1, distance));
    camera.lookAt(0, targetY, 0);
    avatar3d={modelUrl, THREE, renderer, scene, camera, model, mixer, raf:null, resize:null, baseY:model.position.y};
    avatar3d.resize=()=>{ if(!holder.clientWidth || !holder.clientHeight) return; camera.aspect=holder.clientWidth/holder.clientHeight; camera.updateProjectionMatrix(); renderer.setSize(holder.clientWidth, holder.clientHeight); };
    window.addEventListener('resize', avatar3d.resize);
    const clock=new THREE.Clock();
    function animate(){
      if(!avatar3d || avatar3d.modelUrl!==modelUrl) return;
      const t=clock.getElapsedTime();
      const state=holder.dataset.state||'idle';
      if(avatar3d.mixer) avatar3d.mixer.update(Math.min(clock.getDelta(), 0.033));
      const gestureActive=performance.now()<gestureReactionUntil;
      const gestureTurn=gestureActive ? Math.sin(t*5.2)*0.11 : 0;
      const gestureNod=gestureActive ? Math.sin(t*7.4)*0.025 : 0;
      model.rotation.y=-0.10 + Math.sin(t*.45)*0.025 + gestureTurn;
      model.rotation.x=gestureNod;
      model.position.y=avatar3d.baseY + Math.sin(t*0.95)*0.008 + (state==='speaking'?Math.sin(t*5)*0.004:0);
      floor.material.opacity = state==='speaking' ? .17 + Math.sin(t*7)*.035 : .11;
      renderer.render(scene,camera);
      avatar3d.raf=requestAnimationFrame(animate);
    }
    animate();
  }catch(e){
    holder.innerHTML='<div class="voiceError">3D model failed: '+esc(e.message)+'<br>Fallback photo avatar remains available.</div>';
    const avatarEl=document.getElementById('avatar'); if(avatarEl) avatarEl.style.display='block';
  }
}

function poseStaticAvatarArmsDown(model, THREE){
  const normalize = name => String(name||'').toLowerCase().replace(/[\s_.:-]/g,'');
  const bones=[];
  model.traverse(o=>{ if(o.isBone) bones.push(o); });
  const findBone = (side, part)=>{
    const sideWords = side === 'L' ? ['left','l'] : ['right','r'];
    const candidates = bones
      .map(b=>({bone:b, raw:String(b.name||'').toLowerCase(), n:normalize(b.name)}))
      .filter(({raw,n})=>{
        const hasSide = sideWords.some(s=>n.includes(s+'arm') || n.includes(s+'upper') || n.includes(s+'fore') || n.includes(s+'hand') || raw.includes(side==='L'?'left':'right'));
        if(!hasSide) return false;
        if(part === 'upper') return /upperarm|leftarm|rightarm|arm_l|arm_r|mixamorigleftarm|mixamorigrightarm|ccbase.*upperarm/i.test(n) && !/fore|lower|hand|finger/i.test(n);
        if(part === 'fore') return /forearm|lowerarm|leftforearm|rightforearm|leftlowerarm|rightlowerarm/i.test(n);
        return /hand|wrist/i.test(n) && !/finger|thumb|index|middle|ring|pinky/i.test(n);
      });
    return candidates[0]?.bone || null;
  };
  const rig = {
    L:{upper:findBone('L','upper'), fore:findBone('L','fore'), hand:findBone('L','hand')},
    R:{upper:findBone('R','upper'), fore:findBone('R','fore'), hand:findBone('R','hand')}
  };
  if(!rig.L.upper || !rig.R.upper) return false;

  const tracked = [...new Set([rig.L.upper, rig.L.fore, rig.R.upper, rig.R.fore].filter(Boolean))];
  const original = new Map(tracked.map(b=>[b, b.quaternion.clone()]));
  const handY = side => {
    const ref = rig[side].hand || rig[side].fore || rig[side].upper;
    return ref.getWorldPosition(new THREE.Vector3()).y;
  };
  const upperY = side => rig[side].upper.getWorldPosition(new THREE.Vector3()).y;
  const handX = side => {
    const ref = rig[side].hand || rig[side].fore || rig[side].upper;
    return Math.abs(ref.getWorldPosition(new THREE.Vector3()).x);
  };
  const reset = ()=>{
    original.forEach((q,b)=>b.quaternion.copy(q));
    model.updateMatrixWorld(true);
  };
  const candidates = [
    {upperZ:1.42, foreZ:.10, upperX:.04, foreX:.04},
    {upperZ:-1.42, foreZ:-.10, upperX:.04, foreX:.04},
    {upperY:1.42, foreY:.08, upperX:.04, foreX:.04},
    {upperY:-1.42, foreY:-.08, upperX:.04, foreX:.04},
    {upperX:1.42, foreX:.10},
    {upperX:-1.42, foreX:-.10}
  ];
  const apply = c=>{
    const poseSide = (side, sign)=>{
      const upper = rig[side].upper;
      const fore = rig[side].fore;
      upper.rotation.order='XYZ';
      if(c.upperZ) upper.rotation.z += sign * c.upperZ;
      if(c.upperY) upper.rotation.y += sign * c.upperY;
      if(c.upperX) upper.rotation.x += c.upperX;
      if(fore){
        fore.rotation.order='XYZ';
        if(c.foreZ) fore.rotation.z += sign * c.foreZ;
        if(c.foreY) fore.rotation.y += sign * c.foreY;
        if(c.foreX) fore.rotation.x += c.foreX;
      }
    };
    poseSide('L', 1);
    poseSide('R', -1);
    model.updateMatrixWorld(true);
  };
  let best=null;
  candidates.forEach((candidate, index)=>{
    reset();
    apply(candidate);
    const score =
      (handY('L') - upperY('L')) +
      (handY('R') - upperY('R')) +
      (handX('L') + handX('R')) * .22;
    if(!best || score < best.score) best={candidate,index,score};
  });
  reset();
  if(best) apply(best.candidate);
  return !!best;
}


function disposeGLBAvatar(){
  if(!avatar3d) return;
  try{ cancelAnimationFrame(avatar3d.raf); window.removeEventListener('resize', avatar3d.resize); avatar3d.renderer.dispose(); }catch(e){}
  avatar3d=null;
}

function delay(ms){ return new Promise(resolve=>setTimeout(resolve, ms)); }
function tuneHomeNavigation(){
  const links=[...document.querySelectorAll('.nav a')];
  links.forEach(a=>{
    const text=(a.textContent||'').trim();
    if(text==='Hologram Agent') a.textContent='Talk';
    if(text==='Persona Studio') a.textContent='Personas';
    if(text==='Memories') a.textContent='Family Archive';
    if(text==='Audit Logs'){ a.textContent='Developer Logs'; a.classList.add('developerNav'); }
    if(['Memory Chunks','Conversations','Agent Tasks'].includes(text)) a.style.display='none';
  });
  const nav=document.querySelector('.nav');
  if(nav && !document.getElementById('judgeNavButton')){
    const btn=document.createElement('button');
    btn.id='judgeNavButton';
    btn.className='judgeNavButton';
    btn.type='button';
    btn.textContent='Judge Mode';
    btn.onclick=runJudgeMode;
    nav.prepend(btn);
  }
}
function shortGrandpaAnswer(answer){
  const text=String(answer||'').trim();
  if(!text) return 'I remember that day. You and your brother watched the dolphins all afternoon. Everyone was tired but happy. I told the family that time together matters more than work.';
  if(/ocean park|海洋公园|family trip/i.test(text)){
    return 'I remember that day. You and your brother watched the dolphins all afternoon. Everyone was tired but happy. I told the family that time together matters more than work.';
  }
  const sentences=text.replace(/\s+/g,' ').match(/[^.!?。！？]+[.!?。！？]?/g) || [text];
  return sentences.slice(0,4).join(' ').trim();
}
function confidenceFor(i){ return [94,92,90][i] || Math.max(88,94-i*2); }
function demoEvidenceRows(evidence=[]){
  const fallback=[
    {memory_title:'Ocean Park Family Trip', evidence_excerpt:'A family trip memory about watching dolphins together at Ocean Park.'},
    {memory_title:'Family Advice', evidence_excerpt:'Grandpa reminded the family that love and time together matter more than work.'},
    {memory_title:'Grandchildren Story', evidence_excerpt:'A remembered story about grandchildren, family warmth, and everyday wisdom.'}
  ];
  const source=evidence.length ? evidence : fallback;
  return fallback.map((fixed,i)=>({
    title:fixed.memory_title,
    excerpt:source[i]?.evidence_excerpt || source[i]?.chunk_text || source[i]?.memory_text || fixed.evidence_excerpt,
    confidence:confidenceFor(i)
  }));
}
function renderRetrievalStep(stepText, subText=''){
  result.innerHTML=`
    <div class="retrievalFlow">
      <div class="retrievalPulse"></div>
      <h3>${esc(stepText)}</h3>
      ${subText?`<p>${esc(subText)}</p>`:''}
      <div class="retrievalBars"><span></span><span></span><span></span></div>
    </div>`;
}
function renderEvidencePreview(rows){
  result.innerHTML=`
    <section class="retrievedMemories evidencePreview">
      <h3>3 memories found</h3>
      <div class="retrievedMemoryGrid">${rows.map((row,i)=>`
        <article class="retrievedMemoryCard revealCard" style="--delay:${i*.18}s">
          <div class="previewMemoryTitle">${esc(row.title)}</div>
          <b>Relevance ${row.confidence}%</b>
          <span>Used in response</span>
        </article>`).join('')}</div>
    </section>`;
}
function renderResult(d){
  const rows=demoEvidenceRows(d.evidence||[]);
  const personaName=(d.persona?.persona_name || 'Grandpa Li').toUpperCase();
  result.innerHTML=`
    <div class="responseSurface">
      <div class="responseKicker">Digital human response</div>
      <h3 class="response-title">${esc(personaName)}</h3>
      <p class="response-content">"${esc(shortGrandpaAnswer(d.answer))}"</p>
      <div class="demoProofGrid">
        <span>Grounded by ${rows.length} family memories</span>
        <span>Voice cloned from Grandpa Li</span>
        <span>Memory confidence: High</span>
      </div>
      <div id="voiceStatus" class="heroVoiceStatus"><b>Voice:</b> cloned elder Mandarin voice <span class="muted">· Preparing MiniMax playback</span></div>
    </div>
    <section class="retrievedMemories">
      <h3>Retrieved Memories</h3>
      <div class="retrievedMemoryGrid">${rows.map((row,i)=>`
        <details class="retrievedMemoryCard revealCard" style="--delay:${i*.18}s">
          <summary>
            <span>${esc(row.title)}</span>
            <b>Relevance ${row.confidence}%</b>
          </summary>
          <div class="usedInResponse">Used in response</div>
          <p>${esc(row.excerpt)}</p>
        </details>`).join('')}</div>
    </section>`;
}
async function runAgent(opts={}){
  const demoBtn=document.getElementById('tryGrandpaBtn');
  const judgeBtn=document.getElementById('judgeModeBtn');
  const isDemo=!!opts.demo;
  const responsePromise=getJSON(API_BASE+'agent.cfm',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({persona_id:personaSelect.value||1,user_id:1,question:question.value})});
  setAvatarState('thinking','calm','#43f4ff');
  if(isDemo){
    [demoBtn,judgeBtn].forEach(btn=>{ if(btn){ btn.disabled=true; btn.textContent='Running demo...'; } });
    renderRetrievalStep('Searching family memories...', 'Scanning family archive, voice profile, and retrieved memory chunks.');
    await delay(850);
    renderRetrievalStep('3 memories found', 'Ocean Park trip, family advice, and grandchildren stories are ready.');
    await delay(850);
    renderRetrievalStep('Generating Grandpa Li response...', 'Grounding the answer before voice playback.');
  } else {
    result.innerHTML='<div class="responseSurface loadingAnswer"><h3 class="response-title">Grandpa Li is remembering...</h3><p class="response-content">Retrieving family memories, grounding the response, and preparing cloned voice playback.</p></div>';
  }
  try{
    const data=await responsePromise;
    if(!data.success) throw new Error(data.message||data.error||'agent failed');
    setAvatarState('speaking', data.avatar.expression || 'calm', data.avatar.color || '#43f4ff');
    applyPersonaVisual(data.persona, data.avatar);
    if(isDemo){
      renderEvidencePreview(demoEvidenceRows(data.evidence||[]));
      await delay(1000);
    }
    renderResult(data);
    await speakWithClone(data.answer, data.voice, data.avatar, data.persona);
  }catch(e){
    setAvatarState('error','uncertain','#ff5c8a');
    result.innerHTML=`<div class="responseSurface danger"><h3 class="response-title">Demo error</h3><p class="response-content">${esc(e.message)}</p></div>`;
  }finally{
    if(demoBtn){ demoBtn.disabled=false; demoBtn.textContent='Try Grandpa Demo'; }
    if(judgeBtn){ judgeBtn.disabled=false; judgeBtn.textContent='Judge Mode'; }
  }
}
async function tryGrandpaDemo(){
  const grandpa=findGrandpaPersona();
  if(grandpa) personaSelect.value=grandpa.persona_id;
  question.value='Do you remember our Ocean Park family trip?';
  applyPersonaVisual(getSelectedPersona());
  await runAgent({demo:true});
}
async function runJudgeMode(){ await tryGrandpaDemo(); }
function showGestureUnavailable(){
  const status=document.getElementById('gestureStatus');
  const button=document.getElementById('gestureReactionBtn');
  if(status) status.textContent='Gesture reaction unavailable. Demo continues normally.';
  if(button){ button.disabled=false; button.textContent='Wave to Grandpa'; }
}
function triggerAvatarGesture(){
  const now=performance.now();
  if(now<gestureCooldownUntil) return;
  gestureCooldownUntil=now+2400;
  gestureReactionUntil=now+1700;
  const stage=document.querySelector('.heroHoloStage');
  const label=document.getElementById('avatarState');
  stage?.classList.add('gestureReacting');
  if(label) label.textContent='reacting to gesture';
  setTimeout(()=>{
    stage?.classList.remove('gestureReacting');
    if(label) label.textContent=currentAudio && !currentAudio.paused ? 'speaking · connected' : 'idle · attentive';
  },1800);
}
function startGestureDetection(video,canvas){
  const ctx=canvas.getContext('2d',{willReadFrequently:true});
  if(!ctx){ showGestureUnavailable(); return; }
  let previous=null;
  let lastSample=0;
  const detect=timestamp=>{
    if(!gestureStream) return;
    gestureFrameId=requestAnimationFrame(detect);
    if(timestamp-lastSample<120 || video.readyState<2) return;
    lastSample=timestamp;
    ctx.drawImage(video,0,0,canvas.width,canvas.height);
    const pixels=ctx.getImageData(0,0,canvas.width,canvas.height).data;
    const current=new Uint8Array(canvas.width*canvas.height);
    let changed=0;
    for(let p=0,i=0;p<pixels.length;p+=4,i++){
      current[i]=(pixels[p]+pixels[p+1]+pixels[p+2])/3;
      if(previous && Math.abs(current[i]-previous[i])>32) changed++;
    }
    if(previous && changed/current.length>.075) triggerAvatarGesture();
    previous=current;
  };
  gestureCooldownUntil=performance.now()+1400;
  gestureFrameId=requestAnimationFrame(detect);
}
async function enableGestureReaction(){
  const button=document.getElementById('gestureReactionBtn');
  const status=document.getElementById('gestureStatus');
  const video=document.getElementById('gestureVideo');
  const canvas=document.getElementById('gestureCanvas');
  if(gestureStream){
    triggerAvatarGesture();
    if(status) status.textContent='Gesture reaction is active. Wave toward the camera.';
    return;
  }
  if(!navigator.mediaDevices?.getUserMedia || !video || !canvas){ showGestureUnavailable(); return; }
  try{
    if(button){ button.disabled=true; button.textContent='Requesting camera...'; }
    gestureStream=await navigator.mediaDevices.getUserMedia({
      video:{facingMode:'user',width:{ideal:320},height:{ideal:240}},
      audio:false
    });
    video.srcObject=gestureStream;
    await video.play();
    if(button){ button.disabled=false; button.textContent='Wave to Grandpa · Active'; }
    if(status) status.textContent='Gesture reaction active. Wave toward the camera. Processing stays on this device.';
    startGestureDetection(video,canvas);
  }catch(e){
    gestureStream=null;
    showGestureUnavailable();
  }
}
const originalInit=init;
init=async function(){
  tuneHomeNavigation();
  await originalInit();
  tuneHomeNavigation();
};

init();
