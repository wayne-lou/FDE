-- HoloMemory AI demo schema
-- Database name: demo_hm
-- PostgreSQL 13+

CREATE EXTENSION IF NOT EXISTS pgcrypto;

DROP TABLE IF EXISTS hm_agent_steps CASCADE;
DROP TABLE IF EXISTS hm_agent_tasks CASCADE;
DROP TABLE IF EXISTS hm_rag_retrievals CASCADE;
DROP TABLE IF EXISTS hm_messages CASCADE;
DROP TABLE IF EXISTS hm_conversations CASCADE;
DROP TABLE IF EXISTS hm_memory_chunks CASCADE;
DROP TABLE IF EXISTS hm_memory_items CASCADE;
DROP TABLE IF EXISTS hm_voice_profiles CASCADE;
DROP TABLE IF EXISTS hm_avatar_profiles CASCADE;
DROP TABLE IF EXISTS hm_personas CASCADE;
DROP TABLE IF EXISTS hm_users CASCADE;
DROP TABLE IF EXISTS hm_audit_logs CASCADE;

CREATE TABLE hm_users (
  user_id SERIAL PRIMARY KEY,
  display_name VARCHAR(120) NOT NULL,
  email VARCHAR(180) UNIQUE NOT NULL,
  user_role VARCHAR(40) NOT NULL DEFAULT 'owner',
  user_status VARCHAR(30) NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE hm_personas (
  persona_id SERIAL PRIMARY KEY,
  owner_user_id INT NOT NULL REFERENCES hm_users(user_id),
  persona_name VARCHAR(120) NOT NULL,
  relationship VARCHAR(80) NOT NULL,
  gender VARCHAR(20) NOT NULL DEFAULT 'unknown', -- male, female, unknown, pet
  birth_date DATE,
  reference_photo_url VARCHAR(500),
  persona_type VARCHAR(40) NOT NULL DEFAULT 'family', -- family, friend, pet, self_archive
  short_bio TEXT,
  speaking_style TEXT,
  catchphrases TEXT,
  consent_status VARCHAR(40) NOT NULL DEFAULT 'demo_sanitized',
  persona_status VARCHAR(30) NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_hm_personas_owner ON hm_personas(owner_user_id);
CREATE INDEX idx_hm_personas_status ON hm_personas(persona_status);

CREATE TABLE hm_avatar_profiles (
  avatar_id SERIAL PRIMARY KEY,
  persona_id INT NOT NULL REFERENCES hm_personas(persona_id) ON DELETE CASCADE,
  avatar_mode VARCHAR(40) NOT NULL DEFAULT 'hologram_3d', -- hologram_3d, photo_card, pet_orb
  avatar_color VARCHAR(20) NOT NULL DEFAULT '#43f4ff',
  model_url VARCHAR(500),
  image_url VARCHAR(500),
  motion_profile VARCHAR(40) NOT NULL DEFAULT 'calm',
  avatar_status VARCHAR(30) NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_hm_avatar_persona ON hm_avatar_profiles(persona_id);

CREATE TABLE hm_voice_profiles (
  voice_id SERIAL PRIMARY KEY,
  persona_id INT NOT NULL REFERENCES hm_personas(persona_id) ON DELETE CASCADE,
  voice_provider VARCHAR(60) NOT NULL DEFAULT 'browser_tts', -- browser_tts, local_xtts, elevenlabs, cartesia, azure, minimax, fish_audio
  voice_clone_status VARCHAR(40) NOT NULL DEFAULT 'not_trained', -- not_trained, sample_uploaded, training, local_ready, provider_ready, failed
  voice_label VARCHAR(120) NOT NULL,
  sample_audio_url VARCHAR(500),
  sample_audio_path VARCHAR(500),
  provider_voice_id VARCHAR(200),
  generated_audio_url VARCHAR(500),
  pitch VARCHAR(30) NOT NULL DEFAULT 'medium',
  speaking_rate VARCHAR(30) NOT NULL DEFAULT 'normal',
  voice_status VARCHAR(30) NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_hm_voice_persona ON hm_voice_profiles(persona_id);

CREATE TABLE hm_memory_items (
  memory_id SERIAL PRIMARY KEY,
  persona_id INT NOT NULL REFERENCES hm_personas(persona_id) ON DELETE CASCADE,
  memory_type VARCHAR(40) NOT NULL, -- chat, audio, photo, video, diary, event, note
  memory_title VARCHAR(220) NOT NULL,
  memory_date DATE,
  source_channel VARCHAR(80) DEFAULT 'manual_upload',
  original_url VARCHAR(500),
  transcript TEXT,
  summary TEXT,
  emotion_tag VARCHAR(60),
  location_text VARCHAR(180),
  privacy_level VARCHAR(40) NOT NULL DEFAULT 'private',
  memory_status VARCHAR(30) NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_hm_memory_persona ON hm_memory_items(persona_id);
CREATE INDEX idx_hm_memory_type ON hm_memory_items(memory_type);
CREATE INDEX idx_hm_memory_date ON hm_memory_items(memory_date);
CREATE INDEX idx_hm_memory_text ON hm_memory_items USING gin(to_tsvector('simple', coalesce(memory_title,'') || ' ' || coalesce(transcript,'') || ' ' || coalesce(summary,'')));

CREATE TABLE hm_memory_chunks (
  chunk_id SERIAL PRIMARY KEY,
  memory_id INT NOT NULL REFERENCES hm_memory_items(memory_id) ON DELETE CASCADE,
  persona_id INT NOT NULL REFERENCES hm_personas(persona_id) ON DELETE CASCADE,
  chunk_index INT NOT NULL DEFAULT 1,
  chunk_text TEXT NOT NULL,
  chunk_summary TEXT,
  keywords TEXT,
  embedding_json TEXT, -- demo stores optional provider embeddings as JSON text
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_hm_chunk_persona ON hm_memory_chunks(persona_id);
CREATE INDEX idx_hm_chunk_memory ON hm_memory_chunks(memory_id);
CREATE INDEX idx_hm_chunk_text ON hm_memory_chunks USING gin(to_tsvector('simple', coalesce(chunk_text,'') || ' ' || coalesce(keywords,'')));

CREATE TABLE hm_conversations (
  conversation_id SERIAL PRIMARY KEY,
  persona_id INT NOT NULL REFERENCES hm_personas(persona_id),
  user_id INT NOT NULL REFERENCES hm_users(user_id),
  conversation_title VARCHAR(220) NOT NULL DEFAULT 'Memory conversation',
  conversation_status VARCHAR(30) NOT NULL DEFAULT 'open',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_hm_conv_persona ON hm_conversations(persona_id);

CREATE TABLE hm_messages (
  message_id SERIAL PRIMARY KEY,
  conversation_id INT NOT NULL REFERENCES hm_conversations(conversation_id) ON DELETE CASCADE,
  sender_type VARCHAR(30) NOT NULL, -- user, persona_agent, system
  message_text TEXT NOT NULL,
  retrieved_context TEXT,
  voice_output_url VARCHAR(500),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_hm_msg_conv ON hm_messages(conversation_id);

CREATE TABLE hm_rag_retrievals (
  retrieval_id SERIAL PRIMARY KEY,
  conversation_id INT REFERENCES hm_conversations(conversation_id) ON DELETE SET NULL,
  persona_id INT NOT NULL REFERENCES hm_personas(persona_id),
  question_text TEXT NOT NULL,
  chunk_id INT REFERENCES hm_memory_chunks(chunk_id),
  score NUMERIC(8,4) NOT NULL DEFAULT 0,
  evidence_excerpt TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_hm_rag_persona ON hm_rag_retrievals(persona_id);

CREATE TABLE hm_agent_tasks (
  agent_task_id SERIAL PRIMARY KEY,
  persona_id INT NOT NULL REFERENCES hm_personas(persona_id),
  user_id INT NOT NULL REFERENCES hm_users(user_id),
  input_goal TEXT NOT NULL,
  agent_mode VARCHAR(60) NOT NULL DEFAULT 'memory_conversation', -- memory_conversation, reminisce, family_digest, safety_review
  risk_level VARCHAR(40) NOT NULL DEFAULT 'low',
  agent_summary TEXT,
  recommended_response TEXT,
  agent_status VARCHAR(40) NOT NULL DEFAULT 'completed',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_hm_agent_persona ON hm_agent_tasks(persona_id);

CREATE TABLE hm_agent_steps (
  agent_step_id SERIAL PRIMARY KEY,
  agent_task_id INT NOT NULL REFERENCES hm_agent_tasks(agent_task_id) ON DELETE CASCADE,
  step_order INT NOT NULL,
  step_type VARCHAR(50) NOT NULL, -- intent, rag, style, safety, response, voice, avatar
  step_title VARCHAR(180) NOT NULL,
  step_detail TEXT,
  step_status VARCHAR(40) NOT NULL DEFAULT 'completed',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_hm_steps_task ON hm_agent_steps(agent_task_id);

CREATE TABLE hm_audit_logs (
  audit_log_id SERIAL PRIMARY KEY,
  actor_user_id INT REFERENCES hm_users(user_id),
  entity_type VARCHAR(80) NOT NULL,
  entity_id INT,
  action_name VARCHAR(80) NOT NULL,
  action_detail TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_hm_audit_entity ON hm_audit_logs(entity_type, entity_id);

CREATE TABLE IF NOT EXISTS hm_persona_assets (
  asset_id SERIAL PRIMARY KEY,
  persona_id INT NOT NULL REFERENCES hm_personas(persona_id) ON DELETE CASCADE,
  asset_type VARCHAR(30) NOT NULL,
  file_url VARCHAR(500) NOT NULL,
  file_name VARCHAR(240),
  mime_type VARCHAR(120),
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_hm_assets_persona ON hm_persona_assets(persona_id);
