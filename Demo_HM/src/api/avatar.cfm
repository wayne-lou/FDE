<cfscript>
util = new demo_hm.services.JsonUtil();
try {
  if(cgi.request_method != "POST") util.send({success:true, mode:"avatar_api_ready", message:"POST {persona_id,audio_url,text} to create talking-head avatar through the Python bridge. If no provider is configured, local 2.5D hologram fallback is used."});
  raw = toString(getHttpRequestData().content);
  payload = len(trim(raw)) ? deserializeJSON(raw) : {};
  personaId = val(payload.persona_id ?: 0);
  audioUrl = toString(payload.audio_url ?: "");
  text = toString(payload.text ?: "");
  if(personaId <= 0) util.error("persona_id required",400,"");

  q="";
  cfquery(name="q", datasource="demo_hm") {
    writeOutput("SELECT p.persona_id,p.persona_name,p.reference_photo_url,a.image_url,a.avatar_mode,a.provider_avatar_id FROM hm_personas p LEFT JOIN hm_avatar_profiles a ON a.persona_id=p.persona_id WHERE p.persona_id=" & personaId & " LIMIT 1");
  }
  if(!q.recordCount) util.error("persona not found",404,"");
  row = util.queryToArray(q)[1];
  img = row.image_url ?: row.reference_photo_url ?: "";
  if(!len(img) || !len(audioUrl)) util.send({success:true, mode:"local_photo_avatar", provider:"local_css_avatar", message:"No provider avatar call. Missing uploaded photo or generated cloned audio URL.", image_url:img});

  req = {provider:"did", persona_id:personaId, persona_name:row.persona_name, image_url:img, audio_url:audioUrl, text:text};
  try {
    cfhttp(method="post", url="http://127.0.0.1:8010/avatar", result="httpRes", timeout="180") {
      cfhttpparam(type="header", name="Content-Type", value="application/json");
      cfhttpparam(type="body", value=serializeJSON(req));
    }
    res = deserializeJSON(toString(httpRes.fileContent));
    if(res.success) {
      cfquery(name="upd", datasource="demo_hm") { writeOutput("UPDATE hm_avatar_profiles SET provider_avatar_id=" & sqlString(res.talk_id ?: row.provider_avatar_id ?: "") & ", avatar_mode='talking_photo', updated_at=now() WHERE persona_id=" & personaId); }
      util.send(res);
    }
    util.send({success:true, mode:"local_photo_avatar", provider:"local_css_avatar", warning:(res.error ?: "avatar provider did not return video"), image_url:img});
  } catch(any bridgeErr) {
    util.send({success:true, mode:"local_photo_avatar", provider:"local_css_avatar", warning:"avatar bridge failed: " & bridgeErr.message, image_url:img});
  }
} catch(any e){ util.error("avatar api failed",500,e.message & " / " & e.detail); }
function sqlString(any v=""){
  if(isNull(arguments.v)) return "''";
  return "'" & replace(toString(arguments.v),"'","''","all") & "'";
}
</cfscript>
