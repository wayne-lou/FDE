<!doctype html><html><head><meta charset="utf-8"><title>Persona Studio</title><link rel="stylesheet" href="../assets/css/app.css"></head><body>
<div class="layout">
  <cfmodule template="menu.cfm" active="persona_studio">
  <main class="main">
    <section class="hero"><h1>Persona Studio</h1><div class="muted">Create/edit a persona, manage photos + voice samples, and capture photo/audio directly in browser. This replaces the old separate Personas / Voice Profiles / Avatar Profiles operation.</div></section>
    <section class="studioGrid">
      <div class="card">
        <div class="splitTitle"><h2>Persona List</h2><button class="btn secondary" id="newBtn" type="button">New Persona</button></div>
        <div id="personaRows" class="personaRows"></div>
      </div>
      <div class="card">
        <h2>Create / Edit Persona + Voice + Avatar</h2>
        <input type="hidden" id="persona_id">
        <div class="formGrid twoCols">
          <div class="field"><label>Name</label><input id="persona_name" placeholder="Grandpa Li"></div>
          <div class="field"><label>Relationship</label><input id="relationship" placeholder="grandfather / mother / friend / pet"></div>
          <div class="field"><label>Gender</label><select id="gender"><option value="male">male</option><option value="female">female</option><option value="pet">pet</option><option value="unknown">unknown</option></select></div>
          <div class="field"><label>Birth date</label><input id="birth_date" type="date"></div>
          <div class="field"><label>Persona type</label><select id="persona_type"><option value="family">family</option><option value="friend">friend</option><option value="pet">pet</option><option value="self_archive">self_archive</option></select></div>
          <div class="field"><label>Status</label><select id="persona_status"><option value="active">active</option><option value="inactive">inactive</option><option value="archived">archived</option></select></div>
        </div>
        <div class="field"><label>Short bio</label><textarea id="short_bio" rows="3" placeholder="Who this person is and what memories matter."></textarea></div>
        <div class="field"><label>Speaking style / tone</label><textarea id="speaking_style" rows="3" placeholder="Warm, calm, concise, often says..."></textarea></div>
        <div class="field"><label>Catchphrases / words often used</label><textarea id="catchphrases" rows="3" placeholder="别着急；慢慢来；吃好睡好"></textarea></div>
        <div class="formGrid twoCols avatarModelFields">
          <div class="field"><label>3D Avatar GLB URL</label><input id="avatar_model_url" placeholder="https://.../avatar.glb"></div>
          <div class="field"><label>MetaPerson Avatar Code</label><input id="provider_avatar_id" placeholder="avatar code from MetaPerson export"></div>
        </div>
        <div class="studioActions"><button class="btn" id="savePersonaBtn" type="button">Save Persona</button><button class="btn secondary" id="saveAvatarModelBtn" type="button">Save 3D Avatar</button><span id="saveStatus" class="muted">No row selected.</span></div>
      </div>
    </section>

    <section class="card metapersonCard">
      <div class="splitTitle"><div><h2>3D Avatar Generator · MetaPerson</h2><div class="muted">Generate a true 3D avatar from a photo, export GLB, then Hologram Agent will render the GLB with Three.js. REST API is Enterprise-only; this uses the official iframe + JS message flow.</div></div><button class="btn secondary" id="openMetaPersonBtn" type="button">Open Creator</button></div>
      <div class="status muted" id="metapersonConfigStatus">MetaPerson keys are read from server-side configuration. They are no longer displayed on this page.</div>
      <div class="studioActions">
        <button class="btn secondary" id="sendPhotoToMetaPersonBtn" type="button">Generate From Active Photo</button>
        <button class="btn secondary" id="exportMetaPersonBtn" type="button">Export GLB</button>
        <button class="btn" id="saveExportedModelBtn" type="button">Save Exported GLB</button>
        <span id="metaPersonStatus" class="muted">Open Creator after selecting a persona with a clear front photo. Creator is embedded inline; use buttons above.</span>
      </div>
      <div class="metapersonProgress" id="metapersonProgress">
        <div class="metapersonProgressTop"><b>MetaPerson Status</b><span id="metapersonProgressText">Waiting.</span></div>
        <div class="metapersonProgressTrack"><div id="metapersonProgressBar" class="metapersonProgressBar" style="width:0%"></div></div>
        <div class="muted smallText">Use external buttons: Generate From Active Photo → Export GLB → Save Exported GLB. The iframe progress and generated model remain visible.</div>
      </div>
      <div class="metapersonFrameWrap" id="metapersonFrameWrap" style="display:none">
        <div class="metapersonToolbar">
          <b>MetaPerson Creator</b>
          <span class="muted">Embedded creator. Use external buttons only: Generate From Active Photo → Export GLB → Save Exported GLB. Ignore MetaPerson's internal upload controls if they appear.</span>
          <button class="btn secondary smallBtn" id="closeMetaPersonBtn" type="button">Close Creator</button>
        </div>
        <iframe id="metapersonFrame" src="https://metaperson.avatarsdk.com/iframe.html" allow="fullscreen; microphone; camera" frameborder="0"></iframe>
      </div>
    </section>

    <section class="studioGrid">
      <div class="card">
        <h2>Assets: Photos + Voice Samples</h2>
        <div class="assetPanel">
          <div class="field"><label>Upload multiple photos</label><input id="photoFiles" type="file" accept="image/*" multiple></div>
          <div class="field"><label>Upload multiple voice samples</label><input id="voiceFiles" type="file" accept="audio/*" multiple></div>
          <button class="btn" id="uploadAssetsBtn" type="button">Upload Assets</button>
          <button class="btn secondary" id="prepareVoiceBtn" type="button" >Prepare Voice Clone</button>
          <div id="uploadStatus" class="status">Select a persona first.</div>
          <div id="cloneStatus" class="status muted">Upload a voice sample, then prepare clone profile.</div>
        </div>
        <h3>Captured / Uploaded Assets</h3>
        <div id="assetRows" class="assetRows muted">No assets loaded.</div>
      </div>
      <div class="card">
        <h2>Live Capture</h2>
        <div class="captureGrid">
          <div>
            <h3>Camera photo</h3>
            <video id="cameraVideo" autoplay playsinline muted></video>
            <canvas id="photoCanvas" style="display:none"></canvas>
            <div class="studioActions"><button class="btn secondary" id="startCameraBtn" type="button">Start Camera</button><button class="btn" id="capturePhotoBtn" type="button">Capture + Upload</button></div>
          </div>
          <div>
            <h3>Voice recording</h3>
            <div class="recordBox"><div id="recordDot" class="recordDot"></div><div id="recordStatus">Ready to record a voice sample.</div></div>
            <div class="studioActions"><button class="btn secondary" id="startRecordBtn" type="button">Start Recording</button><button class="btn" id="stopRecordBtn" type="button">Stop + Upload</button></div>
            <audio id="recordPreview" controls style="width:100%;margin-top:12px"></audio>
          </div>
        </div>
      </div>
    </section>

    <section class="card"><h2>Voice Clone Requirement</h2><p class="muted">A persona can have multiple photos and voice samples. The latest uploaded or recorded voice becomes the active speaker reference. Click <b>Prepare Voice Clone</b> after uploading a voice sample. It calls the existing <code>/api/voice.cfm</code> flow, registers the latest voice sample with MiniMax through the local Python bridge, saves <code>provider_voice_id</code>, and generates preview audio. If provider fails, the UI will show fallback instead of pretending success.</p><pre>cd C:\inetpub\demos\demo_hm\voice_clone_service
venv313\Scripts\activate
set HM_VOICE_PROVIDER=minimax
set MINIMAX_REGION=cn
set MINIMAX_API_HOST=https://api.minimax.chat
set MINIMAX_API_KEY=your_key
set HM_PUBLIC_BASE_URL=http://demos.e-xanke.com/demo_hm
python server.py --project-root C:\inetpub\demos\demo_hm</pre></section>
  </main>
</div>
<script src="../assets/js/persona_manager.js?v=28"></script>
</body></html>
