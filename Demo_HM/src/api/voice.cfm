<cfscript>
util = new demo_hm.services.JsonUtil();
try {
  if(cgi.request_method != "POST") {
    util.send({success:true, mode:"voice_api_ready", bridge_url:(application.voiceBridgeUrl ?: "http://127.0.0.1:8010"), message:"POST {persona_id,text,action} to prepare clone or synthesize voice."});
  }

  raw = toString(getHttpRequestData().content);
  payload = len(trim(raw)) ? deserializeJSON(raw) : {};
  action = lcase(toString(payload.action ?: "tts"));
  personaId = val(payload.persona_id ?: 0);
  text = toString(payload.text ?: "");
  if(personaId <= 0 || !len(trim(text))) util.error("persona_id and text are required",400,"");

  ensureVoicePatch();
  syncLatestVoiceAsset(personaId);

  q="";
  cfquery(name="q", datasource="demo_hm") {
    writeOutput("SELECT p.persona_id,p.persona_name,p.gender,p.relationship,v.voice_id,v.voice_provider,v.voice_clone_status,v.voice_label,v.sample_audio_url,v.sample_audio_path,v.provider_voice_id,v.pitch,v.speaking_rate FROM hm_personas p LEFT JOIN hm_voice_profiles v ON v.persona_id=p.persona_id AND v.voice_status='active' WHERE p.persona_id=" & personaId & " LIMIT 1");
  }
  if(!q.recordCount) util.error("persona not found",404,"");
  row = util.queryToArray(q)[1];

  provider = lcase(row.voice_provider ?: "browser_tts");
  if(provider == "local_xtts" || provider == "browser_tts") provider = "minimax";

  samplePath = row.sample_audio_path ?: row.sample_audio_url ?: "";
  localAudioAbs = len(samplePath) ? expandPath("../" & samplePath) : "";
  hasSample = len(samplePath) && fileExists(localAudioAbs);
  hasVoiceId = len(trim(row.provider_voice_id ?: ""));
  canProvider = listFindNoCase("minimax,elevenlabs", provider);

  if(canProvider && (hasVoiceId || hasSample)) {
    req = {
      text:text,
      speaker_wav:localAudioAbs,
      language:"zh-cn",
      persona_id:personaId,
      persona_name:row.persona_name,
      provider:provider,
      provider_voice_id:(row.provider_voice_id ?: ""),
      action:action,
      minimax_api_key:(application.minimaxApiKey ?: ""),
      minimax_region:(application.minimaxRegion ?: "cn"),
      minimax_api_host:(application.minimaxApiHost ?: "https://api.minimax.chat"),
      minimax_group_id:(application.minimaxGroupId ?: ""),
      hm_public_base_url:(application.hmPublicBaseUrl ?: "http://demos.e-xanke.com/demo_hm")
    };

    bridgeUrl = application.voiceBridgeUrl ?: "http://127.0.0.1:8010";
    try {
      cfhttp(method="post", url=bridgeUrl & "/tts", result="httpRes", timeout="180") {
        cfhttpparam(type="header", name="Content-Type", value="application/json; charset=utf-8");
        cfhttpparam(type="body", value=serializeJSON(req));
      }

      statusCode = val(listFirst(toString(httpRes.statusCode), " "));
      resText = toString(httpRes.fileContent ?: "");
      if(statusCode < 200 || statusCode >= 300) {
        if(action == "prepare_clone") util.send({success:false, mode:"provider_bridge_http_error", provider:provider, status_code:httpRes.statusCode, message:"Voice bridge returned HTTP error", bridge_response:left(resText,900)});
        fallback(row, "voice provider bridge HTTP error: " & httpRes.statusCode & " / " & left(resText,220));
      }

      try {
        res = deserializeJSON(resText);
      } catch(any jsonErr) {
        if(action == "prepare_clone") util.send({success:false, mode:"provider_bridge_non_json", provider:provider, message:"Voice bridge did not return JSON", bridge_response:left(resText,900)});
        fallback(row, "voice provider bridge returned non-JSON: " & left(resText,220));
      }

      if(structKeyExists(res,"success") && res.success) {
        newVoiceId = res.provider_voice_id ?: row.provider_voice_id ?: "";
        cfquery(name="upd", datasource="demo_hm") {
          writeOutput("UPDATE hm_voice_profiles SET voice_provider=" & sqlString(res.provider ?: provider) & ", generated_audio_url=" & sqlString(res.audio_url ?: "") & ", provider_voice_id=" & sqlString(newVoiceId) & ", voice_clone_status='provider_ready', updated_at=now() WHERE persona_id=" & personaId);
        }
        util.send({success:true, mode:(res.engine ?: "provider_voice_clone"), audio_url:res.audio_url ?: "", provider:(res.provider ?: provider), provider_voice_id:newVoiceId, label:row.voice_label, gender:row.gender, message:(res.message ?: "Provider generated cloned voice audio.")});
      } else {
        msg = res.error ?: res.message ?: "provider returned no audio";
        if(action == "prepare_clone") util.send({success:false, mode:"provider_failed", provider:provider, message:msg, raw:res});
        fallback(row, msg);
      }
    } catch(any localErr) {
      if(action == "prepare_clone") util.send({success:false, mode:"provider_bridge_exception", provider:provider, message:localErr.message, detail:localErr.detail});
      fallback(row, "voice provider bridge failed: " & localErr.message);
    }
  }

  if(action == "prepare_clone") {
    util.send({success:false, mode:"no_voice_sample", provider:"browser_tts", gender:row.gender, message:"No cloned voice is ready. Select this persona, upload or record at least one voice sample, then click Prepare Voice Clone."});
  }
  fallback(row, "No cloned voice is ready yet. Upload a voice sample and start the Python voice bridge with MiniMax/ElevenLabs key.");
} catch(any e){ util.error("voice api failed",500,e.message & " / " & e.detail); }

function ensureVoicePatch(){
  cfquery(name="vp1", datasource="demo_hm") { writeOutput("ALTER TABLE hm_voice_profiles ADD COLUMN IF NOT EXISTS sample_audio_path VARCHAR(500)"); }
  cfquery(name="vp2", datasource="demo_hm") { writeOutput("ALTER TABLE hm_voice_profiles ADD COLUMN IF NOT EXISTS generated_audio_url VARCHAR(500)"); }
  cfquery(name="vp3", datasource="demo_hm") { writeOutput("ALTER TABLE hm_voice_profiles ADD COLUMN IF NOT EXISTS provider_voice_id VARCHAR(300)"); }
}

function syncLatestVoiceAsset(required numeric personaId){
  hasTable="";
  try {
    cfquery(name="latest", datasource="demo_hm") {
      writeOutput("SELECT file_url FROM hm_persona_assets WHERE persona_id=" & arguments.personaId & " AND asset_type='voice' ORDER BY asset_id DESC LIMIT 1");
    }
    if(latest.recordCount) {
      latestUrl = latest.file_url[1];
      cfquery(name="uv", datasource="demo_hm") {
        writeOutput("UPDATE hm_voice_profiles SET voice_provider='minimax', voice_clone_status=CASE WHEN provider_voice_id IS NULL OR provider_voice_id='' THEN 'sample_uploaded' ELSE voice_clone_status END, sample_audio_url=" & sqlString(latestUrl) & ", sample_audio_path=" & sqlString(latestUrl) & ", updated_at=now() WHERE persona_id=" & arguments.personaId);
      }
    }
  } catch(any ignore) {}
}

function fallback(required struct row, required string warning){
  util.send({success:true, mode:"gender_safe_browser_tts_fallback", provider:"browser_tts", label:(arguments.row.voice_label ?: "browser fallback"), gender:(arguments.row.gender ?: "unknown"), pitch:(arguments.row.pitch ?: "low"), rate:(arguments.row.speaking_rate ?: "slow"), warning:arguments.warning});
}

function sqlString(any v=""){
  if(isNull(arguments.v)) return "''";
  return "'" & replace(toString(arguments.v),"'","''","all") & "'";
}
</cfscript>
