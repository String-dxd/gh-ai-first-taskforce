# TFX Design Standards — quick reference

> Source of truth: `harness/standards/catalog.yaml` in `transformteamsg/tfx-design-standard`.
> This file is the human-readable companion — update it when you add or change a control in the YAML.
> Detail files: `harness/standards/controls/<id>.md`.
> Waiver syntax: `tfx-waive <ID> reason="<specific reason>"` — in the commit message or PR description.

---

## L0 — Never bend (no waiver)

These five controls apply to every surface, every scenario, no exceptions:

- **A11Y-1** — Text contrast ≥ 4.5:1 for body, ≥ 3:1 for large text and UI components
- **A11Y-2** — Every interactive element reachable by keyboard with a visible focus state
- **A11Y-3** — Every form field has a programmatically associated, visible label (not placeholder-only)
- **CMP-2** — Destructive actions show consequences before executing and offer undo or confirmation
- **SLP-4** — No nested cards — group with spacing, typography, and dividers instead

---

## L1 — Must pass or named-human waiver

| ID | Standard | Fires when | Check |
|----|----------|------------|-------|
| **A11Y** | | | |
| A11Y-4 | Interactive targets ≥ 24×24px (44px on mobile) | Any interactive element | deterministic |
| A11Y-5 | `prefers-reduced-motion` disables all non-essential animation | Any animation | deterministic |
| A11Y-6 | Non-text content has a text alternative; decorative content is hidden from AT | Images, icons, SVG | deterministic |
| A11Y-7 | Semantic headings, lists, tables, form groups — no styled divs standing in for structure | Any page | hybrid |
| A11Y-8 | Custom components expose name, role, and value to AT | Custom controls | hybrid |
| A11Y-9 | Every page/view has a descriptive title; `html lang` is correct; SPA views update the title | Every page | deterministic |
| A11Y-10 | Skip link or landmark navigation to main content | Pages with repeated chrome | deterministic |
| A11Y-11 | Async state changes: transient → live region; context change → focus move; never both | Any async action | hybrid |
| **Tokens** | | | |
| TOK-1 | No raw colour values — semantic (shadcn) tokens only | Any UI code | deterministic |
| TOK-2 | All spacing values from the shadcn default token scale | Margin, padding, gap | deterministic |
| TOK-3 | Corner radii from the shadcn default radius scale; child radius never larger than parent | Border-radius | deterministic |
| **Typography** | | | |
| TYP-1 | Display text: Plus Jakarta Sans 600; body/UI text: Inter 400/500/600; no other typefaces | Any text | deterministic |
| TYP-2 | Body text ≥ 14px; labels ≥ 12px; body line-height 1.5–1.6 | Body and label copy | deterministic |
| TYP-3 | Type sizes from the Tailwind default scale only | Font sizes | deterministic |
| **Colour** | | | |
| COL-1 | Primary actions and brand moments use the product's primary brand colour | CTAs, brand moments | hybrid |
| COL-2 | Functional colours (success/warning/danger) from Radix Colors scales; small functional text uses step-12 | Status chips, alerts | deterministic |
| **Components** | | | |
| CMP-1 | Use a Base UI component where one exists; one-offs require a waiver | Dropdowns, dialogs, tooltips | hybrid |
| CMP-3 | Every async transaction has visible loading, success, and error states | Any async action | hybrid |
| CMP-4 | Empty states unambiguously signal "no content" — distinct from loading or error | Empty list/page states | hybrid |
| CMP-8 | Multi-step tasks offer a non-destructive exit at every step; in-progress work is preserved or explicitly discarded | Wizards, forms, dialogs | hybrid |
| CMP-9 | Content authored by one user and rendered to another is sanitised at the render boundary | User-generated content | hybrid |
| **Content** | | | |
| CNT-1 | Error messages state what happened and what to do next; no raw error codes | Error surfaces | hybrid |
| CNT-2 | Feature and page names use plain language; no portmanteaus or codenames in UI | Navigation, page titles | judgment |
| CNT-10 | One term per thing within a product — same action/object/state keeps one name everywhere | Any copy | judgment |
| **Identity** | | | |
| IDN-1 | Product lockups and logos from approved assets only; no recreations | Logo/lockup usage | deterministic |
| IDN-2 | Product icons from the approved icon family; no ad-hoc or regenerated marks | Product icons | deterministic |
| IDN-4 | CaseSync: no celebratory motion, gamification, or exclamatory copy around case data | CaseSync surfaces only | judgment |
| **Anti-slop** | | | |
| SLP-1 | No purple/violet gradient palettes, cyan-on-dark theming, or glow accents | Any styling | deterministic |
| SLP-2 | No gradient text (`background-clip: text`) | Headings, metrics | deterministic |
| SLP-3 | No thick side-tab accent borders on rounded cards | Card components | deterministic |
| SLP-8 | No bounce or elastic easing on interface elements | Any animation | deterministic |
| SLP-10 | Complex multi-section tasks get a page, not a modal | Flow/task design | judgment |
| **Layout** | | | |
| LAY-2 | Layout reflows to a single column at 320 CSS px; reading order holds at 360/768/1280 | Every page | judgment |

---

## L2 — Strong default (rationale waiver)

| ID | Standard | Fires when | Check |
|----|----------|------------|-------|
| **Typography** | | | |
| TYP-4 | No all-caps text (genuine acronyms excepted) | Labels, headings, body | deterministic |
| TYP-5 | Numbers that align in columns or update in place use tabular figures | Data tables, live counters | hybrid |
| TYP-6 | Running body text capped at ~45–75ch per line via `max-width` | Prose blocks | hybrid |
| **Components** | | | |
| CMP-5 | At most one primary (filled) action per view; secondary/tertiary step down | Every view | hybrid |
| CMP-6 | Data tables: semantic rows/headers, numeric columns right-aligned with tabular figures, sticky header | Tables | hybrid |
| CMP-7 | Components stay consistent with their design-system defaults and sibling-page usage | Component overrides | judgment |
| **Content** | | | |
| CNT-3 | Second person, active voice, sentences ≤ 25 words | All copy | hybrid |
| CNT-4 | Content modelling a real-world artifact is faithful or explicitly labelled illustrative | Curriculum/domain content | judgment |
| CNT-5 *(proposed)* | Action words name the action, not the input device — "select", not "click" or "tap" | CTA and link copy | hybrid |
| CNT-6 *(proposed)* | No low-informational-value words — no empty openers, filler words | UI copy | hybrid |
| CNT-7 *(proposed)* | Descriptive copy leads with purpose before mechanism | Titles, descriptions, intros | judgment |
| CNT-8 | Replace nominalised verbs and "to be" constructions with plain action verbs | All copy | judgment |
| CNT-9 | One idea per sentence; simple present tense; no double negatives; no noun stacks; acronyms defined | All copy | hybrid |
| CNT-11 | UI terms match established conventions teachers already know | Common UI terms | judgment |
| CNT-12 | Sentence case everywhere — first word and proper/branded nouns only | Headings, labels, buttons | hybrid |
| CNT-13 | No spelling/proofreading errors; Singapore English spelling (British base) | All copy | hybrid |
| CNT-14 | Copy embodies the TFX voice (Clear, Thoughtful, Approachable) and tone fits the surface | All copy | judgment |
| **Motion** | | | |
| MOT-1 | Interface motion 100–300ms with standard easing; no decorative motion on critical paths | Animations, transitions | deterministic |
| MOT-2 *(proposed)* | Motion values from the declared motion token set; no hardcoded durations or easings | Component animation code | deterministic |
| MOT-3 *(proposed)* | Motion emphasises meaning but never carries it alone — static variant communicates the same | Animated diagrams | judgment |
| **Identity** | | | |
| IDN-3 | Copy on a product surface carries that product's calibrated tone register | Product surfaces | judgment |
| **Anti-slop** | | | |
| SLP-5 | No icon-tile-above-heading feature-card template; no identical card grids as default layout | Page layout | deterministic |
| SLP-6 | Adjacent type-scale steps differ by ≥ 1.25×; no flat hierarchy | Heading/body hierarchy | deterministic |
| SLP-7 | Spacing has rhythm — related items grouped tighter than unrelated | Any layout | deterministic |
| SLP-9 | No AI-writing tells — buzzwords, em-dash chains, filler, or redundant label/helper pairs | All copy | hybrid |
| SLP-11 | Cards only for interactive units; static content grouped with spacing and dividers | Any card usage | judgment |
| **Layout** | | | |
| LAY-1 | Layout uses the product's declared column grid and gutter scale (N/A where no grid declared) | Paged layouts | hybrid |
| LAY-3 | Surface maps to a known page template rather than a bespoke shell | Every page | judgment |
| LAY-4 | Body-text columns capped at ≤ 80ch (target ~66ch); no full-bleed running text | Prose containers | deterministic |
| LAY-5 | Density suits the task — not cramped for data entry, not padded for scanning | Every surface | judgment |
| LAY-6 | Shared edges align; optical alignment used where geometry misleads | Every surface | judgment |
| LAY-7 | One primary focal region; visual reading order matches the task's priority order | Every page | judgment |

---

## Deterministic checks

These controls can be verified by script or tool — wire them as pre-commit hooks or CI steps:

| Tool | Controls |
|------|----------|
| `@axe-core/playwright` (runs in E2E suite) | A11Y-1, A11Y-2, A11Y-3, A11Y-6, A11Y-9, A11Y-10 |
| Playwright `emulateMedia({ reducedMotion: 'reduce' })` | A11Y-5 |
| `checks/token-audit.py` | TOK-1, TOK-2, TOK-3, COL-2 |
| `checks/type-scan.py` | TYP-1, TYP-2, TYP-3, TYP-4 |
| `checks/content-lint.py` | CNT-3, CNT-5, CNT-6, CNT-9, CNT-12, CNT-13, SLP-9 |
| CSS grep / `checks/token-audit.py` | SLP-1, SLP-2, SLP-3, SLP-5, SLP-6, SLP-7, SLP-8, MOT-1, MOT-2 |

Set up axe-playwright globally (not per-test) so every E2E test — not just skill-generated ones — gets accessibility coverage:

```sh
npm install --save-dev @axe-core/playwright
```

```ts
// In your global Playwright setup (e.g. tests/fixtures.ts or playwright.config.ts)
import { checkA11y, injectAxe } from 'axe-playwright'

test.beforeEach(async ({ page }) => {
  await injectAxe(page)
})

// Call in each test after navigation:
await checkA11y(page, null, { runOnly: ['wcag2a', 'wcag2aa'] })
```

---

## Adding or changing a control

1. Edit `harness/standards/catalog.yaml` (YAML is the source of truth — the harness reads it)
2. Add or update the detail file at `harness/standards/controls/<id>.md`
3. Update the relevant row in this file to match
4. Open a PR; design-lead approval required for L0/L1 changes
