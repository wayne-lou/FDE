<cfscript>
setting requesttimeout=600;
contentType = "application/json; charset=utf-8";

function jsonOut(required struct payload, numeric statusCode=200){
  var statusText = "Worker Error";
  if(arguments.statusCode == 200) statusText = "OK";
  cfheader(statuscode=arguments.statusCode, statustext=statusText);
  cfcontent(type=contentType, reset=true);
  writeOutput(serializeJson(arguments.payload));
  abort;
}

function appVal(required string key, string fallback=""){
  if(structKeyExists(application, arguments.key) && !isNull(application[arguments.key]) && len(trim(toString(application[arguments.key])))) return trim(toString(application[arguments.key]));
  return arguments.fallback;
}

function estimateCost(numeric promptTokens, numeric completionTokens){
  return (arguments.promptTokens / 1000000 * 0.15) + (arguments.completionTokens / 1000000 * 0.60);
}

function stripFence(required string text){
  var t = trim(arguments.text);
  t = rereplace(t, "^```json\s*", "", "one");
  t = rereplace(t, "^```\s*", "", "one");
  t = rereplace(t, "\s*```$", "", "one");
  return trim(t);
}

function safeText(any value="", string fallback=""){
  if(isNull(arguments.value)) return arguments.fallback;
  var textValue = trim(toString(arguments.value));
  if(!len(textValue)) return arguments.fallback;
  return textValue;
}


function compactText(any value="", numeric maxLen=2000){
  if(isNull(arguments.value)) return "";
  var t = trim(toString(arguments.value));
  t = rereplace(t, "[\r\n\t]+", " ", "all");
  if(len(t) > arguments.maxLen) t = left(t, arguments.maxLen - 3) & "...";
  return t;
}

function ensureJobTextColumns(){
  // 老库里 current_step / error_message / ppt_filename 曾经是 VARCHAR(100)，
  // 一旦写入中文长错误就会触发“值太长(100)”。worker 启动时强制扩容。
  var alters = [
    "ALTER TABLE ppt_jobs ALTER COLUMN topic TYPE TEXT",
    "ALTER TABLE ppt_jobs ALTER COLUMN brief TYPE TEXT",
    "ALTER TABLE ppt_jobs ALTER COLUMN audience TYPE TEXT",
    "ALTER TABLE ppt_jobs ALTER COLUMN template_type TYPE TEXT",
    "ALTER TABLE ppt_jobs ALTER COLUMN theme TYPE TEXT",
    "ALTER TABLE ppt_jobs ALTER COLUMN mode TYPE TEXT",
    "ALTER TABLE ppt_jobs ALTER COLUMN provider TYPE TEXT",
    "ALTER TABLE ppt_jobs ALTER COLUMN model TYPE TEXT",
    "ALTER TABLE ppt_jobs ALTER COLUMN current_step TYPE TEXT",
    "ALTER TABLE ppt_jobs ALTER COLUMN error_message TYPE TEXT",
    "ALTER TABLE ppt_jobs ALTER COLUMN ppt_filename TYPE TEXT",
    "ALTER TABLE ppt_jobs ALTER COLUMN output_file TYPE TEXT",
    "ALTER TABLE ppt_jobs ALTER COLUMN slide_spec_json TYPE TEXT",
    "ALTER TABLE ppt_jobs ALTER COLUMN presentation_prompt TYPE TEXT",
    "ALTER TABLE ppt_jobs ALTER COLUMN response_id TYPE TEXT"
  ];
  for(var sqlText in alters){
    try { queryExecute(sqlText, {}, {datasource:application.dsn}); } catch(any ignored) {}
  }
}

function updateJob(required numeric jobId, required string status, required numeric progress, required string step, string errorMessage=""){
  queryExecute("
    UPDATE ppt_jobs
    SET status = :status,
        progress = :progress,
        current_step = :current_step,
        error_message = :error_message,
        updated_at = CURRENT_TIMESTAMP
    WHERE job_id = :job_id
  ", {
    job_id:{value:arguments.jobId, cfsqltype:"cf_sql_integer"},
    status:{value:left(arguments.status, 40), cfsqltype:"cf_sql_varchar"},
    progress:{value:arguments.progress, cfsqltype:"cf_sql_integer"},
    current_step:{value:compactText(arguments.step, 1000), cfsqltype:"cf_sql_longvarchar"},
    error_message:{value:compactText(arguments.errorMessage, 3000), cfsqltype:"cf_sql_longvarchar"}
  }, {datasource:application.dsn});
}

function savePrompt(required numeric jobId, required string promptText, required struct usage){
  queryExecute("
    UPDATE ppt_jobs
    SET presentation_prompt = :presentation_prompt,
        prompt_tokens = COALESCE(prompt_tokens, 0) + :prompt_tokens,
        completion_tokens = COALESCE(completion_tokens, 0) + :completion_tokens,
        total_tokens = COALESCE(total_tokens, 0) + :total_tokens,
        estimated_cost = COALESCE(estimated_cost, 0) + :estimated_cost,
        updated_at = CURRENT_TIMESTAMP
    WHERE job_id = :job_id
  ", {
    job_id:{value:arguments.jobId, cfsqltype:"cf_sql_integer"},
    presentation_prompt:{value:arguments.promptText, cfsqltype:"cf_sql_longvarchar"},
    prompt_tokens:{value:arguments.usage.prompt_tokens, cfsqltype:"cf_sql_integer"},
    completion_tokens:{value:arguments.usage.completion_tokens, cfsqltype:"cf_sql_integer"},
    total_tokens:{value:arguments.usage.total_tokens, cfsqltype:"cf_sql_integer"},
    estimated_cost:{value:arguments.usage.estimated_cost, cfsqltype:"cf_sql_decimal", scale:6}
  }, {datasource:application.dsn});
}

function saveSpec(required numeric jobId, required struct spec, required struct usage, required string responseId){
  queryExecute("
    UPDATE ppt_jobs
    SET slide_spec_json = :slide_spec_json,
        response_id = :response_id,
        prompt_tokens = COALESCE(prompt_tokens, 0) + :prompt_tokens,
        completion_tokens = COALESCE(completion_tokens, 0) + :completion_tokens,
        total_tokens = COALESCE(total_tokens, 0) + :total_tokens,
        estimated_cost = COALESCE(estimated_cost, 0) + :estimated_cost,
        slide_count = :slide_count,
        updated_at = CURRENT_TIMESTAMP
    WHERE job_id = :job_id
  ", {
    job_id:{value:arguments.jobId, cfsqltype:"cf_sql_integer"},
    slide_spec_json:{value:serializeJson(arguments.spec), cfsqltype:"cf_sql_longvarchar"},
    response_id:{value:arguments.responseId, cfsqltype:"cf_sql_longvarchar"},
    prompt_tokens:{value:arguments.usage.prompt_tokens, cfsqltype:"cf_sql_integer"},
    completion_tokens:{value:arguments.usage.completion_tokens, cfsqltype:"cf_sql_integer"},
    total_tokens:{value:arguments.usage.total_tokens, cfsqltype:"cf_sql_integer"},
    estimated_cost:{value:arguments.usage.estimated_cost, cfsqltype:"cf_sql_decimal", scale:6},
    slide_count:{value:arrayLen(arguments.spec.slides), cfsqltype:"cf_sql_integer"}
  }, {datasource:application.dsn});
}

function saveRender(required numeric jobId, required struct renderResult, required numeric durationMs){
  queryExecute("
    UPDATE ppt_jobs
    SET status = 'completed',
        progress = 100,
        current_step = 'PPT 已生成，可以下载',
        ppt_filename = :ppt_filename,
        output_file = :output_file,
        ppt_size = :ppt_size,
        slide_count = :slide_count,
        duration_ms = :duration_ms,
        updated_at = CURRENT_TIMESTAMP
    WHERE job_id = :job_id
  ", {
    job_id:{value:arguments.jobId, cfsqltype:"cf_sql_integer"},
    ppt_filename:{value:arguments.renderResult.file_name, cfsqltype:"cf_sql_longvarchar"},
    output_file:{value:arguments.renderResult.file_path, cfsqltype:"cf_sql_longvarchar"},
    ppt_size:{value:arguments.renderResult.file_size, cfsqltype:"cf_sql_bigint"},
    slide_count:{value:arguments.renderResult.slide_count, cfsqltype:"cf_sql_integer"},
    duration_ms:{value:arguments.durationMs, cfsqltype:"cf_sql_integer"}
  }, {datasource:application.dsn});
}

function modelForJob(required query job, string stage="slide"){
  var baseModel = appVal("openaiModel", appVal("llmModel", "gpt-4.1-mini"));
  return baseModel;
}

function openAiJson(required string systemPrompt, required string userPrompt, numeric timeoutSeconds=180, string modelName=""){
  var apiKey = appVal("openaiApiKey");
  if(!len(apiKey)) throw(message="OpenAI API Key 未配置。");
  var modelNameLocal = appVal("openaiModel", appVal("llmModel", "gpt-4.1-mini"));
  if(len(arguments.modelName)) modelNameLocal = arguments.modelName;
  var fallbackModel = "gpt-4o-mini";
  if(modelNameLocal == fallbackModel){
    fallbackModel = appVal("openaiModel", appVal("llmModel", "gpt-4.1-mini"));
  }
  var apiUri = appVal("openaiApiUri", "https://api.openai.com/v1/chat/completions");
  var body = {
    model:modelNameLocal,
    temperature:0.35,
    response_format:{type:"json_object"},
    messages:[
      {role:"system", content:arguments.systemPrompt},
      {role:"user", content:arguments.userPrompt}
    ]
  };
  cfhttp(url=apiUri, method="post", result="httpResult", timeout=arguments.timeoutSeconds){
    cfhttpparam(type="header", name="Authorization", value="Bearer " & apiKey);
    cfhttpparam(type="header", name="Content-Type", value="application/json");
    cfhttpparam(type="body", value=serializeJson(body));
  }
  if(!find("200", httpResult.statusCode)){
    sleep(1500);
    cfhttp(url=apiUri, method="post", result="httpResult", timeout=arguments.timeoutSeconds){
      cfhttpparam(type="header", name="Authorization", value="Bearer " & apiKey);
      cfhttpparam(type="header", name="Content-Type", value="application/json");
      cfhttpparam(type="body", value=serializeJson(body));
    }
  }
  if(!find("200", httpResult.statusCode) && modelNameLocal != fallbackModel){
    body.model = fallbackModel;
    cfhttp(url=apiUri, method="post", result="httpResult", timeout=arguments.timeoutSeconds){
      cfhttpparam(type="header", name="Authorization", value="Bearer " & apiKey);
      cfhttpparam(type="header", name="Content-Type", value="application/json");
      cfhttpparam(type="body", value=serializeJson(body));
    }
    modelNameLocal = fallbackModel;
  }
  if(!find("200", httpResult.statusCode)){
    throw(message="OpenAI 请求失败：" & httpResult.statusCode, detail=left(toString(httpResult.fileContent), 1200));
  }
  var parsed = deserializeJson(toString(httpResult.fileContent));
  var content = stripFence(toString(parsed.choices[1].message.content));
  var usage = {prompt_tokens:0, completion_tokens:0, total_tokens:0, estimated_cost:0};
  if(structKeyExists(parsed, "usage")){
    if(structKeyExists(parsed.usage, "prompt_tokens")) usage.prompt_tokens = val(parsed.usage.prompt_tokens);
    if(structKeyExists(parsed.usage, "completion_tokens")) usage.completion_tokens = val(parsed.usage.completion_tokens);
    if(structKeyExists(parsed.usage, "total_tokens")) usage.total_tokens = val(parsed.usage.total_tokens);
    usage.estimated_cost = estimateCost(usage.prompt_tokens, usage.completion_tokens);
  }
  var responseId = "";
  if(structKeyExists(parsed, "id")) responseId = toString(parsed.id);
  return {
    model:modelNameLocal,
    response_id:responseId,
    content:content,
    json:deserializeJson(content),
    usage:usage
  };
}
function templateRules(required string templateType){
  var rules = {
    educational_course:"学习目标、概念地图、核心概念、例子、练习、小项目、常见错误、总结",
    executive_proposal:"结论先行、业务问题、影响、方案、收益、风险、迁移计划、决策请求",
    decision_guide:"决策问题、评价维度、选项、对比矩阵、推荐路径、避坑、总结",
    travel_guide:"行程总览、Day1、Day2、交通、预算、拍照点、避坑、清单",
    annual_review:"年度主线、成果、坑、转折、反思、下一年计划、总结",
    proposal:"背景、目标、问题、方案、流程、价值、风险、下一步"
  };
  if(structKeyExists(rules, arguments.templateType)) return rules[arguments.templateType];
  return rules.proposal;
}
function makePresentationPrompt(required query job){
  var systemPrompt = "你是资深中文 Presentation Architect。只输出合法 JSON。";
  var userPrompt =
    "为下面输入生成一份可编辑 Presentation Prompt。它不是调试说明，而是给 Slide Planner 和用户共同使用的制作稿。" & chr(10) &
    "主题：" & job.topic[1] & chr(10) &
    "简介：" & job.brief[1] & chr(10) &
    "目标受众：" & job.audience[1] & chr(10) &
    "模式：" & job.mode[1] & chr(10) &
    "风格：" & job.theme[1] & chr(10) &
    "模板类型：" & job.template_type[1] & chr(10) &
    "模板骨架：" & templateRules(job.template_type[1]) & chr(10) & chr(10) &
    "Prompt 必须包含：演示目标、内容研究、故事线、章节规划、逐页制作要求、图片/图表/代码策略、质量底线。" & chr(10) &
    "必须要求逐页 Markdown 可读：每页标题、核心结论、正文要点、图片计划、表格或图表计划、讲稿备注。" & chr(10) &
    "如果是 Python/教学主题，必须要求真实代码块和逐行中文注释，尤其文件整理脚本要有 pathlib/shutil 或 os 示例、测试步骤、常见错误。" & chr(10) &
    "如果是旅行主题，必须要求专业图片计划，图片要匹配具体地点与页面内容，不能随机图。" & chr(10) &
    "禁止空话和模板腔：形成清晰判断、具体执行建议、本页聚焦、听众看完、为什么重要、保留一个可复盘、解释XXX关系、继续判断。" & chr(10) &
    "输出 JSON：{""presentation_prompt"":""...""}。";
  var result = openAiJson(systemPrompt, userPrompt, 120, modelForJob(job,"prompt"));
  if(!structKeyExists(result.json, "presentation_prompt") || !len(trim(toString(result.json.presentation_prompt)))){
    throw(message="OpenAI 未返回可用 Presentation Prompt。");
  }
  return {text:toString(result.json.presentation_prompt), usage:result.usage, model:result.model};
}

function makeSlideSpec(required query job, required string promptText){
  var slideCount = 25;
  if(job.mode[1] == "beauty") slideCount = 25;
  var template = lcase(safeText(job.template_type[1], "proposal"));
  var systemPrompt = "你是顶级中文 PPT 成稿作者。只输出合法 JSON。你写的是可以直接进入 PPT 的逐页成稿，不是提纲、不是写作建议。";
  var modeRule = "balanced：信息密度更高，更多卡片/表格/流程/总结页；视觉克制但内容质量不能下降。";
  if(job.mode[1] == "beauty") modeRule = "beauty：强视觉、更多图片页/时间线/矩阵/大数字/图表页；标题更有冲击力，留白更大。";
  var typeRule = "";
  if(find("educational", template)){
    typeRule = "教学类硬要求：必须包含变量、循环、函数、列表、字典、自动化脚本、小项目、常见错误和练习路径。代码页必须有 codeBlock 和 codeNotes，codeNotes 要逐行解释关键语句。文件整理脚本必须包含 pathlib/shutil 或 os 示例。";
  } else if(find("travel", template)){
    typeRule = "旅行类硬要求：必须包含 Day1/Day2 时间线、路线、交通、预算、餐饮、拍照点、避坑和清单。每个图片页必须给 imagePlan.prompt，英文完整句，匹配具体地点，不要随机风景。";
  } else if(find("executive", template)){
    typeRule = "高管说服类硬要求：必须包含业务损失、性能瓶颈、方案、ROI、风险矩阵、迁移计划、决策请求。必须有数字区间或假设来源说明。";
  } else if(find("decision", template)){
    typeRule = "决策指南类硬要求：必须包含评价维度、候选方案、对比矩阵、推荐路径、避坑清单、购买或执行建议。";
  } else if(find("annual", template)){
    typeRule = "复盘类硬要求：必须包含年度主线、成果证据、踩坑成本、认知变化、下一年计划、总结。";
  } else {
    typeRule = "通用方案类硬要求：必须包含背景、问题、方案流程、架构或模块、价值指标、风险和下一步执行表。";
  }
  var outputSchema = {
    deckTitle:"",
    subtitle:"",
    audience:"",
    templateType:"",
    themeHint:"",
    sections:[
      {name:"", purpose:"", slideStart:1, slideEnd:4}
    ],
    slides:[
      {
        slideNo:1,
        section:"",
        layoutType:"cover|agenda|section_divider|image|timeline|cards|comparison|matrix|table|chart|process|big_number|quote|summary|closing|code",
        title:"",
        coreMessage:"",
        supportingPoints:["","",""],
        thinkAboutIt:"",
        visualType:"cards|timeline|process|matrix|big_number|quote|table|chart|image|none",
        visualIntent:"",
        imagePlan:{role:"hero|background|supporting|thumbnail|none", prompt:"", placement:""},
        chartSuggestion:{chartType:"bar|line|pie|donut|matrix|timeline|none", reason:"", dataHint:""},
        codeBlock:"",
        codeNotes:[""],
        tableRows:[["列1","列2","列3"]],
        speakerNote:""
      }
    ]
  };
  var userPrompt = left(arguments.promptText, 1400) & chr(10) & chr(10) &
    "现在生成最终 Slide Spec。" & chr(10) &
    "主题：" & job.topic[1] & chr(10) &
    "简介：" & job.brief[1] & chr(10) &
    "目标受众：" & job.audience[1] & chr(10) &
    "模板骨架：" & templateRules(job.template_type[1]) & chr(10) &
    "页数：严格 " & slideCount & " 页。" & chr(10) &
    "模式规则：" & modeRule & chr(10) &
    typeRule & chr(10) &
    "每页必须围绕具体主题展开，只讲一个观点。不要重复标题，不要重复 point，不要写元话术。" & chr(10) &
    "每页支持字段：coreMessage、supportingPoints、thinkAboutIt、speakerNote、codeBlock、codeNotes、tableRows、chartData、imagePlan、image_search_query。" & chr(10) &
    "图片计划：imagePlan={role,prompt,placement}。prompt 必须是英文完整画面描述，例如 Golden hour view of Kiyomizu-dera Temple in Kyoto, cinematic travel photography, ultra wide angle, editorial magazine style。" & chr(10) &
    "代码说明：如果有 codeBlock，必须有 codeNotes，每条解释一个关键语句或坑点。" & chr(10) &
    "禁用词：形成清晰判断、具体执行建议、本页聚焦、听众看完、为什么重要、保留一个可复盘、把复杂内容变成清晰、解释XXX关系、继续判断、视觉化表达、结构化叙事。" & chr(10) &
    "JSON格式：" & chr(10) &
    serializeJson(outputSchema);
  var result = openAiJson(systemPrompt, userPrompt, 180, modelForJob(job,"slide"));
  var spec = result.json;
  if(!structKeyExists(spec, "slides") || !isArray(spec.slides) || arrayLen(spec.slides) < 18){
    throw(message="OpenAI Slide Spec 页数不足或缺少 slides。");
  }
  return {spec:spec, usage:result.usage, responseId:result.response_id, model:result.model};
}
function cleanText(any value = ""){
    var s = "";

    if (isNull(arguments.value)) {
        return "";
    }

    if (isSimpleValue(arguments.value)) {
        s = toString(arguments.value);
    }
    else if (isArray(arguments.value)) {
        s = arrayToList(arguments.value, "；");
    }
    else if (isStruct(arguments.value)) {

        if (structKeyExists(arguments.value,"text"))
            return cleanText(arguments.value.text);

        if (structKeyExists(arguments.value,"content"))
            return cleanText(arguments.value.content);

        if (structKeyExists(arguments.value,"summary"))
            return cleanText(arguments.value.summary);

        if (structKeyExists(arguments.value,"title"))
            return cleanText(arguments.value.title);

        if (structKeyExists(arguments.value,"message"))
            return cleanText(arguments.value.message);

        return "";
    }
    else {
        return "";
    }

    s = rereplace(s, "[\x00-\x08\x0B\x0C\x0E-\x1F]", "", "all");
    s = trim(s);

    return s;
}

function themeFor(required string themeName){
  if(arguments.themeName == "executive_dark") return {background:"0F172A", primary:"60A5FA", accent:"A78BFA", text:"F8FAFC", muted:"CBD5E1"};
  if(arguments.themeName == "coffee_warm") return {background:"FFF7ED", primary:"92400E", accent:"D97706", text:"1F2937", muted:"6B7280"};
  if(arguments.themeName == "travel_editorial") return {background:"F8FAFC", primary:"2563EB", accent:"16A34A", text:"0F172A", muted:"64748B"};
  if(arguments.themeName == "minimal_white") return {background:"FFFFFF", primary:"111827", accent:"2563EB", text:"111827", muted:"6B7280"};
  return {background:"FFFFFF", primary:"2563EB", accent:"16A34A", text:"0F172A", muted:"64748B"};
}

function toRendererSpec(required struct spec, required query job){
  var slides = [];
  for(var s in arguments.spec.slides){
    var bullets = [];
    if(structKeyExists(s, "coreMessage") && len(cleanText(s.coreMessage))) arrayAppend(bullets, cleanText(s.coreMessage));
    if(structKeyExists(s, "supportingPoints") && isArray(s.supportingPoints)){
      for(var p in s.supportingPoints){
        if(len(cleanText(p))) arrayAppend(bullets, cleanText(p));
      }
    }
    if(structKeyExists(s, "thinkAboutIt") && len(cleanText(s.thinkAboutIt))) arrayAppend(bullets, "思考：" & cleanText(s.thinkAboutIt));
    var slideTitle = arguments.job.topic[1];
    if(structKeyExists(s, "title")) slideTitle = s.title;
    var slideSubtitle = "";
    if(structKeyExists(s, "section")) slideSubtitle = s.section;
    arrayAppend(slides, {
      title:cleanText(slideTitle),
      subtitle:cleanText(slideSubtitle),
      bullets:bullets
    });
  }
  var deckTitle = arguments.job.topic[1];
  if(structKeyExists(arguments.spec, "deckTitle")) deckTitle = arguments.spec.deckTitle;
  return {
    deck_title:cleanText(deckTitle),
    theme:themeFor(arguments.job.theme[1]),
    slides:slides
  };
}



function defaultImagePrompt(required string topic, required string title, required string template){
  var t = lcase(arguments.template);
  if(find("travel", t)){
    return "Editorial travel photography for " & arguments.title & ", real destination details, natural light, magazine style, no text, no watermark";
  }
  if(find("educational", t)){
    return "Clean modern learning workspace with laptop, notebook and code editor, professional course slide visual, no text, no watermark";
  }
  return "Professional presentation visual for " & arguments.topic & ", clean editorial style, realistic, no text, no watermark";
}



function concretePoint(required query job, required string title, numeric idx=1){
  var topic = cleanText(safeText(arguments.job.topic[1], ""));
  var template = lcase(cleanText(safeText(arguments.job.template_type[1], "proposal")));
  var titleText = cleanText(arguments.title);
  var n = val(arguments.idx);
  if(find("travel", template) || find("京都", topic)){
    if(find("住宿", titleText) || find("酒店", titleText)){
      if(n==1) return "四条河原町优先：晚餐、购物和第二天去岚山都更均衡。";
      if(n==2) return "京都站适合带大件行李或返程早的人，但夜间逛街氛围弱一些。";
      return "祇园清水适合清晨拍清水寺，预算和拖行李成本要提前接受。";
    }
    if(find("交通", titleText) || find("路线", titleText)){
      if(n==1) return "清水寺建议早上公交/出租到五条坂或清水道，再步行上坡。";
      if(n==2) return "去岚山优先用 JR 嵯峨野线到嵯峨岚山，或阪急到岚山站。";
      return "每天只保留一条主线：东山一条线，岚山一条线，减少跨区折返。";
    }
    if(find("餐", titleText) || find("吃", titleText)){
      if(n==1) return "Day1 晚餐放河原町/先斗町，选择多，吃完能步行回住宿区。";
      if(n==2) return "清水寺周边上午只安排咖啡或轻食，避免正餐排队打乱节奏。";
      return "锦市场适合小食和伴手礼，不适合作为唯一正餐依赖。";
    }
    if(find("拍", titleText) || find("视觉", titleText) || find("图片", titleText)){
      if(n==1) return "清水寺主舞台适合清晨，画面要包含木舞台、京都城景和远山。";
      if(n==2) return "二年坂三年坂要拍坡道纵深和木屋立面，不要只拍人流。";
      return "岚山竹林适合 8:30 前拍竖向构图，人多时改拍低角度或局部。";
    }
    if(find("预算", titleText) || find("费用", titleText)){
      if(n==1) return "两日最大变量是住宿和餐饮，交通与门票反而不是主要矛盾。";
      if(n==2) return "酒店价格按入住日期波动，页面只给区间和选择逻辑，不写死单价。";
      return "预留 10%–15% 机动预算，用于出租车、雨天室内项目或临时餐饮。";
    }
    if(n==1) return "把清水寺、祇园、岚山放成两条主线，现场不再临时大改路线。";
    if(n==2) return "每个半天只安排一个核心区，拍照、吃饭和交通都围绕这个区展开。";
    return "遇到人多、下雨或体力不足，优先删购物和网红餐厅，不删主线景点。";
  }
  if(find("educational", template) || find("Python", topic) || find("python", topic)){
    if(find("代码", titleText) || find("脚本", titleText)){
      if(n==1) return "先用 pathlib 定位目录，再用 suffix 判断文件类型。";
      if(n==2) return "移动文件前先 dry-run 打印计划，确认后再执行 shutil.move。";
      return "处理重名文件时追加序号，避免覆盖已有文件。";
    }
    if(find("练习", titleText) || find("答案", titleText)){
      if(n==1) return "练习：增加 mp3 分类，并统计每类移动了多少个文件。";
      if(n==2) return "参考答案要包含输入目录、输出目录、分类规则和异常处理。";
      return "检查点：运行后 PDF、图片、音频分别进入对应文件夹。";
    }
    if(n==1) return "每个语法点都要连接到文件整理脚本，而不是孤立讲概念。";
    if(n==2) return "变量保存路径，列表保存文件集合，字典保存后缀名到文件夹的映射。";
    return "循环负责批量遍历，条件判断负责分流，函数负责封装重复逻辑。";
  }
  if(find("executive", template) || find("Rust", topic) || find("系统", topic)){
    if(n==1) return "先把技术问题翻译成业务影响：订单损失、客服压力和恢复时间。";
    if(n==2) return "方案页要说明迁移边界：哪些模块先重构，哪些保持原系统运行。";
    return "ROI 页面只用可解释假设，避免把不确定数字写成事实。";
  }
  if(n==1) return "用输入资料中的事实或明确假设支撑本页结论。";
  if(n==2) return "把结论拆成可执行动作、判断标准和风险边界。";
  return "不确定的数据标注为待核验，不让排版引擎替内容编事实。";
}

function removePoliteEnding(required string txt){
  var t = cleanText(arguments.txt);
  t = replace(t, "谢谢", "", "all");
  t = replace(t, "感谢聆听", "", "all");
  t = replace(t, "Thank you", "", "all");
  return trim(t);
}

function generateOneSlide(required query job, required string promptText, required struct researchPack, required struct blueprint, required any bp){
  var no = structKeyExists(arguments.bp,"slideNo") ? val(arguments.bp.slideNo) : 1;
  var sys = "你是中文 PPT 单页成稿专家。只输出 JSON。必须返回且只返回 1 页 slides[1]。";
  var usr = "根据蓝图生成单页 SlideSpec，不能写空话，不能写本地fallback模板。" & chr(10) &
    "Deck：" & arguments.blueprint.deckTitle & chr(10) &
    "受众：" & arguments.job.audience[1] & chr(10) &
    "模板：" & arguments.job.template_type[1] & chr(10) &
    "ResearchPack：" & left(serializeJson(arguments.researchPack), 1600) & chr(10) &
    "本页蓝图：" & serializeJson(arguments.bp) & chr(10) &
    "硬规则：必须中文；必须具体到主题；旅行页要给具体地点/交通/住宿/餐饮/预算逻辑；教学页要给代码或练习答案；商业页要给业务影响、指标假设和行动。" & chr(10) &
    "禁止：谢谢、感谢聆听、按场景判断、只展示关键量化指标、补充背景、深化页、背景判断、可执行判断点、空泛建议。" & chr(10) &
    "输出 JSON：{slides:[{slideNo:" & no & ",section,title,layoutType,coreMessage,supportingPoints,thinkAboutIt,visualType,visualIntent,imagePlan:{role,prompt,placement},chartSuggestion:{chartType,reason,dataHint},codeBlock,codeNotes,tableRows,speakerNote}]}。";
  var r = openAiJson(sys, usr, 90, modelForJob(arguments.job,"page"));
  if(structKeyExists(r.json,"slides") && isArray(r.json.slides) && arrayLen(r.json.slides) >= 1){
    var s = r.json.slides[1];
    s.slideNo = no;
    return {slide:s, usage:r.usage, model:r.model, responseId:r.response_id};
  }
  throw(message="OpenAI 单页成稿未返回", detail="P" & no);
}

function makeSlide(required numeric no, required string sectionName, required string layoutName, required string title, required string core, required array points, string visual="cards", string imgRole="none", string code="", string topic="", string template=""){
  return {
    slideNo:arguments.no,
    section:arguments.sectionName,
    layoutType:arguments.layoutName,
    title:arguments.title,
    coreMessage:arguments.core,
    supportingPoints:arguments.points,
    thinkAboutIt:"这一页是否回答了观众最关心的一个问题？",
    visualType:arguments.visual,
    visualIntent:"用版式帮助观众快速理解本页结论，而不是堆文字。",
    imagePlan:{role:arguments.imgRole, prompt:defaultImagePrompt(arguments.topic, arguments.title, arguments.template), placement:(arguments.imgRole == "none" ? "" : "right or full bleed background")},
    chartSuggestion:{chartType:(arguments.visual == "chart" ? "bar" : "none"), reason:(arguments.visual == "chart" ? "对比关键指标或预算结构" : ""), dataHint:""},
    codeBlock:arguments.code,
    codeNotes:(len(arguments.code) ? ["先定义路径，再遍历文件，最后执行移动或复制。", "真实项目里要先 dry-run，确认无误后再写入。", "异常处理必须记录失败文件，避免静默丢失。"] : []),
    tableRows:[["维度","内容","判断"],["目标",arguments.core,"需要具体化"],["行动",arrayLen(arguments.points) ? arguments.points[1] : "下一步", "可执行"]],
    speakerNote:"讲这一页时先给结论，再解释证据，最后落到下一步。"
  };
}

function makeFallbackSlideSpec(required query job, required string promptText, string reason=""){
  var topic = cleanText(safeText(arguments.job.topic[1], "未命名主题"));
  var audience = cleanText(safeText(arguments.job.audience[1], "目标观众"));
  var template = lcase(cleanText(safeText(arguments.job.template_type[1], "proposal")));
  var sections = [];
  var slides = [];
  var codeSample = "from pathlib import Path" & chr(10) & "import shutil" & chr(10) & chr(10) & "source = Path('Downloads')" & chr(10) & "rules = {'.pdf': 'PDF', '.jpg': 'Images', '.png': 'Images'}" & chr(10) & "for file in source.iterdir():" & chr(10) & "    if file.is_file():" & chr(10) & "        folder = source / rules.get(file.suffix.lower(), 'Others')" & chr(10) & "        folder.mkdir(exist_ok=True)" & chr(10) & "        shutil.move(str(file), str(folder / file.name))";

  if(find("travel", template)){
    sections = [
      {name:"旅行定位", purpose:"明确人群、审美和路线策略", slideStart:1, slideEnd:4},
      {name:"路线安排", purpose:"把两天行程拆成可执行时间线", slideStart:5, slideEnd:12},
      {name:"体验细节", purpose:"补足交通、餐饮、拍照和预算", slideStart:13, slideEnd:20},
      {name:"避坑清单", purpose:"降低踩坑概率并形成行动清单", slideStart:21, slideEnd:25}
    ];
    var titles = ["封面："&topic,"这份旅行分享解决什么问题","自由行游客最怕的三件事","整体路线设计原则","Day 1 上午：抵达与第一站","Day 1 下午：核心景点串联","Day 1 晚上：夜景与餐饮","Day 1 路线时间线","Day 2 上午：轻松拍照点","Day 2 下午：购物与城市漫步","Day 2 晚上：返程前收尾","两天路线总览表","交通选择：地铁/步行/打车","预算拆分：住宿、餐饮、门票","餐饮建议：少排队但不踩雷","拍照点规划：光线比滤镜重要","图片风格计划：杂志感旅行图","住宿位置怎么选","雨天/高温备选方案","亲子/情侣/独行微调","常见坑：排队、交通、现金","出发前检查清单","现场决策规则","最后一页：把旅行变成可执行计划","Q&A"];
    for(var i=1;i<=25;i++){
      var sec = i<=4 ? "旅行定位" : (i<=12 ? "路线安排" : (i<=20 ? "体验细节" : "避坑清单"));
      var layout = (i==1 ? "cover" : (i==8 ? "timeline" : (i==12 || i==14 || i==22 ? "table" : (i==17 ? "image" : "cards"))));
      arrayAppend(slides, makeSlide(i, sec, layout, titles[i], "让" & audience & "用最少决策成本完成一次好看、顺路、不踩坑的旅行。", ["路线必须按时间、距离和体力排序。", "图片只服务具体地点和页面内容，不能随机配风景。", "预算、交通、餐饮和备选方案要同时出现。"], (layout=="timeline"?"timeline":(layout=="table"?"table":(layout=="image"?"image":"cards"))), (layout=="image" || i==1 ? "hero" : "none"), "", topic, arguments.job.template_type[1]));
    }
  } else if(find("educational", template)){
    sections = [
      {name:"学习目标", purpose:"建立课程路线", slideStart:1, slideEnd:4},
      {name:"基础概念", purpose:"变量、循环、函数和数据结构", slideStart:5, slideEnd:12},
      {name:"小项目实战", purpose:"文件整理脚本", slideStart:13, slideEnd:20},
      {name:"练习与避坑", purpose:"形成可复用能力", slideStart:21, slideEnd:25}
    ];
    var etitles = ["封面："&topic,"课程目标：学完能做什么","学习路径总览","环境与运行方式","变量：给数据起名字","列表：保存一组数据","字典：保存映射关系","循环：批量处理重复任务","条件判断：按规则分流","函数：封装可复用逻辑","模块：调用现成工具","概念关系图","小项目：文件整理脚本","需求分析：整理哪些文件","数据结构：后缀名到文件夹","核心代码：遍历与移动","代码说明：逐行解释","测试步骤：先 dry-run","异常处理：权限和重名","优化方向：日志与配置","常见错误 1：路径写死","常见错误 2：覆盖文件","练习题：改造成图片整理器","复盘：从脚本到自动化思维","Q&A"];
    for(var j=1;j<=25;j++){
      var sec2 = j<=4 ? "学习目标" : (j<=12 ? "基础概念" : (j<=20 ? "小项目实战" : "练习与避坑"));
      var layout2 = (j==1 ? "cover" : (j==16 ? "code" : (j==12 ? "process" : (j==17 || j==18 || j==19 ? "cards" : "cards"))));
      arrayAppend(slides, makeSlide(j, sec2, layout2, etitles[j], "把语法点落到一个真实自动化脚本里，避免只会背概念。", ["每个概念都要连接到文件整理脚本。", "代码页必须能运行，并说明关键语句。", "练习页要能让学习者马上改造。"], (layout2=="code"?"none":"cards"), "none", (j==16 ? codeSample : ""), topic, arguments.job.template_type[1]));
    }
  } else {
    sections = [
      {name:"背景与问题", purpose:"说明为什么要做", slideStart:1, slideEnd:6},
      {name:"方案设计", purpose:"拆解系统与流程", slideStart:7, slideEnd:14},
      {name:"价值验证", purpose:"用指标和场景证明", slideStart:15, slideEnd:20},
      {name:"落地计划", purpose:"风险、里程碑和下一步", slideStart:21, slideEnd:25}
    ];
    var gtitles = ["封面："&topic,"一句话结论","目标受众真正关心什么","现状问题拆解","业务影响与成本","目标状态","方案总览","核心模块一","核心模块二","核心模块三","流程设计","数据与接口","权限与异常","架构边界","价值指标","效果对比","风险矩阵","成本与资源","里程碑计划","验收标准","第一阶段怎么启动","第二阶段怎么扩展","第三阶段怎么运营","决策请求","Q&A"];
    for(var k=1;k<=25;k++){
      var sec3 = k<=6 ? "背景与问题" : (k<=14 ? "方案设计" : (k<=20 ? "价值验证" : "落地计划"));
      var layout3 = (k==1 ? "cover" : (k==7 || k==11 || k==19 ? "process" : (k==17 ? "matrix" : (k==15 || k==16 ? "chart" : "cards"))));
      arrayAppend(slides, makeSlide(k, sec3, layout3, gtitles[k], "这套方案要帮助" & audience & "从模糊想法推进到可验收交付。", ["先定义边界，再定义流程，最后定义验收。", "所有数字和结论都要能追溯到输入、数据库或研究来源。", "Renderer 只负责排版，不替 Planner 编内容。"], (layout3=="chart"?"chart":(layout3=="process"?"process":(layout3=="matrix"?"matrix":"cards"))), (k==1 ? "hero" : "none"), "", topic, arguments.job.template_type[1]));
    }
  }

  return {
    deckTitle:topic,
    subtitle:"面向 " & audience & " 的高质量 PPT 自动生成稿",
    audience:audience,
    templateType:arguments.job.template_type[1],
    themeHint:arguments.job.theme[1],
    fallback:true,
    fallbackReason:arguments.reason,
    sections:sections,
    slides:slides
  };
}



function bannedPhrases(){
  return ["形成清晰判断","具体执行建议","本页聚焦","听众看完","为什么重要","保留一个可复盘","把复杂内容变成清晰","解释XXX关系","继续判断","视觉化表达","结构化叙事","按场景判断","只展示关键量化指标","非数值关系不强行画图","补充背景","背景判断","深化页","可执行判断点","感谢聆听","谢谢"];
}

function removeBanned(required string txt){
  var t = toString(arguments.txt);
  for(var b in bannedPhrases()){
    t = replace(t, b, "", "all");
  }
  return trim(t);
}

function normalizeArray(any value, numeric maxItems=4){
  var out = [];
  if(isArray(arguments.value)){
    for(var x in arguments.value){ if(len(cleanText(removeBanned(x)))) arrayAppend(out, cleanText(removeBanned(x))); }
  } else if(!isNull(arguments.value) && len(cleanText(arguments.value))){
    arrayAppend(out, cleanText(removeBanned(arguments.value)));
  }
  var final = [];
  for(var i=1; i<=min(arrayLen(out), arguments.maxItems); i++) arrayAppend(final, out[i]);
  return final;
}

function inferLayout(required numeric no, required numeric total, required string template, required string title){
  var t = lcase(arguments.template & " " & arguments.title);
  if(arguments.no == 1) return "cover";
  if(arguments.no == arguments.total) return "closing";
  if(arguments.no == 2) return "agenda";
  if(find("代码", t) || find("script", t) || find("code", t)) return "code";
  if(find("时间线", t) || find("day", t) || find("路线", t) || find("里程碑", t)) return "timeline";
  if(find("对比", t) || find("矩阵", t) || find("风险", t)) return "matrix";
  if(find("预算", t) || find("指标", t) || find("roi", t) || find("成本", t)) return "chart";
  if(find("表", t) || find("清单", t) || find("检查", t)) return "table";
  if(find("图片", t) || find("拍照", t) || find("景点", t)) return "image";
  if(arguments.no % 7 == 0) return "process";
  return "cards";
}

function makeResearchPack(required query job, required string promptText){
  var topic = cleanText(safeText(arguments.job.topic[1], "未命名主题"));
  var template = cleanText(safeText(arguments.job.template_type[1], "proposal"));
  var localPack = {
    source:"local-research-scaffold",
    topic:topic,
    assumptions:[
      "当前版本不接外部搜索 API；Research Agent 只允许基于用户输入、模板规则和可验证假设生成研究包。",
      "所有无法验证的数字必须标记为假设，不能写成事实。",
      "图片只能形成 imagePlan，不直接伪造真实来源。"
    ],
    evidenceRules:[
      "Evidence First：结论先绑定输入、研究包或明确假设。",
      "不知道就写待确认，不让 Renderer 编内容。",
      "所有价格、地址、排名、真实数据必须由后续真实 Research Tool 补齐；但稳定的常识型路线、交通方式、选择逻辑可以作为假设写入，并标注需核验。"
    ],
    visualGuidance:[],
    dataCandidates:[]
  };
  if(find("travel", lcase(template))){
    localPack.visualGuidance = ["每张图必须绑定具体地点、时间、天气或活动", "优先使用 editorial travel photography 风格", "禁止随机山水、空泛城市天际线"];
    localPack.dataCandidates = ["交通时间", "预算区间", "开放时间", "排队风险", "天气备选", "酒店区域和示例酒店", "餐饮落点和备选方案"];
    localPack.kyotoGuide = {hotels:["四条河原町：Cross Hotel Kyoto / Hotel Resol Kyoto Kawaramachi Sanjo（餐饮购物方便，价格按日期核验）", "京都站：Daiwa Roynet Hotel Kyoto Ekimae / Hotel Granvia Kyoto（行李和返程方便）", "祇园清水：Hotel The Celestine Kyoto Gion / Nohga Hotel Kiyomizu Kyoto（清晨拍照方便）"], transit:["清水寺：公交到五条坂/清水道后步行上坡，或出租车到附近下车", "岚山：JR 嵯峨野线到嵯峨岚山，或阪急到岚山", "东山到河原町适合步行串联，减少换乘"], food:["Day1 晚餐放河原町/先斗町，清水寺周边只作轻食", "岚山午餐错峰，准备便利店/咖啡备选", "锦市场适合小食和伴手礼，不作为唯一正餐依赖"], caveats:["价格和开放时间需按出行日期二次核验", "两日路线不要硬塞伏见稻荷，除非删掉锦市场或压缩岚山"]};
  } else if(find("educational", lcase(template))){
    localPack.visualGuidance = ["代码页优先清晰排版，不要装饰图", "概念页用流程图或卡片", "项目页必须有运行步骤和错误处理"];
    localPack.dataCandidates = ["输入输出", "边界条件", "测试步骤", "常见错误", "扩展练习"];
  } else {
    localPack.visualGuidance = ["方案页用流程和模块图", "价值页用指标图", "风险页用矩阵", "决策页用清晰请求"];
    localPack.dataCandidates = ["业务目标", "约束条件", "成功指标", "风险", "里程碑"];
  }
  try {
    var sys = "你是 Research Agent。只输出 JSON。你不能编造真实事实；无法验证的内容必须写成假设或待确认。";
    var usr = "基于以下 PPT 任务生成研究包，不写逐页正文。" & chr(10) &
      "主题：" & topic & chr(10) &
      "简介：" & arguments.job.brief[1] & chr(10) &
      "受众：" & arguments.job.audience[1] & chr(10) &
      "模板：" & template & chr(10) &
      "Prompt摘要：" & left(arguments.promptText, 900) & chr(10) &
      "如果是京都旅行，研究包必须包含 kyotoGuide.hotels/transit/food/caveats，给具体酒店名、区域选择逻辑、交通线路和餐饮落点，价格写需核验。" & chr(10) &
      "如果是教学，研究包必须包含 exercisePlan 和 answerPlan，给练习和参考答案结构。" & chr(10) &
      "输出 JSON：{source, assumptions:[...], evidenceRules:[...], dataCandidates:[...], visualGuidance:[...], imageSearchQueries:[...], kyotoGuide:{hotels:[...],transit:[...],food:[...],caveats:[...]}, exercisePlan:[...], answerPlan:[...]}。";
    var r = openAiJson(sys, usr, 60, modelForJob(arguments.job,"research"));
    if(isStruct(r.json)){
      r.json.source = "openai-research-agent";
      return {pack:r.json, usage:r.usage, model:r.model, responseId:r.response_id};
    }
  } catch(any e) {}
  return {pack:localPack, usage:{prompt_tokens:0, completion_tokens:0, total_tokens:0, estimated_cost:0}, model:"local-research-agent", responseId:"local-research"};
}


function clientBlueprintFromJob(required query job){
  var txt = cleanText(safeText(arguments.job.slide_spec_json[1], ""));
  if(len(txt) < 20) return {};
  try{
    var raw = deserializeJson(txt);
    if(!isStruct(raw) || !structKeyExists(raw,"slides") || !isArray(raw.slides) || arrayLen(raw.slides) < 8) return {};
    var bpSlides = [];
    var sectionMap = {};
    var lastSection = "正文";
    for(var i=1; i<=arrayLen(raw.slides); i++){
      var s = raw.slides[i];
      if(!isStruct(s)) continue;
      var sec = structKeyExists(s,"section") && len(cleanText(s.section)) ? cleanText(s.section) : lastSection;
      lastSection = sec;
      if(!structKeyExists(sectionMap, sec)) sectionMap[sec] = {name:sec, purpose:"围绕" & sec & "形成可展示页面", slideStart:i, slideEnd:i};
      sectionMap[sec].slideEnd = i;
      arrayAppend(bpSlides, {
        slideNo:i,
        section:sec,
        title:structKeyExists(s,"title") ? cleanText(s.title) : ("第" & i & "页"),
        coreIntent:structKeyExists(s,"coreMessage") ? cleanText(s.coreMessage) : (structKeyExists(s,"visualIntent") ? cleanText(s.visualIntent) : "生成本页可展示内容"),
        contentNeed:structKeyExists(s,"supportingPoints") && isArray(s.supportingPoints) ? arrayToList(s.supportingPoints,"；") : "补齐正文、数据、讲稿与可视化说明",
        visualNeed:structKeyExists(s,"layoutType") ? cleanText(s.layoutType) : inferLayout(i, arrayLen(raw.slides), arguments.job.template_type[1], structKeyExists(s,"title") ? s.title : "")
      });
    }
    var sections = [];
    for(var key in sectionMap) arrayAppend(sections, sectionMap[key]);
    arraySort(sections, function(a,b){ return val(a.slideStart)-val(b.slideStart); });
    if(arrayLen(bpSlides) < 8) return {};
    return {
      deckTitle:structKeyExists(raw,"deckTitle") && len(cleanText(raw.deckTitle)) ? cleanText(raw.deckTitle) : cleanText(arguments.job.topic[1]),
      subtitle:structKeyExists(raw,"subtitle") && len(cleanText(raw.subtitle)) ? cleanText(raw.subtitle) : cleanText(arguments.job.brief[1]),
      audience:cleanText(arguments.job.audience[1]),
      sections:sections,
      slides:bpSlides,
      source:"client-stage1-blueprint"
    };
  } catch(any e){
    return {};
  }
}

function makeBlueprint(required query job, required string promptText, required struct researchPack){
  var topic = cleanText(safeText(arguments.job.topic[1], "未命名主题"));
  var template = cleanText(safeText(arguments.job.template_type[1], "proposal"));
  var slideCount = 25;
  try {
    var sys = "你是 Slide Planner。只输出 JSON。你负责故事线和逐页意图，不写长正文，不负责排版细节。";
    var usr = "生成 25 页 PPT 蓝图。Renderer 不会二次创作，所以每页 title/coreIntent 必须具体。" & chr(10) &
      "主题：" & topic & chr(10) & "简介：" & arguments.job.brief[1] & chr(10) &
      "受众：" & arguments.job.audience[1] & chr(10) & "模板骨架：" & templateRules(arguments.job.template_type[1]) & chr(10) &
      "ResearchPack：" & left(serializeJson(arguments.researchPack), 1800) & chr(10) &
      "输出 JSON：{deckTitle,subtitle,audience,sections:[{name,purpose,slideStart,slideEnd}],slides:[{slideNo,section,title,coreIntent,contentNeed,visualNeed}]}。slides 严格 25 页。";
    var r = openAiJson(sys, usr, 80, modelForJob(arguments.job,"planner"));
    if(structKeyExists(r.json,"slides") && isArray(r.json.slides) && arrayLen(r.json.slides) >= 20){
      return {blueprint:r.json, usage:r.usage, model:r.model, responseId:r.response_id};
    }
  } catch(any e) {}
  var fallback = makeFallbackSlideSpec(arguments.job, arguments.promptText, "blueprint fallback");
  var bpSlides = [];
  for(var s in fallback.slides){
    arrayAppend(bpSlides, {slideNo:s.slideNo, section:s.section, title:s.title, coreIntent:s.coreMessage, contentNeed:arrayToList(s.supportingPoints, "；"), visualNeed:s.visualType});
  }
  return {blueprint:{deckTitle:fallback.deckTitle, subtitle:fallback.subtitle, audience:fallback.audience, sections:fallback.sections, slides:bpSlides}, usage:{prompt_tokens:0, completion_tokens:0, total_tokens:0, estimated_cost:0}, model:"local-slide-planner", responseId:"local-blueprint"};
}

function layoutBlueprint(required struct blueprint, required query job){
  var total = arrayLen(arguments.blueprint.slides);
  var template = cleanText(safeText(arguments.job.template_type[1], "proposal"));
  for(var i=1; i<=total; i++){
    var sl = arguments.blueprint.slides[i];
    sl.layoutType = inferLayout(i, total, template, structKeyExists(sl,"title") ? sl.title : "");
    sl.visualType = (sl.layoutType == "timeline" ? "timeline" : (sl.layoutType == "matrix" ? "matrix" : (sl.layoutType == "chart" ? "chart" : (sl.layoutType == "table" ? "table" : (sl.layoutType == "image" ? "image" : "cards")))));
    arguments.blueprint.slides[i] = sl;
  }
  return arguments.blueprint;
}

function sectionFallbackSlides(required query job, required array bpSlides, required string sectionName){
  var out = [];
  var template = cleanText(safeText(arguments.job.template_type[1], "proposal"));
  var topic = cleanText(safeText(arguments.job.topic[1], "未命名主题"));
  for(var bp in arguments.bpSlides){
    var no = val(bp.slideNo);
    var title = structKeyExists(bp,"title") ? cleanText(bp.title) : ("第" & no & "页");
    var core = structKeyExists(bp,"coreIntent") ? cleanText(bp.coreIntent) : "这一页给出一个可执行结论。";
    var points = [core, "把输入信息转成可检查的页面内容。", "需要真实数据时标记待确认，不编造。"];
    var layout = structKeyExists(bp,"layoutType") ? bp.layoutType : inferLayout(no, 25, template, title);
    arrayAppend(out, makeSlide(no, arguments.sectionName, layout, title, core, points, structKeyExists(bp,"visualType")?bp.visualType:"cards", (layout=="image"||no==1?"hero":"none"), "", topic, template));
  }
  return out;
}

function generateSectionSlides(required query job, required string promptText, required struct researchPack, required struct blueprint, required string sectionName, required array bpSlides){
  var totalUsage = {prompt_tokens:0, completion_tokens:0, total_tokens:0, estimated_cost:0};
  var models = [];
  var responseIds = [];
  var gotSlides = [];
  var byNo = {};
  try {
    var sys = "你是 Page Writer。只输出 JSON。严格消费 Slide Planner 蓝图，不改页数、不改 slideNo，不做 Renderer 的事。";
    var usr = "为一个章节生成可直接渲染的 slide spec。" & chr(10) &
      "Deck：" & arguments.blueprint.deckTitle & chr(10) &
      "章节：" & arguments.sectionName & chr(10) &
      "受众：" & arguments.job.audience[1] & chr(10) &
      "模板：" & arguments.job.template_type[1] & chr(10) &
      "ResearchPack：" & left(serializeJson(arguments.researchPack), 2200) & chr(10) &
      "BlueprintSlides：" & serializeJson(arguments.bpSlides) & chr(10) &
      "硬规则：中文正文；每页 supportingPoints 3-5 条，必须具体到主题；Renderer 只排版，不能补内容；图片写 imagePlan.prompt 英文完整描述；代码页必须 codeBlock + codeNotes；餐饮/住宿/交通/练习/ROI必须给具体建议或明确待核验项。" & chr(10) &
      "禁止：谢谢、感谢聆听、按场景判断、只展示关键量化指标、补充背景、深化页、背景判断、可执行判断点、空泛建议。" & chr(10) &
      "必须返回 slides 数量 = BlueprintSlides 数量；slideNo 必须对应。" & chr(10) &
      "输出 JSON：{slides:[{slideNo,section,layoutType,title,coreMessage,supportingPoints,thinkAboutIt,visualType,visualIntent,imagePlan:{role,prompt,placement},chartSuggestion:{chartType,reason,dataHint},codeBlock,codeNotes,tableRows,speakerNote}]}。";
    var r = openAiJson(sys, usr, 120, modelForJob(arguments.job,"page"));
    totalUsage = addUsageTo(totalUsage, r.usage); arrayAppend(models, r.model); arrayAppend(responseIds, r.response_id);
    if(structKeyExists(r.json,"slides") && isArray(r.json.slides)){
      for(var s in r.json.slides){
        if(isStruct(s) && structKeyExists(s,"slideNo")) byNo[toString(val(s.slideNo))] = s;
      }
    }
  } catch(any e) {
    // 不让一个章节失败拖垮整套，下面逐页用 OpenAI 补齐。
  }

  for(var bp in arguments.bpSlides){
    var no = structKeyExists(bp,"slideNo") ? val(bp.slideNo) : 0;
    if(no > 0 && structKeyExists(byNo, toString(no))){
      arrayAppend(gotSlides, byNo[toString(no)]);
    } else {
      var one = generateOneSlide(arguments.job, arguments.promptText, arguments.researchPack, arguments.blueprint, bp);
      totalUsage = addUsageTo(totalUsage, one.usage); arrayAppend(models, one.model); arrayAppend(responseIds, one.responseId);
      arrayAppend(gotSlides, one.slide);
    }
  }
  return {slides:gotSlides, usage:totalUsage, model:arrayToList(models,"+"), responseId:arrayToList(responseIds,",")};
}

function criticRepairSlide(required struct slide, required query job, required struct researchPack){
  var s = duplicate(arguments.slide);
  if(!structKeyExists(s,"slideNo") || val(s.slideNo) <= 0) s.slideNo = 1;
  if(!structKeyExists(s,"section") || !len(cleanText(s.section))) s.section = "正文";
  if(!structKeyExists(s,"title") || !len(cleanText(s.title))) s.title = "第" & s.slideNo & "页";
  s.title = removePoliteEnding(removeBanned(cleanText(s.title)));
  if(!structKeyExists(s,"coreMessage") || !len(cleanText(s.coreMessage))) s.coreMessage = concretePoint(arguments.job, s.title, 1);
  s.coreMessage = removePoliteEnding(removeBanned(cleanText(s.coreMessage)));
  s.supportingPoints = normalizeArray(structKeyExists(s,"supportingPoints") ? s.supportingPoints : [], 4);
  while(arrayLen(s.supportingPoints) < 3) arrayAppend(s.supportingPoints, concretePoint(arguments.job, s.title, arrayLen(s.supportingPoints)+1));
  for(var i=1; i<=arrayLen(s.supportingPoints); i++) s.supportingPoints[i] = removePoliteEnding(removeBanned(s.supportingPoints[i]));
  if(!structKeyExists(s,"layoutType") || !len(cleanText(s.layoutType))) s.layoutType = inferLayout(val(s.slideNo), 25, arguments.job.template_type[1], s.title);
  if(!structKeyExists(s,"visualType") || !len(cleanText(s.visualType))) s.visualType = (s.layoutType == "timeline" ? "timeline" : (s.layoutType == "chart" ? "chart" : (s.layoutType == "table" ? "table" : "cards")));
  if(!structKeyExists(s,"imagePlan") || !isStruct(s.imagePlan)) s.imagePlan = {role:"none", prompt:"", placement:""};
  if((s.layoutType == "image" || s.imagePlan.role != "none") && !len(cleanText(s.imagePlan.prompt))){
    s.imagePlan.prompt = defaultImagePrompt(arguments.job.topic[1], s.title, arguments.job.template_type[1]);
  }
  if(!structKeyExists(s,"chartSuggestion") || !isStruct(s.chartSuggestion)) s.chartSuggestion = {chartType:"none", reason:"", dataHint:""};
  if(!structKeyExists(s,"tableRows") || !isArray(s.tableRows)) s.tableRows = [["维度","内容","判断"],["结论",s.coreMessage,"可执行"]];
  if(!structKeyExists(s,"codeBlock")) s.codeBlock = "";
  if(!structKeyExists(s,"codeNotes") || !isArray(s.codeNotes)) s.codeNotes = [];
  if(len(cleanText(s.codeBlock)) && arrayLen(s.codeNotes) < 2) s.codeNotes = ["说明输入路径、遍历规则和输出结果。", "先 dry-run 再真实移动文件，避免误删或覆盖。"];
  if(!structKeyExists(s,"thinkAboutIt") || !len(cleanText(s.thinkAboutIt))) s.thinkAboutIt = "这一页的结论是否能被输入、证据或明确假设支撑？";
  if(!structKeyExists(s,"speakerNote") || !len(cleanText(s.speakerNote))) s.speakerNote = concretePoint(arguments.job, s.title, 1);
  s.criticStatus = "passed-local-critic";
  return s;
}

function runPageCritic(required array slides, required query job, required struct researchPack){
  var fixed = [];
  var report = [];
  for(var s in arguments.slides){
    var beforeTitle = structKeyExists(s,"title") ? s.title : "";
    var fs = criticRepairSlide(s, arguments.job, arguments.researchPack);
    arrayAppend(fixed, fs);
    arrayAppend(report, {slideNo:fs.slideNo, title:fs.title, status:fs.criticStatus, changed:(beforeTitle != fs.title)});
  }
  arraySort(fixed, function(a,b){ return val(a.slideNo) - val(b.slideNo); });
  return {slides:fixed, report:report};
}

function buildPlannerMarkdown(required struct spec){
  var lines = [];
  arrayAppend(lines, "## Agent 制作过程");
  arrayAppend(lines, "");
  arrayAppend(lines, "## 1. Research Agent");
  arrayAppend(lines, "- 来源：" & (structKeyExists(arguments.spec.researchPack,"source") ? arguments.spec.researchPack.source : "unknown"));
  if(structKeyExists(arguments.spec.researchPack,"assumptions") && isArray(arguments.spec.researchPack.assumptions)){
    for(var a in arguments.spec.researchPack.assumptions) arrayAppend(lines, "- " & a);
  }
  arrayAppend(lines, "");
  arrayAppend(lines, "## 2. Slide Planner / Layout Agent");
  if(structKeyExists(arguments.spec,"sections") && isArray(arguments.spec.sections)){
    for(var sec in arguments.spec.sections) arrayAppend(lines, "- " & sec.name & "：" & sec.purpose & "（" & sec.slideStart & "-" & sec.slideEnd & "）");
  }
  arrayAppend(lines, "");
  arrayAppend(lines, "## 3. Page Critic");
  if(structKeyExists(arguments.spec,"criticReport") && isArray(arguments.spec.criticReport)){
    for(var r in arguments.spec.criticReport) arrayAppend(lines, "- P" & r.slideNo & " " & r.status & "：" & r.title);
  }
  return arrayToList(lines, chr(10));
}

function addUsageTo(required struct totalUsage, required struct u){
  arguments.totalUsage.prompt_tokens += val(arguments.u.prompt_tokens);
  arguments.totalUsage.completion_tokens += val(arguments.u.completion_tokens);
  arguments.totalUsage.total_tokens += val(arguments.u.total_tokens);
  arguments.totalUsage.estimated_cost += val(arguments.u.estimated_cost);
  return arguments.totalUsage;
}

function makeAgenticSlideSpec(required query job, required string promptText){
  var totalUsage = {prompt_tokens:0, completion_tokens:0, total_tokens:0, estimated_cost:0};
  var models = [];
  var responseIds = [];
  var research = makeResearchPack(arguments.job, arguments.promptText);
  totalUsage = addUsageTo(totalUsage, research.usage); arrayAppend(models, research.model); arrayAppend(responseIds, research.responseId);
  var clientBp = clientBlueprintFromJob(arguments.job);
  var bpResult = {};
  if(isStruct(clientBp) && structKeyExists(clientBp,"slides") && isArray(clientBp.slides) && arrayLen(clientBp.slides) >= 8){
    bpResult = {blueprint:clientBp, usage:{prompt_tokens:0, completion_tokens:0, total_tokens:0, estimated_cost:0}, model:"stage1-client-blueprint", responseId:"stage1-client-blueprint"};
  } else {
    bpResult = makeBlueprint(arguments.job, arguments.promptText, research.pack);
  }
  totalUsage = addUsageTo(totalUsage, bpResult.usage); arrayAppend(models, bpResult.model); arrayAppend(responseIds, bpResult.responseId);
  var blueprint = layoutBlueprint(bpResult.blueprint, arguments.job);
  var allSlides = [];
  if(!structKeyExists(blueprint,"sections") || !isArray(blueprint.sections) || arrayLen(blueprint.sections)==0){
    blueprint.sections = [{name:"正文", purpose:"完成主要内容", slideStart:1, slideEnd:arrayLen(blueprint.slides)}];
  }
  for(var sec in blueprint.sections){
    var bpSlides = [];
    for(var bps in blueprint.slides){
      if(val(bps.slideNo) >= val(sec.slideStart) && val(bps.slideNo) <= val(sec.slideEnd)) arrayAppend(bpSlides, bps);
    }
    if(arrayLen(bpSlides) == 0) continue;
    var sectionResult = generateSectionSlides(arguments.job, arguments.promptText, research.pack, blueprint, sec.name, bpSlides);
    totalUsage = addUsageTo(totalUsage, sectionResult.usage); arrayAppend(models, sectionResult.model); arrayAppend(responseIds, sectionResult.responseId);
    for(var ss in sectionResult.slides) arrayAppend(allSlides, ss);
  }
  if(arrayLen(allSlides) < 18){
    throw(message="OpenAI逐页成稿不足", detail="目标至少18页，实际" & arrayLen(allSlides) & "页。已停止，不生成低质量本地降级PPT。");
  }
  var critic = runPageCritic(allSlides, arguments.job, research.pack);
  var spec = {
    deckTitle:structKeyExists(blueprint,"deckTitle") ? blueprint.deckTitle : arguments.job.topic[1],
    subtitle:structKeyExists(blueprint,"subtitle") ? blueprint.subtitle : "Agentic PPT 自动生成",
    audience:structKeyExists(blueprint,"audience") ? blueprint.audience : arguments.job.audience[1],
    templateType:arguments.job.template_type[1],
    themeHint:arguments.job.theme[1],
    pipeline:"research-agent -> slide-planner -> layout-agent -> page-writer -> page-critic -> renderer",
    rendererContract:"Renderer 严格消费本 spec，只做排版，不生成正文、不补事实、不改结论。",
    researchPack:research.pack,
    sections:blueprint.sections,
    slides:critic.slides,
    criticReport:critic.report
  };
  spec.plannerMarkdown = buildPlannerMarkdown(spec);
  return {spec:spec, usage:totalUsage, responseId:arrayToList(responseIds, ","), model:arrayToList(models, "+")};
}

try {
  ensureJobTextColumns();
  requestedJobId = 0;
  if(structKeyExists(url, "jobId")) requestedJobId = val(url.jobId);
  if(requestedJobId <= 0){
    rawBody = toString(getHttpRequestData().content);
    if(len(trim(rawBody))){
      body = deserializeJson(rawBody);
      if(structKeyExists(body, "jobId")) requestedJobId = val(body.jobId);
    }
  }

  if(requestedJobId > 0){
    job = queryExecute("SELECT * FROM ppt_jobs WHERE job_id = :job_id AND status = 'queued'", {
      job_id:{value:requestedJobId, cfsqltype:"cf_sql_integer"}
    }, {datasource:application.dsn});
  } else {
    job = queryExecute("SELECT * FROM ppt_jobs WHERE status = 'queued' ORDER BY created_at ASC LIMIT 1", {}, {datasource:application.dsn});
  }

  if(job.recordCount == 0) jsonOut({success:true, message:"没有待处理任务。"});

  jobId = val(job.job_id[1]);
  startedAt = getTickCount();

  updateJob(jobId, "planning", 15, "正在规划演示结构");
  promptText = cleanText(safeText(job.presentation_prompt[1], ""));
  if(!len(promptText)){
    throw(message="任务缺少 Presentation Prompt，请回到页面先生成 Prompt。");
  }

  // v34: 第一阶段的 slide_spec_json 只允许作为“逐页蓝图/人工可改草稿”。
  // 第二阶段生成 PPT 时必须重新走 OpenAI Research/Designer/PageWriter/Reviewer，不能直接拿第一阶段草稿渲染。
  existingSpecText = cleanText(safeText(job.slide_spec_json[1], ""));
  updateJob(jobId, "researching", 25, "OpenAI Research：整理证据、假设、图片与数据需求");
  updateJob(jobId, "designing", 40, "OpenAI Designer：按页决定视觉语言和版式");
  updateJob(jobId, "writing", 58, "OpenAI Page Writer：按章节逐页成稿");
  specResult = makeAgenticSlideSpec(job, promptText);
  updateJob(jobId, "critic", 82, "Page Critic：逐页检查标题、正文、图片计划、代码说明和禁用词");
  saveSpec(jobId, specResult.spec, specResult.usage, specResult.responseId);
  queryExecute("UPDATE ppt_jobs SET model = :model WHERE job_id = :job_id", {job_id:{value:jobId, cfsqltype:"cf_sql_integer"}, model:{value:specResult.model, cfsqltype:"cf_sql_longvarchar"}}, {datasource:application.dsn});

  queryExecute("
    UPDATE ppt_jobs
    SET status = 'completed',
        progress = 100,
        current_step = 'Slide Spec 已生成，等待浏览器导出 PPTX',
        duration_ms = :duration_ms,
        updated_at = CURRENT_TIMESTAMP
    WHERE job_id = :job_id
  ", {
    job_id:{value:jobId, cfsqltype:"cf_sql_integer"},
    duration_ms:{value:getTickCount() - startedAt, cfsqltype:"cf_sql_integer"}
  }, {datasource:application.dsn});

  jsonOut({success:true, jobId:jobId, status:"completed", slideCount:arrayLen(specResult.spec.slides)});
} catch(any e) {
  if(isDefined("jobId") && val(jobId) > 0){
    try {
      detailText = "";
      if(structKeyExists(e, "detail") && len(toString(e.detail))) detailText = " | " & e.detail;
      updateJob(jobId, "failed", 100, "生成失败", e.message & detailText);
    } catch(any ignored){}
  }
  jsonOut({success:false, message:"Worker 执行失败。", detail:compactText(e.message, 1000)}, 500);
}
</cfscript>



