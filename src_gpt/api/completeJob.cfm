<cfscript>
contentType = "application/json; charset=utf-8";

function jsonOut(required struct payload, numeric statusCode=200){
  cfheader(statuscode=arguments.statusCode, statustext=(arguments.statusCode == 200 ? "OK" : "Complete Error"));
  cfcontent(type=contentType, reset=true);
  writeOutput(serializeJson(arguments.payload));
  abort;
}

function q(required string sql, struct params={}){
  return queryExecute(arguments.sql, arguments.params, {datasource:application.dsn});
}

function ensureResultTables(){
  q("
    CREATE TABLE IF NOT EXISTS ppt_metrics (
      metric_id SERIAL PRIMARY KEY,
      job_id INTEGER,
      prompt_tokens INTEGER,
      completion_tokens INTEGER,
      total_tokens INTEGER,
      estimated_cost DOUBLE PRECISION,
      duration_ms INTEGER,
      slide_count INTEGER,
      ppt_filename TEXT,
      ppt_size BIGINT,
      model TEXT,
      provider TEXT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ");
  q("
    CREATE TABLE IF NOT EXISTS ppt_demo_results (
      demo_result_id SERIAL PRIMARY KEY,
      topic TEXT,
      brief TEXT,
      audience TEXT,
      template_type TEXT,
      mode VARCHAR(50),
      theme TEXT,
      provider TEXT,
      model TEXT,
      prompt_tokens INTEGER,
      completion_tokens INTEGER,
      total_tokens INTEGER,
      slide_count INTEGER,
      duration_ms INTEGER,
      estimated_cost DOUBLE PRECISION,
      output_file TEXT,
      ppt_size BIGINT,
      status VARCHAR(50),
      error_message TEXT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ");
}

try {
  rawBody = toString(getHttpRequestData().content);
  if(!len(trim(rawBody))) jsonOut({success:false, message:"请求体为空。"}, 400);
  body = deserializeJson(rawBody);

  jobId = val(body.jobId ?: 0);
  if(jobId <= 0) jsonOut({success:false, message:"jobId 无效。"}, 400);

  fileName = left(trim(toString(body.fileName ?: "")), 260);
  pptSize = val(body.pptSize ?: 0);
  slideCount = val(body.slideCount ?: 0);
  renderMs = val(body.renderDurationMs ?: 0);
  ensureResultTables();

  jobQ = q("
    SELECT *
    FROM ppt_jobs
    WHERE job_id = :job_id
    LIMIT 1
  ", {
    job_id:{value:jobId, cfsqltype:"cf_sql_integer"}
  });
  if(!jobQ.recordCount) jsonOut({success:false, message:"未找到对应生成任务。"}, 404);

  finalDuration = val(jobQ.duration_ms[1]) + renderMs;
  finalSlideCount = slideCount > 0 ? slideCount : val(jobQ.slide_count[1]);

  q("
    UPDATE ppt_jobs
    SET status = 'completed',
        progress = 100,
        current_step = '浏览器已生成 PPTX',
        ppt_filename = :ppt_filename,
        ppt_size = :ppt_size,
        slide_count = :slide_count,
        duration_ms = :duration_ms,
        updated_at = CURRENT_TIMESTAMP
    WHERE job_id = :job_id
  ", {
    job_id:{value:jobId, cfsqltype:"cf_sql_integer"},
    ppt_filename:{value:fileName, cfsqltype:"cf_sql_longvarchar"},
    ppt_size:{value:pptSize, cfsqltype:"cf_sql_bigint"},
    slide_count:{value:finalSlideCount, cfsqltype:"cf_sql_integer"},
    duration_ms:{value:finalDuration, cfsqltype:"cf_sql_integer"}
  });

  try {
    q("
      INSERT INTO ppt_metrics(
        job_id, prompt_tokens, completion_tokens, total_tokens, estimated_cost,
        duration_ms, slide_count, ppt_filename, ppt_size, model, provider, created_at
      )
      VALUES(
        :job_id, :prompt_tokens, :completion_tokens, :total_tokens, :estimated_cost,
        :duration_ms, :slide_count, :ppt_filename, :ppt_size, :model, :provider, CURRENT_TIMESTAMP
      )
    ", {
      job_id:{value:jobId, cfsqltype:"cf_sql_integer"},
      prompt_tokens:{value:val(jobQ.prompt_tokens[1]), cfsqltype:"cf_sql_integer"},
      completion_tokens:{value:val(jobQ.completion_tokens[1]), cfsqltype:"cf_sql_integer"},
      total_tokens:{value:val(jobQ.total_tokens[1]), cfsqltype:"cf_sql_integer"},
      estimated_cost:{value:val(jobQ.estimated_cost[1]), cfsqltype:"cf_sql_double"},
      duration_ms:{value:finalDuration, cfsqltype:"cf_sql_integer"},
      slide_count:{value:finalSlideCount, cfsqltype:"cf_sql_integer"},
      ppt_filename:{value:fileName, cfsqltype:"cf_sql_longvarchar"},
      ppt_size:{value:pptSize, cfsqltype:"cf_sql_bigint"},
      model:{value:toString(jobQ.model[1]), cfsqltype:"cf_sql_longvarchar"},
      provider:{value:toString(jobQ.provider[1]), cfsqltype:"cf_sql_longvarchar"}
    });
  } catch(any metricsError) {}

  try {
    q("
      INSERT INTO ppt_demo_results(
        topic, brief, audience, template_type, mode, theme, provider, model,
        prompt_tokens, completion_tokens, total_tokens, slide_count, duration_ms,
        estimated_cost, output_file, ppt_size, status, error_message, created_at
      )
      VALUES(
        :topic, :brief, :audience, :template_type, :mode, :theme, :provider, :model,
        :prompt_tokens, :completion_tokens, :total_tokens, :slide_count, :duration_ms,
        :estimated_cost, :output_file, :ppt_size, 'success', '', CURRENT_TIMESTAMP
      )
    ", {
      topic:{value:toString(jobQ.topic[1]), cfsqltype:"cf_sql_longvarchar"},
      brief:{value:toString(jobQ.brief[1]), cfsqltype:"cf_sql_longvarchar"},
      audience:{value:toString(jobQ.audience[1]), cfsqltype:"cf_sql_longvarchar"},
      template_type:{value:toString(jobQ.template_type[1]), cfsqltype:"cf_sql_longvarchar"},
      mode:{value:toString(jobQ.mode[1]), cfsqltype:"cf_sql_longvarchar"},
      theme:{value:toString(jobQ.theme[1]), cfsqltype:"cf_sql_longvarchar"},
      provider:{value:toString(jobQ.provider[1]), cfsqltype:"cf_sql_longvarchar"},
      model:{value:toString(jobQ.model[1]), cfsqltype:"cf_sql_longvarchar"},
      prompt_tokens:{value:val(jobQ.prompt_tokens[1]), cfsqltype:"cf_sql_integer"},
      completion_tokens:{value:val(jobQ.completion_tokens[1]), cfsqltype:"cf_sql_integer"},
      total_tokens:{value:val(jobQ.total_tokens[1]), cfsqltype:"cf_sql_integer"},
      slide_count:{value:finalSlideCount, cfsqltype:"cf_sql_integer"},
      duration_ms:{value:finalDuration, cfsqltype:"cf_sql_integer"},
      estimated_cost:{value:val(jobQ.estimated_cost[1]), cfsqltype:"cf_sql_double"},
      output_file:{value:fileName, cfsqltype:"cf_sql_longvarchar"},
      ppt_size:{value:pptSize, cfsqltype:"cf_sql_bigint"}
    });
  } catch(any demoError) {}

  jsonOut({success:true, jobId:jobId});
} catch(any e) {
  jsonOut({success:false, message:"记录浏览器导出结果失败。", detail:e.message}, 500);
}
</cfscript>
