-- Performance indexes scoped exclusively to private fr_edu schema.
create index if not exists fr_assessment_grades_approved_by_idx on fr_edu.assessment_grades(approved_by);
create index if not exists fr_assessment_grades_grade_code_idx on fr_edu.assessment_grades(grade_code);
create index if not exists fr_assessment_pool_topic_code_idx on fr_edu.assessment_pool(topic_code);
create index if not exists fr_assessment_questions_question_code_idx on fr_edu.assessment_questions(question_code);
create index if not exists fr_attempts_assessment_code_idx on fr_edu.attempts(assessment_code);
create index if not exists fr_audit_events_actor_user_id_idx on fr_edu.audit_events(actor_user_id);
create index if not exists fr_grade_topics_approved_by_idx on fr_edu.grade_topics(approved_by);
create index if not exists fr_grade_topics_topic_code_idx on fr_edu.grade_topics(topic_code);
create index if not exists fr_guardian_consents_guardian_user_id_idx on fr_edu.guardian_consents(guardian_user_id);
create index if not exists fr_guardian_consents_learner_user_id_idx on fr_edu.guardian_consents(learner_user_id);
create index if not exists fr_questions_topic_code_idx on fr_edu.questions(topic_code);
create index if not exists fr_responses_lexeme_id_idx on fr_edu.responses(lexeme_id);
create index if not exists fr_responses_question_code_idx on fr_edu.responses(question_code);
create index if not exists fr_unit_grades_approved_by_idx on fr_edu.unit_grades(approved_by);
create index if not exists fr_unit_grades_grade_code_idx on fr_edu.unit_grades(grade_code);
create index if not exists fr_units_topic_code_idx on fr_edu.units(topic_code);
create index if not exists fr_user_roles_assigned_by_idx on fr_edu.user_roles(assigned_by);
