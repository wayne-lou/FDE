<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Memory Retrieval Explorer &middot; HoloMemory AI</title>
  <cfoutput><link rel="stylesheet" href="../assets/css/app.css?v=#randRange(10000,99999)#"></cfoutput>
  <style>
    :root{--bg:#050e19;--panel:#0b1b2d;--line:rgba(83,202,255,.27);--text:#f3f8ff;--muted:#93afc9;--cyan:#49dcff;--green:#70f5ad}
    *{box-sizing:border-box}
    html,body{margin:0;min-height:100%;background:var(--bg);color:var(--text);font-family:Inter,Arial,"Microsoft Yahei",sans-serif}
    body{background:radial-gradient(circle at 45% -12%,rgba(73,220,255,.13),transparent 34%),radial-gradient(circle at 88% 64%,rgba(112,245,173,.07),transparent 28%),var(--bg)}
    .showcase-shell .layout{grid-template-columns:260px minmax(0,1fr)}
    .showcase-page{width:100%;min-width:0;min-height:100vh;margin:0;padding:22px 28px 18px;display:flex;flex-direction:column}
    .showcase-hero{display:flex;align-items:end;justify-content:space-between;gap:28px;margin-top:13px}
    .eyebrow{display:block;margin-bottom:7px;color:var(--green);font-size:10px;font-weight:900;letter-spacing:.13em;text-transform:uppercase}
    h1{margin:0;font-size:43px;line-height:1.04}
    .showcase-hero p{max-width:460px;margin:0;color:#a4c0d9;font-size:14px;line-height:1.5;text-align:right}
    .stat-pills{display:flex;gap:10px;margin:17px 0 15px;padding-bottom:15px;border-bottom:1px solid rgba(73,220,255,.18)}
    .stat-pill{flex:1;min-width:0;padding:10px 14px;border:1px solid rgba(73,220,255,.23);border-radius:999px;background:rgba(8,23,39,.76);color:#91aec8;font-size:11px;text-align:center}
    .stat-pill b{margin-right:5px;color:#effaff;font-size:14px}
    .explorer-layout{display:grid;grid-template-columns:minmax(0,1.42fr) minmax(320px,.78fr);gap:15px;flex:1;min-height:0}
    .memory-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));grid-template-rows:repeat(3,1fr);gap:11px}
    .memory-card{position:relative;min-width:0;padding:14px 15px;border:1px solid rgba(73,220,255,.23);border-radius:9px;background:linear-gradient(145deg,rgba(15,36,58,.94),rgba(7,18,31,.96));box-shadow:inset 0 0 24px rgba(73,220,255,.025);cursor:pointer;transition:.2s}
    .memory-card:hover,.memory-card.selected{border-color:rgba(112,245,173,.60);box-shadow:0 0 26px rgba(73,220,255,.08),inset 0 0 28px rgba(112,245,173,.035)}
    .memory-card.selected:before{content:"";position:absolute;left:-1px;top:16px;bottom:16px;width:3px;border-radius:3px;background:var(--green);box-shadow:0 0 12px var(--green)}
    .memory-card-head,.memory-card-foot{display:flex;align-items:center;justify-content:space-between;gap:10px}
    .memory-type{padding:4px 8px;border:1px solid rgba(73,220,255,.28);border-radius:999px;background:rgba(73,220,255,.07);color:#a9eaff;font-size:9px;font-weight:900;letter-spacing:.06em;text-transform:uppercase}
    .memory-date{color:#6f8ca7;font-size:10px}
    .memory-card h2{margin:13px 0 8px;color:#f5faff;font-size:17px;line-height:1.25}
    .memory-source{margin:0 0 12px;color:#82a1bd;font-size:11px}
    .memory-card-foot{padding-top:10px;border-top:1px solid rgba(73,220,255,.11);font-size:10px}
    .emotion{color:#c3d8e9}.emotion b{color:#fff;text-transform:capitalize}
    .ready{color:#82f7b1;font-weight:850}
    .memory-card:last-child{grid-column:1/-1}
    .detail-panel{min-width:0;padding:20px;border:1px solid rgba(112,245,173,.34);border-radius:10px;background:linear-gradient(145deg,rgba(14,34,55,.97),rgba(6,17,29,.98));box-shadow:0 20px 54px rgba(0,0,0,.24),inset 0 0 34px rgba(112,245,173,.035);display:flex;flex-direction:column}
    .panel-label{display:flex;align-items:center;gap:9px;color:#add9ee;font-size:10px;font-weight:900;letter-spacing:.1em;text-transform:uppercase}
    .panel-label:before{content:"";width:8px;height:8px;border-radius:50%;background:var(--green);box-shadow:0 0 12px var(--green)}
    .detail-panel h2{margin:19px 0 5px;font-size:25px;line-height:1.18}
    .detail-source{margin:0 0 15px;color:#83a2be;font-size:11px}
    .detail-facts{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:7px}
    .detail-facts div{padding:9px 10px;border:1px solid rgba(73,220,255,.13);border-radius:7px;background:rgba(5,17,29,.55)}
    .detail-facts span{display:block;margin-bottom:3px;color:#6f8ca7;font-size:9px;text-transform:uppercase}
    .detail-facts b{color:#eaf7ff;font-size:11px}
    .relevance b{color:var(--green)}
    .memory-quote{margin:14px 0 12px;padding:13px 14px;border-left:2px solid var(--cyan);background:rgba(73,220,255,.045);color:#d4e6f4;font-size:12px;line-height:1.55}
    .tag-list{display:flex;flex-wrap:wrap;gap:6px}
    .tag-list span{padding:5px 8px;border:1px solid rgba(73,220,255,.19);border-radius:999px;color:#9fc5de;font-size:9px}
    .match-reasons{margin-top:13px;padding-top:11px;border-top:1px solid rgba(73,220,255,.12)}
    .match-reasons>span{display:block;margin-bottom:7px;color:#7e9db8;font-size:9px;font-weight:900;letter-spacing:.08em;text-transform:uppercase}
    .match-reasons div{display:flex;align-items:center;gap:8px;margin-top:6px;color:#bdd4e5;font-size:10px}
    .match-reasons i{width:6px;height:6px;border-radius:50%;background:var(--green);box-shadow:0 0 8px rgba(112,245,173,.55)}
    .usage{margin-top:auto;padding:11px 12px;border:1px solid rgba(112,245,173,.18);border-radius:7px;background:rgba(112,245,173,.045)}
    .usage span{display:block;margin-bottom:4px;color:var(--green);font-size:9px;font-weight:900;text-transform:uppercase}
    .usage p{margin:0;color:#d6e8f5;font-size:11px;line-height:1.4}
    .flow-strip{display:grid;grid-template-columns:1fr 34px 1fr 34px 1fr 34px 1fr 34px 1fr;align-items:center;margin-top:14px;padding:11px 16px;border:1px solid rgba(73,220,255,.18);border-radius:9px;background:rgba(8,22,37,.77)}
    .flow-step{text-align:center;color:#d7eafa;font-size:11px;font-weight:800}.flow-step b{display:block;margin-bottom:3px;color:var(--green);font-size:8px}
    .flow-arrow{position:relative;height:1px;background:linear-gradient(90deg,var(--cyan),var(--green))}
    .flow-arrow:after{content:"";position:absolute;right:0;top:-3px;width:7px;height:7px;border-top:1px solid var(--green);border-right:1px solid var(--green);transform:rotate(45deg)}
    @media(max-width:1100px){.showcase-shell .layout{grid-template-columns:1fr}.showcase-shell .side{position:relative;height:auto}.showcase-page{padding:24px 20px}.showcase-hero{align-items:flex-start;flex-direction:column}.showcase-hero p{text-align:left}.stat-pills{flex-wrap:wrap}.stat-pill{flex:1 1 45%}.explorer-layout{grid-template-columns:1fr}.memory-grid{grid-template-rows:auto}.flow-strip{grid-template-columns:1fr}.flow-arrow{width:1px;height:18px;margin:auto}}
  </style>
</head>
<body class="showcase-shell">
<div class="layout">
<cfmodule template="menu.cfm" active="memory_retrieval">
<main class="showcase-page">
  <header class="showcase-hero">
    <div><span class="eyebrow">Searchable family evidence</span><h1>Memory Retrieval Explorer</h1></div>
    <p>Family memories become searchable evidence for grounded digital-human responses.</p>
  </header>

  <section class="stat-pills">
    <div class="stat-pill"><b>5</b>Family Memories</div>
    <div class="stat-pill"><b>3</b>Memory Types</div>
    <div class="stat-pill"><b>Voice + Photo + Chat</b></div>
    <div class="stat-pill"><b>Evidence</b>Ready</div>
  </section>

  <section class="explorer-layout">
    <div class="memory-grid" aria-label="Family memory archive">
      <article class="memory-card selected" data-memory="ocean">
        <div class="memory-card-head"><span class="memory-type">Photo Memory</span><time class="memory-date">July 12, 2026</time></div>
        <h2>Ocean Park Family Trip</h2><p class="memory-source">Source: Photo Album</p>
        <div class="memory-card-foot"><span class="emotion">Emotion: <b>Happy</b></span><span class="ready">Evidence Ready</span></div>
      </article>
      <article class="memory-card" data-memory="advice">
        <div class="memory-card-head"><span class="memory-type">Voice Memory</span><time class="memory-date">February 08, 2026</time></div>
        <h2>Grandpa's Beijing Family Advice</h2><p class="memory-source">Source: Phone Recording</p>
        <div class="memory-card-foot"><span class="emotion">Emotion: <b>Warm</b></span><span class="ready">Evidence Ready</span></div>
      </article>
      <article class="memory-card" data-memory="dinner">
        <div class="memory-card-head"><span class="memory-type">Diary Memory</span><time class="memory-date">February 07, 2026</time></div>
        <h2>Family Dinner Before Spring Festival</h2><p class="memory-source">Source: Diary</p>
        <div class="memory-card-foot"><span class="emotion">Emotion: <b>Family</b></span><span class="ready">Evidence Ready</span></div>
      </article>
      <article class="memory-card" data-memory="walk">
        <div class="memory-card-head"><span class="memory-type">Diary Memory</span><time class="memory-date">November 03, 2025</time></div>
        <h2>Morning Walk Routine</h2><p class="memory-source">Source: Manual Note</p>
        <div class="memory-card-foot"><span class="emotion">Emotion: <b>Calm</b></span><span class="ready">Evidence Ready</span></div>
      </article>
      <article class="memory-card" data-memory="momo">
        <div class="memory-card-head"><span class="memory-type">Video Memory</span><time class="memory-date">January 18, 2026</time></div>
        <h2>Momo Waiting by the Door</h2><p class="memory-source">Source: Phone Video</p>
        <div class="memory-card-foot"><span class="emotion">Emotion: <b>Cute</b></span><span class="ready">Evidence Ready</span></div>
      </article>
    </div>

    <aside class="detail-panel">
      <div class="panel-label">Selected Memory Detail</div>
      <h2 id="detailTitle">Ocean Park Family Trip</h2>
      <p class="detail-source" id="detailSource">Photo Album &middot; Hong Kong Ocean Park</p>
      <div class="detail-facts">
        <div><span>Emotion</span><b id="detailEmotion">Happy</b></div>
        <div><span>Used in response</span><b id="detailUsed">Yes</b></div>
        <div class="relevance"><span>Relevance</span><b id="detailRelevance">94%</b></div>
        <div><span>Grounding</span><b>Evidence Ready</b></div>
      </div>
      <blockquote class="memory-quote" id="detailQuote">"Grandpa laughed at the boys watching sea animals and said this day should be remembered. Everyone was tired but happy."</blockquote>
      <div class="tag-list" id="detailTags"><span>family trip</span><span>grandchildren</span><span>Ocean Park</span><span>happy memory</span></div>
      <div class="match-reasons"><span>Why this memory matched</span><div><i></i>Direct place and trip reference</div><div><i></i>Grandchildren relationship context</div><div><i></i>Shared emotional language</div></div>
      <div class="usage"><span>Usage</span><p id="detailUsage">Used by Grandpa Li to answer family-trip questions.</p></div>
    </aside>
  </section>

  <section class="flow-strip">
    <div class="flow-step"><b>01</b>Capture</div><i class="flow-arrow"></i>
    <div class="flow-step"><b>02</b>Chunk</div><i class="flow-arrow"></i>
    <div class="flow-step"><b>03</b>Retrieve</div><i class="flow-arrow"></i>
    <div class="flow-step"><b>04</b>Select Evidence</div><i class="flow-arrow"></i>
    <div class="flow-step"><b>05</b>Ground Response</div>
  </section>
</main>
<script>
  const memoryDetails={
    ocean:{title:"Ocean Park Family Trip",source:"Photo Album",location:"Hong Kong Ocean Park",emotion:"Happy",used:"Yes",relevance:"94%",quote:"Grandpa laughed at the boys watching sea animals and said this day should be remembered. Everyone was tired but happy.",tags:["family trip","grandchildren","Ocean Park","happy memory"],usage:"Used by Grandpa Li to answer family-trip questions."},
    advice:{title:"Grandpa's Beijing Family Advice",source:"Phone Recording",location:"Beijing family home",emotion:"Warm",used:"Yes",relevance:"92%",quote:"Grandpa reminded the family to slow down, rest well, and make time for the people who matter.",tags:["family advice","voice","Beijing","wisdom"],usage:"Used by Grandpa Li to answer questions about work, rest, and family priorities."},
    dinner:{title:"Family Dinner Before Spring Festival",source:"Diary",location:"Beijing family home",emotion:"Family",used:"Yes",relevance:"91%",quote:"The family gathered before Spring Festival, sharing dinner, stories, and plans for the year ahead.",tags:["Spring Festival","family dinner","tradition","togetherness"],usage:"Used for responses about family traditions and shared meals."},
    walk:{title:"Morning Walk Routine",source:"Manual Note",location:"Neighborhood park",emotion:"Calm",used:"Yes",relevance:"89%",quote:"Grandpa valued quiet morning walks, familiar paths, and the simple rhythm of starting the day slowly.",tags:["morning walk","routine","calm","wellbeing"],usage:"Used for emotional grounding and questions about daily routines."},
    momo:{title:"Momo Waiting by the Door",source:"Phone Video",location:"Home entrance",emotion:"Cute",used:"Yes",relevance:"88%",quote:"Momo waited by the door for the family and became excited the moment familiar footsteps returned.",tags:["Momo","family pet","home","welcome"],usage:"Used for family-pet stories and warm memories about returning home."}
  };
  document.querySelectorAll(".memory-card").forEach(function(card){
    card.addEventListener("click",function(){
      const detail=memoryDetails[card.dataset.memory];
      document.querySelectorAll(".memory-card").forEach(function(item){item.classList.remove("selected");});
      card.classList.add("selected");
      document.getElementById("detailTitle").textContent=detail.title;
      document.getElementById("detailSource").textContent=detail.source+" · "+detail.location;
      document.getElementById("detailEmotion").textContent=detail.emotion;
      document.getElementById("detailUsed").textContent=detail.used;
      document.getElementById("detailRelevance").textContent=detail.relevance;
      document.getElementById("detailQuote").textContent='"'+detail.quote+'"';
      document.getElementById("detailTags").innerHTML=detail.tags.map(function(tag){return "<span>"+tag+"</span>";}).join("");
      document.getElementById("detailUsage").textContent=detail.usage;
    });
  });
</script>
</div>
</body>
</html>
