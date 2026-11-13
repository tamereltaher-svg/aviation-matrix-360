
alter table avi_knowledge.relationships drop constraint relationships_basis_check;
alter table avi_knowledge.relationships add constraint relationships_basis_check
check(basis in ('documented_historical','scientific_mechanism','pedagogical_navigation','interpretive','operational_dependency','regulatory_framework'));
update avi_knowledge.relationships r set basis='regulatory_framework'
where r.from_node_id=(select id from avi_knowledge.nodes where code='cabin_staffing_oversight')
  and r.to_node_id in (select id from avi_knowledge.nodes where code in ('cabin_evacuation_management','flight_attendant_role'));
update avi_knowledge.relationships r set basis='operational_dependency'
where (r.from_node_id in (select id from avi_knowledge.nodes where code in ('flight_attendant_role','cabin_evacuation_management','flightcrew_role','crew_coordination','cabin_passenger_safety'))
    or r.to_node_id in (select id from avi_knowledge.nodes where code in ('crew_coordination','cabin_passenger_safety','cabin_exit_systems','cabin_evacuation_management')))
  and r.basis='scientific_mechanism';
