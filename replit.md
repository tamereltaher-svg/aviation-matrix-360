# Aviation Matrix 360

A professional corporate website for **Aviation Matrix 360** — an integrated aviation ecosystem focused on operations, education, and innovation.

## Run & Operate

- `pnpm --filter @workspace/aviation-matrix-360 run dev` — run the website (uses `PORT` env var)
- `pnpm run typecheck` — full typecheck across all packages
- `pnpm run build` — typecheck + build all packages

## Stack

- pnpm workspaces, Node.js 24, TypeScript 5.9
- Frontend: React 19, Vite 7, Tailwind CSS v4
- Routing: Wouter
- Animations: Framer Motion
- Forms: React Hook Form + Zod
- UI: shadcn/ui + Radix UI + Lucide React

## Where things live

- `artifacts/aviation-matrix-360/src/pages/` — all page components
- `artifacts/aviation-matrix-360/src/components/layout/` — Navbar and Footer
- `artifacts/aviation-matrix-360/src/index.css` — global styles and CSS theme variables (navy/white aviation palette)
- `artifacts/aviation-matrix-360/src/App.tsx` — wouter router + providers

## Architecture decisions

- Static corporate site only — no backend, no database, no authentication
- Single artifact (`artifacts/aviation-matrix-360`) served at root path `/`
- All CSS theme variables defined in `index.css` using space-separated HSL values (`--primary: 224 68% 20%`)
- Google Fonts (`@import url(...)`) must be the **first line** of `index.css` — PostCSS fails silently otherwise
- Kids Aviation Matrix is a sub-program under Aviation Matrix Academy, not a top-level nav item

## Product

Five-page corporate website:
- **Home** — Hero, Our Ecosystem (Operations / Education / Future Generations cards), Our Vision, Contact section
- **About** — Mission and ecosystem overview
- **Platform** — Aviation Matrix Operations Platform detail
- **Academy** — Professional Aviation Learning + Kids Aviation Matrix sub-section
- **Contact** — Contact form + email only (no phone/address until officially announced)

## User preferences

- No phone numbers anywhere on the site
- No physical addresses until officially announced
- No Flight Support section
- Kids Aviation Matrix must be a sub-program under Academy, not a separate nav item
- Contact email: info@aviationmatrix360.com
- Keep the navy + white aviation color scheme

## Gotchas

- The `PORT` env var is set by Replit workflows — do not hardcode ports in `vite.config.ts`
- Do not run `pnpm dev` at workspace root — use `pnpm --filter @workspace/aviation-matrix-360 run dev`
- Any `@import url(...)` in `index.css` must come before `@import "tailwindcss"` or PostCSS will fail silently

## Pointers

- See the `pnpm-workspace` skill for workspace structure, TypeScript setup, and package details
