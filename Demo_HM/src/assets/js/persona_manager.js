const API_BASE='../api/';
let personas=[];
let selectedId='';
let mediaStream=null;
let recorder=null;
let chunks=[];
let prepareBusy=false;
let uploadBusy=false;
let metaPersonExport={model_url:'',avatar_code:'',avatar_state:'',screenshot_url:''};
let metaPersonCredentials={client_id:'',client_secret:'',configured:false};
let metaPersonLoaded=false;
let metaPersonExportAvailable=false;

function esc(s){return String(s??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));}
function byId(id){return document.getElementById(id);}
function val(id){const el=byId(id); return el ? String(el.value||'') : '';}
function setVal(id,v){const el=byId(id); if(el) el.value = v ?? '';}
function setText(id,t){const el=byId(id); if(el) el.textContent = t ?? '';}
function setHTML(id,t){const el=byId(id); if(el) el.innerHTML = t ?? '';}
function currentPersonaId(){
  const hidden = val('persona_id');
  if(hidden) return hidden;
  if(selectedId) return String(selectedId);
  if(personas.length && personas[0].persona_id) return String(personas[0].persona_id);
  return '';
}
async function getJSON(url, opts){
  const r=await fetch(url,opts);
  const t=await r.text();
  let data;
  try{ data=JSON.parse(t); }catch(e){ throw new Error('API not JSON: '+t.slice(0,300)); }
  if(!r.ok && data && data.message) throw new Error(data.message);
  return data;
}
const fields=['persona_id','persona_name','relationship','gender','birth_date','persona_type','persona_status','short_bio','speaking_style','catchphrases'];

function bindEvents(){
  const map = {
    newBtn:()=>fillForm({gender:'unknown',persona_type:'family',persona_status:'active'}),
    savePersonaBtn:savePersona,
    uploadAssetsBtn:uploadSelectedAssets,
    prepareVoiceBtn:prepareVoiceClone,
    startCameraBtn:startCamera,
    capturePhotoBtn:capturePhoto,
    startRecordBtn:startRecording,
    stopRecordBtn:stopRecording,
    openMetaPersonBtn:openMetaPersonCreator,
    sendPhotoToMetaPersonBtn:sendActivePhotoToMetaPerson,
    exportMetaPersonBtn:exportMetaPersonAvatar,
    saveExportedModelBtn:saveExportedMetaPersonModel,
    saveAvatarModelBtn:saveAvatarModel,
    closeMetaPersonBtn:closeMetaPersonCreator
  };
  Object.entries(map).forEach(([id,fn])=>{
    const el=byId(id);
    if(!el) return;
    el.addEventListener('click', ev=>{ev.preventDefault(); ev.stopPropagation(); fn();}, false);
  });
}

async function init(){
  bindEvents();
  window.hmPrepareVoiceClone = prepareVoiceClone;
  window.addEventListener('message', onMetaPersonMessage);
  await loadMetaPersonCredentials();
  await loadPersonas();
}

async function loadPersonas(){
  try{
    const d=await getJSON(API_BASE+'persona_studio.cfm?action=list&_=' + Date.now());
    personas=d.rows||[];
    if(!selectedId && personas.length){ selectedId=String(personas[0].persona_id); }
    const p=personas.find(x=>String(x.persona_id)===String(selectedId)) || personas[0] || {gender:'unknown',persona_type:'family',persona_status:'active'};
    fillForm(p);
    renderRows();
    await loadAssets();
  }catch(e){ setHTML('personaRows','<div class="voiceError">Persona load failed: '+esc(e.message)+'</div>'); }
}

function renderRows(){
  const box=byId('personaRows');
  if(!box) return;
  if(!personas.length){ box.innerHTML='<div class="muted">No personas yet. Click New Persona.</div>'; return; }
  box.innerHTML=personas.map(p=>`<div class="personaListRow ${String(p.persona_id)===String(selectedId)?'active':''}" data-persona-id="${esc(p.persona_id)}">
    <div class="miniPhoto">${p.reference_photo_url||p.image_url?`<img src="../${esc(p.reference_photo_url||p.image_url)}">`:(esc((p.persona_name||'?').slice(0,1)))}</div>
    <div class="personaListBody"><b>${esc(p.persona_name)}</b><br><span>${esc(p.relationship)} · ${esc(p.gender)}</span><br><span class="muted">Voice: ${esc(p.voice_provider||'browser_tts')} · ${esc(p.voice_clone_status||'not_trained')} ${p.provider_voice_id?'· '+esc(p.provider_voice_id):''}</span><br><span class="muted">Avatar: ${p.model_url?'3D GLB ready':'photo/fallback'}</span></div>
    <button class="btn secondary" type="button">Edit</button>
  </div>`).join('');
  box.querySelectorAll('.personaListRow').forEach(row=>{
    row.addEventListener('click',()=>selectPersona(row.getAttribute('data-persona-id')));
  });
}

async function selectPersona(id){
  selectedId=String(id||'');
  const p=personas.find(x=>String(x.persona_id)===String(selectedId))||{};
  fillForm(p);
  renderRows();
  await loadAssets();
}
window.selectPersona=selectPersona;

function fillForm(p){
  for(const f of fields){ setVal(f, p[f] ?? ''); }
  if(!val('gender')) setVal('gender','unknown');
  if(!val('persona_type')) setVal('persona_type','family');
  if(!val('persona_status')) setVal('persona_status','active');
  setVal('avatar_model_url', p.model_url || '');
  setVal('provider_avatar_id', p.provider_avatar_id || '');
  selectedId = val('persona_id') || selectedId || '';
  setText('saveStatus', selectedId ? `Selected persona_id=${selectedId}` : 'New persona. Save before uploading assets.');
  setText('uploadStatus', selectedId ? 'Ready. You can upload assets or prepare clone from existing voice samples.' : 'Select a persona first.');
}

async function savePersona(){
  const data={};
  fields.forEach(f=>data[f]=val(f));
  if(!data.persona_name.trim()){setText('saveStatus','Name is required.');return;}
  setText('saveStatus','Saving...');
  try{
    const d=await getJSON(API_BASE+'persona_studio.cfm?action=save',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)});
    selectedId=String(d.persona_id);
    setVal('persona_id',selectedId);
    setText('saveStatus','Saved persona_id='+selectedId);
    await loadPersonas();
  }catch(e){setText('saveStatus','Save failed: '+e.message);}
}

async function loadAssets(){
  const box=byId('assetRows');
  if(!box) return;
  const id=currentPersonaId();
  if(!id){box.innerHTML='<div class="muted">Select/save a persona first.</div>';return;}
  try{
    const d=await getJSON(API_BASE+'persona_studio.cfm?action=assets&persona_id='+encodeURIComponent(id)+'&_='+Date.now());
    const rows=d.rows||[];
    const voiceCount=rows.filter(a=>a.asset_type==='voice').length;
    if(voiceCount>0) setText('cloneStatus',`Found ${voiceCount} voice sample(s). Click Prepare Voice Clone to create/update provider voice.`);
    if(!rows.length){box.innerHTML='<div class="muted">No uploaded assets yet.</div>';return;}
    box.innerHTML=rows.map(a=>`<div class="assetRow"><span class="assetType ${esc(a.asset_type)}">${esc(a.asset_type)}</span><a href="../${esc(a.file_url)}" target="_blank">${esc(a.file_name||a.file_url)}</a><span class="muted">${esc(a.mime_type||'')} · ${esc(a.created_at||'')}</span></div>`).join('');
  }catch(e){ box.innerHTML='<div class="voiceError">Asset load failed: '+esc(e.message)+'</div>'; }
}

async function uploadOne(type,file){
  const id=currentPersonaId();
  if(!id) throw new Error('Save/select a persona first.');
  const fd=new FormData();
  fd.append('persona_id', id);
  fd.append('asset_type', type);
  fd.append('upload_file', file, file.name||(`${type}_${Date.now()}`));
  return getJSON(API_BASE+'persona_studio.cfm?action=upload',{method:'POST',body:fd});
}

async function uploadSelectedAssets(){
  if(uploadBusy) return;
  const id=currentPersonaId();
  if(!id){ setText('uploadStatus','Save/select a persona first.'); return; }
  setVal('persona_id', id);
  const photoEl=byId('photoFiles'), voiceEl=byId('voiceFiles');
  const photos=photoEl ? Array.from(photoEl.files||[]) : [];
  const voices=voiceEl ? Array.from(voiceEl.files||[]) : [];
  if(!photos.length && !voices.length){setText('uploadStatus','Choose at least one photo or voice file.'); return;}
  uploadBusy=true;
  const btn=byId('uploadAssetsBtn'); if(btn) btn.disabled=true;
  setText('uploadStatus',`Uploading ${photos.length} photos and ${voices.length} voice samples...`);
  try{
    for(const f of photos) await uploadOne('photo',f);
    for(const f of voices) await uploadOne('voice',f);
    setText('uploadStatus','Uploaded. Latest photo/voice is now active for this persona.');
    if(photoEl) photoEl.value=''; if(voiceEl) voiceEl.value='';
    await loadPersonas(); await loadAssets();
  }catch(e){ setText('uploadStatus','Upload failed: '+e.message); }
  finally{uploadBusy=false; if(btn) btn.disabled=false;}
}

async function prepareVoiceClone(){
  if(prepareBusy) return;
  const pid = currentPersonaId();
  const btn = byId('prepareVoiceBtn');
  if(!pid){ setText('cloneStatus','Save/select a persona first.'); return; }
  setVal('persona_id', pid);
  setText('cloneStatus','Calling MiniMax voice clone bridge...');
  prepareBusy=true; if(btn) btn.disabled=true;
  try{
    const selectedName=(val('persona_name')||'this persona').trim();
    const previewText=`你好，我是${selectedName}。今天天气很好，我们慢慢聊。`;
    const d=await getJSON(API_BASE+'voice.cfm?_='+Date.now(),{
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body:JSON.stringify({persona_id:pid,text:previewText,action:'prepare_clone'})
    });
    if(!d.success) throw new Error(d.message||d.error||'voice clone failed');
    const audio=d.audio_url?` <a href="../${esc(d.audio_url)}" target="_blank">Preview audio</a>`:'';
    if(d.provider_voice_id){
      setHTML('cloneStatus',`Voice clone ready. Provider: ${esc(d.provider||'minimax')} · voice_id: ${esc(d.provider_voice_id)}.${audio}`);
    }else if(String(d.mode||'').includes('fallback') || d.provider==='browser_tts'){
      setHTML('cloneStatus','Voice provider not ready; fallback only. '+esc(d.warning||d.message||''));
    }else{
      setHTML('cloneStatus','Voice request completed. '+esc(d.message||'')+audio);
    }
    await loadPersonas(); await loadAssets();
  }catch(e){ setText('cloneStatus','Prepare voice clone failed: '+e.message); }
  finally{ prepareBusy=false; if(btn) btn.disabled=false; }
}
window.hmPrepareVoiceClone=prepareVoiceClone;

async function startCamera(){
  try{ mediaStream=await navigator.mediaDevices.getUserMedia({video:true,audio:false}); const v=byId('cameraVideo'); if(v) v.srcObject=mediaStream; }
  catch(e){ setText('uploadStatus','Camera failed: '+e.message); }
}
async function capturePhoto(){
  if(!currentPersonaId()){ setText('uploadStatus','Save/select a persona first.'); return; }
  const v=byId('cameraVideo'), canvas=byId('photoCanvas');
  if(!v || !canvas){ setText('uploadStatus','Camera UI not found.'); return; }
  if(!v.srcObject){ await startCamera(); }
  const w=v.videoWidth||640, h=v.videoHeight||480; canvas.width=w; canvas.height=h; canvas.getContext('2d').drawImage(v,0,0,w,h);
  canvas.toBlob(async blob=>{ if(!blob){setText('uploadStatus','Capture failed.');return;} const file=new File([blob],`camera_photo_${Date.now()}.jpg`,{type:'image/jpeg'}); try{setText('uploadStatus','Uploading captured photo...'); await uploadOne('photo',file); setText('uploadStatus','Captured photo uploaded.'); await loadPersonas(); await loadAssets();}catch(e){setText('uploadStatus','Photo upload failed: '+e.message);} },'image/jpeg',0.92);
}
async function startRecording(){
  if(!currentPersonaId()){ setText('uploadStatus','Save/select a persona first.'); return; }
  try{
    chunks=[]; const stream=await navigator.mediaDevices.getUserMedia({audio:true}); recorder=new MediaRecorder(stream);
    recorder.ondataavailable=e=>{if(e.data.size)chunks.push(e.data)};
    recorder.onstart=()=>{const dot=byId('recordDot'); if(dot) dot.classList.add('on'); setText('recordStatus','Recording... say a clear reference sentence.');};
    recorder.start();
  }catch(e){ setText('recordStatus','Microphone failed: '+e.message); }
}
async function stopRecording(){
  if(!recorder){setText('recordStatus','No active recording.');return;}
  recorder.onstop=async()=>{
    const dot=byId('recordDot'); if(dot) dot.classList.remove('on');
    const blob=new Blob(chunks,{type:'audio/webm'});
    const preview=byId('recordPreview'); if(preview) preview.src=URL.createObjectURL(blob);
    const file=new File([blob],`voice_sample_${Date.now()}.webm`,{type:'audio/webm'});
    try{setText('recordStatus','Uploading recorded voice...'); await uploadOne('voice',file); setText('recordStatus','Recorded voice uploaded. This becomes the active speaker reference.'); await loadPersonas(); await loadAssets();}
    catch(e){setText('recordStatus','Voice upload failed: '+e.message);}
  };
  recorder.stop(); recorder.stream.getTracks().forEach(t=>t.stop()); recorder=null;
}


async function loadMetaPersonCredentials(){
  try{
    const d=await getJSON(API_BASE+'persona_studio.cfm?action=metaperson_config&_=' + Date.now());
    metaPersonCredentials={client_id:d.client_id||'', client_secret:d.client_secret||'', configured:!!d.configured};
    setText('metapersonConfigStatus', d.configured ? ('MetaPerson configured on server: '+(d.client_id_prefix||'client id loaded')) : 'MetaPerson server config missing. Set METAPERSON_CLIENT_ID and METAPERSON_CLIENT_SECRET, then reload.');
  }catch(e){
    metaPersonCredentials={client_id:'', client_secret:'', configured:false};
    setText('metapersonConfigStatus','MetaPerson config check failed: '+e.message);
  }
}
function saveMetaPersonCredentials(){ return metaPersonCredentials.configured; }
function metaFrame(){return byId('metapersonFrame');}
function setMetaProgress(text, pct){
  setText('metaPersonStatus', text || 'MetaPerson working...');
  const label=byId('metapersonProgressText'); if(label) label.textContent=text || '';
  const bar=byId('metapersonProgressBar'); if(bar && typeof pct==='number') bar.style.width=Math.max(0,Math.min(100,pct))+'%';
}
function postMetaPerson(msg){
  const f=metaFrame();
  if(!f || !f.contentWindow){ setText('metaPersonStatus','Open MetaPerson Creator first.'); return false; }
  f.contentWindow.postMessage(msg, '*');
  return true;
}
function sendMetaPersonSetup(){
  const cid=metaPersonCredentials.client_id, sec=metaPersonCredentials.client_secret;
  if(!cid || !sec){ setText('metaPersonStatus','MetaPerson server config missing. Set METAPERSON_CLIENT_ID / METAPERSON_CLIENT_SECRET and reload.'); return false; }
  postMetaPerson({eventName:'authenticate', clientId:cid, clientSecret:sec});
  postMetaPerson({eventName:'set_export_parameters', format:'glb', lod:1, textureProfile:'1K.jpg', useZip:false, headOnly:'false', removeNeckLayers:0});
  postMetaPerson({eventName:'set_ui_parameters',
    language:'EN',
    showLatestCreatedAvatar:true,
    isExportButtonVisible:false,
    isScreenshotButtonVisible:false,
    closeExportDialogWhenExportCompleted:true,
    // Keep MetaPerson's own loading / progress / generated model visible.
    // Only ask SDK to hide the internal photo-entry buttons when supported.
    isTakeSelfieButtonVisible:false,
    isBrowsePhotoButtonVisible:false,
    isUploadPhotoButtonVisible:false,
    isTakePhotoButtonVisible:false,
    hideUploadPhotoButton:true,
    hideTakeSelfieButton:true,
    defaultPipeline:(val('gender')==='female'?'female':'male'),
    enableLipsync:false
  });
  return true;
}
function scheduleMetaPersonSetup(){
  [0,500,1200,2500,4500].forEach(ms=>setTimeout(()=>sendMetaPersonSetup(), ms));
}
function openMetaPersonCreator(){
  saveMetaPersonCredentials();
  const wrap=byId('metapersonFrameWrap');
  const frame=byId('metapersonFrame');
  if(wrap){
    wrap.style.display='block';
    wrap.scrollIntoView({behavior:'smooth', block:'start'});
  }
  if(frame){
    frame.style.width='100%';
    frame.style.height='760px';
    frame.style.minHeight='720px';
  }
  document.body.classList.remove('metapersonModalOpen');
  setMetaProgress('Creator opened. Loading MetaPerson iframe...', 15);
  scheduleMetaPersonSetup();
}
function closeMetaPersonCreator(){
  const wrap=byId('metapersonFrameWrap');
  if(wrap) wrap.style.display='none';
  document.body.classList.remove('metapersonModalOpen');
  setMetaProgress('Creator closed. If GLB was exported, click Save Exported GLB.', 0);
}
function onMetaPersonMessage(evt){
  const data=evt.data || {};
  if(data.source !== 'metaperson_creator' && !data.eventName) return;
  console.log('[MetaPerson message]', data);
  const evtName=data.eventName;
  const lowerName=String(evtName||'').toLowerCase();
  if(lowerName.includes('generation') || lowerName.includes('generate')){
    if(data.status && String(data.status).toLowerCase().includes('progress')) setMetaProgress('Generating 3D avatar...', 70);
  }
  if(lowerName.includes('error') || data.errorMessage || data.error){
    setMetaProgress('MetaPerson error: '+(data.errorMessage||data.error||evtName), 5);
  }
  if(evtName === 'metaperson_creator_loaded' || evtName === 'creator_loaded' || evtName === 'loaded'){
    metaPersonLoaded=true;
    setMetaProgress('Creator loaded. Authenticating with server-side MetaPerson credentials...', 30);
    scheduleMetaPersonSetup();
  }
  if(evtName === 'authentication_status' || evtName === 'authenticationStatus'){
    setMetaProgress(data.isAuthenticated ? 'Authenticated. Click Generate From Active Photo.' : ('MetaPerson auth failed: '+(data.errorMessage||'check credentials')), data.isAuthenticated ? 45 : 10);
  }
  if(evtName === 'action_availability_changed'){
    if(data.actionName === 'avatar_export') metaPersonExportAvailable = !!data.isAvailable;
    if(data.actionName === 'avatar_generation' && data.isAvailable) setMetaProgress('MetaPerson ready. Click Generate From Active Photo.', 50);
    if(data.actionName === 'avatar_export' && data.isAvailable) setMetaProgress('Avatar ready for export. Click Export GLB.', 85);
  }
  if(evtName === 'model_generated' || evtName === 'avatar_generated' || evtName === 'model_created'){
    metaPersonExport.avatar_code = data.avatarCode || metaPersonExport.avatar_code || '';
    setMetaProgress('3D avatar generated. Click Export GLB.', 85);
  }
  if(evtName === 'model_exported' || evtName === 'avatar_exported' || evtName === 'export_result' || evtName === 'avatar_export_result' || evtName === 'download_url_generated') {
    metaPersonExport.model_url = data.url || data.modelUrl || data.glbUrl || data.fileUrl || data.downloadUrl || data.file_url || data.model_url || data.avatarUrl || data.avatar_url || (data.data && (data.data.url||data.data.glbUrl||data.data.fileUrl||data.data.downloadUrl||data.data.avatarUrl)) || '';
    metaPersonExport.avatar_code = data.avatarCode || metaPersonExport.avatar_code || '';
    metaPersonExport.avatar_state = data.avatarState || '';
    setVal('avatar_model_url', metaPersonExport.model_url);
    setVal('provider_avatar_id', metaPersonExport.avatar_code);
    setMetaProgress('GLB exported. Click Save Exported GLB.', 100);
  }
  if(evtName === 'model_screenshot'){
    metaPersonExport.screenshot_url = data.screenshotUrl || metaPersonExport.screenshot_url || '';
  }
}
async function sendActivePhotoToMetaPerson(){
  const wrap=byId('metapersonFrameWrap');
  if(!wrap || wrap.style.display==='none') openMetaPersonCreator();
  scheduleMetaPersonSetup();
  const p=personas.find(x=>String(x.persona_id)===String(currentPersonaId())) || {};
  const photoUrl=p.reference_photo_url || p.image_url || '';
  if(!photoUrl){ setText('metaPersonStatus','Upload/select a clear front photo first.'); return; }
  try{
    setMetaProgress('Reading active persona photo...', 55);
    const r=await fetch('../'+photoUrl, {cache:'no-store'});
    if(!r.ok) throw new Error('Cannot read active photo: HTTP '+r.status);
    const blob=await r.blob();
    const base64=await new Promise((resolve,reject)=>{ const fr=new FileReader(); fr.onload=()=>resolve(String(fr.result).split(',')[1]||''); fr.onerror=reject; fr.readAsDataURL(blob); });
    const gender=(val('gender')||p.gender||'').toLowerCase()==='female'?'female':'male';
    const dataUrl='data:'+blob.type+';base64,'+base64;
    const msg={eventName:'generate_avatar', gender, age:'adult', image:base64, imageData:base64, photo:dataUrl, dataUrl:dataUrl};
    postMetaPerson(msg);
    setTimeout(()=>postMetaPerson(msg), 1000);
    setTimeout(()=>postMetaPerson(msg), 2500);
    setMetaProgress('Active photo sent. Generating 3D avatar, usually 30–90 seconds. Keep this page open.', 65);
  }catch(e){ setText('metaPersonStatus','Generate failed: '+e.message); }
}
function exportMetaPersonAvatar(){
  postMetaPerson({eventName:'set_export_parameters', format:'glb', lod:1, textureProfile:'1K.jpg', useZip:false, headOnly:'false', removeNeckLayers:0});
  postMetaPerson({eventName:'export_avatar'});
  setTimeout(()=>postMetaPerson({eventName:'export_avatar'}), 800);
  setMetaProgress('Export requested. Waiting for GLB URL from MetaPerson...', 92);
}
async function saveAvatarModel(){
  const pid=currentPersonaId();
  if(!pid){ setText('metaPersonStatus','Select/save a persona first.'); return; }
  const modelUrl=val('avatar_model_url').trim();
  const code=val('provider_avatar_id').trim();
  if(!modelUrl && !code){ setText('metaPersonStatus','No GLB URL/avatar code to save.'); return; }
  try{
    const d=await getJSON(API_BASE+'persona_studio.cfm?action=save_avatar_model',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({persona_id:pid,model_url:modelUrl,provider_avatar_id:code,screenshot_url:metaPersonExport.screenshot_url||''})});
    setText('metaPersonStatus','Saved 3D avatar. Open Hologram Agent to view GLB.');
    await loadPersonas();
  }catch(e){ setText('metaPersonStatus','Save 3D avatar failed: '+e.message); }
}
async function saveExportedMetaPersonModel(){
  if(metaPersonExport.model_url){ setVal('avatar_model_url', metaPersonExport.model_url); }
  if(metaPersonExport.avatar_code){ setVal('provider_avatar_id', metaPersonExport.avatar_code); }
  await saveAvatarModel();
}

init().catch(e=>{document.body.insertAdjacentHTML('beforeend','<div class="status voiceError">'+esc(e.message)+'</div>')});
