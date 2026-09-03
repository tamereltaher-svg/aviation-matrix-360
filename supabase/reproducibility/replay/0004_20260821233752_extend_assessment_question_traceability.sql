create table if not exists public.question_career_tracks (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.question_bank(id) on delete cascade,
  career_track_id uuid not null references public.career_tracks(id) on delete cascade,
  relevance_weight numeric not null default 1 check (relevance_weight >= 0 and relevance_weight <= 1),
  rationale text,
  created_at timestamptz not null default now(),
  unique(question_id, career_track_id)
);

create table if not exists public.question_references (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.question_bank(id) on delete cascade,
  reference_source_id uuid not null references public.assessment_reference_sources(id) on delete cascade,
  relevance_note text not null,
  created_at timestamptz not null default now(),
  unique(question_id, reference_source_id)
);

alter table public.question_career_tracks enable row level security;
alter table public.question_references enable row level security;
