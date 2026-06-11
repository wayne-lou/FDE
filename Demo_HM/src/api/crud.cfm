<cfscript>
util = new demo_hm.services.JsonUtil();
module = lcase(url.module ?: form.module ?: "personas");
action = lcase(url.action ?: form.action ?: "list");
config = {
  users:{table:"hm_users",pk:"user_id",label:"display_name",fields:"display_name,email,user_role,user_status",enums:{user_role:"owner,reviewer,admin",user_status:"active,inactive"}},
  personas:{table:"hm_personas",pk:"persona_id",label:"persona_name",fields:"owner_user_id,persona_name,relationship,gender,birth_date,reference_photo_url,persona_type,short_bio,speaking_style,catchphrases,consent_status,persona_status",enums:{gender:"male,female,unknown,pet",persona_type:"family,friend,pet,self_archive",consent_status:"demo_sanitized,explicit_consent,pending,restricted",persona_status:"active,inactive,archived"},lookups:{owner_user_id:"users"}},
  avatars:{table:"hm_avatar_profiles",pk:"avatar_id",label:"avatar_mode",fields:"persona_id,avatar_mode,avatar_color,model_url,image_url,motion_profile,avatar_status",enums:{avatar_mode:"hologram_3d,photo_card,pet_orb",motion_profile:"calm,playful,energetic",avatar_status:"active,inactive"},lookups:{persona_id:"personas"}},
  voices:{table:"hm_voice_profiles",pk:"voice_id",label:"voice_label",fields:"persona_id,voice_provider,voice_clone_status,voice_label,sample_audio_url,sample_audio_path,provider_voice_id,generated_audio_url,pitch,speaking_rate,voice_status",enums:{voice_provider:"browser_tts,local_xtts,elevenlabs,cartesia,azure,minimax,fish_audio",voice_clone_status:"not_trained,sample_uploaded,training,local_ready,provider_ready,failed",pitch:"low,medium,high",speaking_rate:"slow,normal,fast",voice_status:"active,inactive"},lookups:{persona_id:"personas"}},
  memories:{table:"hm_memory_items",pk:"memory_id",label:"memory_title",fields:"persona_id,memory_type,memory_title,memory_date,source_channel,transcript,summary,emotion_tag,location_text,privacy_level,memory_status",enums:{memory_type:"chat,audio,photo,video,diary,event,note",privacy_level:"private,family_shared,restricted",memory_status:"active,inactive,archived"},lookups:{persona_id:"personas"},long:"transcript,summary"},
  chunks:{table:"hm_memory_chunks",pk:"chunk_id",label:"chunk_summary",fields:"memory_id,persona_id,chunk_index,chunk_text,chunk_summary,keywords",lookups:{persona_id:"personas",memory_id:"memories"},long:"chunk_text,keywords"},
  conversations:{table:"hm_conversations",pk:"conversation_id",label:"conversation_title",fields:"persona_id,user_id,conversation_title,conversation_status",enums:{conversation_status:"open,closed,archived"},lookups:{persona_id:"personas",user_id:"users"}},
  agent_tasks:{table:"hm_agent_tasks",pk:"agent_task_id",label:"agent_mode",fields:"persona_id,user_id,input_goal,agent_mode,risk_level,agent_summary,recommended_response,agent_status",enums:{agent_mode:"memory_conversation,reminisce,family_digest,safety_review",risk_level:"low,medium,high",agent_status:"completed,pending,failed"},lookups:{persona_id:"personas",user_id:"users"},long:"input_goal,agent_summary,recommended_response"},
  audit_logs:{table:"hm_audit_logs",pk:"audit_log_id",label:"action_name",fields:"actor_user_id,entity_type,entity_id,action_name,action_detail",lookups:{actor_user_id:"users"},long:"action_detail"}
};
if(!structKeyExists(config,module)) util.error("Unknown module",400,module);
cfg=config[module];
try {
  if(action=="meta") util.send({success:true,module:module,config:cfg});
  if(action=="lookup"){
    target = lcase(url.target ?: "personas");
    if(!structKeyExists(config,target)) util.error("Unknown lookup",400,target);
    tc=config[target]; q="";
    sql="SELECT #tc.pk# AS id, #tc.label# AS label FROM #tc.table# ORDER BY #tc.pk# LIMIT 200";
    cfquery(name="q", datasource="demo_hm"){ writeOutput(sql); }
    util.send({success:true,rows:util.queryToArray(q)});
  }
  if(action=="list"){
    q=""; sql="SELECT * FROM #cfg.table# ORDER BY #cfg.pk# DESC LIMIT 100";
    cfquery(name="q", datasource="demo_hm"){ writeOutput(sql); }
    util.send({success:true,rows:util.queryToArray(q),pk:cfg.pk});
  }
  if(action=="get"){
    id=val(url.id ?: 0); q=""; sql="SELECT * FROM #cfg.table# WHERE #cfg.pk# = " & id;
    cfquery(name="q", datasource="demo_hm") { writeOutput(sql); }
    util.send({success:true,row:(q.recordCount?util.queryToArray(q)[1]:{})});
  }
  if(action=="save"){
    raw=toString(getHttpRequestData().content); data=deserializeJSON(raw); id=val(data[cfg.pk] ?: 0); fields=listToArray(cfg.fields); 
    if(id>0){
      sets=[]; for(f in fields){ if(structKeyExists(data,f)) arrayAppend(sets,"#f#=" & sqlValue(f,data[f])); }
      if(!arrayLen(sets)) util.error("No fields to update",400,"");
      sql="UPDATE #cfg.table# SET " & arrayToList(sets,",") & ", updated_at=now() WHERE #cfg.pk#=" & id;
      cfquery(name="uq", datasource="demo_hm") { writeOutput(sql); }
      util.send({success:true,message:"Updated",id:id});
    } else {
      cols=[]; vals=[]; for(f in fields){ if(structKeyExists(data,f)){ arrayAppend(cols,f); arrayAppend(vals,sqlValue(f,data[f])); } }
      if(!arrayLen(cols)) util.error("No fields to create",400,"");
      sql="INSERT INTO #cfg.table# (" & arrayToList(cols,",") & ") VALUES (" & arrayToList(vals,",") & ") RETURNING #cfg.pk#";
      cfquery(name="iq", datasource="demo_hm") { writeOutput(sql); }
      util.send({success:true,message:"Created",id:iq[cfg.pk][1]});
    }
  }
  if(action=="delete"){
    id=val(url.id ?: 0); sql="DELETE FROM #cfg.table# WHERE #cfg.pk#=" & id;
    cfquery(name="dq", datasource="demo_hm") { writeOutput(sql); }
    util.send({success:true,message:"Deleted",id:id});
  }
  util.error("Unknown action",400,action);
} catch(any e){ util.error("crud api failed",500,e.message & " / " & e.detail); }

function sqlValue(required string f, any v=""){
  if(isNull(arguments.v)) return "NULL";
  var s = trim(toString(arguments.v));
  if(!len(s)) return "NULL";
  if(right(arguments.f,3)=="_id" || listFindNoCase("chunk_index,entity_id",arguments.f)) return toString(val(s));
  if(findNoCase("date",arguments.f) && arguments.f != "updated_at" && arguments.f != "created_at") return "'" & replace(s,"'","''","all") & "'";
  return "'" & replace(s,"'","''","all") & "'";
}
</cfscript>
