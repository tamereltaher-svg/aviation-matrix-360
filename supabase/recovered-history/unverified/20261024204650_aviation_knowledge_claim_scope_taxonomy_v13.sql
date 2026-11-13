
-- Add precise regulatory / operational provenance classification without altering existing claims.
alter table avi_knowledge.claims drop constraint claims_claim_kind_check;
alter table avi_knowledge.claims add constraint claims_claim_kind_check
check (claim_kind in ('historical','scientific','interpretive','pedagogical','operational','regulatory'));
alter table avi_knowledge.claims
add column applicability text not null default 'contextual'
check(applicability in ('contextual','universal_science','international_guidance','jurisdiction_specific','operator_specific'));
update avi_knowledge.claims set claim_kind='operational',applicability='jurisdiction_specific'
where claim_key='cabin_crew_safety_primary';
update avi_knowledge.claims set claim_kind='operational',applicability='international_guidance'
where claim_key='icao_proactive_cabin_safety';
update avi_knowledge.claims set claim_kind='regulatory',applicability='international_guidance'
where claim_key in ('state_approved_minimum_crew','floor_exit_staffing_guidance');
update avi_knowledge.claims set claim_kind='regulatory',applicability='jurisdiction_specific'
where claim_key='cabin_flightdeck_coordination_faa';
comment on column avi_knowledge.claims.applicability is 'Differentiates descriptive international guidance from jurisdiction-specific obligations and universal science.';
