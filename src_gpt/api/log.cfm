<cfscript>
contentType = "application/json; charset=utf-8";

function jsonOut(required struct payload, numeric statusCode=200){
  cfheader(statuscode=arguments.statusCode, statustext=(arguments.statusCode == 200 ? "OK" : "Log Error"));
  cfcontent(type=contentType, reset=true);
  writeOutput(serializeJson(arguments.payload));
  abort;
}

function s(required struct source, required string key, string fallback=""){
  if(structKeyExists(arguments.source, arguments.key) && !isNull(arguments.source[arguments.key])){
    return trim(toString(arguments.source[arguments.key]));
  }
  return arguments.fallback;
}

function n(required struct source, required string key, numeric fallback=0){
  if(structKeyExists(arguments.source, arguments.key) && !isNull(arguments.source[arguments.key])){
    return val(arguments.source[arguments.key]);
  }
  return arguments.fallback;
}

function q(required string sql, struct params={}){
  return queryExecute(arguments.sql, arguments.params, {datasource:application.dsn});
}

function ensureColumn(required string tableName, required string columnName, required string columnDef){
  var existsQ = q("
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = :table_name
      AND column_name = :column_name
    LIMIT 1
  ", {
    table_name:{value:arguments.tableName, cfsqltype:"cf_sql_longvarchar"},
    column_name:{value:arguments.columnName, cfsqltype:"cf_sql_longvarchar"}
  });
  if(!existsQ.recordCount){
    q("ALTER TABLE #arguments.tableName# ADD COLUMN #arguments.columnName# #arguments.columnDef#");
  }
}

function ensureSchema(){
  q("
    CREATE TABLE IF NOT EXISTS ppt_jobs (
      job_id SERIAL PRIMARY KEY,
      topic TEXT,
      brief TEXT,
      audience TEXT,
      template_type TEXT,
      theme TEXT,
      mode VARCHAR(50),
      provider TEXT,
      model TEXT,
      status VARCHAR(50),
      ppt_filename TEXT,
      ppt_size INTEGER,
      error_message TEXT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ");

  q("
    CREATE TABLE IF NOT EXISTS ppt_runs (
      run_id SERIAL PRIMARY KEY,
      job_id INTEGER,
      stage_name TEXT,
      stage_status VARCHAR(50),
      duration_ms INTEGER,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ");

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
      ppt_size INTEGER,
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
      ppt_size INTEGER,
      quality_note TEXT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ");

  ensureColumn("ppt_jobs", "topic", "TEXT");
  ensureColumn("ppt_jobs", "brief", "TEXT");
  ensureColumn("ppt_jobs", "audience", "TEXT");
  ensureColumn("ppt_jobs", "template_type", "VARCHAR(100)");
  ensureColumn("ppt_jobs", "theme", "VARCHAR(100)");
  ensureColumn("ppt_jobs", "mode", "VARCHAR(50)");
  ensureColumn("ppt_jobs", "provider", "VARCHAR(100)");
  ensureColumn("ppt_jobs", "model", "VARCHAR(100)");
  ensureColumn("ppt_jobs", "status", "VARCHAR(50)");
  ensureColumn("ppt_jobs", "ppt_filename", "TEXT");
  ensureColumn("ppt_jobs", "ppt_size", "INTEGER");
  ensureColumn("ppt_jobs", "error_message", "TEXT");
  ensureColumn("ppt_jobs", "created_at", "TIMESTAMP DEFAULT CURRENT_TIMESTAMP");

  ensureColumn("ppt_runs", "job_id", "INTEGER");
  ensureColumn("ppt_runs", "stage_name", "VARCHAR(100)");
  ensureColumn("ppt_runs", "stage_status", "VARCHAR(50)");
  ensureColumn("ppt_runs", "duration_ms", "INTEGER");
  ensureColumn("ppt_runs", "created_at", "TIMESTAMP DEFAULT CURRENT_TIMESTAMP");

  ensureColumn("ppt_metrics", "job_id", "INTEGER");
  ensureColumn("ppt_metrics", "prompt_tokens", "INTEGER");
  ensureColumn("ppt_metrics", "completion_tokens", "INTEGER");
  ensureColumn("ppt_metrics", "total_tokens", "INTEGER");
  ensureColumn("ppt_metrics", "estimated_cost", "DOUBLE PRECISION");
  ensureColumn("ppt_metrics", "duration_ms", "INTEGER");
  ensureColumn("ppt_metrics", "slide_count", "INTEGER");
  ensureColumn("ppt_metrics", "ppt_filename", "TEXT");
  ensureColumn("ppt_metrics", "ppt_size", "INTEGER");
  ensureColumn("ppt_metrics", "model", "VARCHAR(100)");
  ensureColumn("ppt_metrics", "provider", "VARCHAR(100)");
  ensureColumn("ppt_metrics", "created_at", "TIMESTAMP DEFAULT CURRENT_TIMESTAMP");

  ensureColumn("ppt_demo_results", "topic", "TEXT");
  ensureColumn("ppt_demo_results", "brief", "TEXT");
  ensureColumn("ppt_demo_results", "audience", "TEXT");
  ensureColumn("ppt_demo_results", "template_type", "VARCHAR(100)");
  ensureColumn("ppt_demo_results", "mode", "VARCHAR(50)");
  ensureColumn("ppt_demo_results", "theme", "VARCHAR(100)");
  ensureColumn("ppt_demo_results", "provider", "VARCHAR(100)");
  ensureColumn("ppt_demo_results", "model", "VARCHAR(100)");
  ensureColumn("ppt_demo_results", "prompt_tokens", "INTEGER");
  ensureColumn("ppt_demo_results", "completion_tokens", "INTEGER");
  ensureColumn("ppt_demo_results", "total_tokens", "INTEGER");
  ensureColumn("ppt_demo_results", "slide_count", "INTEGER");
  ensureColumn("ppt_demo_results", "duration_ms", "INTEGER");
  ensureColumn("ppt_demo_results", "estimated_cost", "DOUBLE PRECISION");
  ensureColumn("ppt_demo_results", "output_file", "TEXT");
  ensureColumn("ppt_demo_results", "ppt_size", "INTEGER");
  ensureColumn("ppt_demo_results", "quality_note", "TEXT");
  ensureColumn("ppt_demo_results", "demo_name", "TEXT");
  ensureColumn("ppt_demo_results", "quality_mode", "VARCHAR(50)");
  ensureColumn("ppt_demo_results", "status", "VARCHAR(50)");
  ensureColumn("ppt_demo_results", "error_message", "TEXT");
  ensureColumn("ppt_demo_results", "created_at", "TIMESTAMP DEFAULT CURRENT_TIMESTAMP");
  try { q("ALTER TABLE ppt_demo_results ALTER COLUMN demo_name DROP NOT NULL"); } catch(any ignore) {}
  try { q("ALTER TABLE ppt_demo_results ALTER COLUMN quality_mode DROP NOT NULL"); } catch(any ignore) {}
  try { q("ALTER TABLE ppt_demo_results ALTER COLUMN status DROP NOT NULL"); } catch(any ignore) {}
  try {
    nn = q("SELECT column_name FROM information_schema.columns WHERE table_name = 'ppt_demo_results' AND is_nullable = 'NO' AND column_default IS NULL AND column_name <> 'demo_result_id'");
    for(row in nn){
      q("ALTER TABLE ppt_demo_results ALTER COLUMN " & row.column_name & " DROP NOT NULL");
    }
  } catch(any ignoreNN) {}
}

try {
  rawBody = toString(getHttpRequestData().content);
  if(!len(trim(rawBody))) jsonOut({success:false, message:"日志内容为空。"}, 400);
  req = deserializeJson(rawBody);

  if(!structKeyExists(application, "dsn") || !len(trim(application.dsn))){
    jsonOut({success:false, message:"未配置 application.dsn，无法写入数据库。"});
  }

  ensureSchema();

  stageName = s(req, "stage_name", "browser_generation");
  templateType = s(req, "template_type", s(req, "narrativeType", ""));
  statusValue = s(req, "status", "success");
  durationMs = n(req, "duration_ms", n(req, "execution_ms", 0));

  jobQ = q("
    INSERT INTO ppt_jobs(
      topic, brief, audience, template_type, theme, mode, provider, model, status,
      ppt_filename, ppt_size, error_message, created_at
    )
    VALUES(
      :topic, :brief, :audience, :template_type, :theme, :mode, :provider, :model, :status,
      :ppt_filename, :ppt_size, :error_message, CURRENT_TIMESTAMP
    )
    RETURNING job_id
  ", {
    topic:{value:s(req,"topic"), cfsqltype:"cf_sql_longvarchar"},
    brief:{value:s(req,"brief"), cfsqltype:"cf_sql_longvarchar"},
    audience:{value:s(req,"audience"), cfsqltype:"cf_sql_longvarchar"},
    template_type:{value:templateType, cfsqltype:"cf_sql_longvarchar"},
    theme:{value:s(req,"theme"), cfsqltype:"cf_sql_longvarchar"},
    mode:{value:s(req,"mode"), cfsqltype:"cf_sql_longvarchar"},
    provider:{value:s(req,"provider"), cfsqltype:"cf_sql_longvarchar"},
    model:{value:s(req,"model"), cfsqltype:"cf_sql_longvarchar"},
    status:{value:statusValue, cfsqltype:"cf_sql_longvarchar"},
    ppt_filename:{value:s(req,"ppt_filename"), cfsqltype:"cf_sql_longvarchar"},
    ppt_size:{value:n(req,"ppt_size"), cfsqltype:"cf_sql_integer"},
    error_message:{value:s(req,"error_message"), cfsqltype:"cf_sql_longvarchar"}
  });
  jobId = 0;
  try { if(jobQ.recordCount) jobId = val(jobQ.job_id[1]); } catch(any ignoreJob) {}

  q("
    INSERT INTO ppt_runs(job_id, stage_name, stage_status, duration_ms, created_at)
    VALUES(:job_id, :stage_name, :stage_status, :duration_ms, CURRENT_TIMESTAMP)
  ", {
    job_id:{value:jobId, cfsqltype:"cf_sql_integer"},
    stage_name:{value:stageName, cfsqltype:"cf_sql_longvarchar"},
    stage_status:{value:statusValue, cfsqltype:"cf_sql_longvarchar"},
    duration_ms:{value:durationMs, cfsqltype:"cf_sql_integer"}
  });

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
    prompt_tokens:{value:n(req,"prompt_tokens"), cfsqltype:"cf_sql_integer"},
    completion_tokens:{value:n(req,"completion_tokens"), cfsqltype:"cf_sql_integer"},
    total_tokens:{value:n(req,"total_tokens"), cfsqltype:"cf_sql_integer"},
    estimated_cost:{value:n(req,"estimated_cost"), cfsqltype:"cf_sql_double"},
    duration_ms:{value:durationMs, cfsqltype:"cf_sql_integer"},
    slide_count:{value:n(req,"slide_count"), cfsqltype:"cf_sql_integer"},
    ppt_filename:{value:s(req,"ppt_filename"), cfsqltype:"cf_sql_longvarchar"},
    ppt_size:{value:n(req,"ppt_size"), cfsqltype:"cf_sql_integer"},
    model:{value:s(req,"model"), cfsqltype:"cf_sql_longvarchar"},
    provider:{value:s(req,"provider"), cfsqltype:"cf_sql_longvarchar"}
  });

  safeTopic = s(req,"topic","demo");
  safeMode = s(req,"mode","balanced");
  demoName = "demo_" & dateFormat(now(), "yyyymmdd") & "_" & timeFormat(now(), "HHmmss") & "_" & safeMode & "_" & stageName;

  try {
  q("
    INSERT INTO ppt_demo_results(
      demo_name, quality_mode, topic, brief, audience, template_type, mode, theme, provider, model,
      prompt_tokens, completion_tokens, total_tokens, slide_count, duration_ms,
      estimated_cost, output_file, ppt_size, quality_note, status, error_message, created_at
    )
    VALUES(
      :demo_name, :quality_mode, :topic, :brief, :audience, :template_type, :mode, :theme, :provider, :model,
      :prompt_tokens, :completion_tokens, :total_tokens, :slide_count, :duration_ms,
      :estimated_cost, :output_file, :ppt_size, :quality_note, :status, :error_message, CURRENT_TIMESTAMP
    )
  ", {
    demo_name:{value:demoName, cfsqltype:"cf_sql_longvarchar"},
    quality_mode:{value:safeMode, cfsqltype:"cf_sql_longvarchar"},
    topic:{value:s(req,"topic"), cfsqltype:"cf_sql_longvarchar"},
    brief:{value:s(req,"brief"), cfsqltype:"cf_sql_longvarchar"},
    audience:{value:s(req,"audience"), cfsqltype:"cf_sql_longvarchar"},
    template_type:{value:templateType, cfsqltype:"cf_sql_longvarchar"},
    mode:{value:s(req,"mode"), cfsqltype:"cf_sql_longvarchar"},
    theme:{value:s(req,"theme"), cfsqltype:"cf_sql_longvarchar"},
    provider:{value:s(req,"provider"), cfsqltype:"cf_sql_longvarchar"},
    model:{value:s(req,"model"), cfsqltype:"cf_sql_longvarchar"},
    prompt_tokens:{value:n(req,"prompt_tokens"), cfsqltype:"cf_sql_integer"},
    completion_tokens:{value:n(req,"completion_tokens"), cfsqltype:"cf_sql_integer"},
    total_tokens:{value:n(req,"total_tokens"), cfsqltype:"cf_sql_integer"},
    slide_count:{value:n(req,"slide_count"), cfsqltype:"cf_sql_integer"},
    duration_ms:{value:durationMs, cfsqltype:"cf_sql_integer"},
    estimated_cost:{value:n(req,"estimated_cost"), cfsqltype:"cf_sql_double"},
    output_file:{value:s(req,"ppt_filename"), cfsqltype:"cf_sql_longvarchar"},
    ppt_size:{value:n(req,"ppt_size"), cfsqltype:"cf_sql_integer"},
    quality_note:{value:stageName & " / " & statusValue, cfsqltype:"cf_sql_longvarchar"},
    status:{value:statusValue, cfsqltype:"cf_sql_longvarchar"},
    error_message:{value:s(req,"error_message"), cfsqltype:"cf_sql_longvarchar"}
  });
  } catch(any demoInsertError) {
    // ppt_jobs / ppt_runs / ppt_metrics 已经写入成功。demo_results 如果旧表约束异常，不阻断主流程。
  }

  jsonOut({success:true, job_id:jobId});
} catch(any e) {
  jsonOut({success:false, message:"数据库记录失败。", detail:e.message}, 200);
}
</cfscript>

