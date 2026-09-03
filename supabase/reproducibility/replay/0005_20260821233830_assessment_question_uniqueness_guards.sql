alter table public.question_bank add constraint question_bank_version_code_key unique (assessment_version_id, code);
alter table public.question_options add constraint question_options_question_code_key unique (question_id, option_code);
alter table public.question_dimension_scores add constraint question_dimension_scores_option_dimension_key unique (option_id, dimension_id);
