# Aviation Matrix — Navigation Map v1.0

## Canonical staff flow
`login.html` → `portal.html` → Domain Hub → Tool

## Staff entry
- Staff Login alias: `login.html`
- Main Operating Portal: `portal.html`

## Domain hubs
- Business & Commercial: `business_hub.html`
- Kids Aviation: `kids_hub.html`
- Talent Intelligence: `talent_hub.html`
- Learning & Assessment: `learning_hub.html`
- Airline & Employer: `airline_hub.html`
- Platform & Governance: `platform_hub.html`

## Important rule
Do not use `index.html` as the staff login page.
`index.html` is the public/candidate-facing Aviation Matrix application shell.

## Navigation fixes in this package
1. Fixed Kids Hub store route:
   `wings_shop.html` → `kids_wings_shop.html`
2. Added `login.html` as a stable alias to `portal.html`.
3. Added persistent “Main Portal / Hub” return buttons to key staff tools.
4. No backend authentication logic, Supabase keys, database schema, or business data were changed.
