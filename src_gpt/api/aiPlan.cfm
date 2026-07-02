<cfsetting showdebugoutput="false" requesttimeout="240">
<cfscript>
// V14: API must always return JSON. No HTML error page should leak to the browser UI.
CONTENT_TYPE_JSON = "application/json; charset=utf-8";

function safeString(any v, string fallback=""){
  if(isNull(arguments.v)) return arguments.fallback;
  return toString(arguments.v);
}
function safeTrim(any v, string fallback=""){
  return trim(safeString(arguments.v, arguments.fallback));
}
function jsonOut(required struct payload, numeric statusCode=200){
  var statusText = "OK";
  if(arguments.statusCode != 200) statusText = "AI Plan Error";
  cfheader(statuscode=arguments.statusCode, statustext=statusText);
  cfheader(name="Cache-Control", value="no-store, no-cache, must-revalidate, max-age=0");
  cfcontent(type=CONTENT_TYPE_JSON, reset=true);
  writeOutput(serializeJson(arguments.payload));
  abort;
}
function valOf(required struct data, required string key, string fallback=""){
  if(structKeyExists(arguments.data, arguments.key) && !isNull(arguments.data[arguments.key])){
    return safeTrim(arguments.data[arguments.key], arguments.fallback);
  }
  return arguments.fallback;
}
function appVal(required string key, string fallback=""){
  if(structKeyExists(application, arguments.key) && !isNull(application[arguments.key])){
    var v = safeTrim(application[arguments.key], "");
    if(len(v)) return v;
  }
  return arguments.fallback;
}
function stripJson(required string text){
  var s = trim(arguments.text);
  s = reReplace(s, "^```json[[:space:]]*", "", "one");
  s = reReplace(s, "^```[[:space:]]*", "", "one");
  s = reReplace(s, "[[:space:]]*```$", "", "one");
  var firstBrace = find("{", s);
  var revPos = find("}", reverse(s));
  var lastBrace = 0;
  if(revPos > 0) lastBrace = len(s) - revPos + 1;
  if(firstBrace > 0 && lastBrace >= firstBrace) s = mid(s, firstBrace, lastBrace-firstBrace+1);
  return s;
}
function isHttpOk(required any httpRes){
  if(!isStruct(arguments.httpRes) || !structKeyExists(arguments.httpRes, "statusCode")) return false;
  return find("200", toString(arguments.httpRes.statusCode)) > 0;
}
function httpText(required any httpRes){
  if(isStruct(arguments.httpRes) && structKeyExists(arguments.httpRes,"fileContent") && !isNull(arguments.httpRes.fileContent)){
    return toString(arguments.httpRes.fileContent);
  }
  return "";
}
function errText(required any httpRes){
  var raw = left(httpText(arguments.httpRes), 1800);
  try {
    var parsed = deserializeJson(httpText(arguments.httpRes));
    if(isStruct(parsed) && structKeyExists(parsed,"error")){
      if(isStruct(parsed.error) && structKeyExists(parsed.error,"message")) return safeString(parsed.error.message);
      return serializeJson(parsed.error);
    }
  } catch(any ignore) {}
  return raw;
}
function callOpenAI(required string apiUri, required string apiKey, required struct body){
  var httpRes = {};
  cfhttp(method="post", url=arguments.apiUri, result="httpRes", timeout="150"){
    cfhttpparam(type="header", name="Content-Type", value="application/json");
    cfhttpparam(type="header", name="Authorization", value="Bearer " & arguments.apiKey);
    cfhttpparam(type="body", value=serializeJson(arguments.body));
  }
  return httpRes;
}
function normalizeSlideSpec(required struct spec, required string topic, required string audience, required string mode, required string templateType){
  if(!structKeyExists(arguments.spec,"deckTitle") || !len(safeTrim(arguments.spec.deckTitle,""))) arguments.spec.deckTitle = arguments.topic;
  if(!structKeyExists(arguments.spec,"subtitle")) arguments.spec.subtitle = "";
  if(!structKeyExists(arguments.spec,"audience") || !len(safeTrim(arguments.spec.audience,""))) arguments.spec.audience = arguments.audience;
  arguments.spec.mode = arguments.mode;
  arguments.spec.templateType = arguments.templateType;
  if(!structKeyExists(arguments.spec,"evidenceNotice")) arguments.spec.evidenceNotice = "涉及实时价格、库存、酒店、图片、法规或外部数据时，已标注待核验。";
  if(!structKeyExists(arguments.spec,"researchPack") || !isStruct(arguments.spec.researchPack)) arguments.spec.researchPack = {};
  if(!structKeyExists(arguments.spec.researchPack,"evidencePolicy")) arguments.spec.researchPack.evidencePolicy = "实时事实、价格、图片和产品信息必须标注待核验；Renderer不得自行编造。";
  if(!structKeyExists(arguments.spec,"sections") || !isArray(arguments.spec.sections)) arguments.spec.sections = [];
  if(!structKeyExists(arguments.spec,"slides") || !isArray(arguments.spec.slides)) return arguments.spec;

  for(var i=1; i<=arrayLen(arguments.spec.slides); i++){
    var sl = arguments.spec.slides[i];
    if(!isStruct(sl)) sl = {};
    sl.slideNo = i;
    if(!structKeyExists(sl,"section") || !len(safeTrim(sl.section,""))) sl.section = "正文";
    if(!structKeyExists(sl,"pageRole") || !len(safeTrim(sl.pageRole,""))) sl.pageRole = "content";
    if(!structKeyExists(sl,"layoutType") || !len(safeTrim(sl.layoutType,""))) sl.layoutType = "cards";
    if(!structKeyExists(sl,"visualType") || !len(safeTrim(sl.visualType,""))) sl.visualType = sl.layoutType;
    if(!structKeyExists(sl,"title") || !len(safeTrim(sl.title,""))) sl.title = "第" & i & "页";
    if(!structKeyExists(sl,"coreMessage")) sl.coreMessage = "";
    if(!structKeyExists(sl,"supportingPoints") || !isArray(sl.supportingPoints)) sl.supportingPoints = [];
    if(arrayLen(sl.supportingPoints) < 2 && len(safeTrim(sl.coreMessage,""))) arrayAppend(sl.supportingPoints, safeString(sl.coreMessage));
    if(!structKeyExists(sl,"speakerNote")) sl.speakerNote = "";
    if(!structKeyExists(sl,"research") || !isStruct(sl.research)) sl.research = {dataNeeds:[], facts:[], assumptions:[], verificationNeeded:[], imageQueries:[]};
    if(!structKeyExists(sl,"layout") || !isStruct(sl.layout)) sl.layout = {type:sl.layoutType, density:"medium", composition:"standard", visualPriority:sl.visualType};
    if(!structKeyExists(sl,"quality") || !isStruct(sl.quality)) sl.quality = {specificityScore:70, checks:[]};
    arguments.spec.slides[i] = sl;
  }
  return arguments.spec;
}
function scrubCustomerUnsafe(required struct spec){
  var banned = "OpenAI|Planner|Renderer|Agent|Pipeline|Prompt|Slide Spec|Gamma|Beautiful.ai|Tome|token|cost|fallback|本地规划|规划器|渲染器";
  if(!structKeyExists(arguments.spec,"slides") || !isArray(arguments.spec.slides)) return arguments.spec;
  for(var i=1; i<=arrayLen(arguments.spec.slides); i++){
    var sl = arguments.spec.slides[i];
    for(var k in sl){
      if(isSimpleValue(sl[k])){
        sl[k] = reReplace(toString(sl[k]), banned, "", "all");
      }
    }
    arguments.spec.slides[i] = sl;
  }
  return arguments.spec;
}

rawBody = ""; req = {}; topic = ""; brief = ""; audience = ""; mode = ""; theme = ""; templateType = ""; templateRules = "";
apiKey = ""; apiUri = ""; model = ""; targetSlides = 20; nl = chr(10); systemPrompt = ""; userPrompt = "";
messages = []; requestBody = {}; started = 0; httpRes = {}; firstErr = ""; retryBody = {}; duration = 0;
resText = ""; res = {}; content = ""; specJson = ""; spec = {}; usage = {}; pt = 0; ct = 0; tt = 0; est = 0; detailText = "";

try {
  rawBody = safeString(getHttpRequestData().content, "");
  if(!len(trim(rawBody))) jsonOut({success:false, message:"请求内容为空。"}, 400);

  req = {};
  try { req = deserializeJson(rawBody); }
  catch(any badReq){ jsonOut({success:false, message:"请求JSON格式错误。"}, 400); }

  topic = valOf(req,"topic");
  brief = valOf(req,"brief");
  audience = valOf(req,"audience");
  mode = valOf(req,"mode","beauty");
  theme = valOf(req,"theme","auto");
  templateType = valOf(req,"template_type","proposal");
  templateRules = valOf(req,"template_rules","");
  if(!len(topic)) jsonOut({success:false, message:"主题不能为空。"}, 400);

  apiKey = appVal("openaiApiKey", "");
  apiUri = appVal("openaiApiUri", "https://api.openai.com/v1/chat/completions");
  model = appVal("openaiQualityModel", appVal("openaiModel", "gpt-4.1-mini"));
  if(!len(apiKey)) jsonOut({success:false, message:"OpenAI API Key 未配置。"}, 500);

  targetSlides = 20;
  if(mode == "beauty") targetSlides = 24;
  if(mode == "economic") targetSlides = 16;

  nl = chr(10);
  systemPrompt = "你是商业级Presentation Planner。你只输出合法JSON，不输出Markdown，不解释过程。所有字段必须是客户可见的演示内容。";
  userPrompt = "为用户需求生成可直接渲染的Slide Spec JSON。" & nl &
    "主题：" & topic & nl &
    "简介：" & brief & nl &
    "目标受众：" & audience & nl &
    "模式：" & mode & nl &
    "风格：" & theme & nl &
    "模板类型：" & templateType & nl &
    "模板规则：" & templateRules & nl &
    "目标页数：" & targetSlides & nl & nl &
    "硬性要求：" & nl &
    "1. 只输出JSON对象，不要Markdown。" & nl &
    "2. 禁止出现开发过程词：OpenAI、Planner、Renderer、Agent、Pipeline、Prompt、Slide Spec、Gamma、Beautiful.ai、Tome、token、cost、本地规划、fallback。" & nl &
    "3. Renderer只排版；每页的正文、表格、图表、代码、练习答案、图片计划必须在JSON里给完整。" & nl &
    "4. 内容必须具体。表格页每行必须有具体候选、价格或代价、适用场景。图表页必须有chartData和insight。图片页必须有英文image_search_query和imagePlan。" & nl &
    "5. 实时价格、酒店、产品、法规、图片均标注estimate或needs_verification，不许假装实时核验。" & nl &
    "6. 教学类讲多个概念就分别给代码；练习页必须给answerCode或验收标准。" & nl &
    "7. beauty低文字密度、多主视觉；economic高信息密度、多表格少图片；balanced适中。" & nl & nl &
    "输出结构：" & nl &
    '{"deckTitle":"","subtitle":"","audience":"","templateType":"","mode":"","evidenceNotice":"","sections":[{"name":"","purpose":"","slideStart":1,"slideEnd":3}],"researchPack":{"evidencePolicy":"","dataNeeds":[]},"slides":[...]}' & nl &
    "每个slide必须包含：slideNo, section, pageRole, layoutType, visualType, title, coreMessage, supportingPoints, speakerNote, research, layout, quality。" & nl &
    "research包含：dataNeeds, facts, assumptions, verificationNeeded, imageQueries。layout包含：type, density, composition, visualPriority。quality包含：specificityScore, checks。" & nl &
    "按需增加：tableRows、chartData、chartSuggestion、codeBlock、codeNotes、exercise、imagePlan、image_search_query。" & nl & nl &
    "模板要求：" & nl &
    "educational_course：学习目标、知识地图、概念讲解、对比例子、完整项目、常见错误、课堂练习和参考答案。" & nl &
    "travel_guide：日程时间线、具体住宿、交通、餐饮、预算、拍照点、避坑、雨天方案。酒店和价格写参考区间并标注待核验。" & nl &
    "executive_proposal：业务问题、损失、方案、ROI假设、成本、风险、时间线、决策请求。" & nl &
    "decision_guide：选择维度、候选方案、价格或代价、适合人群、推荐路径和避坑。" & nl &
    "annual_review：阶段事件、关键指标、成功和失败、原因、经验、下一年目标。";

  messages = [];
  arrayAppend(messages, {role:"system", content:systemPrompt});
  arrayAppend(messages, {role:"user", content:userPrompt});
  requestBody = {model:model, messages:messages, temperature:0.25, response_format:{type:"json_object"}};
  if(findNoCase("gpt-5", model)) requestBody.max_completion_tokens = 12000; else requestBody.max_tokens = 12000;

  started = getTickCount();
  httpRes = callOpenAI(apiUri, apiKey, requestBody);
  firstErr = "";
  if(!isHttpOk(httpRes)){
    firstErr = errText(httpRes);
    retryBody = duplicate(requestBody);
    structDelete(retryBody, "response_format", false);
    if(structKeyExists(retryBody,"max_tokens") && findNoCase("max_tokens", firstErr)){
      retryBody.max_completion_tokens = retryBody.max_tokens;
      structDelete(retryBody,"max_tokens",false);
    }
    if(structKeyExists(retryBody,"max_completion_tokens") && findNoCase("max_completion_tokens", firstErr)){
      retryBody.max_tokens = retryBody.max_completion_tokens;
      structDelete(retryBody,"max_completion_tokens",false);
    }
    httpRes = callOpenAI(apiUri, apiKey, retryBody);
    if(!isHttpOk(httpRes)){
      jsonOut({success:false, message:"AI规划失败，请稍后重试。", detail:"HTTP " & safeString(httpRes.statusCode,"unknown") & "：" & errText(httpRes), firstAttempt:firstErr, model:model}, 502);
    }
  }

  duration = getTickCount() - started;
  resText = httpText(httpRes);
  res = {};
  try { res = deserializeJson(resText); }
  catch(any openaiParse){ jsonOut({success:false, message:"AI服务返回格式异常。", detail:left(resText, 1200)}, 502); }

  content = "";
  if(structKeyExists(res,"choices") && isArray(res.choices) && arrayLen(res.choices) >= 1){
    if(structKeyExists(res.choices[1],"message") && structKeyExists(res.choices[1].message,"content")) content = safeString(res.choices[1].message.content, "");
  }
  if(!len(trim(content))) jsonOut({success:false, message:"AI规划返回空内容。", detail:left(resText, 1200)}, 502);

  specJson = stripJson(content);
  spec = {};
  try { spec = deserializeJson(specJson); }
  catch(any parseErr){ jsonOut({success:false, message:"AI规划JSON解析失败。", detail:parseErr.message & " | " & left(specJson, 1500)}, 502); }

  if(!structKeyExists(spec,"slides") || !isArray(spec.slides) || arrayLen(spec.slides) < 8){
    jsonOut({success:false, message:"AI规划内容不完整。", detail:left(specJson, 1500)}, 502);
  }

  spec = normalizeSlideSpec(spec, topic, audience, mode, templateType);
  spec = scrubCustomerUnsafe(spec);

  usage = {};
  if(structKeyExists(res,"usage") && isStruct(res.usage)) usage = res.usage;
  pt = 0; ct = 0; tt = 0;
  if(structKeyExists(usage,"prompt_tokens")) pt = val(usage.prompt_tokens);
  if(structKeyExists(usage,"completion_tokens")) ct = val(usage.completion_tokens);
  if(structKeyExists(usage,"total_tokens")) tt = val(usage.total_tokens); else tt = pt + ct;
  est = ((pt/1000000)*0.4) + ((ct/1000000)*1.6);

  jsonOut({
    success:true,
    source:"openai",
    model:model,
    planner_prompt:userPrompt,
    slide_spec:spec,
    slide_spec_json:serializeJson(spec),
    prompt_tokens:pt,
    completion_tokens:ct,
    total_tokens:tt,
    estimated_cost:est,
    duration_ms:duration
  });
} catch(any e) {
  detailText = safeString(e.message, "未知错误");
  if(structKeyExists(e,"detail") && len(safeTrim(e.detail,""))) detailText = detailText & " | " & safeString(e.detail);
  jsonOut({success:false, message:"AI规划执行失败。", detail:detailText}, 500);
}
</cfscript>
