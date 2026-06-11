<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Judge Mode · HoloMemory AI</title>
  <style>
    :root{--bg:#050e19;--panel:#0b1b2d;--panel2:#0f243a;--line:rgba(83,202,255,.28);--text:#f3f8ff;--muted:#93afc9;--cyan:#49dcff;--green:#70f5ad}
    *{box-sizing:border-box}
    html,body{margin:0;min-height:100%;background:var(--bg);color:var(--text);font-family:Inter,Arial,"Microsoft Yahei",sans-serif}
    body{background:radial-gradient(circle at 50% -10%,rgba(73,220,255,.13),transparent 34%),radial-gradient(circle at 86% 65%,rgba(112,245,173,.06),transparent 28%),var(--bg)}
    .showcase-page{width:min(1440px,100%);min-height:100vh;margin:auto;padding:34px 46px 30px;display:flex;flex-direction:column}
    .brand{display:flex;align-items:center;gap:10px;color:#b6ecff;font-size:12px;font-weight:900;letter-spacing:.13em;text-transform:uppercase}
    .brand:before{content:"HM";width:34px;height:34px;display:grid;place-items:center;border:1px solid var(--cyan);border-radius:50%;background:rgba(73,220,255,.09);color:var(--cyan);letter-spacing:0;box-shadow:0 0 20px rgba(73,220,255,.18)}
    .showcase-hero{display:flex;align-items:end;justify-content:space-between;gap:30px;margin-top:24px;padding-bottom:24px;border-bottom:1px solid rgba(73,220,255,.18)}
    .eyebrow{display:block;margin-bottom:8px;color:var(--green);font-size:11px;font-weight:900;letter-spacing:.13em;text-transform:uppercase}
    h1{margin:0;font-size:clamp(38px,4vw,60px);line-height:1.02;letter-spacing:0}
    .showcase-hero p{max-width:540px;margin:0;color:#a4c0d9;font-size:17px;line-height:1.5;text-align:right}
    .judge-grid{display:grid;grid-template-columns:.82fr 1.05fr 1.18fr;gap:18px;flex:1;margin:24px 0 18px}
    .glow-card{position:relative;min-width:0;border:1px solid var(--line);border-radius:10px;background:linear-gradient(145deg,rgba(15,36,58,.96),rgba(7,18,31,.97));box-shadow:0 20px 54px rgba(0,0,0,.25),inset 0 0 34px rgba(73,220,255,.035)}
    .panel-label{display:flex;align-items:center;gap:9px;color:#add9ee;font-size:11px;font-weight:900;letter-spacing:.1em;text-transform:uppercase}
    .panel-label span{width:25px;height:25px;display:grid;place-items:center;border:1px solid rgba(112,245,173,.40);border-radius:50%;color:var(--green);font-size:9px}
    .question-card{padding:24px;display:flex;flex-direction:column;justify-content:space-between;border-color:rgba(73,220,255,.38)}
    .question-mark{width:62px;height:62px;display:grid;place-items:center;margin:32px 0 20px;border:1px solid rgba(73,220,255,.45);border-radius:50%;color:var(--cyan);font-size:32px;font-weight:300;box-shadow:0 0 30px rgba(73,220,255,.12)}
    .question-card blockquote{margin:0;color:#fff;font-size:clamp(24px,2.2vw,33px);font-weight:750;line-height:1.24}
    .question-footer{padding-top:20px;border-top:1px solid rgba(73,220,255,.14);color:#7797b3;font-size:12px}
    .evidence-panel{padding:22px}
    .evidence-stack{display:flex;flex-direction:column;gap:12px;margin-top:20px}
    .evidence-card{padding:15px 16px;border:1px solid rgba(73,220,255,.22);border-left:3px solid var(--green);border-radius:8px;background:rgba(5,17,29,.72);animation:reveal .55s ease both}
    .evidence-card:nth-child(2){animation-delay:.12s}.evidence-card:nth-child(3){animation-delay:.24s}
    .evidence-card h3{margin:0 0 11px;font-size:16px}
    .evidence-score{display:flex;align-items:center;justify-content:space-between;gap:12px;margin-bottom:8px;color:#85a5c1;font-size:11px}
    .evidence-score b{color:var(--green);font-size:13px}
    .score-track{height:3px;margin-bottom:11px;overflow:hidden;border-radius:3px;background:rgba(255,255,255,.08)}
    .score-track i{display:block;height:100%;background:linear-gradient(90deg,var(--cyan),var(--green));box-shadow:0 0 10px var(--cyan)}
    .evidence-meta{display:flex;justify-content:space-between;gap:10px;color:#7896b1;font-size:10px}
    .used{color:#93ffc0;font-weight:800}
    .response-card{padding:24px;display:flex;flex-direction:column;border-color:rgba(112,245,173,.34)}
    .response-card h2{margin:26px 0 14px;color:#fff;font-size:24px}
    .response-card blockquote{margin:0;color:#dbeaf7;font-size:17px;font-weight:450;line-height:1.62}
    .response-details{display:grid;grid-template-columns:1fr;gap:8px;margin-top:auto;padding-top:20px}
    .response-details div{display:flex;align-items:center;justify-content:space-between;gap:14px;padding:10px 12px;border:1px solid rgba(73,220,255,.14);border-radius:7px;background:rgba(5,17,29,.58);font-size:11px}
    .response-details span{color:#7f9db8}.response-details b{color:#dff8ec;text-align:right}
    .flow-strip{display:grid;grid-template-columns:1fr 38px 1fr 38px 1fr 38px 1fr 38px 1fr;align-items:center;padding:14px 18px;border:1px solid rgba(73,220,255,.19);border-radius:9px;background:rgba(8,22,37,.77)}
    .flow-step{text-align:center;color:#d7eafa;font-size:12px;font-weight:800}
    .flow-step b{display:block;margin-bottom:4px;color:var(--green);font-size:9px;letter-spacing:.08em}
    .flow-arrow{position:relative;height:1px;background:linear-gradient(90deg,var(--cyan),var(--green))}
    .flow-arrow:after{content:"";position:absolute;right:0;top:-3px;width:7px;height:7px;border-top:1px solid var(--green);border-right:1px solid var(--green);transform:rotate(45deg)}
    @keyframes reveal{from{opacity:0;transform:translateY(8px)}to{opacity:1;transform:none}}
    @media(max-width:980px){.showcase-page{padding:26px 22px}.showcase-hero{align-items:flex-start;flex-direction:column}.showcase-hero p{text-align:left}.judge-grid{grid-template-columns:1fr}.flow-strip{grid-template-columns:1fr}.flow-arrow{width:1px;height:18px;margin:auto}.question-card{min-height:360px}}
  </style>
</head>
<body>
<main class="showcase-page">
  <div class="brand">HoloMemory AI</div>
  <header class="showcase-hero">
    <div><span class="eyebrow">Transparent memory reasoning</span><h1>Judge Mode: Evidence-Grounded Response</h1></div>
    <p>One question. Three retrieved memories. One grounded digital-human answer.</p>
  </header>

  <section class="judge-grid">
    <article class="glow-card question-card">
      <div>
        <div class="panel-label"><span>01</span> Family Question</div>
        <div class="question-mark">?</div>
        <blockquote>"Do you remember our Ocean Park family trip?"</blockquote>
      </div>
      <div class="question-footer">Asked by a family member · Natural conversation</div>
    </article>

    <section class="glow-card evidence-panel">
      <div class="panel-label"><span>02</span> Retrieved Memories</div>
      <div class="evidence-stack">
        <article class="evidence-card">
          <h3>Ocean Park Family Trip</h3>
          <div class="evidence-score"><span>Relevance</span><b>94%</b></div>
          <div class="score-track"><i style="width:94%"></i></div>
          <div class="evidence-meta"><span>Source: Photo Album</span><span class="used">Used in response: Yes</span></div>
        </article>
        <article class="evidence-card">
          <h3>Family Advice</h3>
          <div class="evidence-score"><span>Relevance</span><b>92%</b></div>
          <div class="score-track"><i style="width:92%"></i></div>
          <div class="evidence-meta"><span>Source: Chat Memory</span><span class="used">Used in response: Yes</span></div>
        </article>
        <article class="evidence-card">
          <h3>Grandchildren Story</h3>
          <div class="evidence-score"><span>Relevance</span><b>90%</b></div>
          <div class="score-track"><i style="width:90%"></i></div>
          <div class="evidence-meta"><span>Source: Family Archive</span><span class="used">Used in response: Yes</span></div>
        </article>
      </div>
    </section>

    <article class="glow-card response-card">
      <div class="panel-label"><span>03</span> Grounded Digital Human</div>
      <h2>Grandpa Li responds</h2>
      <blockquote>"I remember that day. You and your brother watched the dolphins all afternoon. Everyone was tired but happy. I told the family that time together matters more than work."</blockquote>
      <div class="response-details">
        <div><span>Voice</span><b>Grandpa Li cloned elder Mandarin voice</b></div>
        <div><span>Grounding</span><b>3 memories used</b></div>
        <div><span>Risk</span><b>Low hallucination risk</b></div>
      </div>
    </article>
  </section>

  <section class="flow-strip" aria-label="Grounded response flow">
    <div class="flow-step"><b>01</b>Question</div><i class="flow-arrow"></i>
    <div class="flow-step"><b>02</b>Memory Retrieval</div><i class="flow-arrow"></i>
    <div class="flow-step"><b>03</b>Evidence Selection</div><i class="flow-arrow"></i>
    <div class="flow-step"><b>04</b>Grounded Response</div><i class="flow-arrow"></i>
    <div class="flow-step"><b>05</b>Voice Playback</div>
  </section>
</main>
</body>
</html>
