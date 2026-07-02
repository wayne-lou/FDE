<cfsetting showdebugoutput="false">
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>AI PPT 生成器</title>
  <link rel="stylesheet" href="assets/app.css?v=20260701-agent">
</head>
<body>
  <main class="shell">
    <header class="hero">
      <div class="eyebrow">Presentation Agent OS</div>
      <h1>AI PPT 生成器</h1>
      <p>先生成可审阅的逐页规划，再生成可编辑的专业演示文稿。</p>
    </header>

    <section class="panel form-panel">
      <div class="field">
        <label for="topicPreset">主题选择</label>
        <select id="topicPreset">
          <option value="custom">其他...</option>
          <option value="python">Python 入门</option>
          <option value="review">年度复盘</option>
          <option value="coffee">如何选择咖啡豆</option>
          <option value="rust">Rust 订单系统</option>
          <option value="kyoto">京都两日游</option>
        </select>
      </div>

      <div class="field">
        <label for="topicInput">主题</label>
        <input id="topicInput" type="text" placeholder="例如：医疗临床证据问答系统">
      </div>

      <div class="field">
        <label for="briefInput">简介</label>
        <textarea id="briefInput" rows="4" placeholder="说明背景、重点、必须覆盖的内容和你希望观众带走的结论。"></textarea>
      </div>

      <div class="form-grid">
        <div class="field">
          <label for="audienceInput">目标受众</label>
          <input id="audienceInput" type="text" placeholder="例如：AI 工程面试官 / 管理层 / 初学者">
        </div>
        <div class="field">
          <label for="qualityMode">模式</label>
          <select id="qualityMode">
            <option value="beauty">最大化美观度</option>
            <option value="balanced">平衡模式</option>
          </select>
        </div>
        <div class="field">
          <label for="themeName">风格</label>
          <select id="themeName">
            <option value="auto">自动推荐</option>
            <option value="executive_dark">商务深色</option>
            <option value="education_light">教育清爽</option>
            <option value="travel_editorial">旅行杂志</option>
            <option value="coffee_warm">咖啡暖色</option>
            <option value="minimal_white">极简白</option>
          </select>
        </div>
      </div>

      <div class="actions">
        <button id="promptButton" type="button" class="btn secondary">生成规划</button>
        <button id="generateButton" type="button" class="btn primary" disabled>生成 PPT</button>
      </div>
    </section>

    <section class="panel stage-panel">
      <div class="tabs">
        <button id="promptTab" class="tab active" type="button">提示词</button>
        <button id="blueprintTab" class="tab" type="button">逐页内容</button>
      </div>
      <div id="promptPane" class="tab-pane active">
        <textarea id="promptInput" rows="14" placeholder="点击“生成规划”后，这里会显示真实发送给 OpenAI 的完整提示词。"></textarea>
      </div>
      <div id="blueprintPane" class="tab-pane">
        <pre id="blueprintPreview">尚未生成规划。</pre>
      </div>
    </section>

    <section id="resultBox" class="result-box" aria-live="polite"></section>
  </main>

  <script src="assets/vendor/pptxgen.bundle.js?v=20260701-agent"></script>
  <script src="assets/pptx-browser.js?v=20260701-agent"></script>
  <script src="assets/app.js?v=20260701-agent"></script>
</body>
</html>
