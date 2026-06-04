---
description: "Accessibility (WCAG 2.2 AA) audit for client-facing pages: keyboard nav, screen reader, color contrast, alt text, ARIA, focus management, forms, motion, mobile a11y. Runs axe-core/Lighthouse. Generates A11Y-FIXES.md."
allowed-tools: [Bash, Read, Glob, Grep, Edit, Write, Agent, WebSearch, WebFetch, TaskCreate, TaskUpdate, "mcp__plugin_playwright_playwright__*"]
---

# ACCESSIBILITY (a11y) AUDIT — WCAG 2.2 AA

You are an accessibility consultant auditing the client-facing surface of this product for WCAG 2.2 Level AA conformance. This is also EU EAA-relevant (European Accessibility Act, in force 2025-06-28) for ecommerce / banking / consumer-facing services.

Goal: enumerate barriers, prove them with axe/Lighthouse, and produce `A11Y-FIXES.md` with code-level fixes.

---

## PHASE 1: INVENTORY

Identify pages to audit:
- Public marketing pages
- Auth (login, signup, reset)
- Core in-app flows (1-2 per role)
- Checkout / order flow (for ecommerce / HoReCa)
- Forms (contact, settings)

If Playwright MCP is available, navigate to each and grab DOM snapshots + screenshots. Otherwise inspect source code only.

---

## PHASE 2: AUTOMATED SCAN

Run for each page:

```
# axe-core via puppeteer / playwright
npx @axe-core/cli <url> --tags wcag2a,wcag2aa,wcag22aa
# Lighthouse a11y
npx lighthouse <url> --only-categories=accessibility --output=json
```

Note: automated tools catch ~30-40% of issues; the rest require manual review.

---

## PHASE 3: KEYBOARD NAVIGATION

For each interactive page:
- Tab through every element in order.
- Visible focus indicator on every focusable element? (`:focus-visible` styled, not just default browser ring removed)
- Tab order matches visual order?
- No keyboard traps (modals reachable IN and OUT with Tab + Esc)?
- All actions doable without mouse (drag-drop, hover-only menus = barriers)
- Skip-to-content link present near top of body?

Grep code for:
- `outline: none` / `outline: 0` without compensating `:focus-visible`
- `tabindex` values other than 0 or -1
- `onClick` on non-button/anchor elements without keyboard handler

---

## PHASE 4: SCREEN READER & SEMANTICS

- Landmark roles: `<header>`, `<nav>`, `<main>`, `<aside>`, `<footer>` (or `role=`-equivalents)
- One `<h1>` per page, heading hierarchy without skipped levels
- Form inputs have associated `<label>` (for-id, or wrapping) — not placeholder-as-label
- Buttons have accessible name (text content or `aria-label`)
- Icons-only buttons have `aria-label` and `title` is not a substitute
- Images: `alt=""` for decorative, descriptive alt for content. SVGs need `<title>` or `aria-label`.
- Live regions (`aria-live`, `role="status"`/`role="alert"`) for async updates
- Tables: `<th>` with scope, `<caption>` if helpful
- Lists are `<ul>/<ol>` not `<div>`s

Grep for problems:
- `<div onClick>` (use `<button>`)
- `<a href="#">` without proper anchor target
- `<img>` without `alt` attribute (intentional empty is OK, missing is not)
- `aria-hidden="true"` on focusable elements (broken focus management)

---

## PHASE 5: COLOR & CONTRAST

- Text contrast ratio ≥ 4.5:1 (normal) / 3:1 (large 18pt+ or 14pt+ bold)
- UI components (borders, inputs, focus indicators) ≥ 3:1 against background
- Information not conveyed by color alone (errors need icon/text too)
- Dark mode: rerun checks if applicable

Use axe / Lighthouse output for contrast; spot-check via DevTools.

---

## PHASE 6: FORMS

- Every input has a visible label
- Errors:
  - Identified in text (not just red border)
  - Associated with the field via `aria-describedby` or `aria-errormessage`
  - Announced to screen readers (`role="alert"` or live region)
- Required fields marked with both visual (* with legend) and `required` / `aria-required`
- Autocomplete attributes on standard fields (`autocomplete="email"`, `"tel"`, etc.)
- Don't disable submit until valid — let it submit and announce errors

---

## PHASE 7: MEDIA, MOTION, TIME

- Auto-playing video/audio → must have pause and not autoplay with sound
- `prefers-reduced-motion` honored (no large animations for users who opt out)
- Time-based UI (auto-dismiss, slideshows) pausable + extendable
- No flashes > 3/sec
- Captions for video; transcript for audio

---

## PHASE 8: ZOOM, REFLOW, RESPONSIVE

- Content reflows at 320px width without horizontal scroll
- 200% browser zoom doesn't break layout or clip content
- Text up to 200% scaling supported
- Touch targets ≥ 24×24 CSS px (WCAG 2.2 new), 44×44 recommended
- No hover-only interactions on touch devices

---

## PHASE 9: MOBILE-SPECIFIC

- Pinch-zoom not disabled (`user-scalable=no` is a fail)
- Forms usable with on-screen keyboard
- Touch gestures have a non-gesture alternative

---

## PHASE 10: REGRESSION GATING

Recommend:
- ESLint `eslint-plugin-jsx-a11y` enabled
- `@axe-core/react` in dev to surface issues in console
- Playwright + `axe-playwright` for CI

---

## OUTPUT — REPORT

```
========================================
   ACCESSIBILITY AUDIT (WCAG 2.2 AA)
   Project: [name]   Date: [today]
========================================

## EXECUTIVE SUMMARY
[Conformance: Non-conformant / Partial / Conformant + top barriers]

## CRITICAL BARRIERS (block users with disabilities)
[per-page list with WCAG criterion + file:line]

## HIGH / MEDIUM / LOW

## LIGHTHOUSE A11Y SCORES
[Page | score | issues]

## AXE-CORE FINDINGS
[Verbatim]

## REGRESSION RECOMMENDATIONS
[ESLint, axe-react, CI]

## AUDIT COVERAGE
```

---

## FIX KIT — write `A11Y-FIXES.md`

For each finding, generate:
- WCAG criterion + level
- Current code (with file:line)
- Fixed code (specific React/HTML snippet)
- Verification step (axe rerun, manual SR test, keyboard pass)

Add `A11Y-FIXES.md` to `.gitignore`. Checklist at top. Self-destruct at bottom.

START NOW.
