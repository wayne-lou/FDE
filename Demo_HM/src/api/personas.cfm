<cfscript>
util = new demo_hm.services.JsonUtil();
try {
  cfquery(name="patchAvatar1", datasource="demo_hm"){ writeOutput("ALTER TABLE hm_avatar_profiles ADD COLUMN IF NOT EXISTS model_url VARCHAR(1000)"); }
  cfquery(name="patchAvatar2", datasource="demo_hm"){ writeOutput("ALTER TABLE hm_avatar_profiles ADD COLUMN IF NOT EXISTS provider_avatar_id VARCHAR(255)"); }
  q="";
  cfquery(name="q", datasource="demo_hm"){
    writeOutput("SELECT p.persona_id,p.persona_name,p.relationship,p.gender,p.birth_date,p.reference_photo_url,p.persona_type,p.short_bio,p.speaking_style,p.catchphrases,p.persona_status,a.avatar_color,a.avatar_mode,a.image_url,a.model_url,a.provider_avatar_id,v.voice_label,v.voice_provider,v.voice_clone_status,v.sample_audio_url,v.sample_audio_path,v.pitch,v.speaking_rate FROM hm_personas p LEFT JOIN hm_avatar_profiles a ON a.persona_id=p.persona_id LEFT JOIN hm_voice_profiles v ON v.persona_id=p.persona_id ORDER BY p.persona_id");
  }
  util.send({success:true, rows:util.queryToArray(q)});
} catch(any e){ util.error("personas api failed",500,e.message); }
</cfscript>
