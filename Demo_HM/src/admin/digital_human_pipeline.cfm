<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Digital Human Creation Pipeline &middot; HoloMemory AI</title>
  <cfoutput><link rel="stylesheet" href="../assets/css/app.css?v=#randRange(10000,99999)#"></cfoutput>
  <style>
    :root{--bg:#050e19;--panel:#0b1b2d;--line:rgba(83,202,255,.27);--text:#f3f8ff;--muted:#93afc9;--cyan:#49dcff;--green:#70f5ad}
    *{box-sizing:border-box}
    html,body{margin:0;min-height:100%;background:var(--bg);color:var(--text);font-family:Inter,Arial,"Microsoft Yahei",sans-serif}
    body{background:radial-gradient(circle at 42% 0,rgba(73,220,255,.12),transparent 34%),radial-gradient(circle at 88% 56%,rgba(112,245,173,.07),transparent 30%),var(--bg)}
    .showcase-shell .layout{grid-template-columns:260px minmax(0,1fr)}
    .showcase-page{width:100%;min-width:0;min-height:100vh;margin:0;padding:25px 28px 18px;display:flex;flex-direction:column}
    .showcase-hero{display:flex;align-items:end;justify-content:space-between;gap:30px;margin-top:22px;padding-bottom:22px;border-bottom:1px solid rgba(73,220,255,.18)}
    .eyebrow{display:block;margin-bottom:8px;color:var(--green);font-size:11px;font-weight:900;letter-spacing:.13em;text-transform:uppercase}
    h1{margin:0;font-size:clamp(38px,3.5vw,52px);line-height:1.02;letter-spacing:0}
    .showcase-hero p{max-width:430px;margin:0;color:#a4c0d9;font-size:14px;line-height:1.5;text-align:right}
    .pipeline-layout{display:grid;grid-template-columns:minmax(0,1.75fr) minmax(285px,.68fr);gap:16px;flex:1;margin:18px 0 12px}
    .glow-card{border:1px solid var(--line);border-radius:10px;background:linear-gradient(145deg,rgba(15,36,58,.96),rgba(7,18,31,.97));box-shadow:0 20px 54px rgba(0,0,0,.25),inset 0 0 34px rgba(73,220,255,.035)}
    .pipeline-board{padding:17px;display:flex;flex-direction:column;justify-content:center}
    .section-label{color:#add9ee;font-size:11px;font-weight:900;letter-spacing:.1em;text-transform:uppercase}
    .pipeline-steps{display:grid;grid-template-columns:repeat(11,minmax(0,1fr));align-items:center;margin-top:32px}
    .pipeline-step{position:relative;min-width:0;height:294px;display:flex;flex-direction:column;align-items:center;justify-content:center;padding:14px 5px;border:1px solid rgba(73,220,255,.25);border-radius:9px;background:rgba(5,17,29,.72);text-align:center}
    .pipeline-step.final{border-color:rgba(112,245,173,.55);background:linear-gradient(180deg,rgba(112,245,173,.11),rgba(5,17,29,.76));box-shadow:0 0 32px rgba(112,245,173,.10)}
    .step-visual{position:relative;width:58px;height:82px;display:flex;align-items:center;justify-content:center;margin-bottom:13px;border:1px solid rgba(73,220,255,.20);border-radius:8px;background:linear-gradient(180deg,rgba(73,220,255,.07),rgba(5,17,29,.28));overflow:hidden}
    .photo-visual .portrait-head{position:absolute;top:14px;width:28px;height:28px;border:1px solid var(--cyan);border-radius:50%;background:rgba(73,220,255,.14)}
    .photo-visual .portrait-body{position:absolute;bottom:11px;width:48px;height:34px;border:1px solid rgba(73,220,255,.55);border-radius:24px 24px 8px 8px;background:rgba(73,220,255,.08)}
    .voice-visual{gap:4px}
    .voice-visual i{width:4px;border-radius:4px;background:linear-gradient(var(--cyan),var(--green));box-shadow:0 0 7px rgba(73,220,255,.45)}
    .voice-visual i:nth-child(1),.voice-visual i:nth-child(5){height:20px}.voice-visual i:nth-child(2),.voice-visual i:nth-child(4){height:42px}.voice-visual i:nth-child(3){height:62px}
    .profile-visual{flex-direction:column;gap:7px;padding:12px}
    .profile-visual:before{content:"";width:26px;height:26px;border:1px solid var(--cyan);border-radius:50%;background:rgba(73,220,255,.11)}
    .profile-visual i{display:block;width:100%;height:3px;border-radius:3px;background:rgba(164,221,242,.34)}
    .profile-visual i:last-child{width:70%}
    .memory-visual{display:grid;grid-template-columns:repeat(2,24px);grid-template-rows:repeat(2,26px);gap:5px}
    .memory-visual i{display:block;border:1px solid rgba(73,220,255,.38);border-radius:3px;background:linear-gradient(145deg,rgba(73,220,255,.16),rgba(112,245,173,.06))}
    .memory-visual i:nth-child(2){border-color:rgba(112,245,173,.42)}.memory-visual i:nth-child(3){grid-column:1/-1}
    .avatar-visual .avatar-head{position:absolute;top:13px;width:30px;height:34px;border:1px solid var(--green);border-radius:45% 45% 50% 50%;background:rgba(112,245,173,.10);box-shadow:0 0 15px rgba(112,245,173,.10)}
    .avatar-visual .avatar-body{position:absolute;bottom:8px;width:54px;height:38px;border:1px solid rgba(73,220,255,.48);border-radius:27px 27px 6px 6px;background:rgba(73,220,255,.08)}
    .human-visual{border-color:rgba(112,245,173,.48);border-radius:50%;color:#dffff0;font-size:19px;font-weight:900;box-shadow:inset 0 0 26px rgba(112,245,173,.11),0 0 24px rgba(112,245,173,.12)}
    .human-visual:after{content:"";position:absolute;inset:9px;border:1px solid rgba(73,220,255,.30);border-radius:50%}
    .pipeline-step b{color:#eef8ff;font-size:14px;line-height:1.3}
    .pipeline-step small{margin-top:8px;color:#7796b2;font-size:10px;line-height:1.35}
    .connector{position:relative;height:1px;background:linear-gradient(90deg,var(--cyan),var(--green))}
    .connector:after{content:"";position:absolute;right:0;top:-3px;width:7px;height:7px;border-top:1px solid var(--green);border-right:1px solid var(--green);transform:rotate(45deg)}
    .featured-persona-card{padding:18px;display:flex;flex-direction:column;border-color:rgba(112,245,173,.35)}
    .persona-orb{position:relative;width:128px;height:128px;display:grid;place-items:center;margin:22px auto 18px;border:1px solid rgba(73,220,255,.42);border-radius:50%;background:radial-gradient(circle,rgba(73,220,255,.25),rgba(9,29,46,.8) 58%,rgba(5,14,25,.9));color:#dcfbff;font-size:36px;font-weight:900;box-shadow:0 0 44px rgba(73,220,255,.16)}
    .persona-orb:after{content:"";position:absolute;inset:10px;border:1px solid rgba(112,245,173,.18);border-radius:50%}
    .featured-persona-card h2{margin:0;text-align:center;font-size:28px}
    .persona-subtitle{margin:7px 0 20px;color:#91aec9;font-size:12px;line-height:1.45;text-align:center}
    .status-list{display:flex;flex-direction:column;gap:8px;margin-top:auto}
    .status-list div{display:flex;align-items:center;gap:10px;padding:10px 12px;border:1px solid rgba(73,220,255,.14);border-radius:7px;background:rgba(5,17,29,.58);color:#cfe3f3;font-size:12px}
    .status-list span{width:20px;height:20px;display:grid;place-items:center;border-radius:50%;background:rgba(112,245,173,.11);color:var(--green);font-size:11px;font-weight:900}
    .difference{display:grid;grid-template-columns:.72fr 1.28fr;gap:30px;align-items:center;padding:20px 24px;border:1px solid rgba(73,220,255,.18);border-radius:9px;background:rgba(8,22,37,.77)}
    .difference h2{margin:0 0 9px;font-size:22px}.difference p{margin:0;color:#8da9c3;font-size:13px;line-height:1.55}
    .difference-lines{padding-left:26px;border-left:1px solid rgba(73,220,255,.20)}
    .difference-lines strong{display:block;color:#d7e7f5;font-size:20px;line-height:1.45}
    .difference-lines strong:nth-child(2){color:#eafff2}
    .difference-lines p{margin-top:9px}
    @media(min-width:1101px) and (max-height:950px){
      .showcase-page{padding:20px 28px 14px}
      .showcase-hero{margin-top:14px;padding-bottom:16px}
      .showcase-hero h1{font-size:50px}
      .pipeline-layout{margin:16px 0 12px}
      .pipeline-board,.featured-persona-card{padding:15px}
      .pipeline-steps{margin-top:20px}
      .pipeline-step{height:282px;padding:11px 4px}
      .step-visual{width:56px;height:78px;margin-bottom:11px}
      .persona-orb{width:96px;height:96px;margin:10px auto 10px;font-size:29px}
      .featured-persona-card h2{font-size:24px}
      .persona-subtitle{margin:5px 0 12px}
      .status-list{gap:5px}
      .status-list div{padding:7px 10px}
      .difference{padding:14px 20px}
      .difference h2{font-size:20px}
    }
    @media(max-width:1100px){.showcase-shell .layout{grid-template-columns:1fr}.showcase-shell .side{position:relative;height:auto}.pipeline-layout{grid-template-columns:1fr}.pipeline-steps{grid-template-columns:1fr}.pipeline-step{height:auto;min-height:130px}.connector{width:1px;height:22px;margin:auto}.showcase-hero{align-items:flex-start;flex-direction:column}.showcase-hero p{text-align:left}.difference{grid-template-columns:1fr}.difference-lines{padding:18px 0 0;border-left:0;border-top:1px solid rgba(73,220,255,.20)}}
  </style>
</head>
<body class="showcase-shell">
<div class="layout">
<cfmodule template="menu.cfm" active="digital_pipeline">
<main class="showcase-page">
  <header class="showcase-hero">
    <div><span class="eyebrow">Preserving identity across generations</span><h1>Digital Human Creation Pipeline</h1></div>
    <p>From family memories to a living, voice-enabled digital persona.</p>
  </header>

  <section class="pipeline-layout">
    <article class="glow-card pipeline-board">
      <div class="section-label">Family inputs become a trusted digital presence</div>
      <div class="pipeline-steps">
        <div class="pipeline-step"><div class="step-visual photo-visual"><span class="portrait-head"></span><span class="portrait-body"></span></div><b>Photo</b><small>Identity and likeness</small></div>
        <i class="connector"></i>
        <div class="pipeline-step"><div class="step-visual voice-visual"><i></i><i></i><i></i><i></i><i></i></div><b>Voice Samples</b><small>Familiar tone and cadence</small></div>
        <i class="connector"></i>
        <div class="pipeline-step"><div class="step-visual profile-visual"><i></i><i></i></div><b>Persona Profile</b><small>Character and speaking style</small></div>
        <i class="connector"></i>
        <div class="pipeline-step"><div class="step-visual memory-visual"><i></i><i></i><i></i></div><b>Memory Archive</b><small>Stories, advice, and moments</small></div>
        <i class="connector"></i>
        <div class="pipeline-step"><div class="step-visual avatar-visual"><span class="avatar-head"></span><span class="avatar-body"></span></div><b>3D Avatar</b><small>Visible human presence</small></div>
        <i class="connector"></i>
        <div class="pipeline-step final"><div class="step-visual human-visual">HM</div><b>Digital Human Ready</b><small>Grounded conversation</small></div>
      </div>
    </article>

    <aside class="glow-card featured-persona-card">
      <div class="section-label">Featured Digital Human</div>
      <div class="persona-orb">GL</div>
      <h2>Grandpa Li</h2>
      <p class="persona-subtitle">Grandfather &middot; Mandarin elder voice &middot; 3D avatar ready</p>
      <div class="status-list">
        <div><span>&#10003;</span>Voice cloned</div>
        <div><span>&#10003;</span>Avatar generated</div>
        <div><span>&#10003;</span>5 memories linked</div>
        <div><span>&#10003;</span>Evidence grounding enabled</div>
        <div><span>&#10003;</span>Ready for conversation</div>
      </div>
    </aside>
  </section>

  <section class="difference">
    <div><span class="eyebrow">What makes it different?</span><h2>More than an answer engine</h2><p>Technology becomes meaningful when it carries a real person's context forward.</p></div>
    <div class="difference-lines">
      <strong>General AI answers questions.</strong>
      <strong>HoloMemory preserves people.</strong>
      <p>Family memories, voice recordings, and personal stories become an evidence-grounded digital human for future generations.</p>
    </div>
  </section>
</main>
</div>
</body>
</html>
