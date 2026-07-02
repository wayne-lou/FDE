(function () {
  const $ = (id) => document.getElementById(id);

  const examples = {
    python: {
      topic: "Python 入门：从零写出第一个自动化脚本",
      brief: "面向没有编程经验的学习者，讲清变量、循环、函数、列表、字典、文件整理脚本、练习路径和常见错误。",
      audience: "Python 初学者 / 转行学习者",
      theme: "education_light",
      mode: "balanced"
    },
    review: {
      topic: "个人年度复盘：从结果到反思再到下一年计划",
      brief: "围绕年度主线、三件成果、三个坑、认知变化和明年行动计划，形成一套适合分享和汇报的复盘。",
      audience: "团队同事 / 个人成长分享",
      theme: "minimal_white",
      mode: "balanced"
    },
    coffee: {
      topic: "如何选择适合自己的咖啡豆",
      brief: "从烘焙度、产地、处理法、风味轮、酸甜苦平衡和购买决策框架出发，帮助新手买到适合自己的咖啡豆。",
      audience: "咖啡新手 / 生活方式用户",
      theme: "coffee_warm",
      mode: "beauty"
    },
    rust: {
      topic: "Rust 重写订单系统的立项建议",
      brief: "面向 CEO 说明当前订单系统的业务损失、性能瓶颈、并发稳定性、重写成本、ROI、迁移风险和立项路径。",
      audience: "CEO / 技术管理层",
      theme: "executive_dark",
      mode: "beauty"
    },
    kyoto: {
      topic: "京都两日游路线：从清水寺到岚山",
      brief: "用两天时间线组织京都旅行体验，包含路线节奏、交通建议、预算、餐饮、拍照点和避坑提醒。",
      audience: "自由行游客 / 旅行分享",
      theme: "travel_editorial",
      mode: "beauty"
    }
  };

  let currentPlan = null;
  let currentPlanJobId = null;
  let activePane = "prompt";

  function setResult(html, type = "info") {
    $("resultBox").className = "result-box " + type;
    $("resultBox").innerHTML = html || "";
  }

  function escapeHtml(value) {
    return String(value == null ? "" : value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function inferTemplateType(payload) {
    const txt = ((payload.topic || "") + " " + (payload.brief || "") + " " + (payload.audience || "") + " " + (payload.theme || "")).toLowerCase();
    if (/python|代码|脚本|编程|课程|教学|培训/.test(txt)) return "educational_course";
    if (/京都|旅行|路线|酒店|景点|餐饮|自由行|清水寺|岚山/.test(txt)) return "travel_guide";
    if (/咖啡|咖啡豆|烘焙|风味/.test(txt)) return "decision_guide";
    if (/rust|订单|ceo|管理层|roi|投资回报|立项|重写/.test(txt)) return "executive_proposal";
    if (/复盘|年度|成长|下一年/.test(txt)) return "annual_review";
    return "proposal";
  }

  function buildTemplateRules(payload) {
    const tt = inferTemplateType(payload);
    const common = [
      "目标：生成一份客户可展示的中文可编辑PPT，不是Markdown搬运。",
      "阶段1只输出逐页蓝图：每页必须有标题、页面目标、核心结论、推荐版式、证据需求、视觉需求。",
      "阶段2才生成PPT：每页按蓝图生成正文、视觉结构、表格/图表/代码/讲稿。",
      "客户可见内容必须中文；禁止出现OpenAI、Prompt、Agent、Renderer、fallback、placeholder、image prompt等内部词。",
      "图表只用于真实数值；流程/矩阵/架构/风险不能画假柱状图。",
      "每页只有一个视觉中心；整套PPT保留2-4种重复版式；禁止连续多页表格或bullet。"
    ];
    if (tt === "travel_guide") common.push("旅行类必须包含两日路线、交通、具体住宿/餐饮建议、预算、拍照点、避坑、备选方案；图片页必须绑定具体地点。 ");
    if (tt === "educational_course") common.push("课程类必须包含概念解释、代码示例、逐行解释、练习题、参考答案、常见错误和小项目。 ");
    if (tt === "executive_proposal") common.push("高管汇报必须包含业务损失、方案选择、ROI/成本、风险、迁移路径、验收指标和决策请求；少用底层术语。 ");
    if (tt === "annual_review") common.push("复盘类必须包含年度主线、成果证据、问题代价、反思、下一年计划和行动清单。 ");
    if (tt === "decision_guide") common.push("决策指南必须包含评价维度、选项对比、推荐路径、预算/价格区间、避坑和购买/执行建议。 ");
    return common.join("\n");
  }

  function collectInput() {
    const topic = $("topicInput").value.trim();
    const brief = $("briefInput").value.trim();
    const audience = $("audienceInput").value.trim();
    if (!topic) throw new Error("请先填写主题。");
    const payload = {
      topic,
      brief,
      audience,
      mode: $("qualityMode").value,
      theme: $("themeName").value
    };
    payload.template_type = inferTemplateType(payload);
    payload.template_rules = buildTemplateRules(payload);
    return payload;
  }

  async function apiPost(url, data) {
    const resp = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(data || {})
    });
    const text = await resp.text();
    let json;
    try {
      json = JSON.parse(text);
    } catch (err) {
      throw new Error("接口返回不是 JSON：" + text.slice(0, 240));
    }
    if (!resp.ok || json.success === false) {
      throw new Error(json.message || json.error || ("接口失败：" + resp.status));
    }
    return json;
  }

  async function apiGet(url) {
    const resp = await fetch(url, { method: "GET", cache: "no-store" });
    const text = await resp.text();
    let json;
    try {
      json = JSON.parse(text);
    } catch (err) {
      throw new Error("接口返回不是 JSON：" + text.slice(0, 240));
    }
    if (!resp.ok || json.success === false) {
      throw new Error(json.message || json.error || ("接口失败：" + resp.status));
    }
    return json;
  }

  function kickWorker(url) {
    fetch(url, { method: "POST", cache: "no-store" }).catch(() => {});
  }

  function wait(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  async function poll(url, done, onTick) {
    for (let i = 0; i < 240; i += 1) {
      const data = await apiGet(url + (url.includes("?") ? "&" : "?") + "t=" + Date.now());
      if (typeof onTick === "function") onTick(data);
      if (done(data)) return data;
      await wait(1800);
    }
    throw new Error("任务等待超时，请稍后查看状态。");
  }

  function renderPlanBlueprint(plan) {
    const slides = Array.isArray(plan.slides) ? plan.slides : [];
    const lines = [];
    lines.push("# " + (plan.deckTitle || plan.deck_title || "演示规划"));
    lines.push("");
    lines.push("- 受众：" + (plan.audience || ""));
    lines.push("- 场景：" + (plan.scenario || plan.templateType || ""));
    lines.push("- 风格意图：" + (plan.themeIntent || plan.themeHint || ""));
    lines.push("- 页数：" + slides.length);
    lines.push("");
    lines.push("## 逐页蓝图");
    slides.forEach((slide, idx) => {
      const no = slide.slideId || slide.slideNo || (idx + 1);
      const title = slide.keyMessage || slide.title || slide.pageGoal || slide.coreMessage || "页面目标";
      lines.push("");
      lines.push("### " + no + ". " + title);
      lines.push("- 章节：" + (slide.section || ""));
      lines.push("- 页面角色：" + (slide.pageRole || slide.layoutType || slide.pageType || ""));
      lines.push("- 页面目标：" + (slide.pageGoal || slide.coreIntent || slide.coreMessage || ""));
      lines.push("- 推荐版式：" + (slide.suggestedLayout || slide.layoutType || slide.visualType || ""));
      lines.push("- 证据需求：" + (slide.evidenceNeed || (slide.research && slide.research.verificationNeeded ? slide.research.verificationNeeded.join("；") : "")));
      lines.push("- 视觉需求：" + (slide.visualNeed || slide.visualIntent || (slide.imagePlan && slide.imagePlan.scene ? slide.imagePlan.scene : "")));
    });
    $("blueprintPreview").textContent = lines.join("\n");
  }

  async function generatePlan() {
    $("promptButton").disabled = true;
    $("generateButton").disabled = true;
    currentPlan = null;
    const payload = collectInput();
    $("promptInput").value = "";
    $("blueprintPreview").textContent = "AI 正在生成逐页蓝图...";
    showPane("prompt");
    setResult("正在创建规划任务...", "info");
    const created = await apiPost("api/createPlanJob.cfm", payload);
    currentPlanJobId = created.jobId;
    $("promptInput").value = payload.template_rules + "\n\n---\n主题：" + payload.topic + "\n简介：" + payload.brief + "\n受众：" + payload.audience + "\n模板类型：" + payload.template_type + "\n模式：" + payload.mode + "\n风格：" + payload.theme;
    kickWorker("api/worker_plan.cfm?jobId=" + encodeURIComponent(currentPlanJobId));
    const done = await poll(
      "api/planStatus.cfm?jobId=" + encodeURIComponent(currentPlanJobId),
      (data) => data.status === "plan_completed" || data.status === "failed",
      (data) => {
        setResult("AI 正在生成逐页蓝图<br>Job #" + escapeHtml(data.jobId || currentPlanJobId) + " · " + escapeHtml(data.status || "planning") + " · " + escapeHtml(data.progress || 0) + "% · " + escapeHtml(data.currentStep || ""), "info");
      }
    );
    if (done.status === "failed") throw new Error(done.errorMessage || "规划生成失败。");
    currentPlan = done.plan || done.slideSpec || {};
    if (!currentPlan.slides || !Array.isArray(currentPlan.slides)) throw new Error("规划结果缺少 slides。");
    renderPlanBlueprint(currentPlan);
    $("promptButton").disabled = false;
    $("generateButton").disabled = false;
    showPane("blueprint");
    const m = done.metrics || {};
    setResult("规划已生成。请检查“逐页内容”，确认后点击“生成 PPT”。<br>模型：" + escapeHtml(m.model || done.model || "") + " · Tokens：" + escapeHtml(m.total_tokens || done.totalTokens || 0), "success");
  }

  function downloadBlob(blob, fileName) {
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = fileName;
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(url), 12000);
  }

  async function generatePpt() {
    if (!currentPlan || !Array.isArray(currentPlan.slides)) throw new Error("请先生成规划。");
    $("generateButton").disabled = true;
    const payload = collectInput();
    const presentationPrompt = $("promptInput").value.trim();
    setResult("正在创建 PPT 生成任务...", "info");
    const created = await apiPost("api/createJob.cfm", {
      ...payload,
      presentation_prompt: presentationPrompt,
      client_slide_spec_json: JSON.stringify(currentPlan)
    });
    const jobId = created.jobId;
    kickWorker("api/worker_generate.cfm?jobId=" + encodeURIComponent(jobId));
    const done = await poll(
      "api/jobStatus.cfm?jobId=" + encodeURIComponent(jobId),
      (data) => data.status === "completed" || data.status === "failed",
      (data) => {
        setResult("AI 正在按页生成 PPT 内容<br>Job #" + escapeHtml(data.jobId || jobId) + " · " + escapeHtml(data.status || "running") + " · " + escapeHtml(data.progress || 0) + "% · " + escapeHtml(data.currentStep || ""), "info");
      }
    );
    if (done.status === "failed") throw new Error(done.errorMessage || "PPT 生成失败。");
    if (!done.slideSpec || !Array.isArray(done.slideSpec.slides)) throw new Error("SlideSpec 缺失，已停止渲染。");
    const rendered = await window.BrowserPptx.renderPlan(done.slideSpec, payload);
    downloadBlob(rendered.blob, rendered.fileName);
    let logMessage = "";
    try {
      const log = await apiPost("api/log.cfm", {
        jobId,
        topic: payload.topic,
        brief: payload.brief,
        audience: payload.audience,
        theme: payload.theme,
        mode: payload.mode,
        provider: done.provider || "openai",
        model: done.model || "",
        promptTokens: done.promptTokens || (done.metrics && done.metrics.prompt_tokens) || 0,
        completionTokens: done.completionTokens || (done.metrics && done.metrics.completion_tokens) || 0,
        totalTokens: done.totalTokens || (done.metrics && done.metrics.total_tokens) || 0,
        estimatedCost: done.estimatedCost || (done.metrics && done.metrics.estimated_cost) || 0,
        durationMs: done.durationMs || (done.metrics && done.metrics.duration_ms) || 0,
        slideCount: done.slideSpec.slides.length,
        pptFilename: rendered.fileName,
        pptSize: rendered.blob.size,
        status: "completed",
        errorMessage: ""
      });
      logMessage = " · 数据库记录：" + escapeHtml(log.status || "成功");
    } catch (err) {
      logMessage = " · 数据库写入失败：" + escapeHtml(err.message);
    }
    const metrics = done.metrics || {};
    setResult(
      "PPT 已生成并开始下载。<br>来源：" +
        escapeHtml(metrics.provider || done.provider || "OpenAI") +
        " · 模型：" +
        escapeHtml(metrics.model || done.model || "") +
        " · Tokens：" +
        escapeHtml(metrics.total_tokens || done.totalTokens || 0) +
        " · Cost $" +
        escapeHtml(Number(metrics.estimated_cost || done.estimatedCost || 0).toFixed(5)) +
        " · 页数：" +
        escapeHtml(done.slideSpec.slides.length) +
        " · 文件大小：" +
        Math.round(rendered.blob.size / 1024) +
        " KB" +
        logMessage,
      logMessage.includes("失败") ? "warn" : "success"
    );
    $("generateButton").disabled = false;
  }

  function showPane(name) {
    activePane = name;
    $("promptTab").classList.toggle("active", name === "prompt");
    $("blueprintTab").classList.toggle("active", name === "blueprint");
    $("promptPane").classList.toggle("active", name === "prompt");
    $("blueprintPane").classList.toggle("active", name === "blueprint");
  }

  function applyExample(key) {
    const sample = examples[key];
    if (!sample) {
      $("topicInput").value = "";
      $("briefInput").value = "";
      $("audienceInput").value = "";
      $("themeName").value = "auto";
      $("qualityMode").value = "beauty";
      return;
    }
    $("topicInput").value = sample.topic;
    $("briefInput").value = sample.brief;
    $("audienceInput").value = sample.audience;
    $("themeName").value = sample.theme;
    $("qualityMode").value = sample.mode;
  }

  window.addEventListener("DOMContentLoaded", () => {
    $("topicPreset").addEventListener("change", (e) => applyExample(e.target.value));
    $("promptButton").addEventListener("click", () => generatePlan().catch((err) => { $("promptButton").disabled=false; $("generateButton").disabled=!currentPlan; setResult("需要处理<br>" + escapeHtml(err.message), "error"); }));
    $("generateButton").addEventListener("click", () => generatePpt().catch((err) => { $("generateButton").disabled=false; setResult("需要处理<br>" + escapeHtml(err.message), "error"); }));
    $("promptTab").addEventListener("click", () => showPane("prompt"));
    $("blueprintTab").addEventListener("click", () => showPane("blueprint"));
    applyExample("kyoto");
    $("topicPreset").value = "kyoto";
  });
})();
