update public.question_bank set prompt = case code
when 'CFV1_CC_001' then 'During boarding, you notice a large bag positioned in a way that could obstruct the aisle. The passenger asks you to leave it there because the flight is short. What would you do?'
when 'CFV1_CC_002' then 'A passenger is angry about a seat change and is speaking loudly in front of other passengers. What is your first action?'
when 'CFV1_CC_003' then 'During pre-departure preparation, you notice a colleague has skipped a check step because they are in a hurry. What do you do?'
when 'CFV1_CC_004' then 'During turbulence, several passengers request different services while the crew instructions require the cabin to be secured. How do you prioritize?'
when 'CFV1_CC_005' then 'During a cabin check, you notice a small difference between what should be present and what is actually there. There is no obvious immediate danger. What do you do?'
when 'CFV1_CC_006' then 'A passenger insists on doing something that conflicts with current safety instructions and says a previous crew allowed it. What would you do?'
when 'CFV1_CC_007' then 'A passenger is very anxious about flying and keeps asking the same question while you are under workload pressure. How do you handle it?'
when 'CFV1_CC_008' then 'You receive a new procedure update that you have not used before, and departure time is close. What is your approach?'
when 'CFV1_CC_009' then 'A passenger makes a provocative personal comment toward you during service. How do you respond?'
when 'CFV1_CC_010' then 'You receive a short operational instruction in English with one word you do not understand, while the rest is clear. What do you do?'
else prompt end
where code like 'CFV1_CC_%';

update public.question_options qo set option_text = case q.code || ':' || qo.option_code
when 'CFV1_CC_001:A' then 'Ask for the bag to be stowed safely according to procedure and explain that the aisle must remain clear.'
when 'CFV1_CC_001:B' then 'Leave it temporarily and return to it before departure if time allows.'
when 'CFV1_CC_001:C' then 'Allow it because the flight is short and passengers can still pass.'
when 'CFV1_CC_001:D' then 'Tell the passenger to deal with it without further explanation.'
when 'CFV1_CC_002:A' then 'Listen calmly, identify the issue briefly, and explain what can realistically be done.'
when 'CFV1_CC_002:B' then 'State the rule immediately and ask the passenger to lower their voice.'
when 'CFV1_CC_002:C' then 'Ask another crew member to handle the passenger because they are speaking loudly.'
when 'CFV1_CC_002:D' then 'Ignore the passenger for a few minutes until they calm down.'
when 'CFV1_CC_003:A' then 'Address the colleague professionally, make sure the missed step is completed, and escalate if the issue remains unresolved.'
when 'CFV1_CC_003:B' then 'Complete the step for them without saying anything to avoid tension.'
when 'CFV1_CC_003:C' then 'Assume each crew member is responsible for their own tasks and do not intervene.'
when 'CFV1_CC_003:D' then 'Report it immediately without first speaking to the colleague or checking the situation.'
when 'CFV1_CC_004:A' then 'Secure the cabin according to crew instructions first, then return to service requests when conditions allow.'
when 'CFV1_CC_004:B' then 'Complete the two quickest requests first, then secure the cabin.'
when 'CFV1_CC_004:C' then 'Handle the most demanding passenger first to avoid a complaint.'
when 'CFV1_CC_004:D' then 'Stop all communication with passengers until the turbulence ends.'
when 'CFV1_CC_005:A' then 'Verify the difference according to procedure and report it if the condition does not match what is required.'
when 'CFV1_CC_005:B' then 'Make a mental note, continue the check, and return to it later.'
when 'CFV1_CC_005:C' then 'Ignore it because the difference is small and there is no obvious danger.'
when 'CFV1_CC_005:D' then 'Correct it yourself based on what you think is right without verifying.'
when 'CFV1_CC_006:A' then 'Stay calm, explain that the current safety instruction is the reference, follow it, and escalate if needed.'
when 'CFV1_CC_006:B' then 'Allow the request this time to avoid conflict with the passenger.'
when 'CFV1_CC_006:C' then 'Tell the passenger that the previous crew was wrong.'
when 'CFV1_CC_006:D' then 'Immediately ask a more senior colleague to make the decision for you.'
when 'CFV1_CC_007:A' then 'Give a clear and reassuring answer, confirm understanding, and briefly follow up when priorities allow.'
when 'CFV1_CC_007:B' then 'Repeat the same answer each time no matter how often the question is asked.'
when 'CFV1_CC_007:C' then 'Tell the passenger you are busy and ask them to speak to you later.'
when 'CFV1_CC_007:D' then 'Ask the passenger next to them to reassure them.'
when 'CFV1_CC_008:A' then 'Review the update from the approved source, identify what changed, and clarify anything unclear before applying it.'
when 'CFV1_CC_008:B' then 'Rely on a quick explanation from a colleague and apply it immediately.'
when 'CFV1_CC_008:C' then 'Use the old procedure because you already know it well.'
when 'CFV1_CC_008:D' then 'Memorize the new steps quickly without understanding why they changed.'
when 'CFV1_CC_009:A' then 'Remain calm, maintain professional boundaries, and redirect the interaction to the situation or service needed.'
when 'CFV1_CC_009:B' then 'Respond in the same tone, but without insulting the passenger.'
when 'CFV1_CC_009:C' then 'Walk away immediately without saying anything.'
when 'CFV1_CC_009:D' then 'Tell nearby passengers that the comment was unacceptable.'
when 'CFV1_CC_010:A' then 'Confirm the meaning of the word using an approved source or authorized person before acting on the part that depends on it.'
when 'CFV1_CC_010:B' then 'Infer the meaning from context and proceed because the rest is clear.'
when 'CFV1_CC_010:C' then 'Ignore the word and focus only on the part you understood.'
when 'CFV1_CC_010:D' then 'Ask any nearby person to translate the entire instruction.'
else qo.option_text end
from public.question_bank q where q.id=qo.question_id and q.code like 'CFV1_CC_%';

insert into public.question_options(question_id,option_code,option_text,sequence_no,scoring_rationale,candidate_feedback)
select q.id,'TIMEOUT','Time expired',99,'No response was submitted within the 15-second limit.','Time expired before an answer was submitted.'
from public.question_bank q
where q.code like 'CFV1_CC_%'
and not exists(select 1 from public.question_options qo where qo.question_id=q.id and qo.option_code='TIMEOUT');

insert into public.question_dimension_scores(option_id,dimension_id,score,evidence_note)
select topt.id,qds.dimension_id,0,'No response within the 15-second limit; recorded as timeout.'
from public.question_bank q
join public.question_options src on src.question_id=q.id and src.option_code='A'
join public.question_dimension_scores qds on qds.option_id=src.id
join public.question_options topt on topt.question_id=q.id and topt.option_code='TIMEOUT'
where q.code like 'CFV1_CC_%'
and not exists(select 1 from public.question_dimension_scores ex where ex.option_id=topt.id and ex.dimension_id=qds.dimension_id);
