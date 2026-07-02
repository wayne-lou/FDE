<cfsetting showdebugoutput="false" requesttimeout="20">
<cfscript>
contentType = "application/json; charset=utf-8";
function cleanError(required string raw){
  r = arguments.raw;
  if(!len(trim(r))) return "";
  if(findNoCase("OpenAI返回空内容", r)) return "AI规划输出为空，系统已切换稳定模型重试；如果仍失败，请重新点击生成规划。";
  if(findNoCase("504", r) || findNoCase("timeout", r)) return "AI服务响应超时，请重新点击生成规划。";
  if(findNoCase("Lucee", r) || find("<", r)) return "规划服务异常，请刷新后重试。";
  return left(r, 180);
}
function jsonOut(required struct payload, numeric statusCode=200){
  cfheader(statuscode=arguments.statusCode, statustext=(arguments.statusCode == 200 ? "OK" : "Plan Status Error"));
  cfcontent(type=contentType, reset=true);
  writeOutput(serializeJson(arguments.payload));
  abort;
}
try{
  jobId = val(url.jobId ?: 0);
  if(jobId <= 0) jsonOut({success:false, message:"jobId 无效。"}, 400);
  q = queryExecute("SELECT job_id,status,progress,current_step,error_message,slide_spec_json,provider,model,prompt_tokens,completion_tokens,total_tokens,estimated_cost,duration_ms,slide_count FROM ppt_jobs WHERE job_id=:id", {id:{value:jobId,cfsqltype:"cf_sql_integer"}}, {datasource:application.dsn});
  if(!q.recordCount) jsonOut({success:false, message:"规划任务不存在。"}, 404);
  spec = {};
  txt = trim(toString(q.slide_spec_json[1] ?: ""));
  if(len(txt)) { try { spec = deserializeJson(txt); } catch(any ignored){} }
  jsonOut({
    success:true,
    jobId:q.job_id[1],
    status:toString(q.status[1]),
    progress:val(q.progress[1]),
    currentStep:toString(q.current_step[1] ?: ""),
    errorMessage:cleanError(toString(q.error_message[1] ?: "")),
    slideSpec:spec,
    slideSpecJson:txt,
    metrics:{
      provider:toString(q.provider[1] ?: ""), model:toString(q.model[1] ?: ""),
      prompt_tokens:val(q.prompt_tokens[1]), completion_tokens:val(q.completion_tokens[1]), total_tokens:val(q.total_tokens[1]),
      estimated_cost:val(q.estimated_cost[1]), duration_ms:val(q.duration_ms[1]), slide_count:val(q.slide_count[1])
    }
  });
}catch(any e){ jsonOut({success:false, message:"读取规划状态失败。", detail:e.message}, 500); }
</cfscript>