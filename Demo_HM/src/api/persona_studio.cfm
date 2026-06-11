<cfscript>
util = new demo_hm.services.JsonUtil();
action = lcase(url.action ?: form.action ?: "list");
try {
  ensureSchemaPatch();
  ensureAssetsTable();

  if(action == "list") {
    q="";
    cfquery(name="q", datasource="demo_hm") {
      writeOutput("SELECT p.persona_id,p.owner_user_id,p.persona_name,p.relationship,p.gender,p.birth_date,p.reference_photo_url,p.persona_type,p.short_bio,p.speaking_style,p.catchphrases,p.consent_status,p.persona_status,p.created_at,p.updated_at,a.avatar_id,a.avatar_mode,a.avatar_color,a.image_url,a.model_url,a.provider_avatar_id,a.motion_profile,a.avatar_status,v.voice_id,v.voice_provider,v.voice_clone_status,v.voice_label,v.sample_audio_url,v.sample_audio_path,v.pitch,v.speaking_rate,v.voice_status FROM hm_personas p LEFT JOIN hm_avatar_profiles a ON a.persona_id=p.persona_id LEFT JOIN hm_voice_profiles v ON v.persona_id=p.persona_id ORDER BY p.persona_id DESC");
    }
    util.send({success:true, rows:util.queryToArray(q)});
  }

  if(action == "metaperson_config") {
    cid = getEnv("METAPERSON_CLIENT_ID");
    sec = getEnv("METAPERSON_CLIENT_SECRET");
    // Fallback to application scope if the user prefers setting these in Application.cfc / server context.
    if(!len(cid) && structKeyExists(application,"metapersonClientId")) cid = toString(application.metapersonClientId);
    if(!len(sec) && structKeyExists(application,"metapersonClientSecret")) sec = toString(application.metapersonClientSecret);
    util.send({success:true, configured:(len(cid)>0 && len(sec)>0), client_id:cid, client_secret:sec, client_id_prefix:(len(cid)>6 ? left(cid,6) & "..." : cid)});
  }

  if(action == "assets") {
    personaId = val(url.persona_id ?: 0);
    q="";
    cfquery(name="q", datasource="demo_hm") { writeOutput("SELECT asset_id,persona_id,asset_type,file_url,file_name,mime_type,is_active,created_at FROM hm_persona_assets WHERE persona_id=" & personaId & " ORDER BY asset_id DESC"); }
    util.send({success:true, rows:util.queryToArray(q)});
  }

  if(action == "save") {
    raw = toString(getHttpRequestData().content);
    data = deserializeJSON(raw);
    id = val(data.persona_id ?: 0);
    owner = val(data.owner_user_id ?: 1);
    name = trim(toString(data.persona_name ?: ""));
    rel = trim(toString(data.relationship ?: "family"));
    if(!len(name)) util.error("persona_name required",400,"");
    gender = normalizeEnum(data.gender ?: "unknown", "male,female,pet,unknown", "unknown");
    ptype = normalizeEnum(data.persona_type ?: "family", "family,friend,pet,self_archive", "family");
    status = normalizeEnum(data.persona_status ?: "active", "active,inactive,archived", "active");
    bdate = trim(toString(data.birth_date ?: ""));
    bio = toString(data.short_bio ?: "");
    style = toString(data.speaking_style ?: "");
    catchp = toString(data.catchphrases ?: "");

    if(id > 0) {
      sql = "UPDATE hm_personas SET owner_user_id=" & owner & ", persona_name=" & sqlString(name) & ", relationship=" & sqlString(rel) & ", gender=" & sqlString(gender) & ", birth_date=" & sqlDate(bdate) & ", persona_type=" & sqlString(ptype) & ", short_bio=" & sqlString(bio) & ", speaking_style=" & sqlString(style) & ", catchphrases=" & sqlString(catchp) & ", persona_status=" & sqlString(status) & ", updated_at=now() WHERE persona_id=" & id;
      cfquery(name="uq", datasource="demo_hm") { writeOutput(sql); }
    } else {
      sql = "INSERT INTO hm_personas(owner_user_id,persona_name,relationship,gender,birth_date,persona_type,short_bio,speaking_style,catchphrases,consent_status,persona_status) VALUES(" & owner & "," & sqlString(name) & "," & sqlString(rel) & "," & sqlString(gender) & "," & sqlDate(bdate) & "," & sqlString(ptype) & "," & sqlString(bio) & "," & sqlString(style) & "," & sqlString(catchp) & ",'demo_sanitized'," & sqlString(status) & ") RETURNING persona_id";
      cfquery(name="iq", datasource="demo_hm") { writeOutput(sql); }
      id = iq.persona_id[1];
      cfquery(name="av", datasource="demo_hm") { writeOutput("INSERT INTO hm_avatar_profiles(persona_id,avatar_mode,avatar_color,motion_profile,avatar_status) VALUES(" & id & ",'hologram_3d','##43f4ff','calm','active')"); }
      cfquery(name="vv", datasource="demo_hm") { writeOutput("INSERT INTO hm_voice_profiles(persona_id,voice_provider,voice_clone_status,voice_label,pitch,speaking_rate,voice_status) VALUES(" & id & ",'browser_tts','not_trained'," & sqlString(name & " default voice") & "," & sqlString(gender == "male" ? "low" : "medium") & ",'normal','active')"); }
    }
    ensureProfiles(id, name, gender);
    util.send({success:true,message:"Persona saved",persona_id:id});
  }

  if(action == "upload") {
    personaId = val(form.persona_id ?: 0);
    assetType = lcase(form.asset_type ?: "");
    if(personaId <= 0) util.error("persona_id required",400,"");
    if(!listFindNoCase("photo,voice", assetType)) util.error("asset_type must be photo or voice",400,assetType);
    if(!structKeyExists(form,"upload_file") || !len(toString(form.upload_file))) util.error("upload_file required",400,"");

    folder = assetType == "photo" ? "photos" : "voices";
    baseDir = expandPath("../uploads/personas/" & personaId & "/" & folder & "/");
    if(!directoryExists(baseDir)) directoryCreate(baseDir,true);
    accept = assetType == "photo" ? "image/jpeg,image/png,image/webp,image/gif" : "audio/mpeg,audio/mp3,audio/wav,audio/x-wav,audio/mp4,audio/m4a,audio/aac,audio/webm";
    cffile(action="upload", fileField="upload_file", destination=baseDir, nameConflict="makeunique", accept=accept, result="upRes");
    fileUrl = "uploads/personas/" & personaId & "/" & folder & "/" & upRes.serverFile;
    fileName = upRes.clientFile;
    mimeType = upRes.contentType & "/" & upRes.contentSubType;

    cfquery(name="insAsset", datasource="demo_hm") { writeOutput("INSERT INTO hm_persona_assets(persona_id,asset_type,file_url,file_name,mime_type,is_active) VALUES(" & personaId & "," & sqlString(assetType) & "," & sqlString(fileUrl) & "," & sqlString(fileName) & "," & sqlString(mimeType) & ",true)"); }
    if(assetType == "photo") {
      cfquery(name="upP", datasource="demo_hm") { writeOutput("UPDATE hm_personas SET reference_photo_url=" & sqlString(fileUrl) & ", updated_at=now() WHERE persona_id=" & personaId); }
      cfquery(name="upA", datasource="demo_hm") { writeOutput("UPDATE hm_avatar_profiles SET image_url=" & sqlString(fileUrl) & ", avatar_mode='photo_card', updated_at=now() WHERE persona_id=" & personaId); }
    } else {
      cfquery(name="upV", datasource="demo_hm") { writeOutput("UPDATE hm_voice_profiles SET voice_provider='minimax', voice_clone_status='sample_uploaded', sample_audio_url=" & sqlString(fileUrl) & ", sample_audio_path=" & sqlString(fileUrl) & ", updated_at=now() WHERE persona_id=" & personaId); }
    }
    util.send({success:true,message:"Asset uploaded",persona_id:personaId,asset_type:assetType,file_url:fileUrl,file_name:fileName,mime_type:mimeType});
  }

  if(action == "save_avatar_model") {
    raw = toString(getHttpRequestData().content);
    data = len(trim(raw)) ? deserializeJSON(raw) : {};
    personaId = val(data.persona_id ?: 0);
    if(personaId <= 0) util.error("persona_id required",400,"");
    modelUrl = trim(toString(data.model_url ?: data.avatar_model_url ?: ""));
    avatarCode = trim(toString(data.provider_avatar_id ?: data.avatar_code ?: ""));
    screenshotUrl = trim(toString(data.screenshot_url ?: ""));
    if(!len(modelUrl) && !len(avatarCode) && !len(screenshotUrl)) util.error("model_url or avatar_code required",400,"");
    ensureProfiles(personaId, "persona", "unknown");
    cfquery(name="upModel", datasource="demo_hm") {
      writeOutput("UPDATE hm_avatar_profiles SET model_url=" & sqlString(modelUrl) & ", provider_avatar_id=" & sqlString(avatarCode) & ", avatar_mode='metaperson_glb', avatar_status='active', updated_at=now() WHERE persona_id=" & personaId);
    }
    if(len(screenshotUrl)) {
      cfquery(name="upShot", datasource="demo_hm") { writeOutput("UPDATE hm_avatar_profiles SET image_url=" & sqlString(screenshotUrl) & ", updated_at=now() WHERE persona_id=" & personaId); }
    }
    util.send({success:true,message:"3D avatar saved",persona_id:personaId,model_url:modelUrl,provider_avatar_id:avatarCode,screenshot_url:screenshotUrl});
  }

  util.error("Unknown action",400,action);
} catch(any e) { util.error("persona studio api failed",500,e.message & " / " & e.detail); }


function ensureSchemaPatch(){
  // Make v7 safe on older demo_hm databases created by v1-v5 SQL.
  cfquery(name="c1", datasource="demo_hm") { writeOutput("ALTER TABLE hm_personas ADD COLUMN IF NOT EXISTS gender VARCHAR(20) NOT NULL DEFAULT 'unknown'"); }
  cfquery(name="c2", datasource="demo_hm") { writeOutput("ALTER TABLE hm_personas ADD COLUMN IF NOT EXISTS birth_date DATE"); }
  cfquery(name="c3", datasource="demo_hm") { writeOutput("ALTER TABLE hm_personas ADD COLUMN IF NOT EXISTS reference_photo_url VARCHAR(500)"); }
  cfquery(name="c4", datasource="demo_hm") { writeOutput("ALTER TABLE hm_voice_profiles ADD COLUMN IF NOT EXISTS sample_audio_path VARCHAR(500)"); }
  cfquery(name="c5", datasource="demo_hm") { writeOutput("ALTER TABLE hm_voice_profiles ADD COLUMN IF NOT EXISTS generated_audio_url VARCHAR(500)"); }
  cfquery(name="c6", datasource="demo_hm") { writeOutput("ALTER TABLE hm_avatar_profiles ADD COLUMN IF NOT EXISTS model_url VARCHAR(1000)"); }
  cfquery(name="c7", datasource="demo_hm") { writeOutput("ALTER TABLE hm_avatar_profiles ADD COLUMN IF NOT EXISTS provider_avatar_id VARCHAR(255)"); }
}

function ensureAssetsTable(){
  cfquery(name="assetTable", datasource="demo_hm") {
    writeOutput("CREATE TABLE IF NOT EXISTS hm_persona_assets ( asset_id SERIAL PRIMARY KEY, persona_id INT NOT NULL REFERENCES hm_personas(persona_id) ON DELETE CASCADE, asset_type VARCHAR(30) NOT NULL, file_url VARCHAR(500) NOT NULL, file_name VARCHAR(240), mime_type VARCHAR(120), is_active BOOLEAN NOT NULL DEFAULT true, created_at TIMESTAMPTZ NOT NULL DEFAULT now() )");
  }
  cfquery(name="assetIdx", datasource="demo_hm") { writeOutput("CREATE INDEX IF NOT EXISTS idx_hm_assets_persona ON hm_persona_assets(persona_id)"); }
}

function ensureProfiles(required numeric id, required string nm, required string gender){
  q1=""; cfquery(name="q1", datasource="demo_hm") { writeOutput("SELECT avatar_id FROM hm_avatar_profiles WHERE persona_id=" & arguments.id & " LIMIT 1"); }
  if(!q1.recordCount) cfquery(name="ia", datasource="demo_hm") { writeOutput("INSERT INTO hm_avatar_profiles(persona_id,avatar_mode,avatar_color,motion_profile,avatar_status) VALUES(" & arguments.id & ",'hologram_3d','##43f4ff','calm','active')"); }
  q2=""; cfquery(name="q2", datasource="demo_hm") { writeOutput("SELECT voice_id FROM hm_voice_profiles WHERE persona_id=" & arguments.id & " LIMIT 1"); }
  if(!q2.recordCount) cfquery(name="iv", datasource="demo_hm") { writeOutput("INSERT INTO hm_voice_profiles(persona_id,voice_provider,voice_clone_status,voice_label,pitch,speaking_rate,voice_status) VALUES(" & arguments.id & ",'browser_tts','not_trained'," & sqlString(arguments.nm & " default voice") & "," & sqlString(arguments.gender == "male" ? "low" : "medium") & ",'normal','active')"); }
}

function normalizeEnum(any v, required string allowed, required string def){
  s = lcase(trim(toString(arguments.v ?: "")));
  return listFindNoCase(arguments.allowed, s) ? s : arguments.def;
}
function sqlString(any v=""){
  if(isNull(arguments.v)) return "NULL";
  return "'" & replace(toString(arguments.v),"'","''","all") & "'";
}
function sqlDate(any v=""){
  s = trim(toString(arguments.v ?: ""));
  if(!len(s)) return "NULL";
  return sqlString(s);
}

function getEnv(required string k){
  try {
    v = createObject("java","java.lang.System").getenv(arguments.k);
    return isNull(v) ? "" : toString(v);
  } catch(any e) { return ""; }
}
</cfscript>
