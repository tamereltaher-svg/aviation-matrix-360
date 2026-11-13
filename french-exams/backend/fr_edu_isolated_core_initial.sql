create schema if not exists fr_edu;

revoke all on schema fr_edu from public, anon, authenticated;

grant usage on schema fr_edu to service_role;

create table if not exists fr_edu.stages(
 code text primary key,
 title_fr text not null,
 sort_order smallint not null unique,
 created_at timestamptz not null default now()
);

create table if not exists fr_edu.grades(
 code text primary key,
 stage_code text not null references fr_edu.stages(code),
 title_fr text not null,
 school_order smallint not null unique,
 created_at timestamptz not null default now()
);

create index if not exists fr_grades_stage_idx on fr_edu.grades(stage_code);

create table if not exists fr_edu.topics(
 code text primary key,
 title_fr text not null,
 content_status text not null default 'review_required' check(content_status in ('review_required','approved','retired')),
 created_at timestamptz not null default now()
);

create table if not exists fr_edu.grade_topics(
 grade_code text not null references fr_edu.grades(code),
 topic_code text not null references fr_edu.topics(code),
 approval_status text not null default 'draft' check(approval_status in ('draft','approved','rejected')),
 approved_by uuid references auth.users(id),
 approved_at timestamptz,
 primary key(grade_code,topic_code),
 check ((approval_status <> 'approved') or (approved_by is not null and approved_at is not null))
);

create table if not exists fr_edu.units(
 id uuid primary key default gen_random_uuid(),
 topic_code text not null references fr_edu.topics(code),
 unit_key text not null unique,
 title_fr text not null,
 position smallint not null check(position >= 1),
 status text not null default 'draft' check(status in ('draft','review','published','retired')),
 created_at timestamptz not null default now()
);

create table if not exists fr_edu.unit_grades(
 unit_id uuid not null references fr_edu.units(id) on delete cascade,
 grade_code text not null references fr_edu.grades(code),
 approved_at timestamptz,
 approved_by uuid references auth.users(id),
 primary key(unit_id,grade_code),
 check((approved_at is null and approved_by is null) or (approved_at is not null and approved_by is not null))
);

create table if not exists fr_edu.lexemes(
 id uuid primary key default gen_random_uuid(),
 topic_code text not null references fr_edu.topics(code),
 canonical_fr text not null,
 visual_type text not null check(visual_type in ('color','number','letter','shape','emoji')),
 visual_value text not null,
 missing_index smallint,
 source_key text not null default 'demo_2026_11',
 content_status text not null default 'review_required' check(content_status in ('review_required','approved','retired')),
 created_at timestamptz not null default now(),
 unique(topic_code,canonical_fr),
 check(missing_index is null or missing_index >= 0)
);

create index if not exists fr_lexemes_topic_idx on fr_edu.lexemes(topic_code);

create table if not exists fr_edu.questions(
 code text primary key,
 topic_code text not null references fr_edu.topics(code),
 prompt_fr text not null,
 question_type text not null check(question_type in ('choose','write','letter','match','audio')),
 source_text text,
 review_status text not null default 'review_required' check(review_status in ('review_required','approved','retired')),
 created_at timestamptz not null default now()
);

create table if not exists fr_edu.question_options(
 question_code text not null references fr_edu.questions(code) on delete cascade,
 option_number smallint not null check(option_number between 1 and 8),
 option_text text not null,
 primary key(question_code,option_number)
);

create table if not exists fr_edu.question_keys(
 question_code text primary key references fr_edu.questions(code) on delete cascade,
 accepted_answers text[] not null default '{}'::text[],
 auto_gradable boolean not null default false,
 review_note text,
 check(not auto_gradable or cardinality(accepted_answers) > 0)
);

create table if not exists fr_edu.assessments(
 code text primary key,
 title_fr text not null,
 question_count smallint not null check(question_count between 1 and 200),
 max_attempts smallint not null default 3 check(max_attempts between 1 and 3),
 score_policy text not null default 'automatic' check(score_policy in ('automatic','partial_review','manual')),
 status text not null default 'draft' check(status in ('draft','approved','published','retired')),
 source_key text not null default 'prototype_2026_11',
 created_at timestamptz not null default now()
);

create table if not exists fr_edu.assessment_pool(
 assessment_code text not null references fr_edu.assessments(code) on delete cascade,
 topic_code text not null references fr_edu.topics(code),
 mode text not null check(mode in ('choose','write','letter')),
 question_count smallint not null check(question_count between 1 and 200),
 primary key(assessment_code,topic_code,mode)
);

create table if not exists fr_edu.assessment_questions(
 assessment_code text not null references fr_edu.assessments(code) on delete cascade,
 question_code text not null references fr_edu.questions(code),
 position smallint not null check(position > 0),
 points smallint not null default 1 check(points between 1 and 10),
 primary key(assessment_code,position),
 unique(assessment_code,question_code)
);

create table if not exists fr_edu.assessment_grades(
 assessment_code text not null references fr_edu.assessments(code) on delete cascade,
 grade_code text not null references fr_edu.grades(code),
 approval_status text not null default 'draft' check(approval_status in ('draft','approved','rejected')),
 approved_by uuid references auth.users(id),
 approved_at timestamptz,
 primary key(assessment_code,grade_code),
 check ((approval_status <> 'approved') or (approved_at is not null and approved_by is not null))
);

create table if not exists fr_edu.profiles(
 user_id uuid primary key references auth.users(id) on delete cascade,
 display_name text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);

create table if not exists fr_edu.user_roles(
 user_id uuid not null references auth.users(id) on delete cascade,
 role_name text not null check(role_name in ('student','teacher','admin')),
 assigned_by uuid references auth.users(id),
 assigned_at timestamptz not null default now(),
 primary key(user_id,role_name)
);

create table if not exists fr_edu.guardian_consents(
 id uuid primary key default gen_random_uuid(),
 learner_user_id uuid not null references auth.users(id) on delete cascade,
 guardian_user_id uuid not null references auth.users(id),
 consent_version text not null,
 granted_at timestamptz not null default now(),
 revoked_at timestamptz,
 evidence_reference text,
 check(guardian_user_id <> learner_user_id)
);

create table if not exists fr_edu.attempts(
 id uuid primary key default gen_random_uuid(),
 student_user_id uuid not null references auth.users(id) on delete cascade,
 assessment_code text not null references fr_edu.assessments(code),
 attempt_number smallint not null check(attempt_number between 1 and 3),
 state text not null default 'in_progress' check(state in ('in_progress','submitted','scored','review_required','void')),
 auto_score numeric(7,2),
 maximum_score numeric(7,2),
 started_at timestamptz not null default now(),
 submitted_at timestamptz,
 review_completed_at timestamptz,
 unique(student_user_id,assessment_code,attempt_number),
 check(auto_score is null or auto_score >= 0),
 check(maximum_score is null or maximum_score >= 0),
 check(auto_score is null or maximum_score is null or auto_score <= maximum_score)
);

create index if not exists fr_attempts_by_student_idx on fr_edu.attempts(student_user_id,started_at desc);

create table if not exists fr_edu.responses(
 attempt_id uuid not null references fr_edu.attempts(id) on delete cascade,
 display_order smallint not null check(display_order between 1 and 200),
 question_code text references fr_edu.questions(code),
 lexeme_id uuid references fr_edu.lexemes(id),
 answer_mode text not null check(answer_mode in ('choose','write','letter','match','audio')),
 answer_value text,
 score numeric(6,2),
 requires_review boolean not null default false,
 checked_at timestamptz,
 primary key(attempt_id,display_order),
 check((question_code is not null) <> (lexeme_id is not null)),
 check(score is null or score >= 0)
);

create table if not exists fr_edu.audit_events(
 id bigint generated always as identity primary key,
 actor_user_id uuid references auth.users(id),
 event_code text not null,
 object_kind text not null,
 object_id text,
 context jsonb not null default '{}'::jsonb,
 occurred_at timestamptz not null default now()
);

alter table fr_edu.stages enable row level security;

alter table fr_edu.grades enable row level security;

alter table fr_edu.topics enable row level security;

alter table fr_edu.grade_topics enable row level security;

alter table fr_edu.units enable row level security;

alter table fr_edu.unit_grades enable row level security;

alter table fr_edu.lexemes enable row level security;

alter table fr_edu.questions enable row level security;

alter table fr_edu.question_options enable row level security;

alter table fr_edu.question_keys enable row level security;

alter table fr_edu.assessments enable row level security;

alter table fr_edu.assessment_pool enable row level security;

alter table fr_edu.assessment_questions enable row level security;

alter table fr_edu.assessment_grades enable row level security;

alter table fr_edu.profiles enable row level security;

alter table fr_edu.user_roles enable row level security;

alter table fr_edu.guardian_consents enable row level security;

alter table fr_edu.attempts enable row level security;

alter table fr_edu.responses enable row level security;

alter table fr_edu.audit_events enable row level security;

revoke all on all tables in schema fr_edu from public, anon, authenticated;

revoke all on all sequences in schema fr_edu from public, anon, authenticated;

grant select, insert, update, delete on all tables in schema fr_edu to service_role;

grant usage, select on all sequences in schema fr_edu to service_role;

alter default privileges in schema fr_edu revoke all on tables from public, anon, authenticated;

alter default privileges in schema fr_edu revoke all on sequences from public, anon, authenticated;

alter default privileges in schema fr_edu grant select, insert, update, delete on tables to service_role;

alter default privileges in schema fr_edu grant usage, select on sequences to service_role;

insert into fr_edu.stages(code,title_fr,sort_order) values
('maternelle','Maternelle','1'),
('primaire','Primaire','2'),
('preparatoire','Préparatoire','3'),
('secondaire','Secondaire','4') on conflict(code) do nothing;

insert into fr_edu.grades(code,stage_code,title_fr,school_order) values
('kg1','maternelle','KG1','1'),
('kg2','maternelle','KG2','2'),
('p1','primaire','1re année primaire','3'),
('p2','primaire','2e année primaire','4'),
('p3','primaire','3e année primaire','5'),
('p4','primaire','4e année primaire','6'),
('p5','primaire','5e année primaire','7'),
('p6','primaire','6e année primaire','8'),
('prep1','preparatoire','1re année préparatoire','9'),
('prep2','preparatoire','2e année préparatoire','10'),
('prep3','preparatoire','3e année préparatoire','11'),
('sec1','secondaire','1re année secondaire','12'),
('sec2','secondaire','2e année secondaire','13'),
('sec3','secondaire','3e année secondaire','14') on conflict(code) do nothing;

insert into fr_edu.topics(code,title_fr) values
('colors','Les Couleurs'),
('numbers','Les Nombres'),
('alphabet','L''Alphabet'),
('shapes','Les Formes'),
('animals','Les Animaux'),
('fruits','Les Fruits'),
('grammar','Grammaire') on conflict(code) do nothing;

insert into fr_edu.lexemes(topic_code,canonical_fr,visual_type,visual_value,missing_index,source_key) values
('colors','Rouge','color','#e53935',1,'french-exams demo November 2026'),
('colors','Bleu','color','#1976d2',2,'french-exams demo November 2026'),
('colors','Vert','color','#43a047',2,'french-exams demo November 2026'),
('colors','Jaune','color','#fdd835',1,'french-exams demo November 2026'),
('colors','Noir','color','#151515',2,'french-exams demo November 2026'),
('colors','Blanc','color','#ffffff',2,'french-exams demo November 2026'),
('colors','Rose','color','#f48fb1',2,'french-exams demo November 2026'),
('colors','Orange','color','#fb8c00',2,'french-exams demo November 2026'),
('colors','Violet','color','#8e44ad',2,'french-exams demo November 2026'),
('colors','Marron','color','#795548',2,'french-exams demo November 2026'),
('numbers','Un','number','1',1,'french-exams demo November 2026'),
('numbers','Deux','number','2',1,'french-exams demo November 2026'),
('numbers','Trois','number','3',2,'french-exams demo November 2026'),
('numbers','Quatre','number','4',2,'french-exams demo November 2026'),
('numbers','Cinq','number','5',2,'french-exams demo November 2026'),
('numbers','Six','number','6',1,'french-exams demo November 2026'),
('numbers','Sept','number','7',2,'french-exams demo November 2026'),
('numbers','Huit','number','8',2,'french-exams demo November 2026'),
('numbers','Neuf','number','9',2,'french-exams demo November 2026'),
('numbers','Dix','number','10',1,'french-exams demo November 2026'),
('alphabet','a','letter','A',NULL,'french-exams demo November 2026'),
('alphabet','b','letter','B',NULL,'french-exams demo November 2026'),
('alphabet','c','letter','C',NULL,'french-exams demo November 2026'),
('alphabet','d','letter','D',NULL,'french-exams demo November 2026'),
('alphabet','e','letter','E',NULL,'french-exams demo November 2026'),
('alphabet','f','letter','F',NULL,'french-exams demo November 2026'),
('alphabet','g','letter','G',NULL,'french-exams demo November 2026'),
('alphabet','h','letter','H',NULL,'french-exams demo November 2026'),
('alphabet','i','letter','I',NULL,'french-exams demo November 2026'),
('alphabet','j','letter','J',NULL,'french-exams demo November 2026'),
('alphabet','k','letter','K',NULL,'french-exams demo November 2026'),
('alphabet','l','letter','L',NULL,'french-exams demo November 2026'),
('alphabet','m','letter','M',NULL,'french-exams demo November 2026'),
('alphabet','n','letter','N',NULL,'french-exams demo November 2026'),
('alphabet','o','letter','O',NULL,'french-exams demo November 2026'),
('alphabet','p','letter','P',NULL,'french-exams demo November 2026'),
('alphabet','q','letter','Q',NULL,'french-exams demo November 2026'),
('alphabet','r','letter','R',NULL,'french-exams demo November 2026'),
('alphabet','s','letter','S',NULL,'french-exams demo November 2026'),
('alphabet','t','letter','T',NULL,'french-exams demo November 2026'),
('alphabet','u','letter','U',NULL,'french-exams demo November 2026'),
('alphabet','v','letter','V',NULL,'french-exams demo November 2026'),
('alphabet','w','letter','W',NULL,'french-exams demo November 2026'),
('alphabet','x','letter','X',NULL,'french-exams demo November 2026'),
('alphabet','y','letter','Y',NULL,'french-exams demo November 2026'),
('alphabet','z','letter','Z',NULL,'french-exams demo November 2026'),
('shapes','Cercle','shape','circle',2,'french-exams demo November 2026'),
('shapes','Carré','shape','square',2,'french-exams demo November 2026'),
('shapes','Triangle','shape','triangle',3,'french-exams demo November 2026'),
('shapes','Rectangle','shape','rectangle',3,'french-exams demo November 2026'),
('shapes','Ovale','shape','oval',2,'french-exams demo November 2026'),
('shapes','Étoile','shape','star',3,'french-exams demo November 2026'),
('shapes','Cœur','shape','heart',2,'french-exams demo November 2026'),
('shapes','Losange','shape','diamond',2,'french-exams demo November 2026'),
('shapes','Pentagone','shape','pentagon',4,'french-exams demo November 2026'),
('shapes','Hexagone','shape','hexagon',3,'french-exams demo November 2026'),
('animals','Chat','emoji','🐈',1,'french-exams demo November 2026'),
('animals','Chien','emoji','🐕',2,'french-exams demo November 2026'),
('animals','Lion','emoji','🦁',2,'french-exams demo November 2026'),
('animals','Éléphant','emoji','🐘',3,'french-exams demo November 2026'),
('animals','Lapin','emoji','🐇',2,'french-exams demo November 2026'),
('animals','Cheval','emoji','🐎',3,'french-exams demo November 2026'),
('animals','Vache','emoji','🐄',2,'french-exams demo November 2026'),
('animals','Mouton','emoji','🐑',3,'french-exams demo November 2026'),
('animals','Poisson','emoji','🐟',3,'french-exams demo November 2026'),
('animals','Oiseau','emoji','🐦',3,'french-exams demo November 2026'),
('fruits','Pomme','emoji','🍎',2,'french-exams demo November 2026'),
('fruits','Banane','emoji','🍌',2,'french-exams demo November 2026'),
('fruits','Orange','emoji','🍊',3,'french-exams demo November 2026'),
('fruits','Fraise','emoji','🍓',3,'french-exams demo November 2026'),
('fruits','Raisin','emoji','🍇',3,'french-exams demo November 2026'),
('fruits','Poire','emoji','🍐',2,'french-exams demo November 2026'),
('fruits','Pastèque','emoji','🍉',3,'french-exams demo November 2026'),
('fruits','Citron','emoji','🍋',3,'french-exams demo November 2026'),
('fruits','Cerise','emoji','🍒',3,'french-exams demo November 2026'),
('fruits','Ananas','emoji','🍍',2,'french-exams demo November 2026')
on conflict(topic_code,canonical_fr) do nothing;

insert into fr_edu.assessments(code,title_fr,question_count,max_attempts,score_policy) values
('fr.colors.choose','Les Couleurs — Choisir','10','3','automatic'),
('fr.colors.write','Les Couleurs — Écrire','10','3','automatic'),
('fr.colors.letter','Les Couleurs — Compléter','10','3','automatic'),
('fr.numbers.choose','Les Nombres — Choisir','10','3','automatic'),
('fr.numbers.write','Les Nombres — Écrire','10','3','automatic'),
('fr.numbers.letter','Les Nombres — Compléter','10','3','automatic'),
('fr.alphabet.choose','L''Alphabet — Choisir','10','3','automatic'),
('fr.alphabet.write','L''Alphabet — Écrire','10','3','automatic'),
('fr.alphabet.letter','L''Alphabet — Compléter','10','3','automatic'),
('fr.shapes.choose','Les Formes — Choisir','10','3','automatic'),
('fr.shapes.write','Les Formes — Écrire','10','3','automatic'),
('fr.shapes.letter','Les Formes — Compléter','10','3','automatic'),
('fr.animals.choose','Les Animaux — Choisir','10','3','automatic'),
('fr.animals.write','Les Animaux — Écrire','10','3','automatic'),
('fr.animals.letter','Les Animaux — Compléter','10','3','automatic'),
('fr.fruits.choose','Les Fruits — Choisir','10','3','automatic'),
('fr.fruits.write','Les Fruits — Écrire','10','3','automatic'),
('fr.fruits.letter','Les Fruits — Compléter','10','3','automatic'),
('fr.general','Examen Général','18','3','automatic'),
('fr.grammar.conjugaison.v1','Grammaire — Choisis la bonne réponse','5','3','partial_review')
on conflict(code) do nothing;

insert into fr_edu.assessment_pool(assessment_code,topic_code,mode,question_count) values
('fr.colors.choose','colors','choose','10'),
('fr.colors.write','colors','write','10'),
('fr.colors.letter','colors','letter','10'),
('fr.numbers.choose','numbers','choose','10'),
('fr.numbers.write','numbers','write','10'),
('fr.numbers.letter','numbers','letter','10'),
('fr.alphabet.choose','alphabet','choose','10'),
('fr.alphabet.write','alphabet','write','10'),
('fr.alphabet.letter','alphabet','letter','10'),
('fr.shapes.choose','shapes','choose','10'),
('fr.shapes.write','shapes','write','10'),
('fr.shapes.letter','shapes','letter','10'),
('fr.animals.choose','animals','choose','10'),
('fr.animals.write','animals','write','10'),
('fr.animals.letter','animals','letter','10'),
('fr.fruits.choose','fruits','choose','10'),
('fr.fruits.write','fruits','write','10'),
('fr.fruits.letter','fruits','letter','10'),
('fr.general','colors','choose','1'),
('fr.general','colors','write','1'),
('fr.general','colors','letter','1'),
('fr.general','numbers','choose','1'),
('fr.general','numbers','write','1'),
('fr.general','numbers','letter','1'),
('fr.general','alphabet','choose','1'),
('fr.general','alphabet','write','1'),
('fr.general','alphabet','letter','1'),
('fr.general','shapes','choose','1'),
('fr.general','shapes','write','1'),
('fr.general','shapes','letter','1'),
('fr.general','animals','choose','1'),
('fr.general','animals','write','1'),
('fr.general','animals','letter','1'),
('fr.general','fruits','choose','1'),
('fr.general','fruits','write','1'),
('fr.general','fruits','letter','1')
on conflict(assessment_code,topic_code,mode) do nothing;

insert into fr_edu.questions(code,topic_code,prompt_fr,question_type,source_text) values
('fr.grammar.001','grammar','Je ............ le chocolat.','choose','WhatsApp question batch 2026-11-13'),
('fr.grammar.002','grammar','Ils ............ le film.','choose','WhatsApp question batch 2026-11-13'),
('fr.grammar.003','grammar','Tu ............ les pantalons.','choose','WhatsApp question batch 2026-11-13'),
('fr.grammar.004','grammar','Ce soir, nous ............ à Alex.','choose','WhatsApp question batch 2026-11-13'),
('fr.grammar.005','grammar','Hier, vous ............ les devoirs.','choose','WhatsApp question batch 2026-11-13')
on conflict(code) do nothing;

insert into fr_edu.question_options(question_code,option_number,option_text) values
('fr.grammar.001',1,'Manges'),
('fr.grammar.001',2,'Mange'),
('fr.grammar.001',3,'Mangez'),
('fr.grammar.002',1,'Regardent'),
('fr.grammar.002',2,'Regarde'),
('fr.grammar.002',3,'Regardes'),
('fr.grammar.003',1,'Choisissez'),
('fr.grammar.003',2,'Choisis'),
('fr.grammar.003',3,'Choisit'),
('fr.grammar.004',1,'Viyageons'),
('fr.grammar.004',2,'Allons'),
('fr.grammar.004',3,'Voyager'),
('fr.grammar.004',4,'Voyages'),
('fr.grammar.005',1,'Corrigez'),
('fr.grammar.005',2,'Allez'),
('fr.grammar.005',3,'Corrigez'),
('fr.grammar.005',4,'Avez'),
('fr.grammar.005',5,'Corrige')
on conflict(question_code,option_number) do nothing;

insert into fr_edu.question_keys(question_code,accepted_answers,auto_gradable,review_note) values
('fr.grammar.001',ARRAY['Mange']::text[],true,'Subject je requires mange.'),
('fr.grammar.002',ARRAY['Regardent']::text[],true,'Subject ils requires regardent.'),
('fr.grammar.003',ARRAY['Choisis']::text[],true,'Subject tu requires choisis.'),
('fr.grammar.004',ARRAY['Allons']::text[],true,'Allons matches nous in this context; spelling of Alex is retained from submitted draft.'),
('fr.grammar.005','{}'::text[],false,'The temporal cue hier indicates a past action, and the submitted options do not yield an unambiguous correct answer. Duplicate Corrigez retained verbatim.')
on conflict(question_code) do nothing;

insert into fr_edu.assessment_questions(assessment_code,question_code,position,points) values
('fr.grammar.conjugaison.v1','fr.grammar.001',1,1),
('fr.grammar.conjugaison.v1','fr.grammar.002',2,1),
('fr.grammar.conjugaison.v1','fr.grammar.003',3,1),
('fr.grammar.conjugaison.v1','fr.grammar.004',4,1),
('fr.grammar.conjugaison.v1','fr.grammar.005',5,1)
on conflict(assessment_code,position) do nothing;
