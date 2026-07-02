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
  slideCount = 22;
  if(mode == "beauty") slideCount = 24;

  if(!len(topic)) jsonOut({success:false, message:"主题不能为空。"}, 400);
  if(!len(presentationPrompt)) jsonOut({success:false, message:"缺少 Presentation Prompt。"}, 400);
  retryLine = "";
  if(len(retryReason)) retryLine = "上一次质量检查失败原因：" & retryReason & chr(10);

  modeRule = "balanced 模式：22 页左右，信息密度更高，多用 cards/table/process/summary，少用复杂图片页。";
  if(mode == "beauty") modeRule = "beauty 模式：24 页左右，更多 section/timeline/cards/big_number/chart，留白更大，标题更有冲击力。";

  systemPrompt = "你是资深 Presentation Architect。你必须把用户输入动态转换为专业中文 PPT Slide Spec。你不能输出 markdown，不能输出解释，只能输出合法 JSON。";

  userPrompt = presentationPrompt & chr(10) & chr(10) &
    "现在进入 Slide Planner。请生成可直接渲染的 slide_spec。" & chr(10) &
    "主题：" & topic & chr(10) &
    "简介：" & brief & chr(10) &
    "目标受众：" & audience & chr(10) &
    "模板类型：" & templateType & chr(10) &
    "模板骨架：" & templateRules & chr(10) &
    "风格：" & theme & chr(10) &
    "模式规则：" & modeRule & chr(10) &
    "页数：" & slideCount & " 页。" & chr(10) &
    retryLine & chr(10) &
    "硬性要求：全部中文；每页一个具体观点；不要重复标题；不要重复 points；不要出现平台自嗨或元话术；不要出现这些词：形成清晰判断、具体执行建议、本页聚焦、听众看完、为什么重要、保留一个可复盘、把复杂内容变成清晰、解释XXX关系、继续判断、视觉化表达、核心观点先行、结构化叙事。" & chr(10) &
    "Layout 必须从 cover, agenda, section, cards, timeline, process, comparison, matrix, table, big_number, quote, summary, closing 中选择，不要连续三页相同。" & chr(10) &
    "如果需要图，imagePlan.image_prompt 写完整英文画面提示词；不要把图片关键词写进正文。" & chr(10) &
    "如果需要图表，chartSpec 给 chart_type、purpose、fields、axis、label、reason。" & chr(10) & chr(10) &
    "输出 JSON 格式：" & chr(10) &
    '{"deckTitle":"","subtitle":"","audience":"","templateType":"","themeHint":"","intent":{"purpose":"","audienceNeed":"","finalTakeaway":""},"researchSummary":"","storyArc":["",""],"sections":[{"name":"","purpose":"","slideStart":1,"slideEnd":4}],"slides":[{"slideNo":1,"section":"","layoutType":"cover","title":"","coreMessage":"","supportingPoints":["","",""],"thinkAboutIt":"","visualType":"cards","visualIntent":"","imagePlan":{"image_role":"none","image_prompt":"","placement":""},"chartSpec":{"chart_type":"none","purpose":"","fields":[],"axis":"","label":"","reason":""},"speakerNote":""}]}';

  requestBody = {
    model:modelName,
    temperature:0.5,
    response_format:{type:"json_object"},
    messages:[
      {role:"system", content:systemPrompt},
      {role:"user", content:userPrompt}
    ]
  };

  cfhttp(url=apiUri, method="post", result="httpResult", timeout=180){
    cfhttpparam(type="header", name="Authorization", value="Bearer " & apiKey);
    cfhttpparam(type="header", name="Content-Type", value="application/json");
    cfhttpparam(type="body", value=serializeJson(requestBody));
  }

  if(!find("200", httpResult.statusCode)){
    jsonOut({success:false, message:"OpenAI Slide Spec 请求失败。", detail:left(toString(httpResult.fileContent), 1000), http_status:httpResult.statusCode});
  }

  apiResult = deserializeJson(toString(httpResult.fileContent));
  content = stripFence(toString(apiResult.choices[1].message.content));
  hit = bannedHit(content);
  if(len(hit)) jsonOut({success:false, message:"OpenAI Slide Spec 包含禁用词。", detail:hit});

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




