<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>AI PPT 生成器</title>
  <link rel="stylesheet" href="assets/app.css?v=20260630-08">
</head>
<body>
  <main class="appShell">
    <section class="hero compactHero">
      <div class="heroCopy">
        <p class="eyebrow">AI Presentation Architect</p>
        <h1>AI PPT 生成器</h1>
        <p class="subtitle">输入主题，生成一套 22-24 页专业演示文稿</p>
      </div>
    </section>

    <section class="workspace singlePane">
      <article class="composer card">
        <div class="formGrid">
          <label class="field full">
            <span>主题选择</span>
            <select id="topicPreset">
              <option value="python">Python 入门</option>
              <option value="review">年度复盘</option>
              <option value="coffee">如何选择咖啡豆</option>
              <option value="rust">Rust 订单系统</option>
              <option value="kyoto">京都两日游</option>
              <option value="custom">其他...</option>
            </select>
          </label>
          <label class="field full">
            <span>主题</span>
            <input id="topicInput" type="text">
          </label>
          <label class="field full">
            <span>简介</span>
            <textarea id="briefInput"></textarea>
          </label>
          <label class="field">
            <span>目标受众</span>
            <input id="audienceInput" type="text">
          </label>
          <label class="field">
            <span>模式</span>
            <select id="qualityMode">
              <option value="beauty">最大化美观度</option>
              <option value="balanced">平衡模式</option>
            </select>
          </label>
          <label class="field">
            <span>风格</span>
            <select id="themeName">
              <option value="auto">自动推荐</option>
              <option value="executive_dark">商务深色</option>
              <option value="education_light">教育清爽</option>
              <option value="travel_editorial">旅行杂志</option>
              <option value="coffee_warm">咖啡暖色</option>
              <option value="minimal_white">极简白</option>
            </select>
          </label>
        </div>

        <div class="actions">
          <button id="promptButton" type="button">生成 Prompt</button>
          <button id="generateButton" class="primary" type="button" disabled>生成 PPT</button>
          <button id="batchButton" type="button">生成全部 Demo</button>
        </div>

        <label class="field full promptField">
          <span>生成 Prompt</span>
          <textarea id="promptInput" placeholder="点击生成 Prompt 后，这里会出现完整 Presentation Prompt。你可以修改后再生成 PPT。"></textarea>
        </label>

        <article id="resultBox" class="resultBox muted">
          <strong>等待生成</strong>
          <span>先生成 Prompt，确认后再生成 PPT。</span>
        </article>
      </article>
    </section>
  </main>

  <script src="assets/pptx-browser.js?v=20260630-08"></script>
  <script src="assets/app.js?v=20260630-08"></script>
</body>
</html>

