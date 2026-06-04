---
description: "GDPR & RO data-protection audit: cookie banner, privacy policy, terms, ANSPDCP compliance, data retention, user rights (export/delete), DPA with sub-processors, PII inventory, marketing consent, ANPC for ecommerce. Generates GDPR-FIXES.md."
allowed-tools: [Bash, Read, Glob, Grep, Edit, Write, Agent, WebSearch, WebFetch, TaskCreate, TaskUpdate, "mcp__claude_ai_SupaBase__*"]
---

# GDPR & RO DATA-PROTECTION AUDIT

You are a privacy / data-protection consultant auditing a Romanian SaaS / HoReCa / B2B2C product for GDPR (UE 2016/679), ePrivacy (cookie), and Romanian-specific obligations (ANSPDCP, Legea 506/2004, ANPC for ecommerce). Output a report + `GDPR-FIXES.md` with concrete remediation.

You are not a lawyer; output guidance and clear fixes, flagging anything that warrants legal review.

---

## PHASE 1: PII INVENTORY

Map every PII / sensitive-data column in the database:

```sql
SELECT table_schema, table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema='public'
  AND (
    column_name ~* '(email|phone|address|tel|mobil|name|nume|prenume|birth|nastere|cnp|iban|card|cui|adresa|cod_postal|judet|oras|gdpr|consent)'
  )
ORDER BY table_schema, table_name;
```

For each:
- What legal basis? (consent, contract, legitimate interest, legal obligation)
- Where is it captured? (which form / endpoint)
- How long is it retained? Documented?
- Who has access? (RLS verified by `/rls-audit`)
- Encrypted at rest? (Supabase has TLS in transit + encryption at rest by default — note this)
- Logged anywhere? (logs MUST NOT contain PII)

CNP (Romanian personal ID) and IBAN are special-category-adjacent; require extra justification.

---

## PHASE 2: COOKIE & TRACKER AUDIT

For each public web property:

- Cookie banner present BEFORE any non-essential cookie / tracker fires?
- Granular consent (analytics / marketing / functional categories independently toggleable)?
- "Reject all" as prominent as "Accept all"? (CNIL / ANSPDCP standard)
- Consent log persisted (timestamp, IP, choices, banner version)?
- Banner version in privacy policy, with change history?

Grep the codebase for trackers loaded:
- Google Analytics / GA4 / GTM
- Meta Pixel
- TikTok / LinkedIn / Twitter pixels
- Hotjar / Microsoft Clarity / Mixpanel / Posthog
- Sentry (does it scrub PII before sending?)

Each must be gated by consent for its category. Test in a private browser: load the home page → confirm NO network calls to tracking domains before consent.

---

## PHASE 3: PRIVACY POLICY & TERMS

Locate `/privacy`, `/politica-confidentialitate`, `/terms`, `/termeni`, `/cookies` pages or equivalents.

Privacy policy minimum content (GDPR Art. 13/14):
- Operator name + legal address + contact + DPO (if appointed)
- Categories of personal data processed
- Purposes + legal basis for each
- Recipients / sub-processors (named, not "third parties")
- International transfers (if any, with safeguards)
- Retention period per category
- User rights (Art. 15-22): access, rectification, erasure, restriction, portability, objection, withdraw consent
- ANSPDCP complaint contact (dpo@dataprotection.ro)
- Last updated date

Terms minimum:
- Identity of seller (CUI, Reg. Com., sediu)
- Description of service
- Price + payment + billing
- Withdrawal right (14 days for B2C ecommerce — OUG 34/2014)
- Warranty / refund / SLA
- Dispute resolution: ANPC + EU ODR for ecommerce
- Governing law

Cross-check with the operator's legal entity data (company name, CUI/VAT, registered office, registration number). If not on file, ask the user.

---

## PHASE 4: USER-RIGHTS ENDPOINTS

For every system holding personal data, verify the user can:

- Request a copy of their data (export) — within 30 days.
- Request deletion (right to erasure) — within 30 days, except where legal retention applies.
- Rectify wrong data.
- Withdraw consent as easily as it was given.

Either via in-app feature OR documented email process. Test that the process actually works.

---

## PHASE 5: SUB-PROCESSOR REGISTRY (Art. 28 DPA)

List every third-party processor:
- Supabase (US-based parent, EU regions — confirm region used)
- Railway, Hetzner, Cloudflare, Vercel
- Gmail / Google Workspace
- Anthropic (Claude API)
- OpenAI (if used)
- Stripe / payment provider
- Twilio / WhatsApp Business / email sender
- Sentry / monitoring

For each:
- DPA signed? (most have one; verify access)
- Region of processing?
- For transfers outside EU/EEA: SCCs in place? Adequacy decision?
- Publish the list on the privacy page or make available on request.

---

## PHASE 6: MARKETING & TRANSACTIONAL EMAILS

- Marketing emails (newsletter, promotions): explicit opt-in, opt-out link in every email, sender identification.
- Transactional emails: no marketing payload mixed in (otherwise becomes marketing → needs consent).
- Soft opt-in (Legea 506/2004 art. 12): can market similar products to existing customers IF they were given the option to refuse at point of sale AND in every message.
- Suppression list maintained.

---

## PHASE 7: ROMANIAN-SPECIFIC

For ecommerce / HoReCa apps with public users:

- ANPC banner (resolution links) on every page? (mandatory for ecommerce):
  - https://anpc.ro/ce-este-sal/
  - https://ec.europa.eu/consumers/odr/
- "Solutionarea Alternativa a Litigiilor" (SAL) section in terms.
- Order confirmation includes everything per OUG 34/2014.
- For fiscal: e-Factura compliance (for B2B), fiscal printer integration (Datecs, etc.).
- Cookies: ANSPDCP guidance from 2020 requires explicit consent — passive "by using this site you agree" banners are non-compliant.

---

## PHASE 8: DATA BREACH READINESS

- Documented incident response procedure?
- 72-hour breach notification to ANSPDCP (Art. 33) playbook?
- Notification template for affected users (Art. 34)?
- Logging in place to detect breach scope?

---

## OUTPUT — REPORT

```
========================================
   GDPR / RO DATA-PROTECTION AUDIT
   Project: [name]   Operator: [legal entity]   Date: [today]
========================================

## EXECUTIVE SUMMARY
[Compliance rating + top exposure]

## CRITICAL (legal risk / fine eligible)
[no privacy policy, no cookie consent, PII without basis, broken user-rights]

## HIGH
[missing sub-processor list, marketing without opt-in, transfers without SCCs]

## MEDIUM
[outdated policy, banner UX issues, retention undefined]

## LOW / INFO
[hardening, polish]

## PII INVENTORY
[Table per system]

## SUB-PROCESSOR REGISTRY
[Table: name | category | region | DPA | basis]

## COOKIE / TRACKER INVENTORY
[Tracker | gated by consent? | category]

## USER-RIGHTS COVERAGE
[Right | mechanism | tested?]

## AUDIT COVERAGE
```

---

## FIX KIT — write `GDPR-FIXES.md`

Generate:
- Privacy policy template (RO + EN) with the project-specific blanks filled.
- Cookie banner code snippet (React component or vanilla) wired to a consent store.
- Sub-processor list as a Markdown page or JSON config.
- User-rights endpoint stubs (export, delete) where missing.
- Email opt-out wiring instructions.
- ANSPDCP-ready DPIA template if processing is high-risk.

Add `GDPR-FIXES.md` to `.gitignore`. Checklist at top. Self-destruct at bottom.

Flag clearly anything that warrants a real lawyer (cross-border transfers, novel processing, special-category data).

START NOW.
