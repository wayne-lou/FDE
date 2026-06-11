<cfscript>
util = new demo_hm.services.JsonUtil();
try {
  stats={};
  cfquery(name="p", datasource="demo_hm"){ writeOutput("SELECT count(*) c FROM hm_personas WHERE persona_status='active'"); }
  cfquery(name="m", datasource="demo_hm"){ writeOutput("SELECT count(*) c FROM hm_memory_items WHERE memory_status='active'"); }
  cfquery(name="c", datasource="demo_hm"){ writeOutput("SELECT count(*) c FROM hm_memory_chunks"); }
  cfquery(name="v", datasource="demo_hm"){ writeOutput("SELECT count(*) c FROM hm_voice_profiles WHERE voice_status='active'"); }
  cfquery(name="recent", datasource="demo_hm"){
    writeOutput("SELECT memory_id,memory_title,memory_type,memory_date,emotion_tag,summary FROM hm_memory_items WHERE memory_status='active' ORDER BY memory_date DESC NULLS LAST, memory_id DESC LIMIT 5");
  }
  stats.personas=p.c[1]; stats.memories=m.c[1]; stats.chunks=c.c[1]; stats.voices=v.c[1];
  util.send({success:true, stats:stats, recent:util.queryToArray(recent)});
} catch(any e){ util.error("dashboard api failed",500,e.message); }
</cfscript>
