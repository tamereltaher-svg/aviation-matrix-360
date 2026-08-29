# Phase 06 Reviewer UI

Reviewer interface for the CEFR-aligned Phase 06 Reading & Language Use bank.

## Current backend state

- 1,536 review items
- Human review remains pending until reviewers act
- Reviewer authorization is controlled by the database reviewer registry
- Browser roles cannot call reviewer write RPCs directly
- Gate approval does not equal Pilot or Launch approval

## Required runtime environment variables

Configure these in the hosting platform, not in GitHub source code:

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY` (server-only)

## Local development

```bash
npm install
npm run dev
```

## Production build

```bash
npm install
npm run build
npm start
```

## Vercel

Set the project Root Directory to:

`apps/phase06-reviewer`

Then configure the three environment variables above in Vercel Project Settings.

## Security

Never commit a service-role/secret key to GitHub and never expose it through a `NEXT_PUBLIC_` variable. The browser authenticates using Supabase Auth; Next.js server routes validate the user against the governed Phase 06 reviewer registry before using server-side reviewer RPCs.
