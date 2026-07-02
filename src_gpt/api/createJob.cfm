<cfscript>
contentType = "application/json; charset=utf-8";

function jsonOut(required struct payload, numeric statusCode=200){
  cfheader(statuscode=arguments.statusCode, statustext=(arguments.statusCode == 200 ? "OK" : "Job Error"));
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

function ensureJobsTable(){
  queryExecute("
    CREATE TABLE IF NOT EXISTS ppt_jobs (
      job_id SERIAL PRIMARY KEY,
      topic TEXT,
      brief TEXT,
      audience TEXT,
      template_type TEXT,
      theme TEXT,
      mode TEXT,
      provider TEXT,
      model TEXT,
      status VARCHAR(40),
      progress INTEGER DEFAULT 0,
      current_step TEXT,
      presentation_prompt TEXT,
      slide_spec_json TEXT,
      response_id TEXT,
      prompt_tokens INTEGER DEFAULT 0,
      completion_tokens INTEGER DEFAULT 0,
      total_tokens INTEGER DEFAULT 0,
      estimated_cost NUMERIC(12,6) DEFAULT 0,
      duration_ms INTEGER DEFAULT 0,
      slide_count INTEGER DEFAULT 0,
      ppt_filename TEXT,
      ppt_size BIGINT DEFAULT 0,
      output_file TEXT,
      error_message TEXT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ", {}, {datasource:application.dsn});

  var columns = [
    ["topic", "TEXT"],
    ["brief", "TEXT"],
    ["audience", "TEXT"],
    ["template_type", "TEXT"],
    ["theme", "TEXT"],
    ["mode", "TEXT"],
    ["provider", "TEXT"],
    ["model", "TEXT"],
    ["progress", "INTEGER DEFAULT 0"],
    ["current_step", "TEXT"],
    ["presentation_prompt", "TEXT"],
    ["slide_spec_json", "TEXT"],
    ["response_id", "TEXT"],
    ["output_file", "TEXT"],
    ["updated_at", "TIMESTAMP DEFAULT CURRENT_TIMESTAMP"],
    ["prompt_tokens", "INTEGER DEFAULT 0"],
    ["completion_tokens", "INTEGER DEFAULT 0"],
    ["total_tokens", "INTEGER DEFAULT 0"],
    ["estimated_cost", "NUMERIC(12,6) DEFAULT 0"],
    ["duration_ms", "INTEGER DEFAULT 0"],
    ["slide_count", "INTEGER DEFAULT 0"],
    ["ppt_filename", "TEXT"],
    ["ppt_size", "BIGINT DEFAULT 0"],
    ["error_message", "TEXT"]
  ];
  for(var col in columns){
    var existsQ = queryExecute("
      SELECT 1
      FROM information_schema.columns
      WHERE table_name = 'ppt_jobs'
        AND column_name = :column_name
      LIMIT 1
    ", {
      column_name:{value:col[1], cfsqltype:"cf_sql_varchar"}
    }, {datasource:application.dsn});
    if(!existsQ.recordCount){
      queryExecute("ALTER TABLE ppt_jobs ADD COLUMN #col[1]# #col[2]#", {}, {datasource:application.dsn});
    }
  }
  var wideAlters = [
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
  for(var sqlText in wideAlters){
    try { queryExecute(sqlText, {}, {datasource:application.dsn}); } catch(any ignored) {}
  }
}

try {
  rawBody = toString(getHttpRequestData().content);
  if(!len(trim(rawBody))) jsonOut({success:false, message:"请求内容为空。"}, 400);
  req = deserializeJson(rawBody);
  topic = valOf(req, "topic");
  if(!len(topic)) jsonOut({success:false, message:"主题不能为空。"}, 400);

  ensureJobsTable();

  insertResult = queryExecute("
    INSERT INTO ppt_jobs (
      topic, brief, audience, template_type, theme, mode, provider, model,
      status, progress, current_step, presentation_prompt, slide_spec_json, created_at, updated_at
    )
    VALUES (
      :topic, :brief, :audience, :template_type, :theme, :mode, 'openai', :model,
      'queued', 0, '已进入生成队列', :presentation_prompt, :client_slide_spec_json, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
    )
    RETURNING job_id
  ", {
    topic:{value:topic, cfsqltype:"cf_sql_longvarchar"},
    brief:{value:valOf(req, "brief"), cfsqltype:"cf_sql_longvarchar"},
    audience:{value:valOf(req, "audience"), cfsqltype:"cf_sql_longvarchar"},
    template_type:{value:valOf(req, "template_type", "proposal"), cfsqltype:"cf_sql_longvarchar"},
    theme:{value:valOf(req, "theme", "auto"), cfsqltype:"cf_sql_longvarchar"},
    mode:{value:valOf(req, "mode", "beauty"), cfsqltype:"cf_sql_longvarchar"},
    model:{value:appVal("openaiModel", appVal("llmModel", "gpt-4o-mini")), cfsqltype:"cf_sql_longvarchar"},
    presentation_prompt:{value:valOf(req, "presentation_prompt"), cfsqltype:"cf_sql_longvarchar"},
    client_slide_spec_json:{value:valOf(req, "client_slide_spec_json"), cfsqltype:"cf_sql_longvarchar"}
  }, {datasource:application.dsn});

  jsonOut({success:true, jobId:insertResult.job_id[1], status:"queued", progress:0, currentStep:"已进入生成队列"});
} catch(any e) {
  jsonOut({success:false, message:"创建任务失败。", detail:e.message}, 500);
}
</cfscript>
