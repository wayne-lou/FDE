<cfscript>
setting requesttimeout=600;
contentType = "application/json; charset=utf-8";

function jsonOut(required struct payload, numeric statusCode=200){
  cfheader(statuscode=arguments.statusCode, statustext=(arguments.statusCode == 200 ? "OK" : "Worker Error"));
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
    status:{value:arguments.status, cfsqltype:"cf_sql_varchar"},
    progress:{value:arguments.progress, cfsqltype:"cf_sql_integer"},
    current_step:{value:arguments.step, cfsqltype:"cf_sql_longvarchar"},
    error_message:{value:arguments.errorMessage, cfsqltype:"cf_sql_longvarchar"}
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
    response_id:{value:arguments.responseId, cfsqltype:"cf_sql_varchar"},
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
    ppt_filename:{value:arguments.renderResult.file_name, cfsqltype:"cf_sql_varchar"},
    output_file:{value:arguments.renderResult.file_path, cfsqltype:"cf_sql_longvarchar"},
    ppt_size:{value:arguments.renderResult.file_size, cfsqltype:"cf_sql_bigint"},
    slide_count:{value:arguments.renderResult.slide_count, cfsqltype:"cf_sql_integer"},
    duration_ms:{value:arguments.durationMs, cfsqltype:"cf_sql_integer"}
  }, {datasource:application.dsn});
}

function openAiJson(required string systemPrompt, required string userPrompt, numeric timeoutSeconds=180){
  var apiKey = appVal("openaiApiKey");
  if(!len(apiKey)) throw(message="OpenAI API Key 未配置。");
  var modelName = appVal("openaiModel", appVal("llmModel", "gpt-4o-mini"));
  var apiUri = appVal("openaiApiUri", "https://api.openai.com/v1/chat/completions");
  var body = {
    model:modelName,
    temperature:0.5,
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
  return {
    model:modelName,
    response_id:(structKeyExists(parsed, "id") ? toString(parsed.id) : ""),
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
  var systemPrompt = "你是资深 Presentation Architect。只输出 JSON，不要 markdown。";
  var userPrompt = "请为下面输入生成可编辑的 Presentation Prompt，后续用于生成 PPT。" & chr(10) &
    "主题：" & job.topic[1] & chr(10) &
    "简介：" & job.brief[1] & chr(10) &
    "目标受众：" & job.audience[1] & chr(10) &
    "模式：" & job.mode[1] & chr(10) &
    "风格：" & job.theme[1] & chr(10) &
    "模板类型：" & job.template_type[1] & chr(10) &
    "模板骨架：" & templateRules(job.template_type[1]) & chr(10) &
    "必须包含 Intent Planner、Knowledge Builder、Presentation Strategist、Story Architect、Visual Director、Slide Planner、Presentation Critic 七段，中文多段文本，带清晰换行。" & chr(10) &
    '输出 JSON：{"presentation_prompt":"..."}。';
  var result = openAiJson(systemPrompt, userPrompt, 120);
  if(!structKeyExists(result.json, "presentation_prompt") || !len(trim(toString(result.json.presentation_prompt)))){
    throw(message="OpenAI 未返回可用 Presentation Prompt。");
  }
  return {text:toString(result.json.presentation_prompt), usage:result.usage};
}

function makeSlideSpec(required query job, required string promptText){
  var slideCount = (job.mode[1] == "beauty" ? 24 : 22);
  var systemPrompt = "你是资深 Presentation Architect。你必须输出合法 JSON，不要 markdown。";
  var modeRule = (job.mode[1] == "beauty")
    ? "beauty：更多强视觉页，留白更大，标题更有冲击力。"
    : "balanced：信息密度更高，减少复杂图片页，保持叙事质量。";
  var userPrompt = arguments.promptText & chr(10) & chr(10) &
    "现在生成最终 Slide Spec。" & chr(10) &
    "主题：" & job.topic[1] & chr(10) &
    "简介：" & job.brief[1] & chr(10) &
    "目标受众：" & job.audience[1] & chr(10) &
    "模板骨架：" & templateRules(job.template_type[1]) & chr(10) &
    "页数：" & slideCount & chr(10) &
    "模式规则：" & modeRule & chr(10) &
    "禁止出现：形成清晰判断、具体执行建议、本页聚焦、听众看完、为什么重要、保留一个可复盘、把复杂内容变成清晰、解释XXX关系、继续判断、视觉化表达、核心观点先行、结构化叙事。" & chr(10) &
    "每页一个具体观点，points 具体，不要废话，不要重复。输出 JSON 格式：" & chr(10) &
    '{"deckTitle":"","subtitle":"","audience":"","templateType":"","themeHint":"","slides":[{"slideNo":1,"section":"","layoutType":"cover","title":"","coreMessage":"","supportingPoints":["","",""],"thinkAboutIt":"","visualType":"cards","speakerNote":""}]}';
  var result = openAiJson(systemPrompt, userPrompt, 180);
  var spec = result.json;
  if(!structKeyExists(spec, "slides") || !isArray(spec.slides) || arrayLen(spec.slides) < 20){
    throw(message="OpenAI Slide Spec 页数不足或缺少 slides。");
  }
  return {spec:spec, usage:result.usage, responseId:result.response_id};
}

function cleanText(string value=""){
  return trim(rereplace(toString(arguments.value), "[\x00-\x08\x0B\x0C\x0E-\x1F]", "", "all"));
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
    arrayAppend(slides, {
      title:cleanText(s.title ?: arguments.job.topic[1]),
      subtitle:cleanText(s.section ?: ""),
      bullets:bullets
    });
  }
  return {
    deck_title:cleanText(arguments.spec.deckTitle ?: arguments.job.topic[1]),
    theme:themeFor(arguments.job.theme[1]),
    slides:slides
  };
}

try {
  requestedJobId = val(url.jobId ?: 0);
  if(requestedJobId <= 0){
    rawBody = toString(getHttpRequestData().content);
    if(len(trim(rawBody))){
      body = deserializeJson(rawBody);
      if(structKeyExists(body, "jobId")) requestedJobId = val(body.jobId);
    }
  }

  if(requestedJobId > 0){
    job = queryExecute("SELECT * FROM ppt_jobs WHERE job_id = :job_id AND status IN ('queued','failed')", {
      job_id:{value:requestedJobId, cfsqltype:"cf_sql_integer"}
    }, {datasource:application.dsn});
  } else {
    job = queryExecute("SELECT * FROM ppt_jobs WHERE status = 'queued' ORDER BY created_at ASC LIMIT 1", {}, {datasource:application.dsn});
  }

  if(job.recordCount == 0) jsonOut({success:true, message:"没有待处理任务。"});

  jobId = val(job.job_id[1]);
  startedAt = getTickCount();

  updateJob(jobId, "planning", 15, "正在规划演示结构");
  promptText = cleanText(job.presentation_prompt[1] ?: "");
  if(!len(promptText)){
    promptResult = makePresentationPrompt(job);
    promptText = promptResult.text;
    savePrompt(jobId, promptText, promptResult.usage);
  }

  updateJob(jobId, "writing", 45, "正在生成 Slide Spec");
  specResult = makeSlideSpec(job, promptText);
  saveSpec(jobId, specResult.spec, specResult.usage, specResult.responseId);

  updateJob(jobId, "rendering", 78, "正在渲染 PPTX 文件");
  rendererSpec = toRendererSpec(specResult.spec, job);
  renderResult = createObject("component", application.componentRoot & ".RendererGateway").render(rendererSpec);
  if(!renderResult.success){
    throw(message="PPT 渲染失败：" & (renderResult.message ?: "未知错误"));
  }
  saveRender(jobId, renderResult, getTickCount() - startedAt);

  jsonOut({success:true, jobId:jobId, status:"completed", fileName:renderResult.file_name, downloadUrl:"download.cfm?file=" & urlEncodedFormat(renderResult.file_name)});
} catch(any e) {
  if(isDefined("jobId") && val(jobId) > 0){
    try { updateJob(jobId, "failed", 100, "生成失败", e.message & (len(e.detail ?: "") ? " | " & e.detail : "")); } catch(any ignored){}
  }
  jsonOut({success:false, message:"Worker 执行失败。", detail:e.message}, 500);
}
</cfscript>
