component output="false" {
  public struct function run(required numeric persona_id, required numeric user_id, required string goal){
    var util = new demo_hm.services.JsonUtil();
    var rag = new demo_hm.services.RagService();
    var ragResult = rag.search(arguments.persona_id, arguments.goal, 5);
    var evidence = ragResult.evidence;
    var profile = ragResult.query_profile;
    var personaQ = "";
    cfquery(name="avatarPatch1", datasource="demo_hm") { writeOutput("ALTER TABLE hm_avatar_profiles ADD COLUMN IF NOT EXISTS model_url VARCHAR(1000)"); }
    cfquery(name="avatarPatch2", datasource="demo_hm") { writeOutput("ALTER TABLE hm_avatar_profiles ADD COLUMN IF NOT EXISTS provider_avatar_id VARCHAR(255)"); }
    cfquery(name="personaQ", datasource="demo_hm") {
      writeOutput("SELECT p.*, v.voice_label, v.voice_provider, v.voice_clone_status, v.sample_audio_url, v.sample_audio_path, v.provider_voice_id, v.generated_audio_url, v.pitch, v.speaking_rate, a.avatar_mode, a.avatar_color, a.image_url, a.model_url, a.provider_avatar_id, a.motion_profile FROM hm_personas p LEFT JOIN hm_voice_profiles v ON v.persona_id=p.persona_id AND v.voice_status='active' LEFT JOIN hm_avatar_profiles a ON a.persona_id=p.persona_id AND a.avatar_status='active' WHERE p.persona_id=" & val(arguments.persona_id) & " LIMIT 1");
    }
    var personaRows = util.queryToArray(personaQ);
    if(!arrayLen(personaRows)) return {success:false,error:"Persona not found"};
    var p = personaRows[1];

    var grounding = calculateGrounding(evidence);
    var safety = safetyReview(profile, p, evidence);
    var answer = composeGroundedResponse(p, arguments.goal, profile, evidence, grounding, safety);
    var convId = ensureConversation(arguments.persona_id, arguments.user_id, profile.intent);

    cfquery(name="insMsg1", datasource="demo_hm") { writeOutput("INSERT INTO hm_messages(conversation_id,sender_type,message_text) VALUES(" & convId & ",'user'," & sqlString(arguments.goal) & ")"); }
    cfquery(name="insMsg2", datasource="demo_hm") { writeOutput("INSERT INTO hm_messages(conversation_id,sender_type,message_text,retrieved_context,voice_output_url) VALUES(" & convId & ",'persona_agent'," & sqlString(answer) & "," & sqlString(serializeJSON(evidence)) & "," & sqlString(buildVoiceUrl(p, answer)) & ")"); }

    var taskId = 0;
    cfquery(name="taskQ", datasource="demo_hm") {
      writeOutput("INSERT INTO hm_agent_tasks(persona_id,user_id,input_goal,agent_mode,risk_level,agent_summary,recommended_response) VALUES(" & val(arguments.persona_id) & "," & val(arguments.user_id) & "," & sqlString(arguments.goal) & "," & sqlString(profile.intent) & "," & sqlString(safety.risk_level) & "," & sqlString(buildSummary(profile,evidence,grounding,safety)) & "," & sqlString(answer) & ") RETURNING agent_task_id");
    }
    taskId = taskQ.agent_task_id[1];

    var steps = buildSteps(profile, evidence, p, grounding, safety, answer);
    for(var i=1; i<=arrayLen(steps); i++){
      cfquery(name="stepIns", datasource="demo_hm") {
        writeOutput("INSERT INTO hm_agent_steps(agent_task_id,step_order,step_type,step_title,step_detail) VALUES(" & taskId & "," & i & "," & sqlString(steps[i].type) & "," & sqlString(steps[i].title) & "," & sqlString(steps[i].detail) & ")");
      }
    }
    for(var e in evidence){
      cfquery(name="ragIns", datasource="demo_hm") {
        writeOutput("INSERT INTO hm_rag_retrievals(conversation_id,persona_id,question_text,chunk_id,score,evidence_excerpt) VALUES(" & convId & "," & val(arguments.persona_id) & "," & sqlString(arguments.goal) & "," & val(e.chunk_id) & "," & val(e.score) & "," & sqlString(e.evidence_excerpt) & ")");
      }
    }
    cfquery(name="auditIns", datasource="demo_hm") {
      writeOutput("INSERT INTO hm_audit_logs(actor_user_id,entity_type,entity_id,action_name,action_detail) VALUES(" & val(arguments.user_id) & ",'agent_task'," & taskId & ",'run_memory_agent'," & sqlString('intent=' & profile.intent & '; evidence=' & arrayLen(evidence) & '; grounding=' & grounding.level) & ")");
    }

    return {
      success:true,
      agent_task_id:taskId,
      conversation_id:convId,
      persona:p,
      query_profile:profile,
      intent:profile.intent,
      answer:answer,
      evidence:evidence,
      grounding:grounding,
      safety:safety,
      steps:steps,
      voice:{provider:p.voice_provider?:"browser_tts",clone_status:p.voice_clone_status?:"not_trained",label:p.voice_label?:"Browser voice",pitch:p.pitch?:"medium",rate:p.speaking_rate?:"normal",sample:p.sample_audio_url?:"",sample_path:p.sample_audio_path?:"",provider_voice_id:p.provider_voice_id?:"",gender:p.gender?:"unknown",voice_endpoint:"api/voice.cfm",mode:voiceMode(p)},
      avatar:{mode:p.avatar_mode?:"hologram_3d",color:p.avatar_color?:"##43f4ff",image_url:resolveAvatarImage(p),model_url:p.model_url?:"",provider_avatar_id:p.provider_avatar_id?:"",motion:p.motion_profile?:"calm",expression:avatarExpression(profile,grounding,safety),gender:p.gender?:"unknown"}
    };
  }

  private struct function calculateGrounding(required array evidence){
    if(!arrayLen(evidence)) return {level:"none",score:0,label:"No grounded memory found"};
    var s = evidence[1].score;
    if(s>=6) return {level:"strong",score:s,label:"Strong memory grounding"};
    if(s>=3) return {level:"medium",score:s,label:"Partial memory grounding"};
    return {level:"weak",score:s,label:"Weak memory grounding"};
  }

  private struct function safetyReview(required struct profile, required struct p, required array evidence){
    var risk="low"; var notes=[];
    if(profile.intent == "safety_review") { risk="medium"; arrayAppend(notes,"Identity/authorization sensitive request"); }
    if(!arrayLen(evidence)) { if(risk=="low") risk="medium"; arrayAppend(notes,"No memory evidence; avoid fabrication"); }
    if(findNoCase("consent", p.consent_status?:"") || (p.consent_status?:"") == "demo_sanitized") arrayAppend(notes,"Demo/sanitized consent profile");
    return {risk_level:risk, notes:notes, policy:"AI output must be disclosed, memory-grounded, and cannot impersonate a real person for legal/financial/medical decisions."};
  }

  private string function composeGroundedResponse(required struct p, required string goal, required struct profile, required array evidence, required struct grounding, required struct safety){
    var phrase = pickCatchphrase(p.catchphrases?:"");
    var name = p.persona_name ?: "Memory persona";
    if(profile.intent == "safety_review") return "我可以帮你保存和呈现记忆，但不能冒充真人做授权、承诺或敏感决策。这个系统会明确标注为 AI 生成，并且只基于已授权保存的记忆回答。";
    if(!arrayLen(evidence)) return phrase & "我没有在保存的记忆里找到足够明确的证据。为了不编造，我只能说：这件事我现在记不清。你可以补充照片、录音或聊天记录，我再根据新的记忆回答。";

    var e1=evidence[1];
    var detail = cleanEvidence(e1.evidence_excerpt);
    var extra = arrayLen(evidence)>=2 ? cleanEvidence(evidence[2].evidence_excerpt) : "";
    if(profile.intent == "reminisce"){
      return phrase & "我记得这段：" & detail & (len(extra)?" 另外还有一段相关记忆：" & extra:"") & " 所以我不会把它说成很大的事情，最重要的是那天大家在一起、很累但很开心。";
    }
    if(profile.intent == "emotional_support"){
      return phrase & "我想到以前说过的话：" & detail & " 先别急，把事情一件一件做，先处理最重要的。吃好、休息好，家人在，很多事就能慢慢解决。";
    }
    if(profile.intent == "voice_memory"){
      return phrase & "我可以用当前保存的 voice profile 读出这段话。现在页面会用浏览器 TTS 模拟；如果接入 ElevenLabs、MiniMax、Azure 或 Fish Audio 的 voice clone，就会改用克隆音色输出。";
    }
    if(profile.intent == "family_digest"){
      var list=""; for(var i=1;i<=min(3,arrayLen(evidence));i++){ list &= i & ". " & evidence[i].memory_title & "：" & cleanEvidence(evidence[i].evidence_excerpt) & " "; }
      return phrase & "我把相关记忆整理成一个小摘要：" & list;
    }
    return phrase & "根据保存的记忆，我找到的主要依据是：" & detail & (len(extra)?" 还有：" & extra:"") & " 如果你继续问具体地点、人物、时间，我会继续只按保存证据回答。";
  }

  private array function buildSteps(required struct profile, required array evidence, required struct p, required struct grounding, required struct safety, required string answer){
    return [
      {type:"intent", title:"Intent detection", detail:"Question classified as " & profile.intent & "; focus=" & profile.focus & "; terms=" & arrayToList(profile.terms, ', ')},
      {type:"rag", title:"Memory RAG retrieval", detail:"Searched memory chunks from chats/audio/photo notes/diaries. Evidence count=" & arrayLen(evidence) & "; top grounding=" & grounding.label},
      {type:"evidence", title:"Evidence grounding", detail:arrayLen(evidence)?("Top memory: " & evidence[1].memory_title & "; reasons=" & arrayToList(evidence[1].match_reasons, ', ')):"No sufficient evidence; response will refuse to invent."},
      {type:"persona", title:"Persona style composition", detail:"Applied speaking style: " & left(p.speaking_style?:'',220) & "; catchphrases=" & (p.catchphrases?:'')},
      {type:"safety", title:"Consent and anti-fabrication check", detail:"Risk=" & safety.risk_level & "; " & safety.policy},
      {type:"voice", title:"Voice clone adapter", detail:"Voice provider=" & (p.voice_provider?:'browser_tts') & "; clone status=" & (p.voice_clone_status?:'not_trained') & "; provider adapter uses MiniMax/ElevenLabs through /api/voice.cfm; fallback is gender-safe browser TTS."},
      {type:"avatar", title:"Avatar animation", detail:"Avatar mode=" & (p.avatar_mode?:'hologram_3d') & "; expression=" & avatarExpression(profile,grounding,safety) & "; animation linked to speaking/evidence state."},
      {type:"response", title:"Grounded answer", detail:left(answer,500)}
    ];
  }

  private string function buildSummary(required struct profile, required array evidence, required struct grounding, required struct safety){
    return "Intent=" & profile.intent & "; focus=" & profile.focus & "; retrieved " & arrayLen(evidence) & " evidence chunks; grounding=" & grounding.level & "; safety risk=" & safety.risk_level;
  }

  private string function avatarExpression(required struct profile, required struct grounding, required struct safety){
    if(safety.risk_level=="medium") return "careful";
    if(profile.intent=="emotional_support") return "warm";
    if(profile.intent=="reminisce") return "nostalgic";
    if(grounding.level=="none") return "uncertain";
    return "calm";
  }


  private string function resolveAvatarImage(required struct p){
    if(len(p.image_url?:"")) return p.image_url;
    if(len(p.reference_photo_url?:"")) return p.reference_photo_url;
    var g=lcase(p.gender?:"");
    var rel=lcase(p.relationship?:"");
    if(g=="pet" || find("dog",rel) || find("cat",rel) || find("pet",rel)) return "assets/img/default-pet.svg";
    if(g=="male") return "assets/img/default-male.svg";
    if(g=="female") return "assets/img/default-female.svg";
    return "assets/img/default-friend.svg";
  }

  private string function buildVoiceUrl(required struct p, required string answer){
    if(listFindNoCase("minimax,elevenlabs", p.voice_provider?:"") && (len(p.sample_audio_path?:"") || len(p.provider_voice_id?:""))) return "provider://" & (p.voice_label?:"voice");
    if(len(p.provider_voice_id?:"")) return "provider://" & (p.provider_voice_id?:"");
    return "browser-tts://" & (p.voice_label?:"default");
  }
  private string function voiceMode(required struct p){
    if(listFindNoCase("minimax,elevenlabs", p.voice_provider?:"") && (len(p.sample_audio_path?:"") || len(p.provider_voice_id?:""))) return "provider_voice_clone";
    if(len(p.provider_voice_id?:"")) return "provider_voice_clone";
    return "gender_safe_browser_tts_fallback";
  }

  private string function pickCatchphrase(string phrases=""){
    if(!len(trim(arguments.phrases))) return "";
    return trim(listFirst(arguments.phrases,";")) & "。";
  }
  private string function cleanEvidence(string s=""){
    var x = rereplace(arguments.s,"\s+"," ","all");
    return left(x,260);
  }
  private numeric function ensureConversation(required numeric persona_id, required numeric user_id, string intent="memory_conversation"){
    var q="";
    cfquery(name="q", datasource="demo_hm") { writeOutput("INSERT INTO hm_conversations(persona_id,user_id,conversation_title) VALUES(" & val(arguments.persona_id) & "," & val(arguments.user_id) & "," & sqlString('HoloMemory - ' & arguments.intent) & ") RETURNING conversation_id"); }
    return q.conversation_id[1];
  }
  private string function sqlString(any v=""){
    if(isNull(arguments.v)) return "''";
    return "'" & replace(toString(arguments.v),"'","''","all") & "'";
  }
}
