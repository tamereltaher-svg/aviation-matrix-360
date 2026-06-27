# Aviation Matrix 360

**Aviation Matrix 360** is a professional corporate website representing an integrated aviation ecosystem focused on operations, education, and innovation.

Live site: deployed via Replit

---

## Overview

Aviation Matrix 360 connects three core pillars under one unified ecosystem:

| Pillar | Description |
|---|---|
| **Aviation Matrix Operations Platform** | Operational intelligence platform for aviation organizations — structuring operations, governance, visibility, and decision support |
| **Aviation Matrix Academy** | Professional aviation education, operational knowledge development, and industry-focused learning programs |
| **Kids Aviation Matrix** | Future-generation aviation education initiative introducing children to aviation through engaging learning experiences |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | React 19 + Vite 7 |
| Language | TypeScript 5.9 |
| Styling | Tailwind CSS v4 |
| UI Components | shadcn/ui + Radix UI |
| Routing | Wouter |
| Animations | Framer Motion |
| Forms | React Hook Form + Zod |
| Icons | Lucide React |
| Package Manager | pnpm (workspace monorepo) |
| Node | 24 |

---

## Project Structure

```
aviation-matrix-360/
├── artifacts/
│   └── aviation-matrix-360/          # Main website artifact
│       └── src/
│           ├── App.tsx               # Router and providers
│           ├── index.css             # Global styles + CSS theme variables
│           ├── pages/
│           │   ├── home.tsx          # Homepage (Hero, Ecosystem, Vision, Contact)
│           │   ├── about.tsx         # About Aviation Matrix 360
│           │   ├── platform.tsx      # Aviation Matrix Operations Platform
│           │   ├── academy.tsx       # Academy + Kids Aviation Matrix
│           │   └── contact.tsx       # Contact page
│           └── components/
│               ├── layout/
│               │   ├── Navbar.tsx    # Sticky responsive navigation
│               │   └── Footer.tsx    # Site-wide footer
│               └── ui/               # shadcn/ui component library
├── lib/                              # Shared workspace libraries
├── scripts/                          # Utility scripts
├── pnpm-workspace.yaml               # Workspace config and catalog
├── tsconfig.base.json                # Shared TypeScript config
└── package.json                      # Root workspace scripts
```

---

## Pages

| Route | Page |
|---|---|
| `/` | Homepage — Hero, Our Ecosystem, Our Vision, Contact |
| `/about` | About Aviation Matrix 360 |
| `/platform` | Aviation Matrix Operations Platform |
| `/academy` | Aviation Matrix Academy + Kids Aviation Matrix |
| `/contact` | Contact form and information |

---

## Getting Started

**Prerequisites:** Node.js 24, pnpm

```bash
# Install dependencies
pnpm install

# Run the development server
pnpm --filter @workspace/aviation-matrix-360 run dev

# Typecheck
pnpm run typecheck
```

The site runs on the port defined by the `PORT` environment variable (default proxied through Replit's shared reverse proxy).

---

## Design

- **Color palette:** Deep navy primary (`#0d2155`) with steel-blue accents
- **Typography:** Outfit (headings) + Inter (body) via Google Fonts
- **Animations:** Framer Motion scroll-triggered entrance animations
- **Responsive:** Full desktop and mobile support
- **No backend, no database, no authentication** — purely a static corporate website

---

## Brand Structure

```
Aviation Matrix 360  (parent ecosystem)
├── Aviation Matrix Operations Platform
└── Aviation Matrix Academy
    └── Kids Aviation Matrix  (sub-program)
```

---

## Contact

General enquiries: info@aviationmatrix360.com

Official contact details will be announced soon.

---

&copy; 2026 Aviation Matrix 360. All rights reserved.
