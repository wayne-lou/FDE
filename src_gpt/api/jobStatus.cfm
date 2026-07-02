<cfscript>
contentType = "application/json; charset=utf-8";

function jsonOut(required struct payload, numeric statusCode=200){
  cfheader(statuscode=arguments.statusCode, statustext=(arguments.statusCode == 200 ? "OK" : "Job Error"));
  cfcontent(type=contentType, reset=true);
  writeOutput(serializeJson(arguments.payload));
  abort;
}

try {
  jobId = val(url.jobId ?: 0);
  if(jobId <= 0) jsonOut({success:false, message:"jobId 无效。"}, 400);

  job = queryExecute("
    SELECT job_id, status, progress, current_step, output_file, ppt_filename, error_message,
           topic, brief, audience, theme, mode, slide_spec_json,
           provider, model, prompt_tokens, completion_tokens, total_tokens,
           estimated_cost, duration_ms, slide_count, ppt_size, updated_at
    FROM ppt_jobs
    WHERE job_id = :job_id
  ", {
    job_id:{value:jobId, cfsqltype:"cf_sql_integer"}
  }, {datasource:application.dsn});

  if(job.recordCount == 0) jsonOut({success:false, message:"任务不存在。"}, 404);

  fileName = trim(toString(job.ppt_filename[1] ?: ""));
  downloadUrl = "";
  if(len(fileName) && job.status[1] == "completed"){
    downloadUrl = "download.cfm?file=" & urlEncodedFormat(fileName);
  }

  slideSpec = {};
  if(job.status[1] == "completed"){
    specText = trim(toString(job.slide_spec_json[1] ?: ""));
    if(len(specText)){
      try {
        slideSpec = deserializeJson(specText);
      } catch(any ignored) {
        slideSpec = {};
      }
    }
  }

  jsonOut({
    success:true,
    jobId:job.job_id[1],
    status:job.status[1],
    progress:val(job.progress[1]),
    currentStep:toString(job.current_step[1] ?: ""),
    downloadUrl:downloadUrl,
    outputFile:toString(job.output_file[1] ?: ""),
    fileName:fileName,
    errorMessage:toString(job.error_message[1] ?: ""),
    slideSpec:slideSpec,
    input:{
      topic:toString(job.topic[1] ?: ""),
      brief:toString(job.brief[1] ?: ""),
      audience:toString(job.audience[1] ?: ""),
      theme:toString(job.theme[1] ?: ""),
      mode:toString(job.mode[1] ?: "")
    },
    metrics:{
      provider:toString(job.provider[1] ?: ""),
      model:toString(job.model[1] ?: ""),
      prompt_tokens:val(job.prompt_tokens[1]),
      completion_tokens:val(job.completion_tokens[1]),
      total_tokens:val(job.total_tokens[1]),
      estimated_cost:val(job.estimated_cost[1]),
      duration_ms:val(job.duration_ms[1]),
      slide_count:val(job.slide_count[1]),
      ppt_size:val(job.ppt_size[1])
    }
  });
} catch(any e) {
  jsonOut({success:false, message:"读取任务状态失败。", detail:e.message}, 500);
}
</cfscript>
