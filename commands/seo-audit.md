---
description: "Full SEO audit: meta tags, Open Graph, structured data, sitemap, robots.txt, Core Web Vitals, headings, images, internal linking, mobile. Auto-researches latest standards."
allowed-tools: [Bash, Read, Glob, Grep, Agent, WebSearch, WebFetch, TaskCreate, TaskUpdate, TaskGet, TaskList]
---

# MEGA SEO AUDIT

You are a senior SEO engineer performing a comprehensive SEO audit on this Next.js project. Be thorough, meticulous, and report EVERYTHING that could affect search engine rankings, crawlability, or user experience. This is a full technical SEO review.

## INSTRUCTIONS

Run ALL phases below. Use parallel agents where possible to speed up. Create tasks to track progress. At the end, produce a detailed SEO REPORT with category scores (GOOD / NEEDS WORK / MISSING / CRITICAL) and an overall SEO score out of 100.

---

## PHASE 0: RESEARCH LATEST STANDARDS

Before auditing, gather current best practices. Search the web for:

1. **"Next.js SEO best practices 2026"** — what has changed in the App Router, Metadata API, or recommended patterns?
2. **"Google Core Web Vitals 2026"** — current thresholds for LCP, INP (Interaction to Next Paint, replaced FID), CLS
3. **"latest Google algorithm updates 2026"** — any new ranking factors, deprecations, or signals?
4. **"Google Search structured data updates 2026"** — new supported types, deprecated schemas
5. **"Next.js 16 SEO features"** (or whatever the latest major version is)

Summarize what has changed and adapt the audit checklist accordingly. Note any NEW requirements that are not covered in the phases below and add them to the relevant phase.

---

## PHASE 1: TECHNICAL SEO FOUNDATION

### 1a. Sitemap
- Check for `sitemap.xml` or `sitemap.ts` in the app directory (App Router convention)
- Check for `next-sitemap` package in dependencies and its config (`next-sitemap.config.js` or `.mjs`)
- Verify the sitemap includes ALL public pages and excludes private/auth pages
- Check for sitemap index (if site has many pages)
- Check `robots.txt` references the sitemap URL

### 1b. Robots.txt
- Check for `robots.txt` or `robots.ts` in the app directory
- Verify it exists and is not blocking important pages/directories
- Check for `Disallow: /` (blocks everything — CRITICAL)
- Check for unnecessary blocks (blocking CSS/JS/images hurts rendering)
- Verify it allows major crawlers (Googlebot, Bingbot, etc.)
- Check for crawl-delay directive (generally unnecessary for Google)

### 1c. Canonical URLs
- Check for canonical link tags on all pages
- Verify canonicals are absolute URLs (not relative)
- Check for self-referencing canonicals (each page should canonical to itself unless there's a reason)
- Look for conflicting canonicals (different pages pointing to the same canonical)

### 1d. URL Structure
- Check for clean, descriptive URLs (no random IDs, query params for content pages)
- Check for consistent trailing slash behavior (`trailingSlash` in `next.config`)
- Check for URL segments that are too long or contain underscores (hyphens preferred)
- Verify dynamic route segments use meaningful slugs (not numeric IDs)

### 1e. Next.js Configuration
- Read `next.config.ts` (or `.js`, `.mjs`) for:
  - `i18n` configuration (locale handling)
  - `redirects` (proper 301s for moved content?)
  - `rewrites` (any that could cause duplicate content?)
  - `images` domains configuration
  - `output` mode (standalone, export)
  - `trailingSlash` consistency
  - `poweredByHeader` (should be false — information disclosure)

### 1f. Error Pages
- Check for custom `not-found.tsx` / `not-found.js` (App Router) or `404.tsx` (Pages Router)
- Check for custom `error.tsx` / `error.js`
- Verify 404 page returns proper 404 HTTP status code (not soft 404)
- Check for helpful 404 content (search, links to popular pages)

### 1g. Rendering Strategy
- Identify which pages use:
  - Static Generation (SSG) — best for SEO
  - Server-Side Rendering (SSR) — good for SEO
  - Client-Side Rendering (CSR) — BAD for SEO
- Flag pages with important content rendered only on the client side (`"use client"` with data fetching)
- Check for `dynamic = 'force-dynamic'` vs `dynamic = 'force-static'` exports
- Check for `generateStaticParams` on dynamic routes (enables SSG)

---

## PHASE 2: META TAGS & HEAD

For every page and layout in the app directory:

### 2a. Title Tags
- Every page has a `<title>` (via Metadata API: `metadata.title` or `generateMetadata`)
- Titles are unique across pages (no duplicates)
- Titles are under 60 characters (Google truncates longer ones)
- Titles include relevant keywords
- Title template is used in root layout (`title: { default: '...', template: '%s | Brand' }`)

### 2b. Meta Descriptions
- Every page has a `meta description`
- Descriptions are unique across pages
- Descriptions are 150-160 characters (optimal for SERP display)
- Descriptions are compelling (include call-to-action, value proposition)
- No duplicate descriptions across pages

### 2c. Metadata API Usage
- Check if project uses Next.js Metadata API (`export const metadata` or `export async function generateMetadata`)
- Check root layout for base metadata
- Check if `metadataBase` is set (required for resolving relative URLs in metadata)
- Check for proper metadata merging across layout hierarchy

### 2d. Essential Head Tags
- `<meta charset="utf-8">` present
- `<meta name="viewport" content="width=device-width, initial-scale=1">` present
- `<html lang="...">` attribute set (critical for accessibility and SEO)
- Favicon configured (`icon`, `apple-touch-icon` in metadata or `/app/favicon.ico`)
- `theme-color` meta tag for mobile browsers

### 2e. Duplicate Detection
- Scan all pages and layouts for duplicate title/description combinations
- Flag pages that inherit layout metadata without overriding (might cause duplicates)

---

## PHASE 3: OPEN GRAPH & SOCIAL

### 3a. Open Graph Tags
For each page, check for:
- `og:title` (exists? matches or improves on `<title>`?)
- `og:description` (exists? compelling for social shares?)
- `og:image` (exists? proper dimensions?)
- `og:url` (exists? absolute URL?)
- `og:type` (exists? correct type — `website`, `article`, `product`?)
- `og:site_name` (set in root layout?)
- `og:locale` (set for international sites?)

### 3b. OG Image Validation
- OG images should be 1200x630 pixels (recommended by Facebook/LinkedIn)
- Images should be under 8MB
- Check if images are accessible (not behind auth, not broken URLs)
- Check for Next.js OG Image generation (`opengraph-image.tsx` or `twitter-image.tsx`)

### 3c. Twitter Card Tags
- `twitter:card` (summary, summary_large_image, app, player)
- `twitter:title`
- `twitter:description`
- `twitter:image`
- `twitter:site` (brand's Twitter handle)
- `twitter:creator` (author's handle, if applicable)

### 3d. Social Preview Testing
- Check if og:image URLs resolve to actual images (use WebFetch to verify)
- Note any pages missing social metadata entirely

---

## PHASE 4: STRUCTURED DATA (Schema.org)

### 4a. JSON-LD Presence
- Search for `<script type="application/ld+json">` in all pages/components
- Check if a JSON-LD helper/component exists (shared structured data component)
- Verify JSON-LD syntax is valid (parseable JSON)

### 4b. Recommended Schema Types
Based on the project type, check for these schemas:

**For SaaS / Business sites:**
- `Organization` (name, logo, url, sameAs for social profiles)
- `WebSite` (with `SearchAction` for sitelinks search box)
- `Product` or `SoftwareApplication` (for product/pricing pages)
- `FAQPage` (for FAQ sections)
- `BreadcrumbList` (for navigation breadcrumbs)
- `HowTo` (for tutorial/guide pages)

**For HoReCa / Restaurant / Review platforms:**
- `LocalBusiness` / `Restaurant`
- `Review` / `AggregateRating`
- `Menu` / `MenuItem`
- `FoodEstablishment`

**For content / blog sites:**
- `Article` / `BlogPosting`
- `Person` (for author pages)
- `ImageObject`

**For e-commerce:**
- `Product` with `Offer`
- `AggregateRating`
- `BreadcrumbList`

### 4c. Schema Validation
- Validate JSON-LD syntax (valid JSON, correct @context, correct @type)
- Check for required properties per schema type
- Search the web for "Google rich results supported structured data 2026" to verify types are still supported

### 4d. Missing Opportunities
- Identify pages that SHOULD have structured data but don't
- Suggest specific schema types for each page type in the project

---

## PHASE 5: HEADING HIERARCHY

For every page in the project:

### 5a. H1 Tag
- Exactly ONE `<h1>` per page (not zero, not multiple)
- H1 contains relevant keywords
- H1 is not empty or whitespace-only
- H1 is visible (not hidden with CSS)
- H1 is NOT the same as the `<title>` tag (should be related but not identical)

### 5b. Heading Structure
- Headings follow proper hierarchy: H1 > H2 > H3 > H4 (no skipping levels)
- No H3 without a preceding H2
- No H4 without a preceding H3
- Headings are semantic (used for structure, not just styling)

### 5c. Cross-Page Issues
- No duplicate H1s across different pages
- Layout components should NOT contain H1 (each page should define its own)

---

## PHASE 6: IMAGES & MEDIA

### 6a. Alt Text
- ALL images have `alt` attributes
- Alt text is descriptive (not "image1", "photo", "screenshot", "img", or empty string)
- Decorative images use `alt=""` (empty alt, not missing alt)
- Alt text includes relevant keywords where natural

### 6b. Next.js Image Component
- Check for raw `<img>` tags — should use `next/image` (`<Image>`) instead
- `next/image` provides automatic optimization, lazy loading, responsive sizing
- Flag every `<img>` tag that should be `<Image>`

### 6c. Image Optimization
- Images use modern formats (WebP/AVIF) or `next/image` handles conversion
- No unnecessarily large images (check for images > 500KB)
- `priority` prop used on above-the-fold images (LCP candidates)
- Proper `sizes` attribute on responsive images
- `width` and `height` set to prevent CLS (Cumulative Layout Shift)

### 6d. Lazy Loading
- Below-fold images are lazy loaded (default in `next/image`)
- Above-fold / hero images are NOT lazy loaded (use `priority` or `loading="eager"`)

### 6e. Broken Images
- Check for image `src` paths that reference files that don't exist in the project
- Check for hardcoded URLs to external images that might be broken

---

## PHASE 7: INTERNAL LINKING

### 7a. Navigation Structure
- Main navigation links to all important pages
- Footer contains links to key pages (about, contact, legal, sitemap)
- Breadcrumb navigation present on content/product pages

### 7b. Orphan Pages
- Identify pages that have NO internal links pointing to them
- Every page should be reachable through at least one internal link

### 7c. Link Quality
- Check for `<a>` tags (should use Next.js `<Link>` component for internal links)
- Anchor text is descriptive (not "click here", "read more", "link")
- No broken internal links (links to routes that don't exist)
- External links use `rel="noopener noreferrer"` and optionally `target="_blank"`
- External links to untrusted sites use `rel="nofollow"` where appropriate

### 7d. Link Component Usage
- Internal links use `next/link` (`<Link>`) for client-side navigation
- Raw `<a>` tags for internal links miss the SPA navigation benefit

---

## PHASE 8: MOBILE & RESPONSIVENESS

### 8a. Viewport Configuration
- `<meta name="viewport" content="width=device-width, initial-scale=1">` present
- No `maximum-scale=1` or `user-scalable=no` (blocks pinch-to-zoom — accessibility issue)

### 8b. Responsive Design Checks
- Check CSS for fixed-width elements (`width: 1200px` instead of `max-width`)
- Check for horizontal overflow potential (elements wider than viewport)
- Check for media queries or Tailwind responsive classes

### 8c. Touch & Readability
- Touch targets at least 48x48px (buttons, links, interactive elements)
- Base font size at least 16px (prevents iOS zoom on input focus)
- Line height at least 1.5 for body text
- Sufficient color contrast (WCAG AA: 4.5:1 for normal text)

### 8d. Mobile-Specific SEO
- No mobile-specific content differences that could trigger mobile-first indexing issues
- No interstitials / popups that cover content on mobile (Google penalizes this)
- Tap targets not too close together

---

## PHASE 9: INDEXABILITY & CRAWLABILITY

### 9a. Noindex/Nofollow Tags
- Search for `noindex`, `nofollow` meta robots tags
- Verify they are intentional (admin pages, auth pages = OK; public content = BAD)
- Check for `X-Robots-Tag` HTTP headers in middleware or next.config

### 9b. Client-Side Rendering Issues
- Identify pages where critical content is loaded via `useEffect` + `fetch` (invisible to crawlers)
- Content behind `useState` toggles (tabs, accordions) — is it in the initial HTML?
- Lazy-loaded content that requires user interaction to appear

### 9c. Authentication Gates
- Check if any public-facing content is behind authentication
- Verify marketing/landing pages are fully accessible without login
- Check for middleware redirects that might block crawlers

### 9d. JavaScript-Dependent Content
- Pages with `"use client"` that fetch and render all content client-side
- Components that use `dynamic(() => import(...), { ssr: false })` for important content
- Content loaded via client-side API calls that should be server-rendered

### 9e. Pagination & Infinite Scroll
- Check for paginated content — does it use proper `<link rel="next/prev">`?
- Infinite scroll pages — is content accessible via URL pagination?
- `loadMore` buttons that hide content from crawlers

---

## PHASE 10: PERFORMANCE IMPACT ON SEO

### 10a. Core Web Vitals
Search the web for current Core Web Vitals thresholds and check:

- **LCP (Largest Contentful Paint)**: Target < 2.5s
  - Check for large hero images without `priority`
  - Check for render-blocking CSS/JS
  - Check for slow server response (no dynamic rendering where static would work)

- **INP (Interaction to Next Paint)**: Target < 200ms (replaced FID in 2024)
  - Check for heavy JavaScript on interactive pages
  - Check for long tasks in event handlers
  - Check for `useTransition` usage for non-urgent updates

- **CLS (Cumulative Layout Shift)**: Target < 0.1
  - Images without `width`/`height` attributes
  - Dynamic content injected above existing content
  - Fonts causing layout shift (missing `font-display: swap`)
  - Ads/embeds without reserved space

### 10b. Resource Loading
- Check for render-blocking resources in `<head>`
- Check for proper code splitting (dynamic imports for heavy components)
- Check for unused JavaScript (`next/dynamic` for below-fold components)
- Check for `next/script` usage with proper `strategy` (afterInteractive, lazyOnload)

### 10c. Font Loading
- Fonts loaded with `next/font` (automatic optimization)
- Or fonts with `font-display: swap` / `font-display: optional`
- No FOUT (Flash of Unstyled Text) or FOIT (Flash of Invisible Text) issues
- Check for excessive font file sizes (subset fonts to used characters)

### 10d. Third-Party Scripts
- Identify all third-party scripts (analytics, ads, chat widgets, tracking pixels)
- Check if they're loaded with `next/script` and proper strategy
- Heavy third-party scripts should be lazy loaded
- Check for `defer` or `async` on script tags

---

## PHASE 11: INTERNATIONAL SEO (if applicable)

Check if the project has multi-language support:

### 11a. Language Configuration
- Check `next.config` for `i18n` configuration
- Check for `[locale]` dynamic segments in the app directory
- Check for middleware handling locale detection/routing

### 11b. Hreflang Tags
- `<link rel="alternate" hreflang="x">` tags for each language version
- `hreflang="x-default"` for the default/fallback language
- Hreflang tags are bidirectional (page A links to page B, page B links back to page A)
- Hreflang uses correct language codes (ISO 639-1)

### 11c. Content & URL Structure
- Language-specific URLs (`/en/about`, `/fr/about` or `en.example.com/about`)
- Consistent URL structure across languages
- No mixing of languages on a single page
- Translated meta tags (title, description) for each language version

### 11d. If NOT multi-language
- Verify `<html lang="en">` (or appropriate language) is set
- Note if the project SHOULD have multi-language support based on its audience

---

## PHASE 12: GENERATE FIX KIT

After completing ALL phases, generate a **SEO FIX KIT** with self-contained, copy-paste-ready prompts for each finding.

### Rules for generating fix prompts:

1. **One prompt per finding** (or group tightly related findings into one prompt)
2. **Order by impact** — CRITICAL first, then NEEDS WORK, then MISSING
3. **Each prompt must be fully self-contained** — the agent receiving it should NOT need any prior context from this audit. Include:
   - Exact file paths and line numbers
   - What the current (broken) code looks like
   - What the fixed code should look like (or clear instructions)
   - How to verify the fix worked
4. **Tag each prompt** with: severity, estimated complexity (quick/medium/complex), SEO impact (high/medium/low)
5. **For metadata fixes**: Show the exact metadata object/generateMetadata function to add
6. **For structured data**: Provide the complete JSON-LD script to add
7. **For new files** (sitemap, robots.txt): Provide the complete file content
8. **For image fixes**: List exact files and what needs to change

### Output format for each fix prompt:

```
---
### FIX-[number]: [Short title]
**Severity:** CRITICAL | NEEDS WORK | MISSING
**Type:** metadata | structured-data | config | component | new-file | performance
**SEO Impact:** high | medium | low
**Complexity:** quick (< 5 min) | medium (5-30 min) | complex (30+ min)
**Files:** [list of files to modify]

**Prompt (copy-paste this to a Claude Code agent):**

> [The full, self-contained prompt here. Written as if giving instructions to a fresh Claude Code session that knows nothing about this audit. Include all context, file paths, current code snippets, and expected outcome.]

**Verification:**
- [ ] [How to verify the fix — lighthouse check, manual inspection, validator tool, etc.]
---
```

### Write the fix kit file:

Create a file named `SEO-FIXES.md` in the project root (same directory as `package.json`). The file must contain:

1. **Header** with audit date, project name, overall SEO score, total findings count
2. **All fix prompts** ordered by severity (CRITICAL -> NEEDS WORK -> MISSING)
3. **Execution checklist** — a summary table with checkboxes for each fix
4. **Quick wins section** — fixes that take < 5 minutes and have high SEO impact
5. **Self-destruct instruction** at the end

### File format:

```markdown
# SEO Audit Fix Kit
**Project:** [name]
**Audit date:** [today]
**Overall SEO Score:** [X]/100
**Total findings:** [N] ([X] critical, [Y] needs work, [Z] missing)
**Generated by:** Claude SEO Auditor

> **Instructions:** Open a new Claude Code session in this project directory and paste individual FIX prompts below to resolve each finding. Check off each fix as you complete it. After ALL fixes are applied, re-run the SEO audit to verify improvements.

---

## Execution Checklist

| # | Severity | Title | Type | SEO Impact | Status |
|---|----------|-------|------|------------|--------|
| FIX-1 | CRITICAL | [title] | metadata | high | [ ] |
| FIX-2 | NEEDS WORK | [title] | config | medium | [ ] |
| ... | ... | ... | ... | ... | ... |

---

## QUICK WINS (< 5 min, high impact)

[List fixes that are fast and impactful — do these first]

---

## CRITICAL FIXES

[all critical fix prompts]

## NEEDS WORK FIXES

[all needs-work fix prompts]

## MISSING FIXES

[all missing fix prompts]

---

## Self-Destruct

> **IMPORTANT:** After ALL fixes above have been applied and verified with a follow-up audit, delete this file:
> ```
> rm SEO-FIXES.md
> ```
> This file is a working document and should NOT remain in the repository permanently. If you are an AI agent executing these fixes, delete this file as your final action after completing all fixes and verifying improvements.
```

### Additional rules:
- Add `SEO-FIXES.md` to `.gitignore` immediately after creation
- NEVER commit this file to git
- Each fix prompt must be fully self-contained

---

## OUTPUT FORMAT

After completing ALL phases, generate this report:

```
========================================
   SEO AUDIT REPORT
   Project: [name]
   Date: [today]
   Auditor: Claude SEO Auditor
========================================

## OVERALL SEO SCORE: [X]/100

Scoring breakdown:
- Technical Foundation: [X]/10
- Meta Tags & Head: [X]/15
- Open Graph & Social: [X]/10
- Structured Data: [X]/10
- Heading Hierarchy: [X]/10
- Images & Media: [X]/10
- Internal Linking: [X]/10
- Mobile & Responsiveness: [X]/5
- Indexability & Crawlability: [X]/10
- Performance (SEO impact): [X]/10

## EXECUTIVE SUMMARY
[2-3 sentence overview of SEO health]
[Biggest wins available, biggest risks]

## CATEGORY SCORES

| Category | Score | Rating |
|----------|-------|--------|
| Technical Foundation | [X]/10 | GOOD / NEEDS WORK / MISSING / CRITICAL |
| Meta Tags & Head | [X]/15 | GOOD / NEEDS WORK / MISSING / CRITICAL |
| Open Graph & Social | [X]/10 | GOOD / NEEDS WORK / MISSING / CRITICAL |
| Structured Data | [X]/10 | GOOD / NEEDS WORK / MISSING / CRITICAL |
| Heading Hierarchy | [X]/10 | GOOD / NEEDS WORK / MISSING / CRITICAL |
| Images & Media | [X]/10 | GOOD / NEEDS WORK / MISSING / CRITICAL |
| Internal Linking | [X]/10 | GOOD / NEEDS WORK / MISSING / CRITICAL |
| Mobile & Responsiveness | [X]/5 | GOOD / NEEDS WORK / MISSING / CRITICAL |
| Indexability & Crawlability | [X]/10 | GOOD / NEEDS WORK / MISSING / CRITICAL |
| Performance (SEO) | [X]/10 | GOOD / NEEDS WORK / MISSING / CRITICAL |

## CRITICAL FINDINGS (fix immediately — major ranking impact)
[numbered list with file:line references]

## NEEDS WORK FINDINGS (hurting SEO — fix before next deploy)
[numbered list with file:line references]

## MISSING FINDINGS (opportunities not implemented)
[numbered list with file:line references]

## GOOD PRACTICES FOUND
[what the project already does well — positive reinforcement]

## PAGE-BY-PAGE BREAKDOWN

### [Page path / route]
- Title: [value] ([length] chars) — GOOD / TOO LONG / MISSING
- Description: [value] ([length] chars) — GOOD / TOO LONG / TOO SHORT / MISSING
- H1: [value] — GOOD / MISSING / DUPLICATE / MULTIPLE
- OG tags: COMPLETE / PARTIAL / MISSING
- Structured data: [type] / MISSING
- Rendering: SSG / SSR / CSR
- Images: [X] total, [Y] missing alt, [Z] not using next/image

[Repeat for each page/route]

## TECHNICAL DETAILS

### Sitemap
- Status: EXISTS / MISSING
- Type: static / next-sitemap / app-router-convention
- Pages included: [count]
- Issues: [list]

### Robots.txt
- Status: EXISTS / MISSING
- Issues: [list]

### Structured Data
- Types found: [list]
- Valid: YES / NO / PARTIAL
- Missing opportunities: [list]

### Performance Flags
- Render-blocking resources: [list]
- Unoptimized images: [list]
- Missing font optimization: [details]
- Third-party script impact: [details]

### International SEO
- Multi-language: YES / NO
- Hreflang: CORRECT / MISSING / ERRORS
- HTML lang attribute: [value]

## COMPETITIVE QUICK WINS
[Top 5 changes that would have the biggest SEO impact for the least effort]

## AUDIT COVERAGE
[List which phases ran successfully and which were skipped or had limited coverage]
```

Every finding must include:
- Exact file path and line number
- What the issue is
- Why it matters for SEO (what ranking signal it affects)
- How to fix it (specific code change)
- Category rating (GOOD / NEEDS WORK / MISSING / CRITICAL)

---

START THE SEO AUDIT NOW. Use parallel agents for independent phases. Begin with Phase 0 (web research) in parallel with Phase 1 (technical foundation reconnaissance), then proceed through all phases systematically.
