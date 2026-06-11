INSERT INTO hm_users(display_name,email,user_role,user_status) VALUES
('Wayne Demo Owner','owner@demo-hm.local','owner','active'),
('Family Reviewer','reviewer@demo-hm.local','reviewer','active');

INSERT INTO hm_personas(owner_user_id, persona_name, relationship, gender, birth_date, reference_photo_url, persona_type, short_bio, speaking_style, catchphrases, consent_status) VALUES
(1,'Grandpa Li','grandfather','male','1948-06-18','assets/img/grandpa-placeholder.svg','family','A warm, practical grandfather who likes family dinners, old Beijing stories, and simple advice.','Warm, calm, concise, often uses everyday family language. He answers with memory-grounded details and avoids pretending to know things not in the memories.','别着急; 吃饭了吗; 慢慢来; 家人在就好','demo_sanitized'),
(1,'Momo','family dog','pet',NULL,'assets/img/momo-placeholder.svg','pet','A family dog remembered through short videos, photos, and daily notes.','Playful, simple, affectionate, translated as a pet-style companion voice.','汪; 我在呢; 出去玩吗','demo_sanitized');

INSERT INTO hm_avatar_profiles(persona_id, avatar_mode, avatar_color, image_url, motion_profile) VALUES
(1,'hologram_3d','#43f4ff','assets/img/grandpa-placeholder.svg','calm'),
(2,'pet_orb','#ffd166','assets/img/momo-placeholder.svg','playful');

INSERT INTO hm_voice_profiles(persona_id, voice_provider, voice_clone_status, voice_label, sample_audio_url, sample_audio_path, pitch, speaking_rate) VALUES
(1,'local_xtts','sample_uploaded','Grandpa Li cloned voice sample','uploads/audio/grandpa-sample-demo.txt','uploads/audio/grandpa-sample-demo.txt','low','slow'),
(2,'browser_tts','demo_ready','Playful pet voice','uploads/audio/momo-sample-demo.txt','uploads/audio/momo-sample-demo.txt','high','normal');

INSERT INTO hm_memory_items(persona_id,memory_type,memory_title,memory_date,source_channel,transcript,summary,emotion_tag,location_text,privacy_level) VALUES
(1,'audio','Family dinner before Spring Festival','2026-02-08','phone_recording','Grandpa said: do not rush too much, eat well, family being together is the most important thing. He asked whether everyone had dinner and reminded us to rest earlier.','Grandpa cared about dinner, rest, and family presence during Spring Festival.','warm','Beijing family home','private'),
(1,'chat','Advice after a stressful work day','2026-03-12','wechat_export','You told Grandpa that work was stressful. He replied: 别着急，事情一件一件做，先把最重要的做好。He also said family health matters more than temporary pressure.','Grandpa gave calm advice about prioritization and health during work stress.','supportive','Remote chat','private'),
(1,'photo','Ocean Park family trip memory','2026-07-12','photo_album','Photo note: family visited Ocean Park; everyone was tired but happy. Grandpa laughed at the boys watching sea animals and said this day should be remembered.','Family trip to Ocean Park, happy moment with children and grandfather.','happy','Hong Kong Ocean Park','private'),
(1,'diary','Morning walk routine','2025-11-03','manual_note','Grandpa liked morning walks. He often said walking slowly after breakfast helped him feel clear and relaxed.','Grandpa valued simple routines and morning walks.','calm','Neighborhood park','private'),
(2,'video','Momo waiting by the door','2026-01-18','phone_video','Momo waited near the door and became excited when family came home.','Pet memory: Momo waiting for family and showing excitement.','cute','Home entrance','private');

INSERT INTO hm_memory_chunks(memory_id, persona_id, chunk_index, chunk_text, chunk_summary, keywords) VALUES
(1,1,1,'Grandpa said do not rush too much, eat well, and family being together is the most important thing. He asked whether everyone had dinner and reminded us to rest earlier.','Family dinner care and rest reminder','dinner, rest, family, spring festival, care'),
(2,1,1,'When work was stressful, Grandpa said: 别着急，事情一件一件做，先把最重要的做好。Family health matters more than temporary pressure.','Work stress advice and prioritization','stress, work, priority, health, advice, 别着急'),
(3,1,1,'During the Ocean Park family trip, Grandpa laughed at the boys watching sea animals and said this day should be remembered. Everyone was tired but happy.','Ocean Park happy family memory','Ocean Park, Hong Kong, children, happy, trip'),
(4,1,1,'Grandpa liked morning walks after breakfast because walking slowly helped him feel clear and relaxed.','Morning walking routine','morning walk, breakfast, routine, calm'),
(5,2,1,'Momo waited near the door and became excited when family came home.','Dog waiting memory','dog, door, family, home, excited');


-- v9 additional demo personas for richer default testing
INSERT INTO hm_personas(owner_user_id, persona_name, relationship, gender, birth_date, reference_photo_url, persona_type, short_bio, speaking_style, catchphrases, consent_status) VALUES
(1,'Grandma Wang','grandmother','female','1952-09-02','assets/img/default-female.svg','family','A gentle grandmother who remembers recipes, family calls, and festival details.','Soft, caring, detailed, often asks about meals and health.','吃饭了吗; 多穿点; 别太累','demo_sanitized'),
(1,'Dad Chen','father','male','1975-03-16','assets/img/default-male.svg','family','A practical father who gives concise advice about work, money, and responsibility.','Direct, steady, protective, practical.','先把正事做好; 别慌; 我看看','demo_sanitized'),
(1,'Old Friend Kai','old friend','male','1986-11-23','assets/img/default-friend.svg','friend','A humorous old friend with shared school and travel memories.','Casual, joking, energetic, uses short phrases.','可以啊; 你又来了; 走起','demo_sanitized');

INSERT INTO hm_avatar_profiles(persona_id, avatar_mode, avatar_color, image_url, motion_profile)
SELECT persona_id,'hologram_3d','#ff7ac8','assets/img/default-female.svg','gentle' FROM hm_personas WHERE persona_name='Grandma Wang';
INSERT INTO hm_avatar_profiles(persona_id, avatar_mode, avatar_color, image_url, motion_profile)
SELECT persona_id,'hologram_3d','#43f4ff','assets/img/default-male.svg','steady' FROM hm_personas WHERE persona_name='Dad Chen';
INSERT INTO hm_avatar_profiles(persona_id, avatar_mode, avatar_color, image_url, motion_profile)
SELECT persona_id,'hologram_3d','#72ffb0','assets/img/default-friend.svg','energetic' FROM hm_personas WHERE persona_name='Old Friend Kai';

INSERT INTO hm_voice_profiles(persona_id, voice_provider, voice_clone_status, voice_label, pitch, speaking_rate)
SELECT persona_id,'browser_tts','demo_ready','Female fallback voice','medium','slow' FROM hm_personas WHERE persona_name='Grandma Wang';
INSERT INTO hm_voice_profiles(persona_id, voice_provider, voice_clone_status, voice_label, pitch, speaking_rate)
SELECT persona_id,'browser_tts','demo_ready','Male fallback voice','low','normal' FROM hm_personas WHERE persona_name='Dad Chen';
INSERT INTO hm_voice_profiles(persona_id, voice_provider, voice_clone_status, voice_label, pitch, speaking_rate)
SELECT persona_id,'browser_tts','demo_ready','Male friend fallback voice','low','normal' FROM hm_personas WHERE persona_name='Old Friend Kai';

INSERT INTO hm_memory_items(persona_id,memory_type,memory_title,memory_date,source_channel,transcript,summary,emotion_tag,location_text,privacy_level)
SELECT persona_id,'audio','Grandma dumpling recipe call','2026-01-28','phone_recording','Grandma explained how to make dumplings and reminded everyone not to stay up too late before Spring Festival.','Grandma recipe and family care memory.','warm','Family kitchen','private' FROM hm_personas WHERE persona_name='Grandma Wang';
INSERT INTO hm_memory_chunks(memory_id, persona_id, chunk_index, chunk_text, chunk_summary, keywords)
SELECT m.memory_id,m.persona_id,1,'Grandma explained dumpling steps and said: 吃饭了吗，多穿点，别太累。','Grandma food and care memory','grandma, dumplings, food, care, festival' FROM hm_memory_items m WHERE m.memory_title='Grandma dumpling recipe call';

INSERT INTO hm_memory_items(persona_id,memory_type,memory_title,memory_date,source_channel,transcript,summary,emotion_tag,location_text,privacy_level)
SELECT persona_id,'chat','Dad advice before job interview','2026-05-20','wechat_export','Dad said: 别慌，先把正事做好。Prepare the key points, speak clearly, and do not overthink the result.','Father practical interview advice.','supportive','Remote chat','private' FROM hm_personas WHERE persona_name='Dad Chen';
INSERT INTO hm_memory_chunks(memory_id, persona_id, chunk_index, chunk_text, chunk_summary, keywords)
SELECT m.memory_id,m.persona_id,1,'Dad said: 别慌，先把正事做好。Prepare key points, speak clearly, and do not overthink the result.','Dad practical advice memory','dad, interview, advice, work, calm' FROM hm_memory_items m WHERE m.memory_title='Dad advice before job interview';
