# Scope and remaining work

The user approved continuation beyond the original design-only gate and approved
all packages currently declared. This development build implements a useful offline
path through the major modules. The full master specification remains the product
backlog; the presence of a tab does not mean every capability in that module is done.

| Area | Implemented and locally testable | Still required for full specification |
|---|---|---|
| Design | Reference-based Home cards and Day/Week/Month calendar, inline expandable event checklists, nine accessible saved event colors, capsule controls in every button state, warm light/dark Inter themes, reduced-motion-aware eased transitions, large-text checks | Native screen-reader/focus review and device visual acceptance |
| Core data | SQLite records, nested tasks and event task groups, goals/projects, settings, 50-revision audit/undo, optimistic revision checks, export/restore/erase | Release lock/platform configuration, encryption/app-lock design, larger-data performance and durability hardening |
| Scheduler | Ranked deadline-first/importance-first/spread-work alternatives with visible metrics, deterministic deadline/dependency planning, parent deadline inheritance, effort weighting, fixed/external/pinned preservation, split/minimum blocks, free-time reserve, reviewed proposals, overload warnings | Per-task energy/context windows, adaptive estimate ranges, detailed actual block states, invitations/travel/recovery model, richer recurrence, source-confirmed holiday workflow; alternatives are greedy policies rather than a global optimizer |
| Calendar | Read-only explicit-occurrence ICS import and LifeOS-only ICS export; no outside writes | Google OAuth client/project configuration, authorized Calendar/Tasks adapters, cursors/tombstones/offline sync queue and remote version conflict tests; Tasks date must never replace a timed deadline |
| Learning | Courses and editable source notes/concept prerequisite links, PDF/EPUB extraction, local passage search, source-linked task approvals/staleness, self-rated recall queue, task-linked actual focus and daily reflections, optional source-selected tutor modes | Validated concept graph traversal/mastery model, assessment/rubric extraction, persisted adaptive practice evidence and weekly academic review, isolated code execution only if separately designed |
| Library | Local TXT/MD/PDF/EPUB sources and citations, downstream staleness, local search | Readwise authorization, HTML/transcript timestamp ingestion, retrieval ranking/chunk indexing, structured book-to-habit experiments and source conflict comparison |
| Training | Hevy CSV set/session provenance, repeat-import protection, editable/reversible provider-specific exercise aliases, provider-separated session counts and summaries, non-warmup counts, observed load comparison and kg×reps volume when complete | Muscle mapping, equipment profiles, rich trend windows, evidence-grounded planned routines/adherence and export-to-Hevy workflow; no paid Pro dependency |
| Nutrition / metrics | Supported private TXT layout, manual food entries, partial-day calorie/macros, missing values, personal targets, explicit day-completeness review invalidated by food changes, calendar week/month summaries and charts, manual weight/circumference/steps/sleep/energy trends | Inspected official CSV variants and granular Health Connect adapter/consent |
| Finance / habits | Mapped CSV, manual paid/projected expenses, integer MYR sen budget, outing/reserve calculation, finite habit instances and pause, timer/manual focus reflection | Official Wallet variant mapping/XLS, savings/forecast ranges, richer habit rules/minimum variants, weekly/monthly reflection reviews |
| AI | Current-state Home check-in with aggregate-only Gemini sharing and labelled local fallback, Gemini gateway templates, provider labels, bounded selected context, typed create/update-task proposals with revision checks/reason/approval, offline demo, native optional secure access-token storage | Actual free-project/model/key verification and gateway deployment; broader typed scheduling/document commands, durable chat/provenance/cost estimation, provider data-use review |
| Integrations | Explicit unavailable state and offline/manual alternatives | Verified authorized adapters for Google/Readwise/Health Connect; unavailable provider APIs must not be invented. Paid Hevy/Wallet gates are excluded under the user's free-only constraint |

Live external connections cannot be verified without the user's service-specific
account configuration. A template or successful mocked protocol test is not a live
integration. No external account writes, purchases, invitation messages, or AI
backend deployment have occurred.

All remaining features must continue to respect the shared Flutter architecture,
free-only/offline fallback requirement, human approval of actions, data provenance,
and native Windows/Android acceptance. Do not declare the whole product complete
based on this development build's passing checks.
