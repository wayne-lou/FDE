<cfscript>
contentType = "application/json; charset=utf-8";

function jsonOut(required struct payload, numeric statusCode=200){
  cfheader(statuscode=arguments.statusCode, statustext=(arguments.statusCode == 200 ? "OK" : "Prompt Error"));
  cfcontent(type=contentType, reset=true);
  writeOutput(serializeJson(arguments.payload));
  abort;
}

function valOf(required struct data, required string key, string fallback=""){
  if(structKeyExists(arguments.data, arguments.key) && !isNull(arguments.data[arguments.key])){
    return trim(toString(arguments.data[arguments.key]));
  }
  return arguments.fallback;
}

function line(required string label, required string value){
  return arguments.label & "：" & arguments.value & chr(10);
}

try {
  rawBody = toString(getHttpRequestData().content);
  if(!len(trim(rawBody))) jsonOut({success:false, message:"请求内容为空。"}, 400);
  req = deserializeJson(rawBody);

  topic = valOf(req, "topic");
  brief = valOf(req, "brief");
  audience = valOf(req, "audience");
  mode = valOf(req, "mode", "beauty");
  theme = valOf(req, "theme", "auto");
  templateType = valOf(req, "template_type", "proposal");
  templateRules = valOf(req, "template_rules", "背景、目标、问题、方案、价值、风险、下一步。");

  if(!len(topic)) jsonOut({success:false, message:"主题不能为空。"}, 400);

  promptText = "";
  promptText &= line("主题", topic);
  promptText &= line("简介", brief);
  promptText &= line("目标受众", audience);
  promptText &= line("模式", mode);
  promptText &= line("风格", theme);
  promptText &= line("模板类型", templateType);
  promptText &= line("模板骨架", templateRules);
  promptText &= chr(10);

  promptText &= "一、演示目标" & chr(10);
  promptText &= "这套 PPT 要把【" & topic & "】讲成一套可以直接展示的专业演示，而不是文章摘要。观众是【" & audience & "】，内容必须围绕他们关心的判断、行动和决策展开。" & chr(10) & chr(10);

  promptText &= "二、内容研究" & chr(10);
  promptText &= "请先扩展主题知识，不要复述用户输入。需要补充背景、关键概念、真实场景、常见误区、选择标准、行动建议和可落地案例。" & chr(10);
  promptText &= "简介中提到的内容必须被具体使用：" & brief & chr(10) & chr(10);

  promptText &= "三、故事线" & chr(10);
  promptText &= "按照模板骨架组织章节，让整套 deck 有开头、展开、转折、总结和行动建议。不要生成互相独立的卡片。" & chr(10) & chr(10);

  promptText &= "四、逐页制作要求" & chr(10);
  promptText &= "每页只讲一个具体观点。每页必须包含：章节、标题、一句话核心结论、至少 3 个具体支持点、讲稿备注、视觉表达方式。" & chr(10);
  promptText &= "需要代码时，必须输出 codeBlock 和 codeNotes；codeNotes 要解释关键语句、运行方式和常见错误。" & chr(10);
  promptText &= "需要图片时，必须输出 imagePlan，并给出完整英文图片提示词，图片要匹配该页主题，不要随机图。" & chr(10);
  promptText &= "需要表格或图表时，必须输出 tableRows 或 chartSuggestion，并说明图表用途。" & chr(10) & chr(10);

  promptText &= "五、不同主题的硬要求" & chr(10);
  promptText &= "Python/教学：必须讲变量、循环、函数、列表、字典、文件整理脚本、练习路径、常见错误。" & chr(10);
  promptText &= "咖啡：必须讲烘焙度、产地、处理法、风味轮、酸甜苦平衡、手冲/意式适配、购买决策、避坑。" & chr(10);
  promptText &= "Rust/高管提案：必须讲业务损失、性能瓶颈、并发稳定性、重写成本、ROI、迁移风险、立项路径。" & chr(10);
  promptText &= "旅行：必须讲 Day1/Day2 路线、交通、预算、餐饮、拍照点、避坑、清单；图片必须匹配具体景点。" & chr(10) & chr(10);

  promptText &= "六、质量底线" & chr(10);
  promptText &= "禁止出现：形成清晰判断、具体执行建议、本页聚焦、听众看完、为什么重要、保留一个可复盘、把复杂内容变成清晰、解释XXX关系、继续判断、视觉化表达、结构化叙事。" & chr(10);
  promptText &= "不要重复标题，不要重复 points，不要输出 prompt 指令本身，不要把 imageKeywords 渲染成正文。" & chr(10);

  jsonOut({
    success:true,
    source:"server_prompt",
    model:"local-prompt-builder",
    presentation_prompt:promptText,
    prompt_tokens:0,
    completion_tokens:0,
    total_tokens:0,
    estimated_cost:0
  });
} catch(any e) {
  jsonOut({success:false, message:"Prompt 生成失败。", detail:e.message}, 500);
}
</cfscript>
