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

  if(!len(topic)) jsonOut({success:false, message:"主题不能为空。"}, 400);

  systemPrompt = "你是资深 Presentation Architect，做过高管汇报、产品发布、教学培训、投资路演、咨询报告和 TED 演讲。你不写文章，不堆模板，而是为任意主题设计可执行的中文演示文稿策略。只输出 JSON，不要 markdown。";

  userPrompt = "请为下面输入生成可编辑的 Presentation Prompt。这个 Prompt 后续会交给 Slide Planner 生成 PPT。" & chr(10) & chr(10) &
    "主题：" & topic & chr(10) &
    "简介：" & brief & chr(10) &
    "目标受众：" & audience & chr(10) &
    "模式：" & mode & chr(10) &
    "风格：" & theme & chr(10) &
    "模板类型：" & templateType & chr(10) &
    "模板骨架：" & templateRules & chr(10) & chr(10) &
    "必须按 7 个阶段组织 Prompt：" & chr(10) &
    "1. Intent Planner：目的、受众层级、最终 takeaway、希望观众采取的行动、成功标准。" & chr(10) &
    "2. Knowledge Builder：扩展主题知识，包含背景、概念、案例、误区、实践建议和趋势。" & chr(10) &
    "3. Presentation Strategist：选择演示类型，并解释为何适合。" & chr(10) &
    "4. Story Architect：设计完整故事线。" & chr(10) &
    "5. Visual Director：定义每章视觉表达，不要所有页都是卡片。" & chr(10) &
    "6. Slide Planner：约束 22-24 页，每页一个观点。" & chr(10) &
    "7. Presentation Critic：检查重复、空话、连续布局、颜色对比和行动建议。" & chr(10) & chr(10) &
    '输出 JSON：{"presentation_prompt":"..."}。presentation_prompt 必须是中文多段文本，带清晰换行，方便用户修改。';

  requestBody = {
    model:modelName,
    temperature:0.45,
    response_format:{type:"json_object"},
    messages:[
      {role:"system", content:systemPrompt},
      {role:"user", content:userPrompt}
    ]
  };

  cfhttp(url=apiUri, method="post", result="httpResult", timeout=120){
    cfhttpparam(type="header", name="Authorization", value="Bearer " & apiKey);
    cfhttpparam(type="header", name="Content-Type", value="application/json");
    cfhttpparam(type="body", value=serializeJson(requestBody));
  }

  if(!find("200", httpResult.statusCode)){
    jsonOut({success:false, message:"OpenAI Prompt 请求失败。", detail:left(toString(httpResult.fileContent), 1000), http_status:httpResult.statusCode});
  }

  apiResult = deserializeJson(toString(httpResult.fileContent));
  content = stripFence(toString(apiResult.choices[1].message.content));
  parsed = deserializeJson(content);
  promptText = valOf(parsed, "presentation_prompt");
  if(!len(promptText)) jsonOut({success:false, message:"OpenAI 未返回可用 Presentation Prompt。"});

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
    presentation_prompt:promptText,
    prompt_tokens:promptTokens,
    completion_tokens:completionTokens,
    total_tokens:totalTokens,
    estimated_cost:estimateCost(promptTokens, completionTokens)
  });
} catch(any e) {
  jsonOut({success:false, message:"Prompt 生成失败。", detail:e.message});
}
</cfscript>


