<!doctype html><html><head><meta charset="utf-8"><title>HoloMemory AI</title>

<cfoutput>
<link rel="stylesheet" href="assets/css/app.css?v=#randRange(1,10000)#">

</cfoutput>

</head><body>
<div class="layout homeDemo">
  <cfmodule template="admin/menu.cfm" active="hologram">
  <main class="main homeMain">
    <section class="emotionalHero">
      <div class="heroIntro">
        <div class="heroBadge">Digital Human · Voice Clone · Memory RAG · Evidence Grounding</div>
        <h1>HoloMemory AI</h1>
        <h2>A Memory-Grounded Digital Human Platform for Families and Future Generations</h2>
        <p>Preserve memories, voices, and wisdom across generations.</p>
      </div>

      <div class="heroDemoGrid">
        <div class="avatarHeroPanel">
          <div class="holoStage heroHoloStage">
            <div class="memoryOrbit"><span class="orb"></span><span class="orb"></span><span class="orb"></span></div>
            <div class="holoTube"><div class="scan"></div></div>
            <div id="avatar3dContainer" class="avatar3dContainer" style="display:none"></div>
            <div id="avatar" class="avatar"><div id="photoFace" class="photoFace"></div><div class="head"><div class="eye left"></div><div class="eye right"></div><div class="mouth"></div></div><div class="body"></div><div class="legs"></div></div>
            <div class="avatarStatus" id="avatarState">idle · calm</div>
            <div class="holoBase"></div>
          </div>
        </div>

        <div class="demoConversationPanel">
          <div class="askGrandpaCard">
            <span>Ask Grandpa</span>
            <blockquote>"Do you remember our Ocean Park family trip?"</blockquote>
            <div class="groundedAiFlow" aria-label="Memory retrieval, Google Gemini generation, and cloned voice">
              <b>Memory retrieval</b>
              <i aria-hidden="true">→</i>
              <b class="geminiFlowStep"><span class="googleSpark" aria-hidden="true"></span>Google Gemini</b>
              <i aria-hidden="true">→</i>
              <b>Cloned voice</b>
            </div>
            <div class="demoButtonRow">
              <button class="btn tryDemoBtn" id="tryGrandpaBtn" onclick="tryGrandpaDemo()">Try Grandpa Demo</button>
              <button class="btn judgeModeBtn" id="judgeModeBtn" onclick="runJudgeMode()">Judge Mode</button>
            </div>
            <button class="gestureReactionBtn" id="gestureReactionBtn" type="button" onclick="enableGestureReaction()">Wave to Grandpa</button>
            <div class="gestureStatus" id="gestureStatus">Camera stays on this device. No frames are uploaded.</div>
            <video id="gestureVideo" class="gestureVideo" playsinline muted></video>
            <canvas id="gestureCanvas" class="gestureCanvas" width="96" height="72"></canvas>
          </div>

          <div id="result" class="heroResult">
            <div class="emptyResult">
              <h3>Grandpa Li is ready.</h3>
              <p>Run the demo to hear a memory-grounded answer with retrieved family evidence.</p>
              <div class="geminiGroundingBadge">
                <span class="googleSpark" aria-hidden="true"></span>
                <span><b>Google Gemini</b> composes the answer from retrieved memories</span>
              </div>
              <div class="placeholderEvidence">
                <span>Memory Evidence Found</span>
                <b>Ocean Park Family Trip</b>
                <b>Family Dinner Advice</b>
                <b>Voice Memory</b>
              </div>
            </div>
          </div>

          <div class="manualAskPanel">
            <label>Manual ask</label>
            <div class="manualAskRow">
              <select id="personaSelect"></select>
              <input id="question" value="Do you remember our Ocean Park family trip?">
              <button class="btn secondary" onclick="runAgent()">Run Memory Agent</button>
            </div>
          </div>
        </div>
      </div>
    </section>

    <section class="whyItMatters">
      <p>AI answers questions.</p>
      <p>HoloMemory preserves people.</p>
      <h2>Future generations can continue conversations with the voices, memories, and wisdom of those they love.</h2>
    </section>

    <section class="systemOverview">
      <div class="sectionHeading">
        <span>System Overview</span>
        <p>Human memories, voices, and digital personas ready for family conversations.</p>
      </div>
      <div class="stats">
        <div class="card stat"><h3>Digital Personas</h3><div id="s_personas" class="num">--</div></div>
        <div class="card stat"><h3>Family Memories</h3><div id="s_memories" class="num">--</div></div>
        <div class="card stat"><h3>Retrieved Story Links</h3><div id="s_chunks" class="num">--</div></div>
        <div class="card stat"><h3>Voice Memories</h3><div id="s_voices" class="num">--</div></div>
      </div>
    </section>
  </main>
</div>
<cfoutput>
<script src="assets/js/app.js?v=#randRange(1,10000)#"></script>
</cfoutput>
</body></html>
