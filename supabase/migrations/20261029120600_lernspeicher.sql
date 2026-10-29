-- Phase 1 · Migration 7/9 – Lernspeicher für ElementScout (E9)
-- Passend zum vorhandenen Code supabase/functions/_shared/learning-store.ts (Lovable, Commit ed03c8f0):
--   client.from('learning_cases').insert(row)
--   client.from('qualification_patterns').select(...)
--   client.rpc('match_learning_cases', {query_embedding, match_count, min_similarity})
--   client.rpc('bump_qualification_pattern', {p_component_key, p_question_field, p_question})
--   Bucket 'learning-images'
-- supabase-js nutzt das Schema public. Daten liegen deshalb in lern, public stellt nur Sichten
-- und Funktionen bereit – ausschließlich für service_role.
-- Embeddings: google/gemini-embedding-2 mit 3072 Dimensionen → halfvec (HNSW bis 4000 Dimensionen).

create schema if not exists lern;
comment on schema lern is 'Lernfälle aus ElementScout ohne personenbezogene Daten (nur gesalzener Besucher-Hash).';

create table lern.learning_cases (
  id                    uuid primary key default gen_random_uuid(),
  created_at            timestamptz not null default now(),
  source_visitor_hash   text,
  component_name        text,
  category              text,
  din276_code           text,
  component_key         text,
  materials             text[],
  building_details      jsonb not null default '{}',
  user_context          text,
  qualification_qa      jsonb not null default '{}',
  analysis_result       jsonb,
  cost_min              numeric,
  cost_max              numeric,
  cost_status           text,
  image_storage_path    text,
  image_thumb_b64       text,
  image_embedding       extensions.halfvec(3072),
  text_embedding        extensions.halfvec(3072),
  feedback_satisfaction text check (feedback_satisfaction in ('up','down')),
  feedback_message      text,
  quality_score         real
);
create index learning_cases_key_idx on lern.learning_cases (component_key);
create index learning_cases_image_idx on lern.learning_cases using hnsw (image_embedding extensions.halfvec_cosine_ops);
-- Lernfälle bleiben erhalten; nur Feedback und Qualität dürfen nachträglich gesetzt werden.
create trigger learning_cases_nur_feedback before update or delete on lern.learning_cases
  for each row execute function ops.nur_spalten_aenderbar('feedback_satisfaction','feedback_message','quality_score');

create table lern.qualification_patterns (
  id             uuid primary key default gen_random_uuid(),
  component_key  text not null,
  question_field text not null,
  question       jsonb,
  hit_count      int  not null default 0,
  cases_seen     int  not null default 0,
  last_seen_at   timestamptz not null default now(),
  unique (component_key, question_field)
);

-- Sichten in public für supabase-js (einfach, daher einfügbar). security_invoker: es gelten die Rechte des Aufrufers.
create view public.learning_cases with (security_invoker = true) as
  select * from lern.learning_cases;
create view public.qualification_patterns with (security_invoker = true) as
  select * from lern.qualification_patterns;

create or replace function public.match_learning_cases(
  query_embedding text, match_count int default 5, min_similarity double precision default 0.88)
returns table (
  id uuid, component_name text, category text, din276_code text, component_key text,
  cost_min numeric, cost_max numeric, cost_status text, analysis_result jsonb, qualification_qa jsonb,
  feedback_satisfaction text, feedback_message text, quality_score real, similarity double precision)
language sql stable security invoker set search_path = '' as $$
  with q as (select query_embedding::extensions.halfvec(3072) as v)
  select c.id, c.component_name, c.category, c.din276_code, c.component_key,
         c.cost_min, c.cost_max, c.cost_status, c.analysis_result, c.qualification_qa,
         c.feedback_satisfaction, c.feedback_message, c.quality_score,
         1 - (c.image_embedding operator(extensions.<=>) q.v) as similarity
  from lern.learning_cases c, q
  where c.image_embedding is not null
    and 1 - (c.image_embedding operator(extensions.<=>) q.v) >= min_similarity
  order by c.image_embedding operator(extensions.<=>) q.v
  limit greatest(1, least(match_count, 50))
$$;

create or replace function public.bump_qualification_pattern(
  p_component_key text, p_question_field text, p_question jsonb)
returns void language plpgsql security invoker set search_path = '' as $$
begin
  insert into lern.qualification_patterns (component_key, question_field, question, hit_count, last_seen_at)
  values (p_component_key, p_question_field, p_question, 1, now())
  on conflict (component_key, question_field)
  do update set hit_count = lern.qualification_patterns.hit_count + 1,
                question = excluded.question,
                last_seen_at = now();
  -- cases_seen = Zahl der Lernfälle zu diesem Bauteilschlüssel (Basis für die Häufigkeit im Code)
  update lern.qualification_patterns p
     set cases_seen = (select count(*) from lern.learning_cases c where c.component_key = p_component_key)
   where p.component_key = p_component_key;
end $$;

insert into storage.buckets (id, name, public)
values ('learning-images', 'learning-images', false)
on conflict (id) do nothing;
