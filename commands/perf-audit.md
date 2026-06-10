---
description: "Full performance audit: bundle size, Core Web Vitals, images, fonts, caching, SSR/SSG, DB queries, API response times, Lighthouse. Auto-researches latest standards."
allowed-tools: [Bash, Read, Glob, Grep, Agent, WebSearch, WebFetch, TaskCreate, TaskUpdate, TaskGet, TaskList, "mcp__claude_ai_SupaBase__*", "mcp__railway-mcp-server__*", "mcp__cloudflare__*"]
---

# MEGA PERFORMANCE AUDIT

You are a senior performance engineer performing a comprehensive performance audit on this Next.js project. Be thorough, quantitative, and report EVERYTHING that impacts performance. This is a full production-readiness performance review.

## INSTRUCTIONS

Run ALL phases below sequentially (some depend on earlier results). Use parallel agents where possible within each phase. Create tasks to track progress. At the end, produce a detailed PERFORMANCE REPORT with grades per category (A-F) and estimated impact for every fix.

---

## PHASE 0: RESEARCH LATEST STANDARDS

Before auditing, establish the current performance benchmarks and best practices.

### 0a. Search the web for:
- "Next.js 16 performance best practices 2026"
- "Core Web Vitals thresholds 2026"
- "React 19 performance optimization"
- "next/image best practices 2026"
- "React Server Components performance patterns"

### 0b. Update your audit checklist based on findings:
- Note any NEW Core Web Vitals metrics or changed thresholds
- Note any new Next.js features that supersede old patterns (e.g., Turbopack, PPR, partial prerendering)
- Note any React 19+ specific optimizations (use(), server functions, etc.)
- Note any deprecated patterns that should be replaced

Record a brief summary of what you found — include it in the final report under "Standards Used".

---

## PHASE 1: BUILD ANALYSIS

### 1a. Run the build
```bash
npm run build 2>&1
```
Capture the FULL output. If the build fails, report the failure and continue with static analysis only.

### 1b. Analyze build output
- **Per-route sizes**: For each route, note the JS size and whether it's static (SSG), dynamic (SSR), or ISR
- **Total First Load JS**: Should be under 100KB. Flag anything over 80KB as a warning, over 120KB as critical.
- **Largest pages/chunks**: Identify the top 5 heaviest routes and why they are heavy
- **Build time**: Note total build time — excessive build time often indicates unoptimized imports

### 1c. Code splitting analysis
- Search for barrel imports (importing from index files that re-export everything):
  ```
  import { something } from '@/components'
  import { something } from '@/lib'
  import { something } from '@/utils'
  ```
  These prevent tree-shaking. Each should import from the specific file.
- Check for `import * as` patterns that pull in entire modules
- Check for default exports vs named exports (named exports tree-shake better)

### 1d. Heavy dependency detection
Search `package.json` for known heavy libraries and suggest lighter alternatives:
- `moment` or `moment-timezone` → `date-fns` or `dayjs` (saves ~200KB)
- `lodash` (full) → `lodash-es` or native methods or individual imports `lodash/get` (saves ~70KB)
- `axios` → native `fetch` (saves ~13KB, Next.js extends fetch anyway)
- `classnames` → `clsx` (saves ~2KB)
- `uuid` → `crypto.randomUUID()` (native, saves ~8KB)
- `node-fetch` → native `fetch` (available in Node 18+)
- `animate.css` → CSS animations or Framer Motion (if already used)
- `font-awesome` → `lucide-react` or `@heroicons/react` (SVG, tree-shakeable)
- `react-icons` full import → import from specific set `react-icons/fi`
- Any charting library → check if a lighter one exists

---

## PHASE 2: BUNDLE ANALYSIS

### 2a. JS Bundle Size
- Check `.next/` output if build succeeded
- Look for the `_app` and `_document` chunks (or `layout` in App Router)
- Total JS for initial page load: target < 200KB gzipped
- Check for any single chunk over 50KB gzipped (should be code-split)

### 2b. CSS Bundle Size
- Check for Tailwind CSS — is purging configured? (content paths in `tailwind.config.js`)
- Check for unused CSS (global stylesheets imported but partially used)
- Check for duplicate CSS from component libraries
- Check total CSS size — should be under 50KB gzipped for initial load

### 2c. Heaviest node_modules
```bash
# Check largest dependencies (if du is available)
du -sh node_modules/* 2>/dev/null | sort -rh | head -20
```
- Flag any dependency over 10MB in node_modules
- Cross-reference with what actually ends up in the client bundle (server-only deps are fine to be large)

### 2d. Duplicate dependencies
```bash
# Check for duplicates
npm ls --all 2>/dev/null | grep -i "deduped" | wc -l
npm ls --all 2>/dev/null | grep -i "UNMET" | head -20
```
- Multiple versions of the same package inflate bundles
- Look for `react` appearing more than once (common cause of bugs AND bloat)

### 2e. Client/Server boundary analysis
Search for `"use client"` directives:
- How many files have `"use client"`?
- Are any of them high in the component tree? (e.g., in layouts — this forces the entire subtree to be client-rendered)
- Could any `"use client"` be pushed DOWN to a smaller child component?
- Are there imports of heavy libraries in `"use client"` files that could be dynamically imported?

### 2f. Dynamic imports
Search for `next/dynamic` and `React.lazy` usage:
- Are heavy components (charts, maps, editors, modals) dynamically imported?
- Is `ssr: false` used where appropriate (for client-only components like maps)?
- Are loading states provided for dynamic imports?

---

## PHASE 3: RENDERING STRATEGY

### 3a. Route inventory
For every route in the `app/` or `pages/` directory, determine:
- **Static (SSG)**: No `getServerSideProps`, no dynamic data fetching at request time, no `cookies()`, no `headers()`
- **SSR**: Uses `getServerSideProps` or reads `cookies()`/`headers()` or has `export const dynamic = 'force-dynamic'`
- **ISR**: Uses `revalidate` with a time interval
- **Client-side**: Heavy use of `useEffect` + fetch on mount

### 3b. Identify SSR-to-SSG opportunities
Pages that are SSR but could be static or ISR:
- Pages that fetch data that changes infrequently (blog posts, product listings, etc.)
- Pages where the dynamic data is user-independent (same for all users)
- Flag any page using `force-dynamic` without a clear reason

### 3c. React Server Components (RSC) usage
- Are data-fetching components Server Components? (They should be — no `"use client"`)
- Is there `"use client"` on components that only need it for a small interactive part? (Extract the interactive part)
- Are Server Actions used for form submissions? (vs API routes — Server Actions are more efficient)

### 3d. Streaming & Suspense
- Are `loading.tsx` files present for route segments? (enables streaming)
- Are `<Suspense>` boundaries used for slow data fetches? (enables partial rendering)
- Are there heavy server components that block the entire page? (should be wrapped in Suspense)

### 3e. Middleware performance
- Read `middleware.ts` — is it doing heavy work? (Middleware runs on EVERY request in its matcher)
- Is middleware doing database queries? (It should NOT — use edge-compatible checks only)
- Is the matcher too broad? (e.g., matching all routes when only `/dashboard/*` needs auth)
- Is middleware doing redirects that could be handled by `next.config.js` redirects? (static is faster)

---

## PHASE 4: IMAGE OPTIMIZATION

### 4a. Image component usage
Search for all image rendering in the codebase:
- `<img` tags — should use `next/image` instead (flag every raw `<img>`)
- `<Image` from `next/image` — check props:
  - Has `width` + `height` OR `fill` prop? (prevents CLS)
  - Has `alt` text? (accessibility + SEO)
  - Has `priority` on above-fold hero images? (improves LCP)
  - Has `placeholder="blur"` + `blurDataURL` on large images? (better perceived loading)
  - Has `sizes` prop when using `fill`? (prevents downloading oversized images)

### 4b. Image formats
- Search for `.png`, `.jpg`, `.jpeg`, `.gif` references
- Are they in `/public` without optimization? (Next.js optimizes via `next/image` but not raw URLs)
- Could any be converted to WebP/AVIF?
- Are there SVGs that could be inlined for icons? (`@svgr/webpack`)

### 4c. Image sizes
- Check `/public` directory for oversized images
```bash
# Find large image files
find . -path ./node_modules -prune -o \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.gif" -o -name "*.webp" \) -size +500k -print 2>/dev/null
```
- Images over 500KB should be compressed or resized
- Images over 2MB are almost certainly a problem

### 4d. Lazy loading
- Are below-fold images using `loading="lazy"` (default in next/image)?
- Is `priority` set ONLY on the hero/LCP image? (Too many `priority` images defeat the purpose)
- Are there image carousels loading all images eagerly?

---

## PHASE 5: FONT OPTIMIZATION

### 5a. Font loading method
Search for font usage:
- `next/font/google` or `next/font/local` — GOOD (automatic optimization)
- Manual `@font-face` in CSS — check for proper `font-display: swap` or `font-display: optional`
- Google Fonts via `<link>` tag — BAD (render-blocking, no subsetting)
- Font loaded from CDN without preload — BAD

### 5b. Font count
- Count total font files loaded (check Network tab equivalent — search for .woff, .woff2, .ttf, .otf)
- More than 4-5 font files is excessive
- Are all variants actually used? (loading bold+italic when only regular is used)

### 5c. Font subsetting
- Check if fonts are subset to needed characters (Latin only for English sites)
- `next/font` does this automatically — verify it's being used
- Custom fonts should use `unicode-range` in `@font-face`

### 5d. FOUT/FOIT prevention
- `font-display: swap` — shows fallback font immediately, swaps when loaded (good for body text)
- `font-display: optional` — skips font entirely if slow (best for non-critical fonts)
- Check for layout shift caused by font swap (metric for CLS)

---

## PHASE 6: CACHING & HEADERS

### 6a. Static asset caching
Check `next.config.js` for custom headers:
- `/_next/static/*` should have long Cache-Control (immutable, max-age=31536000)
- Next.js does this by default — verify it's not overridden
- Public assets in `/public` — are they cache-busted? (filename hashing or query strings)

### 6b. API response caching
- Check API routes for `Cache-Control` headers
- Check for `revalidate` in `fetch()` calls (Next.js extended fetch)
- Check for in-memory caching (e.g., `unstable_cache`, `cache()` from React)
- Check for Redis/Upstash caching on expensive queries
- Look for `no-store` on fetch calls that COULD be cached

### 6c. ISR configuration
- Check `revalidate` values on static pages:
  - Too low (< 60s) = hammering the server
  - Too high (> 86400) = stale data for users
  - Missing entirely on pages that should have it = fully static or fully dynamic
- Check for `revalidatePath()` / `revalidateTag()` usage for on-demand revalidation

### 6d. CDN & edge caching
- If using Cloudflare: check caching rules via MCP
- If using Vercel: check edge caching configuration
- If using Railway: check if static assets are served via CDN or directly from the container (should be CDN)
- Check for `stale-while-revalidate` pattern in cache headers

### 6e. ETag and conditional requests
- Are ETags enabled? (helps with 304 Not Modified responses)
- Check if the server sends `Last-Modified` headers for static content

### 6f. Application-level cache (cache-aside) correctness
The HTTP/CDN checks above are about *transport* caching. This is about an explicit cache in front of the DB (Redis / Upstash / in-memory / `unstable_cache` / `react cache`):
- **Cache-aside pattern correct?** read → on miss, fetch from DB → write to cache → return; on hit, return. Flag ad-hoc caching that never invalidates.
- **Invalidation strategy**: how is a cached value cleared/updated on write? Stale-forever cache is worse than no cache. Look for writes that update the DB but not (or wrongly) the cache.
- **TTL chosen deliberately** per data volatility (file metadata = long; live counts = short), not a blanket default.
- **Cache stampede / thundering herd**: when a hot key expires, do N concurrent requests all hit the DB at once? (mitigate with single-flight / lock / `stale-while-revalidate` / jittered TTL).
- **What's cached**: small, hot, rarely-changing values (metadata, config, computed aggregates) — NOT large blobs/files in an in-memory KV (RAM is expensive and Redis isn't built to stream large objects; serve those via object storage + CDN, see 6g).
- **Key design**: keys include tenant/auth scope so one user's cached response can't be served to another.
- **Pre-computation**: expensive computations (reports, aggregates) cached/materialized rather than recomputed per request.

### 6g. Large files & object-storage offload
Large uploads/downloads streamed *through* the app server hurt latency, memory, and reliability — and are an architectural smell, not just a perf one:
- **Uploads**: are large files streamed through your API/server, or offloaded to object storage (S3 / GCS / Supabase Storage / R2) via **signed/presigned URLs** so the client uploads directly to the bucket? Direct-to-bucket bypasses your compute entirely (faster + cheaper + safer). Flag any handler buffering/streaming multi-MB bodies through the server or into the relational DB.
- **Metadata vs blob split**: file *metadata* (id, name, size, type, owner) in the DB; the *bytes* in object storage — never the blob in Postgres.
- **Downloads/serving**: served via CDN / signed URLs / range requests, not proxied byte-by-byte through the origin.
- **Signed-URL hygiene**: short expiry, size/content-type constraints (this is a perf+security win — cross-ref `attack-surface` / `security-audit`).
- Image assets specifically: also covered by Phase 4, but confirm they're on a CDN edge, not the origin container.

---

## PHASE 7: DATABASE & API PERFORMANCE

### 7a. N+1 query detection
Search for patterns like:
```javascript
// BAD: N+1 — query in a loop
for (const item of items) {
  const details = await db.query('SELECT * FROM details WHERE item_id = ?', item.id)
}

// GOOD: Single query with IN clause
const details = await db.query('SELECT * FROM details WHERE item_id IN (?)', itemIds)
```
Also check for:
- `.map()` with `await` inside (sequential queries)
- Multiple sequential `supabase.from('table').select()` that could be joined
- Prisma queries in loops

### 7b. Overfetching
Search for `SELECT *` patterns or Supabase `.select('*')` / `.select()` with no columns:
- Should only select needed columns
- Check for large text/blob columns being fetched unnecessarily
- Check for relations being eagerly loaded when not needed

### 7c. Missing pagination
Search for queries that return all rows:
- No `.limit()` or `.range()` on list queries
- No pagination params in API endpoints that return collections
- Tables that could grow unbounded (logs, events, messages)

### 7d. Sequential vs parallel queries
Search for multiple `await` statements that could be `Promise.all`:
```javascript
// BAD: Sequential (total time = sum)
const users = await getUsers()
const posts = await getPosts()
const comments = await getComments()

// GOOD: Parallel (total time = max)
const [users, posts, comments] = await Promise.all([
  getUsers(), getPosts(), getComments()
])
```

### 7e. Connection pooling
- Check Supabase client initialization — is it a singleton?
- Check for new client instances created per request (should reuse)
- If using Prisma, check for the `global` prisma pattern

### 7f. Database indexes (via Supabase MCP if available)
If Supabase MCP is available, run:
```sql
-- Tables with no indexes
SELECT tablename FROM pg_tables
WHERE schemaname = 'public'
AND tablename NOT IN (SELECT DISTINCT tablename FROM pg_indexes WHERE schemaname = 'public');

-- Slow queries (if pg_stat_statements is available)
SELECT query, calls, mean_exec_time, total_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC LIMIT 20;

-- Missing indexes on foreign keys
SELECT
  tc.table_name, kcu.column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
AND tc.table_schema = 'public'
AND kcu.column_name NOT IN (
  SELECT a.attname FROM pg_index i
  JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
  JOIN pg_class c ON c.oid = i.indrelid
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
);

-- Table sizes
SELECT relname, pg_size_pretty(pg_total_relation_size(relid))
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(relid) DESC;
```

### 7g. Supabase-specific patterns
- Check for `realtime` subscriptions where polling would suffice (realtime has overhead)
- Check for polling where `realtime` would be better (frequent polling wastes resources)
- Check for RPC functions that do heavy computation — could they be optimized?
- Check for PostgREST query patterns that generate inefficient SQL

### 7h. API response times (via Railway MCP if available)
If Railway MCP is available:
- Check logs for slow API responses (> 500ms)
- Check for timeout errors
- Check for cold start patterns (first request after idle is slow)

---

## PHASE 8: CLIENT-SIDE PERFORMANCE

### 8a. Re-render analysis
Search for components that likely cause unnecessary re-renders:
- Large parent components that pass new object/array literals as props on every render:
  ```jsx
  // BAD: New object every render
  <Child style={{ color: 'red' }} />
  <Child data={items.filter(i => i.active)} />
  <Child onClick={() => handleClick(id)} />
  ```
- Missing `useMemo` on expensive computations (array sorting, filtering, transformations)
- Missing `useCallback` on callback props passed to memoized children
- State that changes frequently in a high-level component (pushes re-renders down the entire tree)
- Context providers with large value objects that change often (causes all consumers to re-render)

### 8b. Heavy render-path computations
- Regex compilation on every render (should be outside component or `useMemo`)
- Date formatting on every render for static dates
- JSON.parse/stringify on every render
- Large list sorting/filtering without memoization

### 8c. Memory leaks
Search for:
- `useEffect` with subscriptions/listeners but no cleanup return function
- `setInterval` / `setTimeout` without cleanup
- Event listeners added in `useEffect` without `removeEventListener` in cleanup
- WebSocket connections without close in cleanup
- Supabase realtime subscriptions without `.unsubscribe()` in cleanup

### 8d. List virtualization
- Are there lists rendering 50+ items? (Check `.map()` in JSX)
- If so, are they using virtualization? (`react-window`, `react-virtuoso`, `@tanstack/react-virtual`)
- Tables with 100+ rows should use pagination or virtualization

### 8e. Event handler optimization
- Scroll handlers without `throttle` or `requestAnimationFrame`
- Resize handlers without `debounce`
- Input/search handlers without `debounce` (firing API calls on every keystroke)
- Mousemove/touchmove handlers on the main thread

### 8f. useEffect patterns
- Unnecessary `useEffect` — could the logic be in an event handler instead? (React docs: "You might not need an effect")
- Missing dependencies in the dependency array (stale closures = bugs)
- Effects that run on every render because they have `[]` but should have deps, or have deps but shouldn't
- Effects that could be replaced by `useSyncExternalStore` for external state

---

## PHASE 9: NETWORK PERFORMANCE

### 9a. Unnecessary API calls
- Data fetched on mount but never displayed
- Same data fetched multiple times on the same page (by different components)
- Data fetched client-side that could be fetched server-side (RSC)

### 9b. Request waterfalls
- Sequential fetches where the second depends on the first but doesn't need to:
  ```javascript
  // BAD: Waterfall
  const user = await fetch('/api/user')
  const posts = await fetch('/api/posts') // Doesn't depend on user
  ```
- Client components that each make their own API call on mount (waterfall of fetches)
- Nested layouts each doing independent data fetches that resolve sequentially

### 9c. Prefetching
- Check `<Link>` usage — `prefetch` is enabled by default in production (verify not disabled)
- Check for manual `router.prefetch()` on high-priority navigations
- Check for `<link rel="preload">` on critical resources (hero images, fonts, above-fold CSS)
- Check for DNS prefetch on third-party domains (`<link rel="dns-prefetch">`)

### 9d. External scripts
Search for `<script>` tags in `_document`, `layout`, or components:
- Third-party scripts without `async` or `defer` (render-blocking!)
- Analytics, chat widgets, tracking pixels — are they loaded with `next/script` using `strategy="lazyOnload"` or `strategy="afterInteractive"`?
- Multiple scripts from the same provider that could be consolidated

### 9e. Service Worker / PWA
- Is there a service worker for caching? (`next-pwa`, `@serwist/next`, custom)
- If PWA: are critical assets pre-cached?
- Is there offline support where it makes sense?

### 9f. HTTP protocol
- Check if HTTP/2 is supported (multiplexing reduces waterfall impact)
- Check for HTTP/3 / QUIC support
- Check if the server sends proper `Connection: keep-alive`

---

## PHASE 10: CORE WEB VITALS PREDICTION

Based on ALL previous analysis, predict the Core Web Vitals scores. For each metric, identify the specific bottleneck.

### 10a. LCP (Largest Contentful Paint)
**Target: < 2.5s** (Good), **2.5-4s** (Needs Improvement), **> 4s** (Poor)

Identify the LCP element for key pages (usually: hero image, main heading, or large text block):
- Is the LCP image using `priority` prop? (Preloads the image)
- Is the LCP element blocked by render-blocking resources? (CSS, fonts, scripts)
- Is the server response fast? (TTFB directly impacts LCP)
- Is there a long chain: TTFB → CSS → Font → Render? (Each adds delay)
- Are there client-side redirects before the page loads?

### 10b. INP (Interaction to Next Paint)
**Target: < 200ms** (Good), **200-500ms** (Needs Improvement), **> 500ms** (Poor)

Check for long tasks that block the main thread:
- Heavy JavaScript execution on page load (hydration of large component trees)
- Synchronous operations in event handlers (sorting, filtering, complex calculations)
- Event handlers that trigger expensive re-renders
- Third-party scripts blocking the main thread
- Long hydration times (too much client-side JS)

### 10c. CLS (Cumulative Layout Shift)
**Target: < 0.1** (Good), **0.1-0.25** (Needs Improvement), **> 0.25** (Poor)

Check for layout shift causes:
- Images without width/height or `fill` (browser can't reserve space)
- Dynamic content injected after load (banners, alerts, cookie consent)
- Fonts causing layout shift (no `font-display: swap` or missing size-adjust)
- Ads or embeds without reserved space
- Client-side navigation updating content areas with different sizes

### 10d. TTFB (Time to First Byte)
**Target: < 800ms** (Good), **800ms-1.8s** (Needs Improvement), **> 1.8s** (Poor)

Check for TTFB issues:
- Heavy SSR pages with slow database queries
- Middleware doing expensive operations
- No edge caching for cacheable pages
- Server in wrong region (far from users)
- Cold starts on serverless (Railway, Vercel, Lambda)

### 10e. FCP (First Contentful Paint)
**Target: < 1.8s** (Good), **1.8s-3s** (Needs Improvement), **> 3s** (Poor)

Check for FCP blockers:
- Render-blocking CSS (large global stylesheets)
- Render-blocking scripts (without async/defer)
- Large HTML document size
- No streaming (missing Suspense boundaries)

---

## PHASE 11: LIVE INFRASTRUCTURE CHECK

**IMPORTANT**: Only run checks for services that have MCP tools available in this session. Skip sections where the MCP server is not connected. These are READ-ONLY checks — do NOT modify anything on live infrastructure.

### 11a. Railway (if `mcp__railway-mcp-server__*` tools available)

1. **Deployment region**:
   - Check what region the service is deployed to
   - Is it close to the primary user base?
   - Multi-region deployment for global users?

2. **Build caching**:
   - Check if Nixpacks/Docker build caching is enabled
   - Check build times in deployment history — are they consistent or varying wildly?

3. **Cold starts**:
   - Check logs for cold start patterns (first request after idle)
   - Check if the service has a health check configured (keeps it warm)
   - Check min instances configuration (0 = cold starts possible)

4. **Resource allocation**:
   - Check memory usage vs limits
   - Check CPU usage patterns
   - Are there OOM (Out of Memory) kills in logs?

5. **Environment variables**:
   - Is `NODE_ENV=production` set? (Missing = dev mode performance)
   - Check for `NEXT_TELEMETRY_DISABLED=1` (minor, but reduces noise)

### 11b. Supabase (if `mcp__claude_ai_SupaBase__*` tools available)

1. **Get advisors** (`get_advisors`):
   - Check for performance-related recommendations
   - Check for missing indexes suggestions
   - Check for bloated tables / unused indexes

2. **Check slow queries** (via `execute_sql`):
   ```sql
   -- Connection count
   SELECT count(*) FROM pg_stat_activity WHERE state = 'active';

   -- Table sizes and dead tuples (need VACUUM?)
   SELECT relname, n_live_tup, n_dead_tup, last_vacuum, last_autovacuum
   FROM pg_stat_user_tables
   ORDER BY n_dead_tup DESC LIMIT 10;

   -- Index usage statistics
   SELECT relname, indexrelname, idx_scan, idx_tup_read, idx_tup_fetch
   FROM pg_stat_user_indexes
   WHERE idx_scan = 0 AND schemaname = 'public'
   ORDER BY relname;

   -- Cache hit ratio (should be > 99%)
   SELECT
     sum(heap_blks_read) as heap_read,
     sum(heap_blks_hit) as heap_hit,
     CASE WHEN sum(heap_blks_hit) + sum(heap_blks_read) > 0
       THEN round(sum(heap_blks_hit)::numeric / (sum(heap_blks_hit) + sum(heap_blks_read)) * 100, 2)
       ELSE 100 END as cache_hit_ratio
   FROM pg_statio_user_tables;
   ```

3. **Check for connection pooling** — is PgBouncer/Supavisor configured?
   - Direct connections vs pooler connections
   - Connection string using port 6543 (pooler) vs 5432 (direct)?

4. **Check logs** (`get_logs`):
   - Slow query log entries
   - Connection errors / timeouts
   - Rate limiting events

### 11c. Cloudflare (if `mcp__cloudflare__*` tools available)

1. **Caching configuration**:
   - Cache rules for static assets (JS, CSS, images, fonts)
   - Browser TTL settings
   - Edge TTL settings
   - Cache hit rate statistics

2. **Minification**:
   - Auto-minification enabled for JS, CSS, HTML?
   - Brotli compression enabled?
   - Early Hints enabled? (103 status code for preloading)

3. **Performance features**:
   - Rocket Loader enabled? (async JS loading)
   - Polish (image optimization) enabled?
   - Mirage (image lazy loading) enabled?
   - HTTP/2 and HTTP/3 enabled?
   - 0-RTT connection resumption?

4. **Edge optimization**:
   - Are there Cloudflare Workers that could cache dynamic content at the edge?
   - Page Rules for performance (cache level, edge TTL)

---

## PHASE 12: GENERATE FIX KIT

After completing ALL phases, write the results and fix kit to a file in the project root.

### File creation

Create a file named `PERF-FIXES.md` in the project root (same directory as `package.json`). The file must contain all fix prompts and the full report.

### Add to .gitignore

Immediately after creating the file, add `PERF-FIXES.md` to `.gitignore` (create `.gitignore` if it doesn't exist).

---

## OUTPUT FORMAT

After completing ALL phases, generate this report:

```
========================================
   PERFORMANCE AUDIT REPORT
   Project: [name]
   Date: [today]
   Auditor: Claude Performance Scanner
========================================

## STANDARDS USED
[Brief summary of latest standards researched in Phase 0]
[Core Web Vitals thresholds applied]
[Next.js version-specific guidance]

## EXECUTIVE SUMMARY
[2-3 sentence overview of performance posture]
[Overall Performance Grade: A-F]
[Estimated total savings: Xms load time, XKB bundle size]

## SCORECARD

| Category | Grade | Key Issue | Est. Impact |
|----------|-------|-----------|-------------|
| Build & Bundle | A-F | [biggest issue] | -XKB / -Xms |
| Rendering Strategy | A-F | [biggest issue] | -Xms |
| Image Optimization | A-F | [biggest issue] | -XKB / -Xms |
| Font Optimization | A-F | [biggest issue] | -Xms |
| Caching & Headers | A-F | [biggest issue] | -Xms |
| DB & API Performance | A-F | [biggest issue] | -Xms |
| Client-Side Perf | A-F | [biggest issue] | -Xms |
| Network Performance | A-F | [biggest issue] | -Xms |
| Core Web Vitals (predicted) | A-F | [biggest issue] | varies |
| Infrastructure | A-F | [biggest issue] | -Xms |

## CRITICAL FINDINGS (fix immediately — major user impact)
[numbered list with file:line references and estimated impact]

## HIGH FINDINGS (fix before next deploy)
[numbered list with file:line references and estimated impact]

## MEDIUM FINDINGS (fix soon — noticeable improvement)
[numbered list with file:line references and estimated impact]

## LOW FINDINGS (fix when convenient — marginal improvement)
[numbered list with file:line references and estimated impact]

## BUILD ANALYSIS
- Total First Load JS: [X]KB ([gzipped])
- Build time: [X]s
- Largest routes: [table]
- Code splitting issues: [list]
- Heavy dependencies: [list with sizes and alternatives]

## BUNDLE BREAKDOWN
- Client JS total: [X]KB gzipped
- CSS total: [X]KB gzipped
- "use client" files: [count], [issues]
- Dynamic imports: [count], [missing opportunities]

## RENDERING STRATEGY
[Table: route | type (SSG/SSR/ISR/CSR) | recommendation]

## IMAGE AUDIT
- Total images found: [X]
- Using next/image: [X] / [total]
- Raw <img> tags: [X] (should be 0)
- Oversized images: [list]
- Missing priority on LCP: [list]
- Missing dimensions: [list]

## FONT AUDIT
- Loading method: [next/font | manual | CDN]
- Font files: [count]
- font-display: [value]
- Subsetting: [yes/no]

## CACHING STATUS
- Static asset caching: [configured/missing]
- API caching: [configured/missing]
- ISR pages: [count], revalidation: [times]
- CDN caching: [configured/missing]
- App cache-aside: [present? invalidation correct? stampede-safe?]
- Object-storage offload: [large files via signed URLs / direct-to-bucket? or streamed through server?]

## DATABASE & API
- N+1 queries found: [count]
- Missing indexes: [list]
- Sequential-to-parallel opportunities: [count]
- Overfetching: [count]
- Missing pagination: [count]

## CLIENT-SIDE ISSUES
- Re-render risks: [count]
- Memory leaks: [count]
- Missing virtualization: [count]
- Missing debounce/throttle: [count]

## NETWORK
- Render-blocking scripts: [count]
- Missing prefetch: [count]
- Request waterfalls: [count]
- External scripts: [list with strategy]

## CORE WEB VITALS PREDICTION
| Metric | Predicted | Target | Status |
|--------|-----------|--------|--------|
| LCP | Xms | < 2500ms | GOOD/NEEDS WORK/POOR |
| INP | Xms | < 200ms | GOOD/NEEDS WORK/POOR |
| CLS | X.XX | < 0.1 | GOOD/NEEDS WORK/POOR |
| TTFB | Xms | < 800ms | GOOD/NEEDS WORK/POOR |
| FCP | Xms | < 1800ms | GOOD/NEEDS WORK/POOR |

[For each metric: identify the LCP element, INP bottleneck, CLS cause, TTFB chain]

## LIVE INFRASTRUCTURE
[Only sections where MCP was available]

### Railway
- Region: [X]
- Cold starts: [yes/no, frequency]
- Memory: [usage/limit]
- Build time: [X]

### Supabase
- Cache hit ratio: [X]%
- Active connections: [X]
- Unused indexes: [count]
- Dead tuples: [need VACUUM?]
- Advisors: [summary]

### Cloudflare
- Caching: [hit rate]%
- Compression: [brotli/gzip]
- HTTP version: [2/3]
- Performance features: [list]

## ACTION ITEMS (prioritized by impact)
1. [highest impact fix — estimated savings]
2. [second highest]
...

## WHAT'S GOOD
[Positive performance practices already in place — acknowledge good patterns]

## AUDIT COVERAGE
[List which phases ran successfully and which were skipped (e.g., build failed, no MCP available)]
```

Every finding must include:
- Exact file path and line number
- What the performance issue is
- Why it matters (quantified impact where possible)
- How to fix it (specific code suggestion)
- Estimated savings (KB or ms)
- Severity grade

---

## FIX KIT FORMAT

Generate a fix kit with the same format as the security audit. Each fix prompt must be:

```
---
### FIX-[number]: [Short title]
**Severity:** CRITICAL | HIGH | MEDIUM | LOW
**Type:** code | config | npm-command | sql | infra | external-action
**Complexity:** quick (< 5 min) | medium (5-30 min) | complex (30+ min)
**Estimated Impact:** -XKB bundle | -Xms load time | -X CLS score
**Files:** [list of files to modify]

**Prompt (copy-paste this to a Claude Code agent):**

> [The full, self-contained prompt here. Written as if you're giving instructions to a fresh Claude Code session that knows nothing about this audit. Include all context, file paths, current code snippets, and expected outcome.]

**Verification:**
- [ ] [How to verify the fix — run build, check output, measure, etc.]
---
```

### Fix prompt ordering:
1. **Quick wins first within each severity** — fixes that save the most with the least effort
2. Then by estimated impact (biggest savings first)
3. Group related fixes when they touch the same file

### Special categories:
- **Bundle fixes**: Include exact import changes (before/after)
- **Image fixes**: Include exact component prop changes
- **Database fixes**: Include exact SQL for indexes/optimizations
- **Config fixes**: Include exact config file changes
- **Dependency swaps**: Include exact `npm uninstall X && npm install Y` commands
- **Infrastructure fixes**: Mark as "MANUAL" with dashboard instructions

---

## PERF-FIXES.md FILE FORMAT

```markdown
# Performance Audit Fix Kit
**Project:** [name]
**Audit date:** [today]
**Total findings:** [N] ([X] critical, [Y] high, [Z] medium, [W] low)
**Estimated total savings:** -XKB bundle, -Xms load time
**Generated by:** Claude Performance Scanner

> **Instructions:** Open a new Claude Code session in this project directory and paste individual FIX prompts below to resolve each finding. Check off each fix as you complete it. Re-run `npm run build` after each fix to verify the improvement. After ALL fixes are applied and verified, delete this file.

---

## Execution Checklist

| # | Severity | Title | Type | Impact | Status |
|---|----------|-------|------|--------|--------|
| FIX-1 | CRITICAL | [title] | code | -XKB | [ ] |
| FIX-2 | HIGH | [title] | config | -Xms | [ ] |
| ... | ... | ... | ... | ... | ... |

---

## CRITICAL FIXES
[all critical fix prompts here]

## HIGH FIXES
[all high fix prompts]

## MEDIUM FIXES
[all medium fix prompts]

## LOW FIXES
[all low fix prompts]

---

## EXTERNAL ACTIONS (Manual - cannot be automated)

These require manual intervention in web dashboards:

1. **[title]** — [step-by-step instructions]
2. ...

---

## Re-Audit Verification

After applying all fixes, verify improvements:
1. Run `npm run build` and compare total JS size to pre-fix build
2. Run Lighthouse audit and compare scores
3. Check Core Web Vitals in Chrome DevTools Performance tab
4. Monitor real-user metrics for 48 hours via analytics

---

## Self-Destruct

> **IMPORTANT:** After ALL fixes above have been applied and verified, delete this file:
> ```
> rm PERF-FIXES.md
> ```
> This file contains detailed analysis of your application's performance weaknesses and should NOT remain in the repository. If you are an AI agent executing these fixes, delete this file as your final action after completing all fixes. If any fixes marked as "external-action" cannot be completed by an agent, leave ONLY those items in the file and delete everything else.
```

### Additional rules:
- The `PERF-FIXES.md` file MUST be added to `.gitignore` immediately after creation.
- If a `.gitignore` doesn't exist, create one with at least `PERF-FIXES.md` in it.
- NEVER commit this file to git — it contains detailed internal architecture analysis.
- Each fix prompt inside the file must be fully self-contained.
- Include exact before/after code diffs wherever possible.

START THE AUDIT NOW. Use parallel agents for independent phases where possible.
