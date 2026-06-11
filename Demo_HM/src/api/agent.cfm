<cfscript>
util = new demo_hm.services.JsonUtil();
try {
  if(cgi.request_method == "POST") raw = toString(getHttpRequestData().content); else raw = "";
  payload = len(trim(raw)) ? deserializeJSON(raw) : {};
  personaId = val(payload.persona_id ?: 1);
  userId = val(payload.user_id ?: 1);
  question = trim(payload.question ?: "你还记得我们一家去海洋公园那天吗？");
  agent = new demo_hm.services.AgentService();
  result = agent.run(personaId,userId,question);
  util.send(result);
} catch(any e){ util.error("agent api failed",500,e.message & " / " & e.detail); }
</cfscript>
