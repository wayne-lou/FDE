component output="false" {
  /**
   * Memory RAG engine for demo_hm.
   * It does not just LIKE one keyword. It builds a query profile, expands synonyms,
   * scores every memory chunk by title/summary/transcript/keywords/date/emotion,
   * and returns grounded evidence with match reasons.
   * Optional production upgrade: replace scoreLocal() with pgvector/OpenAI embeddings.
   */
  public struct function search(required numeric persona_id, required string question, numeric limit=5){
    var util = new demo_hm.services.JsonUtil();
    var q = "";
    var pid = val(arguments.persona_id);
    var lim = val(arguments.limit); if(lim <= 0) lim = 5;
    var profile = buildQueryProfile(arguments.question);

    cfquery(name="q", datasource="demo_hm") {
      writeOutput("SELECT c.chunk_id,c.memory_id,c.persona_id,c.chunk_text,c.chunk_summary,c.keywords,m.memory_title,m.memory_date,m.memory_type,m.transcript,m.summary,m.emotion_tag,m.location_text,m.source_channel ");
      writeOutput("FROM hm_memory_chunks c JOIN hm_memory_items m ON m.memory_id=c.memory_id ");
      writeOutput("WHERE c.persona_id = " & pid & " AND m.memory_status='active' ORDER BY m.memory_date DESC NULLS LAST, c.chunk_id ASC");
    }

    var rows = util.queryToArray(q);
    var scored = [];
    for(var r in rows){
      var s = scoreLocal(r, profile);
      if(s.score > 0){
        r.score = s.score;
        r.match_reasons = s.reasons;
        r.evidence_excerpt = makeExcerpt(r, profile);
        r.grounding_level = s.score >= 6 ? "strong" : (s.score >= 3 ? "medium" : "weak");
        arrayAppend(scored, r);
      }
    }
    arraySort(scored, function(a,b){ return int((b.score*1000) - (a.score*1000)); });
    var out = [];
    for(var i=1; i<=min(lim,arrayLen(scored)); i++) arrayAppend(out, scored[i]);
    return {query_profile:profile, evidence:out, evidence_count:arrayLen(out), top_score:arrayLen(out)?out[1].score:0};
  }

  public struct function buildQueryProfile(required string question){
    var q = trim(arguments.question);
    var lq = lcase(q);
    var terms = [];
    var intent = "memory_conversation";
    var focus = "general";
    var emotion = "neutral";

    // Intent
    if(find("记得",q) || find("回忆",q) || find("那天",q) || find("以前",q) || find("照片",q) || find("视频",q) || find("remember",lq)) intent="reminisce";
    if(find("压力",q) || find("难受",q) || find("累",q) || find("焦虑",q) || find("安慰",q) || find("劝",q)) { intent="emotional_support"; emotion="supportive"; }
    if(find("声音",q) || find("说一句",q) || find("voice",lq)) intent="voice_memory";
    if(find("总结",q) || find("家书",q) || find("digest",lq)) intent="family_digest";
    if(find("代替",q) || find("冒充",q) || find("授权",q) || find("身份",q)) intent="safety_review";

    // Focus expansion
    if(find("海洋",q) || find("公园",q) || find("旅行",q) || find("香港",q) || find("ocean",lq)) {
      focus="family_trip"; arrayAppend(terms,"ocean"); arrayAppend(terms,"park"); arrayAppend(terms,"海洋"); arrayAppend(terms,"旅行"); arrayAppend(terms,"香港"); arrayAppend(terms,"children"); arrayAppend(terms,"family");
    }
    if(find("春节",q) || find("吃饭",q) || find("晚饭",q) || find("年夜",q) || find("dinner",lq)) {
      focus="family_dinner"; arrayAppend(terms,"dinner"); arrayAppend(terms,"吃饭"); arrayAppend(terms,"春节"); arrayAppend(terms,"family"); arrayAppend(terms,"rest");
    }
    if(find("工作",q) || find("压力",q) || find("priority",lq) || find("stress",lq)) {
      focus="stress_advice"; arrayAppend(terms,"stress"); arrayAppend(terms,"work"); arrayAppend(terms,"priority"); arrayAppend(terms,"压力"); arrayAppend(terms,"别着急"); arrayAppend(terms,"健康");
    }
    if(find("散步",q) || find("早晨",q) || find("walk",lq)) {
      focus="routine"; arrayAppend(terms,"walk"); arrayAppend(terms,"morning"); arrayAppend(terms,"散步"); arrayAppend(terms,"早餐");
    }
    if(find("狗",q) || find("宠物",q) || find("momo",lq) || find("汪",q)) {
      focus="pet"; arrayAppend(terms,"momo"); arrayAppend(terms,"dog"); arrayAppend(terms,"宠物"); arrayAppend(terms,"home");
    }

    // Generic tokens: keep English words and short Chinese phrases that matter.
    var clean = rereplace(lq, "[^a-z0-9一-龥]+", " ", "all");
    for(var p in listToArray(clean," ")){
      p = trim(p);
      if(len(p)>=2 && !arrayFindNoCase(terms,p)) arrayAppend(terms,p);
    }
    // Common family synonyms
    if(find("爷爷",q) || find("外公",q) || find("grandpa",lq)) { arrayAppend(terms,"grandpa"); arrayAppend(terms,"爷爷"); }
    if(find("孩子",q) || find("儿子",q) || find("boys",lq)) { arrayAppend(terms,"children"); arrayAppend(terms,"boys"); }

    return {raw_question:q,intent:intent,focus:focus,emotion:emotion,terms:dedupe(terms)};
  }

  private struct function scoreLocal(required struct r, required struct profile){
    var hay = lcase((r.memory_title?:"") & " " & (r.chunk_text?:"") & " " & (r.chunk_summary?:"") & " " & (r.keywords?:"") & " " & (r.summary?:"") & " " & (r.transcript?:"") & " " & (r.emotion_tag?:"") & " " & (r.location_text?:""));
    var score = 0.0;
    var reasons = [];
    for(var t in profile.terms){
      if(!len(t)) continue;
      if(find(lcase(t), hay)) { score += len(t)>=4 ? 2.0 : 1.0; arrayAppend(reasons,"matched: " & t); }
    }
    // Focus-specific boosts
    if(profile.focus == "family_trip" && (find("ocean",hay)||find("海洋",hay)||find("trip",hay)||find("旅行",hay))) { score += 3; arrayAppend(reasons,"trip memory boost"); }
    if(profile.focus == "family_dinner" && (find("dinner",hay)||find("吃饭",hay)||find("spring festival",hay)||find("春节",hay))) { score += 3; arrayAppend(reasons,"family dinner boost"); }
    if(profile.focus == "stress_advice" && (find("stress",hay)||find("压力",hay)||find("别着急",hay)||find("priority",hay))) { score += 3; arrayAppend(reasons,"advice/stress boost"); }
    if(profile.focus == "pet" && (find("momo",hay)||find("dog",hay)||find("汪",hay))) { score += 3; arrayAppend(reasons,"pet memory boost"); }
    if(profile.intent == "emotional_support" && (find("advice",hay)||find("健康",hay)||find("rest",hay))) { score += 1.5; arrayAppend(reasons,"supportive evidence"); }
    if(find("happy",hay)||find("warm",hay)||find("calm",hay)) score += .25;
    return {score:score,reasons:reasons};
  }

  private string function makeExcerpt(required struct r, required struct profile){
    var txt = r.chunk_text ?: r.summary ?: "";
    var bestPos = 0;
    for(var t in profile.terms){
      var p = findNoCase(t, txt);
      if(p>0){ bestPos=p; break; }
    }
    if(bestPos>80) return mid(txt, bestPos-60, 320);
    return left(txt, 340);
  }

  private array function dedupe(required array a){
    var seen={}; var out=[];
    for(var x in a){ var k=lcase(trim(x)); if(len(k) && !structKeyExists(seen,k)){ seen[k]=true; arrayAppend(out,trim(x)); } }
    return out;
  }
}
