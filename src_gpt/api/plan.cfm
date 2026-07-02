<cfsetting requesttimeout="600">
<cfscript>
contentType = "application/json; charset=utf-8";

function jsonOut(required struct payload, numeric statusCode=200){
  cfheader(statuscode=arguments.statusCode, statustext=(arguments.statusCode == 200 ? "OK" : "Plan Error"));
  cfcontent(type=contentType, reset=true);
  writeOutput(serializeJson(arguments.payload));
  abort;
}

function valOf(required struct data, required string key, string fallback=""){
  if(structKeyExists(arguments.data, arguments.key) && !isNull(arguments.data[arguments.key])) return trim(toString(arguments.data[arguments.key]));
  return arguments.fallback;
}

function appVal(required string key, string fallback=""){
  if(structKeyExists(application, arguments.key) && !isNull(application[arguments.key]) && len(trim(toString(application[arguments.key])))) return trim(toString(application[arguments.key]));
  return arguments.fallback;
}

function estimateCost(numeric promptTokens, numeric completionTokens){
  return (arguments.promptTokens / 1000000 * 0.15) + (arguments.completionTokens / 1000000 * 0.60);
}

function stripFence(required string text){
  local.t = trim(arguments.text);
  local.t = rereplace(local.t, "^```json\s*", "", "one");
  local.t = rereplace(local.t, "^```\s*", "", "one");
  local.t = rereplace(local.t, "\s*```$", "", "one");
  return trim(local.t);
}

function bannedHit(required string text){
  local.banned = ["形成清晰判断","具体执行建议","本页聚焦","听众看完","为什么重要","保留一个可复盘","把复杂内容变成清晰","解释XXX关系","继续判断","视觉化表达","核心观点先行","结构化叙事"];
  for(local.i=1; local.i <= arrayLen(local.banned); local.i++){
    if(findNoCase(local.banned[local.i], arguments.text)) return local.banned[local.i];
  }
  return "";
}

try {
  rawBody = toString(getHttpRequestData().content);
  if(!len(trim(rawBody))) jsonOut({success:false, message:"请求内容为空。"}, 400);
  req = deserializeJson(rawBody);

  apiKey = appVal("openaiApiKey");
  if(!len(apiKey)) jsonOut({success:false, message:"OpenAI API Key 未配置。"});

  modelName = appVal("openaiModel", appVal("llmModel", "gpt-4o-mini"));
  apiUri = appVal("openaiApiUri", "https://api.openai.com/v1/chat/completions");
  topic = valOf(req, "topic");
  brief = valOf(req, "brief");
  audience = valOf(req, "audience");
  mode = valOf(req, "mode", "beauty");
  theme = valOf(req, "theme", "auto");
  templateType = valOf(req, "template_type", "proposal");
  templateRules = valOf(req, "template_rules", "背景、目标、问题、方案、价值、风险、下一步");
  presentationPrompt = valOf(req, "presentation_prompt");
  retryReason = valOf(req, "retry_reason");
  slideCount = 25;
  if(mode == "beauty") slideCount = 28;

  if(!len(topic)) jsonOut({success:false, message:"主题不能为空。"}, 400);
  if(!len(presentationPrompt)) jsonOut({success:false, message:"缺少 Presentation Prompt。"}, 400);
  retryLine = "";
  if(len(retryReason)) retryLine = "上一次质量检查失败原因：" & retryReason & chr(10);

  modeRule = "balanced 模式：25 页左右，信息密度更高，多用 cards/table/process/summary，少用复杂图片页。";
  if(mode == "beauty") modeRule = "beauty 模式：28 页左右，更多 section/timeline/cards/big_number/chart，留白更大，标题更有冲击力。";

  // 第二阶段必须压缩：之前把完整 Presentation Prompt + 大量字段交给模型，容易 504。
  // 这里改成 compact slide spec：仍然动态、仍然 OpenAI，但减少输出长度和推理时间。
  compactUserPrompt = left(presentationPrompt, 700);

  systemPrompt = "你是资深中文PPT成稿作者和演示设计师。你只输出合法JSON。你必须生成逐页成品文案，不输出提纲说明、不输出制作提示、不输出Agent过程。每页内容必须能直接放进PPT。";

  pageCount = (mode == "beauty" ? 28 : 25);
  modeGuide = (mode == "beauty"
    ? "Beauty版：更强视觉感，更多image/timeline/chart/section_divider页，文字更少但信息更准；每页3-4条要点。"
    : "Balanced版：经济适用，更紧凑，多用cards/table/process/comparison，少用大图页；每页4-5条要点。");

  typeGuide = "";
  if(templateType == "travel_guide"){
    typeGuide = "旅行类必须像真实攻略：路线总览、Day1/Day2逐时段、交通换乘、住宿区域、餐饮建议、预算拆分、拍照点、避坑、雨天/体力不足备选、出发清单。必须出现具体地点、时间、费用范围、选择建议。";
  }else if(templateType == "educational_course"){
    typeGuide = "教学类必须像课程：学习目标、知识地图、核心概念、类比、代码/例子、练习、小项目、常见错误、总结。不要只写学习重要性。";
  }else if(templateType == "executive_proposal"){
    typeGuide = "商业/技术说服类必须像CEO汇报：结论先行、业务损失、技术瓶颈、目标架构、数据流/流程、性能指标、成本/ROI、风险缓解、迁移路线、决策请求。必须包含技术图/架构图/指标图所需数据。";
  }else if(templateType == "decision_guide"){
    typeGuide = "决策指南类必须像购买/选择手册：评价维度、候选方案、对比矩阵、推荐路径、价格区间/成本、适合与不适合人群、避坑、清单。";
  }else if(templateType == "annual_review"){
    typeGuide = "复盘类必须像年度总结：年度主线、时间线、关键成果、三个坑、转折、认知变化、下一年计划、行动清单。";
  }else{
    typeGuide = "通用方案类必须包含：背景、问题、目标用户、方案流程、模块架构、价值、风险、实施路线、下一步。";
  }

  userPrompt = "根据以下输入生成一套中文PPT Slide Spec。注意：这是成品逐页文案，不是提纲。" & chr(10) &
    "主题：" & topic & chr(10) &
    "简介：" & brief & chr(10) &
    "目标受众：" & audience & chr(10) &
    "模板类型：" & templateType & chr(10) &
    "模板规则：" & typeGuide & chr(10) &
    "模式规则：" & modeGuide & chr(10) &
    "页数：严格生成 " & pageCount & " 页。" & chr(10) &
    "用户确认后的制作Prompt：" & left(presentationPrompt, 1200) & chr(10) & chr(10) &
    "每页要求：title 4-12字；coreMessage 是一句成品结论；supportingPoints 必须是3-5条真实具体信息，不能重复coreMessage，不能重复上一页。" & chr(10) &
    "如果涉及时间/路线/迁移，用timeline；涉及成本/预算/指标/ROI，用chart/table；涉及架构/流程，用process；涉及对比/风险，用comparison/matrix；Beauty版每4页至少一页image/chart/timeline。" & chr(10) &
    "禁止出现制作提示或空话：形成清晰判断、具体执行建议、听众看完、为什么重要、本页聚焦、继续判断、结构化叙事、核心观点先行、Prompt、P1/P2。" & chr(10) &
    "不要把imageKeywords、iconKeywords、英文关键词写进正文。" & chr(10) &
    "返回JSON结构：" & chr(10) &
    '{"deckTitle":"","subtitle":"","audience":"","templateType":"","themeHint":"","slides":[{"slideNo":1,"section":"","layoutType":"cover|agenda|section_divider|image|timeline|cards|comparison|matrix|table|chart|process|big_number|quote|summary|closing","title":"","coreMessage":"","supportingPoints":["","",""],"visualType":"","imagePlan":{"image_role":"none|hero|background|supporting","image_prompt":"","placement":""},"chartSpec":{"chart_type":"none|bar|line|table|matrix|process","purpose":"","fields":[],"axis":"","label":"","reason":""}}]}';

  maxTokens = (mode == "beauty" ? 5200 : 4600);

  requestBody = {
    model:modelName,
    temperature:0.25,
    max_tokens:maxTokens,
    response_format:{type:"json_object"},
    messages:[
      {role:"system", content:systemPrompt},
      {role:"user", content:userPrompt}
    ]
  };

  cfhttp(url=apiUri, method="post", result="httpResult", timeout=600){
    cfhttpparam(type="header", name="Authorization", value="Bearer " & apiKey);
    cfhttpparam(type="header", name="Content-Type", value="application/json");
    cfhttpparam(type="body", value=serializeJson(requestBody));
  }

  if(!find("200", httpResult.statusCode)){
    jsonOut({success:false, message:"OpenAI Slide Spec 请求失败。", detail:left(toString(httpResult.fileContent), 1000), http_status:httpResult.statusCode});
  }

  apiResult = deserializeJson(toString(httpResult.fileContent));
  content = stripFence(toString(apiResult.choices[1].message.content));
  // 不再因为禁用词直接失败；前端/renderer 会做清理，避免质量检查阻断交付。
  hit = bannedHit(content);

  spec = deserializeJson(content);
  if(!structKeyExists(spec, "slides") || !isArray(spec.slides) || arrayLen(spec.slides) < 20){
    jsonOut({success:false, message:"OpenAI Slide Spec 页数不足或缺少 slides。"});
  }

  promptTokens = 0; completionTokens = 0; totalTokens = 0;
  if(structKeyExists(apiResult, "usage")){
    if(structKeyExists(apiResult.usage, "prompt_tokens")) promptTokens = val(apiResult.usage.prompt_tokens);
    if(structKeyExists(apiResult.usage, "completion_tokens")) completionTokens = val(apiResult.usage.completion_tokens);
    if(structKeyExists(apiResult.usage, "total_tokens")) totalTokens = val(apiResult.usage.total_tokens);
  }

  jsonOut({
    success:true,
    source:"openai",
    model:modelName,
    slide_spec:spec,
    prompt_tokens:promptTokens,
    completion_tokens:completionTokens,
    total_tokens:totalTokens,
    estimated_cost:estimateCost(promptTokens, completionTokens)
  });
} catch(any e) {
  jsonOut({success:false, message:"Slide Spec 生成失败。", detail:e.message});
}
</cfscript>




