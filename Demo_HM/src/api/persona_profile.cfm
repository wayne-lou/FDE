<cfscript>
util = new demo_hm.services.JsonUtil();
try {
  if(cgi.request_method != "POST") util.send({success:true,message:"POST multipart form: persona_id, photo_file, voice_file"});
  personaId = val(form.persona_id ?: 0);
  if(personaId <= 0) util.error("persona_id required",400,"");

  baseDir = expandPath("../uploads/personas/" & personaId & "/");
  if(!directoryExists(baseDir)) directoryCreate(baseDir,true);
  webBase = "uploads/personas/" & personaId & "/";
  photoUrl=""; voiceUrl=""; voicePath="";

  if(structKeyExists(form,"photo_file") && len(toString(form.photo_file))) {
    cffile(action="upload", fileField="photo_file", destination=baseDir, nameConflict="makeunique", accept="image/jpeg,image/png,image/webp,image/gif", result="photoRes");
    photoUrl = webBase & photoRes.serverFile;
    cfquery(name="up1", datasource="demo_hm") { writeOutput("UPDATE hm_personas SET reference_photo_url=" & sqlString(photoUrl) & ", updated_at=now() WHERE persona_id=" & personaId); }
    cfquery(name="up2", datasource="demo_hm") { writeOutput("UPDATE hm_avatar_profiles SET image_url=" & sqlString(photoUrl) & ", avatar_mode='photo_card', updated_at=now() WHERE persona_id=" & personaId); }
  }

  if(structKeyExists(form,"voice_file") && len(toString(form.voice_file))) {
    cffile(action="upload", fileField="voice_file", destination=baseDir, nameConflict="makeunique", accept="audio/mpeg,audio/mp3,audio/wav,audio/x-wav,audio/mp4,audio/m4a,audio/aac,audio/webm", result="voiceRes");
    voiceUrl = webBase & voiceRes.serverFile;
    voicePath = voiceUrl;
    cfquery(name="vq", datasource="demo_hm") { writeOutput("SELECT voice_id FROM hm_voice_profiles WHERE persona_id=" & personaId & " LIMIT 1"); }
    if(vq.recordCount) {
      cfquery(name="uv", datasource="demo_hm") { writeOutput("UPDATE hm_voice_profiles SET voice_provider='local_xtts', voice_clone_status='sample_uploaded', sample_audio_url=" & sqlString(voiceUrl) & ", sample_audio_path=" & sqlString(voicePath) & ", updated_at=now() WHERE persona_id=" & personaId); }
    } else {
      cfquery(name="iv", datasource="demo_hm") { writeOutput("INSERT INTO hm_voice_profiles(persona_id,voice_provider,voice_clone_status,voice_label,sample_audio_url,sample_audio_path) VALUES(" & personaId & ",'local_xtts','sample_uploaded','Uploaded clone sample'," & sqlString(voiceUrl) & "," & sqlString(voicePath) & ")"); }
    }
  }

  util.send({success:true,message:"Profile assets saved",persona_id:personaId,photo_url:photoUrl,voice_url:voiceUrl});
} catch(any e){ util.error("profile upload failed",500,e.message & " / " & e.detail); }

function sqlString(any v=""){
  if(isNull(arguments.v)) return "''";
  return "'" & replace(toString(arguments.v),"'","''","all") & "'";
}
</cfscript>
