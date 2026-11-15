# Aviation Matrix — Octopus Learning Engine v1

**Implementation note — 16 November 2026**

**State:** INTERNAL TECHNICAL PREVIEW. This note records working technical assets, not an approval to publish training content or a change to the existing Aviation Matrix master baseline.

## Purpose

Teach aviation as an interconnected industry. Every lesson should answer: **Where are we? Why does it matter? What is its nucleus? How does it connect? How does it apply? What have we understood and where next?**

The **knowledge graph** records the aviation entities and typed relationships; the **Octopus** organizes eight learner perspectives; and the **Learning Compass** keeps the learner oriented. Neither the graphic octopus nor the flight-lifecycle sequence is the source of factual truth.

## Reused infrastructure

The authoritative database remains **AviationMatrix-Core**, schema `avi_knowledge`, using existing `nodes`, `relationships`, `sources`, `claims`, `lesson_versions`, `lesson_blocks`, `lesson_questions`, `connected_flight_*`, and navigation graph projection/RPCs. Existing student enrollment, lesson release and authentication gates are reused, not replaced.

This work must remain architecturally separate from the AOIP operating system and from the separate Aviation Catering Supabase project.

## New additive database migrations

- `20261115225703_aviation_octopus_learning_compass_and_arms_v1`
  - `avi_knowledge.octopus_compass_stages`: six fixed teaching questions.
  - `avi_knowledge.octopus_arms`: eight learner perspectives.
  - `avi_knowledge.octopus_lesson_compass`: lesson-specific compass prompts anchored to existing graph entities.
  - `avi_knowledge.octopus_lesson_arm_links`: lesson-to-graph anchor links, each with rationale, editorial state and review evidence.
  - `avi_knowledge.octopus_lesson_preview_v1(uuid)`: private internal JSON preview.
- `20261115225827_aviation_octopus_secure_learner_delivery_v1`
  - `public.am_octopus_lesson_v1(enrollment_id uuid, lesson_id uuid)`: authenticated learner entrypoint. It additionally requires canonical verified enrollment, course readiness, lesson unlock, published lesson, **six approved compass stages and eight fully reviewed arms**. No draft is available to a learner through this API.
- `aviation_octopus_review_invalidation_and_editorial_permissions_v1`
  - Reviewed compass/arm text automatically returns to draft if the referenced entity or learner-visible editorial content changes, preventing stale approvals.

The new tables are private with RLS. The internal preview is not callable by `anon` or `authenticated`. The learner RPC is deliberately `SECURITY DEFINER` with explicit identity, enrollment, release and editorial gates; monitor Supabase's corresponding security-advisor warning as a reviewed exception, not as general public access.

## Learning Compass (six stages)

1. **WHERE ARE WE?** — orientation in the industry, course and topic.
2. **WHY?** — problem and purpose.
3. **THE NUCLEUS** — essential mechanism.
4. **THE CONNECTIONS** — dependencies and interdisciplinary links.
5. **THE APPLICATION** — real or clearly synthetic scenario.
6. **VERIFY & MOVE** — evidence of understanding and next navigation.

## Eight interpretive arms

**CONCEPT / DATA / PEOPLE / PROCESS / RULES / DECISIONS / RISKS / LINKS.**

They are pedagogical perspectives, not eight mandatory process steps and not eight independent copies of content. Every link points at an existing entity in the canonical knowledge graph.

## Connected-flight pilot

Uses the pre-existing synthetic case **One Flight, One Connected Aviation System**, with 14 phases, 21 roles and 4 disruptions. The first linked lesson is **One Flight: Cross-Functional Industry Case**.

Implementation attaches **six compass entries** and **sixteen knowledge-graph links across all eight arms**. Existing original lesson text, questions, claims, source records and publishing status have not been rewritten.

At implementation time the pilot lesson, compass entries and arm links are still **draft**. Human expert and instructional reviews are not yet satisfied, and no live student release has been asserted.

## Internal acceptance checks completed

- Preview JSON: 6 compass stages, 8 arms, 16 anchored entities.
- RLS enabled on all four new tables.
- Anonymous execution of learner RPC and direct preview blocked.
- Verified denial without authenticated identity.
- Editorial revision invalidates approval; rollback test leaves no temporary test modifications.
- Offline HTML internal mock-up interaction tested at desktop and mobile, with no horizontal overflow or runtime errors.

## Remaining release gates

1. Scientific and operational expert review of the connected-flight case, source scope, and roles.
2. Instructional validation of each lesson and question against learning objectives.
3. Formal content approval under existing Aviation Matrix publication rules.
4. Student UI integration with real authenticated sessions, progress, saved navigation and regression tests.
5. Internal demonstration rehearsal; public use only after review gates pass.

**Do not confuse the internal static HTML demonstration with a deployed live platform, a regulatory approval, an operational authorization, or a public course release.**
