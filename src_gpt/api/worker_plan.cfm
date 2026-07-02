<cfsetting showdebugoutput="false" requesttimeout="900">
<cfscript>
CONTENT_TYPE_JSON = "application/json; charset=utf-8";

function safeString(any v, string fallback=""){
  if(isNull(arguments.v)) return arguments.fallback;
  if(isSimpleValue(arguments.v)) return toString(arguments.v);
  try { return serializeJson(arguments.v); } catch(any ignored) { return arguments.fallback; }
}
function safeTrim(any v, string fallback=""){
  return trim(safeString(arguments.v, arguments.fallback));
}
function appVal(required string key, string fallback=""){
  if(structKeyExists(application, arguments.key) && !isNull(application[arguments.key])){
    v = safeTrim(application[arguments.key], "");
    if(len(v)) return v;
  }
  return arguments.fallback;
}
function jsonOut(required struct payload, numeric statusCode=200){
  cfheader(statuscode=arguments.statusCode, statustext=(arguments.statusCode == 200 ? "OK" : "Plan Worker Error"));
  cfheader(name="Cache-Control", value="no-store, no-cache, must-revalidate, max-age=0");
  cfcontent(type=CONTENT_TYPE_JSON, reset=true);
  writeOutput(serializeJson(arguments.payload));
  abort;
}
function stripJson(required string text){
  s = trim(arguments.text);
  s = reReplace(s, "^```json[[:space:]]*", "", "one");
  s = reReplace(s, "^```[[:space:]]*", "", "one");
  s = reReplace(s, "[[:space:]]*```$", "", "one");
  firstBrace = find("{", s);
  revPos = find("}", reverse(s));
  lastBrace = 0;
  if(revPos > 0) lastBrace = len(s) - revPos + 1;
  if(firstBrace > 0 && lastBrace >= firstBrace) s = mid(s, firstBrace, lastBrace-firstBrace+1);
  return s;
}
function httpText(required any httpRes){
  if(isStruct(arguments.httpRes) && structKeyExists(arguments.httpRes,"fileContent") && !isNull(arguments.httpRes.fileContent)) return toString(arguments.httpRes.fileContent);
  return "";
}
function isHttpOk(required any httpRes){
  return isStruct(arguments.httpRes) && structKeyExists(arguments.httpRes,"statusCode") && find("200", toString(arguments.httpRes.statusCode)) > 0;
}
function errText(required any httpRes){
  raw = left(httpText(arguments.httpRes), 1600);
  try{
    parsed = deserializeJson(httpText(arguments.httpRes));
    if(isStruct(parsed) && structKeyExists(parsed,"error")){
      if(isStruct(parsed.error) && structKeyExists(parsed.error,"message")) return safeString(parsed.error.message);
      return serializeJson(parsed.error);
    }
  } catch(any ignored) {}
  return raw;
}
function callOpenAI(required string apiUri, required string apiKey, required struct body){
  httpRes = {};
  cfhttp(method="post", url=arguments.apiUri, result="httpRes", timeout="90"){
    cfhttpparam(type="header", name="Content-Type", value="application/json");
    cfhttpparam(type="header", name="Authorization", value="Bearer " & arguments.apiKey);
    cfhttpparam(type="body", value=serializeJson(arguments.body));
  }
  return httpRes;
}
function updateStep(required numeric jobId, required numeric progress, required string step){
  queryExecute("UPDATE ppt_jobs SET progress=:p, current_step=:s, updated_at=CURRENT_TIMESTAMP WHERE job_id=:id", {
    id:{value:arguments.jobId,cfsqltype:"cf_sql_integer"},
    p:{value:arguments.progress,cfsqltype:"cf_sql_integer"},
    s:{value:arguments.step,cfsqltype:"cf_sql_longvarchar"}
  }, {datasource:application.dsn});
}
function failJob(required numeric jobId, required string message, string detail=""){
  queryExecute("UPDATE ppt_jobs SET status='failed', progress=100, current_step=:step, error_message=:err, updated_at=CURRENT_TIMESTAMP WHERE job_id=:id", {
    id:{value:arguments.jobId,cfsqltype:"cf_sql_integer"},
    step:{value:arguments.message,cfsqltype:"cf_sql_longvarchar"},
    err:{value:left(arguments.detail,4000),cfsqltype:"cf_sql_longvarchar"}
  }, {datasource:application.dsn});
}
function ensureArray(required struct st, required string key){
  if(!structKeyExists(arguments.st, arguments.key) || isNull(arguments.st[arguments.key]) || !isArray(arguments.st[arguments.key])) arguments.st[arguments.key] = [];
}
function ensureString(required struct st, required string key, string fallback=""){
  if(!structKeyExists(arguments.st, arguments.key) || isNull(arguments.st[arguments.key])) arguments.st[arguments.key] = arguments.fallback;
  else arguments.st[arguments.key] = safeString(arguments.st[arguments.key], arguments.fallback);
}

function chineseOnly(required string txt){
  t = safeString(arguments.txt, "");
  t = reReplace(t, "[A-Za-z]{2,}", "", "all");
  return trim(t);
}
function hasNumericChart(required any cd){
  if(isNull(arguments.cd) || !isArray(arguments.cd) || arrayLen(arguments.cd) < 2) return false;
  good = 0;
  for(row in arguments.cd){
    if(isArray(row) && arrayLen(row) >= 2 && isNumeric(row[2])) good++;
    else if(isStruct(row) && structKeyExists(row,"value") && isNumeric(row.value)) good++;
  }
  return good >= 2;
}
function inferPageType(required struct sl){
  t = lcase(safeTrim(arguments.sl.title,"") & " " & safeTrim(arguments.sl.coreMessage,"") & " " & safeTrim(arguments.sl.section,""));
  lt = lcase(safeTrim(arguments.sl.layoutType,"cards"));
  if(find("架构",t) || find("层",t) && find("系统",t)) return "architecture";
  if(find("流程",t) || find("步骤",t) || find("路径",t) || find("计划",t)) return "process";
  if(find("矩阵",t) || find("对比",t) || find("选择",t) || find("评估",t)) return "matrix";
  if(find("时间",t) || find("路线",t) || find("里程碑",t) || find("阶段",t)) return "timeline";
  if(find("风险",t) || find("隐藏",t) || find("瓶颈",t)) return "framework";
  if(find("视觉",t) || find("图片",t) || find("场景",t) || find("主视觉",t)) return "image";
  if(hasNumericChart(arguments.sl.chartData) && (find("趋势",t) || find("预算",t) || find("指标",t) || find("数据",t) || find("收益",t) || find("损失",t))) return "chart";
  if(isArray(arguments.sl.tableRows) && arrayLen(arguments.sl.tableRows) >= 2) return "table";
  return lt;
}
function designReviewSlide(required struct sl, required numeric n, required string topic, required string templateType, required string mode){
  // Designer Reviewer: 不是补文字，而是把页面约束成可设计、可渲染、可中文展示的页面稿。
  arguments.sl.title = chineseOnly(safeTrim(arguments.sl.title,"第" & arguments.n & "页"));
  if(!len(arguments.sl.title)) arguments.sl.title = "第" & arguments.n & "页";
  arguments.sl.section = chineseOnly(safeTrim(arguments.sl.section,"正文"));
  if(!len(arguments.sl.section)) arguments.sl.section = "正文";
  arguments.sl.coreMessage = chineseOnly(safeTrim(arguments.sl.coreMessage,""));
  if(isArray(arguments.sl.supportingPoints)){
    pts=[];
    for(p in arguments.sl.supportingPoints){
      v = chineseOnly(safeTrim(p,""));
      if(len(v)) arrayAppend(pts, left(v,70));
    }
    arguments.sl.supportingPoints = pts;
  } else arguments.sl.supportingPoints=[];
  if(arrayLen(arguments.sl.supportingPoints) > 6) arguments.sl.supportingPoints = arraySlice(arguments.sl.supportingPoints,1,6);
  if(!len(arguments.sl.coreMessage) && arrayLen(arguments.sl.supportingPoints)) arguments.sl.coreMessage = arguments.sl.supportingPoints[1];

  pageType = inferPageType(arguments.sl);
  // 禁止把矩阵/流程/概念关系误判成柱状图
  if(pageType == "chart" && !hasNumericChart(arguments.sl.chartData)) pageType = "cards";
  if(listFindNoCase("matrix,process,architecture,framework,comparison", pageType)) arguments.sl.chartData = [];
  arguments.sl.pageType = pageType;
  arguments.sl.layoutType = pageType;
  arguments.sl.visualType = pageType;

  if(!structKeyExists(arguments.sl,"designSpec") || isNull(arguments.sl.designSpec) || !isStruct(arguments.sl.designSpec)) arguments.sl.designSpec = {};
  arguments.sl.designSpec.pageType = pageType;
  arguments.sl.designSpec.visualCenter = pageType == "architecture" ? "中心分层架构图" : pageType == "matrix" ? "三到四列对比矩阵" : pageType == "process" ? "横向步骤流程" : pageType == "framework" ? "左侧主题隐喻图，右侧风险/要点卡片" : pageType == "image" ? "大幅场景视觉图" : "标题加信息卡";
  arguments.sl.designSpec.composition = pageType == "image" ? "左侧65%主视觉，右侧35%说明卡" : pageType == "architecture" ? "中间60%分层结构，左右两侧小卡辅助解释" : pageType == "matrix" ? "整页矩阵表，顶部一句结论" : pageType == "process" ? "中部横向流程，底部关键提醒" : "上方标题，中部主体，底部小结";
  arguments.sl.designSpec.visualRules = "客户可见内容全中文；每页一个视觉中心；正文不超过六条；不用无意义柱状图；图标风格统一；留白充足。";

  // 给视觉页和非旅行主题补中文图像/素材计划，但不把英文prompt露出来
  if(!structKeyExists(arguments.sl,"imagePlan") || isNull(arguments.sl.imagePlan) || !isStruct(arguments.sl.imagePlan)) arguments.sl.imagePlan={};
  if(pageType == "image" || pageType == "architecture" || pageType == "framework"){
    if(!structKeyExists(arguments.sl.imagePlan,"scene") || !len(safeTrim(arguments.sl.imagePlan.scene,""))){
      arguments.sl.imagePlan.scene = arguments.templateType == "educational_course" ? "代码编辑器、文件夹结构和练习步骤组成的教学场景" : (findNoCase("咖啡", arguments.topic) ? "咖啡豆、杯测勺、风味轮和冲煮器具组成的温暖场景" : (findNoCase("Rust", arguments.topic) ? "订单系统架构、监控面板和灰度发布流程组成的商业技术场景" : "与主题相关的专业场景视觉"));
    }
    if(!structKeyExists(arguments.sl.imagePlan,"query")) arguments.sl.imagePlan.query = arguments.sl.imagePlan.scene;
    arguments.sl.imagePlan.aspectRatio = "16:9";
  }

  // Designer Reviewer补最少可用内容，防止空页
  if(arrayLen(arguments.sl.supportingPoints) < 3 && arguments.n > 1){
    while(arrayLen(arguments.sl.supportingPoints) < 3){
      arrayAppend(arguments.sl.supportingPoints, "围绕本页结论补充一个可执行判断点");
    }
  }
  return arguments.sl;
}
function enforceDeckDesign(required struct spec){
  if(!structKeyExists(arguments.spec,"slides") || !isArray(arguments.spec.slides)) return arguments.spec;
  total = arrayLen(arguments.spec.slides);
  // 每4页至少一个视觉/结构页；避免只有旅行有图
  for(i=4; i<=total; i+=4){
    hasVisual=false;
    start=max(1,i-3);
    for(j=start;j<=i && j<=total;j++){
      lt=lcase(safeTrim(arguments.spec.slides[j].layoutType,""));
      if(listFindNoCase("image,gallery,architecture,framework,timeline,process",lt)) hasVisual=true;
    }
    if(!hasVisual && i<=total){
      arguments.spec.slides[i].layoutType="framework";
      arguments.spec.slides[i].pageType="framework";
      arguments.spec.slides[i].visualType="framework";
      arguments.spec.slides[i].chartData=[];
      if(!structKeyExists(arguments.spec.slides[i],"imagePlan") || !isStruct(arguments.spec.slides[i].imagePlan)) arguments.spec.slides[i].imagePlan={};
      arguments.spec.slides[i].imagePlan.scene="主题结构关系视觉图";
    }
  }
  // 删除重复尾页和通用补充页
  clean=[];
  seenTitles={};
  for(sl in arguments.spec.slides){
    titleKey=lcase(safeTrim(sl.title,""));
    if(find("关键补充", titleKey) || find("补充", titleKey) == 1) continue;
    if(structKeyExists(seenTitles,titleKey) && len(titleKey)) continue;
    seenTitles[titleKey]=true;
    arrayAppend(clean, sl);
  }
  arguments.spec.slides=clean;
  return arguments.spec;
}

function normalizeSlide(required struct sl, required numeric n){
  arguments.sl.slideNo = arguments.n;
  ensureString(arguments.sl,"section","正文");
  if(!len(safeTrim(arguments.sl.section,""))) arguments.sl.section = "正文";
  ensureString(arguments.sl,"title","第" & arguments.n & "页");
  if(!len(safeTrim(arguments.sl.title,""))) arguments.sl.title = "第" & arguments.n & "页";
  ensureString(arguments.sl,"coreMessage","");
  ensureString(arguments.sl,"speakerNote","");
  ensureString(arguments.sl,"codeBlock","");
  ensureString(arguments.sl,"exerciseAnswer","");
  ensureString(arguments.sl,"image_search_query","");
  ensureString(arguments.sl,"layoutType","cards");
  if(!len(safeTrim(arguments.sl.layoutType,""))) arguments.sl.layoutType = "cards";
  ensureString(arguments.sl,"visualType",arguments.sl.layoutType);
  ensureArray(arguments.sl,"supportingPoints");
  ensureArray(arguments.sl,"chartData");
  ensureArray(arguments.sl,"tableRows");
  ensureArray(arguments.sl,"codeNotes");
  if(!structKeyExists(arguments.sl,"research") || isNull(arguments.sl.research) || !isStruct(arguments.sl.research)) arguments.sl.research = {};
  ensureArray(arguments.sl.research,"dataNeeds");
  ensureArray(arguments.sl.research,"facts");
  ensureArray(arguments.sl.research,"assumptions");
  ensureArray(arguments.sl.research,"verificationNeeded");
  ensureArray(arguments.sl.research,"imageQueries");
  if(!structKeyExists(arguments.sl,"imagePlan") || isNull(arguments.sl.imagePlan) || !isStruct(arguments.sl.imagePlan)) arguments.sl.imagePlan = {query:"", scene:"", aspectRatio:"16:9"};
  if(!structKeyExists(arguments.sl,"layout") || isNull(arguments.sl.layout) || !isStruct(arguments.sl.layout)) arguments.sl.layout = {type:arguments.sl.layoutType, density:"medium", composition:"standard"};
  if(!structKeyExists(arguments.sl,"quality") || isNull(arguments.sl.quality) || !isStruct(arguments.sl.quality)) arguments.sl.quality = {specificityScore:75, checks:[]};
  if(!structKeyExists(arguments.sl.quality,"checks") || isNull(arguments.sl.quality.checks) || !isArray(arguments.sl.quality.checks)) arguments.sl.quality.checks = [];
  return arguments.sl;
}
function scrubText(required string s){
  return reReplace(arguments.s, "OpenAI|Planner|Renderer|Agent|Pipeline|Prompt|Slide Spec|Gamma|Beautiful\.ai|Tome|token|cost|fallback|本地规划|规划器|渲染器", "", "all");
}
function scrubSpec(required struct spec){
  if(!structKeyExists(arguments.spec,"slides") || !isArray(arguments.spec.slides)) return arguments.spec;
  for(i=1; i<=arrayLen(arguments.spec.slides); i++){
    sl = arguments.spec.slides[i];
    if(isStruct(sl)){
      for(k in sl){ if(isSimpleValue(sl[k])) sl[k] = scrubText(toString(sl[k])); }
      arguments.spec.slides[i] = sl;
    }
  }
  return arguments.spec;
}
function getChoiceContent(required struct res){
  if(structKeyExists(arguments.res,"choices") && isArray(arguments.res.choices) && arrayLen(arguments.res.choices) >= 1){
    if(structKeyExists(arguments.res.choices[1],"message") && structKeyExists(arguments.res.choices[1].message,"content")) return safeString(arguments.res.choices[1].message.content, "");
  }
  return "";
}
function usageVal(required struct res, required string key){
  if(structKeyExists(arguments.res,"usage") && isStruct(arguments.res.usage) && structKeyExists(arguments.res.usage, arguments.key)) return val(arguments.res.usage[arguments.key]);
  return 0;
}
function buildChunkBody(required string model, required string systemPrompt, required string userPrompt, numeric maxTokens=2600){
  b = {
    model: arguments.model,
    temperature: 0.25,
    response_format: {type:"json_object"},
    messages: [
      {role:"system", content:arguments.systemPrompt},
      {role:"user", content:arguments.userPrompt}
    ]
  };
  // gpt-5 / reasoning models can spend tokens on reasoning and return empty content if the cap is too low.
  // Give them a real output budget. For classic chat models keep max_tokens.
  if(findNoCase("gpt-5", arguments.model) || findNoCase("o3", arguments.model) || findNoCase("o4", arguments.model)){
    b.max_completion_tokens = max(arguments.maxTokens, 8000);
    b.reasoning_effort = "minimal";
  } else {
    b.max_tokens = arguments.maxTokens;
  }
  return b;
}
function tryOpenAIJsonOnce(required string apiUri, required string apiKey, required struct body){
  h = callOpenAI(arguments.apiUri, arguments.apiKey, arguments.body);
  if(!isHttpOk(h)){
    msg = errText(h);
    rb = duplicate(arguments.body);
    if(findNoCase("Unsupported parameter", msg) || findNoCase("Unrecognized request argument", msg) || findNoCase("max_tokens", msg)){
      if(structKeyExists(rb,"max_tokens")){
        rb.max_completion_tokens = max(val(rb.max_tokens), 8000);
        structDelete(rb,"max_tokens",false);
      } else if(structKeyExists(rb,"max_completion_tokens")){
        rb.max_tokens = rb.max_completion_tokens;
        structDelete(rb,"max_completion_tokens",false);
        structDelete(rb,"reasoning_effort",false);
      }
      h = callOpenAI(arguments.apiUri, arguments.apiKey, rb);
    }
  }
  if(!isHttpOk(h)) throw(message="OpenAI调用失败", detail="HTTP " & safeString(h.statusCode,"unknown") & "：" & errText(h));
  txt = httpText(h);
  try{ parsed = deserializeJson(txt); } catch(any e){ throw(message="OpenAI响应不是JSON", detail=left(txt,1200)); }
  content = getChoiceContent(parsed);
  if(!len(trim(content))){
    fr = "";
    if(structKeyExists(parsed,"choices") && isArray(parsed.choices) && arrayLen(parsed.choices) && structKeyExists(parsed.choices[1],"finish_reason")) fr = safeString(parsed.choices[1].finish_reason,"");
    throw(message="OpenAI返回空内容", detail="finish_reason=" & fr & "；通常是输出token不足或模型推理耗尽。请重试或换用非reasoning模型。原始响应：" & left(txt,900));
  }
  js = stripJson(content);
  try{ obj = deserializeJson(js); } catch(any pe){ throw(message="规划JSON解析失败", detail=pe.message & " | " & left(js,1200)); }
  obj.__prompt_tokens = usageVal(parsed,"prompt_tokens");
  obj.__completion_tokens = usageVal(parsed,"completion_tokens");
  obj.__total_tokens = usageVal(parsed,"total_tokens");
  return obj;
}
function openAIJson(required string apiUri, required string apiKey, required struct body){
  try{
    return tryOpenAIJsonOnce(arguments.apiUri, arguments.apiKey, arguments.body);
  } catch(any e1){
    // If gpt-5 returns empty content or times out, retry the same prompt with stable JSON model.
    retryBody = duplicate(arguments.body);
    retryBody.model = "gpt-4.1-mini";
    retryBody.max_tokens = 5000;
    structDelete(retryBody,"max_completion_tokens",false);
    structDelete(retryBody,"reasoning_effort",false);
    try{
      sleep(800);
      return tryOpenAIJsonOnce(arguments.apiUri, arguments.apiKey, retryBody);
    } catch(any e2){
      throw(message=safeString(e2.message, safeString(e1.message,"OpenAI规划失败")), detail=safeString(e2.detail, safeString(e1.detail,"")));
    }
  }
}

jobId = 0; jobQ = {}; topic=""; brief=""; audience=""; mode=""; theme=""; templateType=""; templateRules="";
apiKey=""; apiUri=""; model=""; targetSlides=20; nl=chr(10); started=getTickCount(); pt=0; ct=0; tt=0; allSlides=[];
try{
  jobId = val(url.jobId ?: 0);
  if(jobId <= 0) jsonOut({success:false,message:"jobId 无效。"},400);
  jobQ = queryExecute("SELECT * FROM ppt_jobs WHERE job_id=:id LIMIT 1", {id:{value:jobId,cfsqltype:"cf_sql_integer"}}, {datasource:application.dsn});
  if(!jobQ.recordCount) jsonOut({success:false,message:"任务不存在。"},404);
  if(toString(jobQ.status[1]) == "plan_completed") jsonOut({success:true,status:"plan_completed"});
  if(toString(jobQ.status[1]) == "failed") jsonOut({success:false,message:"任务已失败。",detail:toString(jobQ.error_message[1] ?: "")},409);

  topic = safeTrim(jobQ.topic[1], "");
  brief = safeTrim(jobQ.brief[1], "");
  audience = safeTrim(jobQ.audience[1], "");
  mode = safeTrim(jobQ.mode[1], "beauty");
  theme = safeTrim(jobQ.theme[1], "auto");
  templateType = safeTrim(jobQ.template_type[1], "proposal");
  templateRules = safeTrim(jobQ.presentation_prompt[1], "");
  apiKey = appVal("openaiApiKey", "");
  apiUri = appVal("openaiApiUri", "https://api.openai.com/v1/chat/completions");
  model = appVal("openaiQualityModel", appVal("openaiModel", "gpt-4.1-mini"));
  if(findNoCase("gpt-5", model)) model = appVal("openaiModel", "gpt-4.1-mini"); // v21: 规划优先稳定JSON输出，避免reasoning模型空content
  if(!len(topic)) { failJob(jobId,"规划失败","主题为空"); jsonOut({success:false,message:"主题为空。"},400); }
  if(!len(apiKey)) { failJob(jobId,"AI配置缺失","OpenAI API Key 未配置"); jsonOut({success:false,message:"OpenAI API Key 未配置。"},500); }

  targetSlides = 22;
  if(mode == "beauty") targetSlides = 26;
  if(mode == "economic") targetSlides = 16;
  updateStep(jobId, 10, "正在拆分规划任务");

  systemPrompt = "你是中国客户场景下的资深PPT导演、内容总监、版式设计师和质量审稿人。你不是写Markdown的人，而是先做结构大纲、再做逐页文稿、再做页面视觉设计、最后输出可直接渲染的逐页设计稿。只输出合法JSON，不输出Markdown。客户可见文本必须100%中文，不得出现英文界面词、开发过程、模型、成本、token、Prompt、Agent、Renderer、Slide Spec等内部词。每页必须先有页面类型，再有设计意图，再有可落地内容。";
  baseRules = "主题：" & topic & nl & "简介：" & brief & nl & "目标受众：" & audience & nl & "风格：" & theme & nl & "模板类型：" & templateType & nl & "模板规则：" & templateRules & nl & "整套目标页数：" & targetSlides & nl &
    "生成流程要求：先像人类PPT顾问一样生成大纲，再生成逐页文稿，再为每页生成视觉稿设计。输出给系统的是结构化JSON，不是文章。每页都必须包含：section、title、coreMessage、supportingPoints、pageType、layoutType、visualType、visualIntent、designSpec、tableRows、chartData、imagePlan、speakerNote、reviewerNotes。" & nl &
    "页面类型库：cover、section、cards、process、timeline、table、matrix、architecture、framework、comparison、image、gallery,kpi,quote,summary,code。Designer Reviewer必须检查：是否中文、是否有唯一视觉中心、是否用了错误图表、是否像信息图、是否有具体行动信息。每页必须从中选择，不能全部用chart或cards。整套PPT只允许2到4种主布局重复使用，形成统一感。" & nl &
    "设计层要求：designSpec必须写中文，包括主视觉、左右/上下比例、元素数量、图标风格、留白策略、重点强调方式。页面要像信息图，而不是把文字塞进框。标题要大，正文要少，最多4到6个信息块。" & nl &
    "图表规则：只有真实数值比较、趋势、比例、评分、预算、时间、人次、金额才允许chartData。chartData必须是[[中文标签,数字,单位],...]。口味、风险、能力、流程、架构、矩阵、SWOT、概念关系一律不能画柱状图，必须用matrix/table/process/architecture/cards。不要为了凑视觉做伪图表。" & nl &
    "图片和视觉规则：每4到5页至少安排1页 image/gallery/architecture/framework 视觉页。非旅行主题也必须有视觉：咖啡用咖啡豆/风味轮/冲煮器具/包装标签；技术提案用系统架构/流程/风险冰山/路线图；年度复盘用时间轴/成长曲线/关键事件卡；课程用代码场景/练习流程/目录树。imagePlan.scene必须中文，imagePlan.prompt可以英文但不得显示给客户。" & nl &
    "内容质量要求：每页一个明确结论，避免空话。涉及酒店、商品、价格、预算、市场规模等必须给参考区间并标注待核验。课程页必须给代码、逐行解释、练习题和参考答案。CEO/老板汇报必须用业务语言：损失、收益、风险、决策、阶段验收，少用底层技术术语。" & nl &
    "主题动态要求：无论主题是什么，都必须生成足量页面，不得只输出7页；不得使用通用补充页。咖啡主题要覆盖烘焙度、产地、处理法、风味轮、冲煮方式、购买渠道、试错路径、价格区间和避坑。Rust给CEO要覆盖业务损失、为什么不是Java/Go补丁、PoC边界、投资回报、90天计划、失败条件、回滚路径、预算和决策请求。" & nl &
    "模式差异：beauty=更像商业设计稿，更多信息图/视觉页/留白，文字少；balanced=图文均衡、可讲可读；economic=页数少、表格清单多、少装饰但仍专业。";

  // 先让模型给章节蓝图，短请求，避免一次性大JSON 504。
  outlinePrompt = baseRules & nl & nl & '请输出JSON：{"deckTitle":"...","subtitle":"...","sections":[{"name":"...","purpose":"...","slideCount":数字}],"narrative":"..."}。sections的slideCount合计必须等于' & targetSlides & '，且章节名称必须贴合主题，不得使用通用占位章节。';
  updateStep(jobId, 18, "正在生成章节蓝图");
  outline = openAIJson(apiUri, apiKey, buildChunkBody(model, systemPrompt, outlinePrompt, 3200));
  pt += val(outline.__prompt_tokens); ct += val(outline.__completion_tokens); tt += val(outline.__total_tokens);
  deckTitle = structKeyExists(outline,"deckTitle") ? safeTrim(outline.deckTitle, topic) : topic;
  subtitle = structKeyExists(outline,"subtitle") ? safeTrim(outline.subtitle, brief) : brief;
  sections = [];
  if(structKeyExists(outline,"sections") && isArray(outline.sections)) sections = outline.sections;

  pageStart = 1;
  chunkSize = 3;
  chunkIndex = 0;
  while(pageStart <= targetSlides){
    pageEnd = min(pageStart + chunkSize - 1, targetSlides);
    chunkIndex++;
    updateStep(jobId, 18 + int((pageStart-1)/targetSlides*70), "正在生成第 " & pageStart & "-" & pageEnd & " 页");
    chunkPrompt = baseRules & nl & "章节蓝图：" & serializeJson(sections) & nl & nl &
      "只生成第" & pageStart & "到第" & pageEnd & "页，返回JSON：" & chr(123) & '"slides":[...]' & chr(125) & "。" & nl &
      "每个slide字段必须包含：slideNo, section, pageRole, layoutType, visualType, title, coreMessage, supportingPoints(3-5条), speakerNote, research{dataNeeds,facts,assumptions,verificationNeeded,imageQueries}, imagePlan{query,scene,aspectRatio,prompt}, chartData, tableRows, codeBlock, codeNotes, exerciseAnswer, layout{type,density,composition}, quality{specificityScore,checks}。" & nl &
      "表格页必须给tableRows，第一行是表头；图表页必须给chartData二维数组，格式必须是[中文标签,数字,单位/说明]；代码页必须给完整codeBlock和codeNotes；练习页必须给exerciseAnswer；图片页必须给imagePlan.prompt，不要留空，并给中文scene。" & nl &
      "再次强调：除 imagePlan.prompt 外，所有客户可见字段必须中文。不要输出英文标题、英文图表标签、英文说明。" & nl &
      "layoutType只能从cover,agenda,section_divider,timeline,roadmap,cards,data_cards,process,comparison,matrix,table,big_number,quote,summary,closing,image,gallery,chart,code中选。" & nl &
      "第1页如在本范围内必须是cover；最后一页如在本范围内必须是summary或closing。不要生成范围外页面。";
    chunk = openAIJson(apiUri, apiKey, buildChunkBody(model, systemPrompt, chunkPrompt, 5200));
    pt += val(chunk.__prompt_tokens); ct += val(chunk.__completion_tokens); tt += val(chunk.__total_tokens);
    if(!structKeyExists(chunk,"slides") || !isArray(chunk.slides) || !arrayLen(chunk.slides)) throw(message="分段规划为空", detail="第" & pageStart & "-" & pageEnd & "页没有返回slides");
    for(s in chunk.slides){
      if(isStruct(s)) arrayAppend(allSlides, designReviewSlide(normalizeSlide(s, arrayLen(allSlides)+1), arrayLen(allSlides)+1, topic, templateType, mode));
    }
    pageStart = pageEnd + 1;
  }

  if(arrayLen(allSlides) < targetSlides) throw(message="AI规划内容不完整", detail="目标" & targetSlides & "页，实际" & arrayLen(allSlides) & "页。请重新生成规划。");
  if(arrayLen(allSlides) > targetSlides) allSlides = arraySlice(allSlides, 1, targetSlides);

  spec = {
    deckTitle: deckTitle,
    subtitle: subtitle,
    audience: audience,
    templateType: templateType,
    mode: mode,
    themeHint: theme,
    evidenceNotice: "实时价格、库存、图片、法律法规、产品参数等外部事实需二次核验。",
    researchPack: {evidencePolicy:"实时事实和图片必须核验；不可由排版阶段编造。", sections:sections},
    sections: sections,
    slides: allSlides
  };
  spec = enforceDeckDesign(spec);
  spec = scrubSpec(spec);
  est = ((pt/1000000)*0.4) + ((ct/1000000)*1.6);
  dur = getTickCount() - started;
  queryExecute("UPDATE ppt_jobs SET status='plan_completed', progress=100, current_step='规划已完成', slide_spec_json=:spec, prompt_tokens=:pt, completion_tokens=:ct, total_tokens=:tt, estimated_cost=:est, duration_ms=:dur, slide_count=:cnt, model=:model, provider='openai', updated_at=CURRENT_TIMESTAMP WHERE job_id=:id", {
    id:{value:jobId,cfsqltype:"cf_sql_integer"}, spec:{value:serializeJson(spec),cfsqltype:"cf_sql_longvarchar"},
    pt:{value:pt,cfsqltype:"cf_sql_integer"}, ct:{value:ct,cfsqltype:"cf_sql_integer"}, tt:{value:tt,cfsqltype:"cf_sql_integer"},
    est:{value:est,cfsqltype:"cf_sql_decimal",scale:6}, dur:{value:dur,cfsqltype:"cf_sql_integer"}, cnt:{value:arrayLen(allSlides),cfsqltype:"cf_sql_integer"}, model:{value:model,cfsqltype:"cf_sql_longvarchar"}
  }, {datasource:application.dsn});
  jsonOut({success:true,status:"plan_completed",slideCount:arrayLen(allSlides),duration_ms:dur});
}catch(any e){
  detailText = safeString(e.message,"AI规划失败") & (structKeyExists(e,"detail") && len(safeTrim(e.detail,"")) ? " | " & safeString(e.detail) : "");
  if(jobId > 0) failJob(jobId,"AI规划失败",detailText);
  jsonOut({success:false,message:"AI规划失败，请稍后重试。",detail:detailText},500);
}
</cfscript>
