# LifeOS — Codex Master Product & Engineering Prompt

> **Paste this entire document into Codex after connecting the LifeOS repository.**
> **Mandatory execution rule:** The first interaction is DESIGN REVIEW ONLY. Do not scaffold the app, implement screens, install packages, change repository files, or commit code until I approve the proposed design system. This document describes the eventual complete product; it is **not** permission to implement every phase immediately.

## 0. Your role, working rules, and first response

You are my senior Flutter/mobile engineer, product designer, AI systems architect, data integration engineer, and pragmatic technical partner. Build a **personal-first, Android-first LifeOS** to help me plan and adapt my real life. Web will be added later for convenient file import, desktop review, and large-screen planning. Do not target iOS unless I explicitly request it.

**My process is non-negotiable:**
1. Inspect the existing repository read-only. Summarize what exists and what is missing. Do not assume the repository is empty; do not rewrite existing code without permission.
2. **Before writing any code**, identify critical assumptions, tradeoffs, and decisions requiring my input. Make sensible provisional recommendations. Ask only questions that meaningfully affect architecture or visual decisions; group them in one short decision list.
3. **STEP 1 — DESIGN SYSTEM ONLY:** propose and justify design tokens, typography, color/contrast, components, motion, and themes. Show a proposed structure for `design_tokens.dart` and `app_theme.dart`, with an *inline, pasteable draft* if practical. Explain how you verified contrast. **Do not create screens, navigate to a new screen, scaffold business logic, connect APIs, add packages, modify repository files, or proceed to Step 2.**
4. **STOP and wait for explicit design-system approval from me.** When I approve, create or update only the reviewed token/theme files and their focused tests, show the diff and any checks, then stop again. Implement the first UI screen only when I separately select that screen and approve work on it.
5. For every later implementation phase: propose scope, dependencies, data contracts, design, acceptance tests, and any required decisions; obtain my approval; implement only that phase; run available checks; document changed files and limitations; await the next instruction. Do not silently skip ahead.
6. Explain every new package and why it is necessary. Prefer actively maintained, well-supported, permissively licensed packages. Verify current versions against project compatibility before adoption, and ask before adding packages.
7. Never claim a third-party API or integration works unless verified from official documentation and tested with authorized credentials. Always provide manual entry or file-import alternatives.
8. Keep a concise `docs/decisions.md` / ADR-style record of approved decisions when implementation begins, and keep the PRD traceable to actual behavior.

**Do not overbuild.** My highest priority is an intelligent rescheduling and daily decision system, followed by a dynamic academic tutor, book-to-action knowledge coach, useful fitness recommendations based on Hevy, habits/focus, progress tracking, and budget-based decision support.

## 1. Product identity and user context

**App name:** LifeOS.

**Initial users:** Me, one user. I am a student and physically active young adult. My recurring concerns are university deadlines, studying coding/data structures, training, personal development through books/videos, weekly spending, nutrition, appointments, social plans, and changing routines. Design as a coherent personal operating system, **not a gym app with extra tabs**.

**Locale defaults:** Asia/Kuala_Lumpur timezone; Malaysian ringgit (MYR/RM); metric measurements (kg, cm, km); configurable date/time format and locale. Persist timezone-aware instants plus local intent for recurring times. Avoid assuming all users will always remain in Malaysia.

**Reference visuals:** Two design reference images supplied in my conversation: (1) near-black task-management app with large crisp typography and restrained powder-blue task cards; (2) premium dark workout UI with strong hierarchy and a burgundy/black mood. Use them for layout quality, typographic polish, density, and premium feel—**not as exact colors to reproduce**. My explicit palette below overrides their accent colors. If these assets are not available in the repository, ask me to add them to `docs/design/references/`; never pretend you saw files you cannot access.

**Emotional goal:** sexy, fashionable, minimalistic, calm, mature, credible. Quick and natural, like a well-crafted native app. Not playful gamification, neon dashboards, a flashy AI demo, or a workout-only product.

**Product promise:** "LifeOS knows my goals and constraints, helps decide what matters next, transforms learning into action, adjusts my schedule when life changes, and shows whether I am improving." Every recommendation should answer: **what, why, when, and based on which evidence**.

## 2. What I use today — integrate or import rather than duplicate

Treat the following as my existing systems of record until I decide otherwise:

| Existing service | Current role | LifeOS role and fallback |
|---|---|---|
| Google Calendar | Calendar, appointments, and time blocking | Authorized read/sync and optional LifeOS-owned block creation/update; local offline schedule; optional ICS import/export |
| Google Tasks | My visible to-do list, appearing in Calendar | Authorized task list/title/status/date sync; LifeOS keeps richer deadlines, durations, dependencies, priorities, and actual time blocks locally |
| Readwise / Readwise Reader | Books, highlights, reading notes | Import authorized highlights/notes/documents; build cited, book-derived action cards; local Markdown/TXT/PDF/EPUB as permitted |
| Hevy | Actual workout logging | Hevy remains source of truth. Import exported CSV; optional Hevy Pro API read-only integration later; show analytics and recommend future training, but do not require duplicate set logging |
| ChatGPT | Coding lessons and practice | LifeOS offers a course-aware, adaptive practice tutor and tracking of mastery; do not assume private ChatGPT conversations can automatically be fetched |
| Make Time or similar focus app | Laser Focus / timers / end-of-day reflection | LifeOS supports focus sessions and reflection; optional manual import or verified export, not invented sync |
| Wallet (BudgetBakers if that is my Wallet) | Expense tracking | Import transactions CSV/XLS where supported; optional verified Premium REST API; editable weekly budget and forecasts |
| ReciMe | Video-derived recipes and groceries | Link/save recipes and shopping plans if legal supported export/share is available; otherwise manual input, copy, share sheet or files; do not invent an API |
| MyFitnessPal | Daily calories and macronutrients | Import my TXT sample plus officially exported CSVs; preserve source and completeness; manual entries accepted |
| Google activity/steps | Steps and possible health measurements | Manual steps/sleep first; optional Health Connect integration on Android with granular consent; do not rely on deprecated Google Fit APIs |

**Critical Google Tasks limitation:** Official Tasks API `due` contains only the scheduled **date**, not a usable time of day. Do not treat a Google Task as an authoritative timed calendar block. Use Google Calendar event records for timed blocks and maintain LifeOS-specific separate `deadlineAt`, `plannedStartAt`, `plannedEndAt` fields. Google Tasks updates must not silently erase LifeOS deadline times.

**Third-party connections are opt-in.** Have separate controls for connect/disconnect, allowed read/write scopes, last sync, errors, and manual imports. Credentials and personal API keys must never be in source control, logs, crash reports, or bundled release assets. A single-user app is not an excuse for insecure key management.

## 3. Non-negotiable module: Adaptive schedule optimization

This is the heart of the product. My plans change because of public holidays, cancelled lectures, last-minute commitments, assignment extensions, actual work taking longer than estimated, procrastination, social invitations, gym and badminton sessions, snooker, clubs, drinks, and spontaneous hanging out. The scheduler must never pretend life is rigid.

### 3.1 Calendar and task ontology

Model these as different concepts:
- **Hard commitment:** exam, appointment, booked event, accepted social plan, actual university class. Default immovable unless I explicitly edit it.
- **Soft/flexible time block:** planned study, revision, workout, focus block, chores; may be shifted with consent.
- **True deadline:** assignment submission or examination cutoff; *different* from the day I want to work on it.
- **Task and subtask:** work with duration estimate, optional progress %, requirements, dependencies, priority, energy demand, context, allowed time windows, and due date.
- **Recurring habit:** goal/rule that generates planned or optional task instances; avoid creating infinite duplicates.
- **Availability constraint:** sleep, commute, food, personal time, quiet hours, recovery, holidays, and buffer time.
- **Invitation:** proposed social event that may be tentative, accepted, declined, or cancelled, with flexible arrival/departure times, estimated cost, travel, and recovery impact.
- **External event:** imported/calendar-synced event that may be read-only, locked, tentative, or busy, preserving ownership and source provenance.

Priorities are not the same as urgency; allow importance, urgency, health/study category, and user-selected hard constraints. Support fixed, flexible, and preferred time windows, dependency ordering, estimated duration, minimum continuous focus block, splittability, latest safe start, buffers, and event attendance preference.

### 3.2 Core behavior

- Every task gets a realistic estimated duration and, over time, an estimate range based on actual completion history. Let me override estimates.
- Auto-detect unscheduled work, calendar conflicts, deadline risk, overdue subtasks, missed habits, and unrealistic days.
- Produce one or more **proposed schedules** (e.g. deadline-first, balanced, more social/free time) ranked by transparent scores. Explain conflicts, tradeoffs, and why a task moved.
- Never automatically delete, move, or overwrite outside-calendar commitments, other people's invitations, or original due dates. Show a **before/after diff and explicit confirmation** for a batch of changed blocks.
- Optionally allow auto-rescheduling **LifeOS-owned flexible blocks only** with an explicit configurable opt-in, bounded limits and an audit trail. No autonomous spending or accepting invitations.
- Support automatic reassessment when a commitment, public holiday, assignment deadline, task status, actual work duration, priority, sleep window, or connected calendar event changes.
- Distinguish an assignment *extension* (deadline truly changes) from my merely *delaying work* (deadline unchanged). Record the source or my confirmation for extension.
- Honor public holidays using a validated, local calendar source or user-managed holiday calendar; do not hardcode inaccurate Malaysian holiday observance or state-specific holidays.
- Let me say "I procrastinated for 90 minutes," "I only finished half," "Class is cancelled," "I got a deadline extension," "My friends invited me out Friday 9pm–2am," or "Move my workout; gym closed". Parse into proposed typed changes, then show a review screen.
- Budget and recovery can be additional signals: show whether a night out fits budget and may affect my next morning availability, without judgment or guessing that I will drink or be impaired.
- Let me mark blocks as started, paused, completed, partially completed, abandoned, skipped intentionally, or postponed. Record plan vs actual while protecting privacy.
- Include minimum daily anchors (sleep, meals, commute), break buffers, configurable maximum work hours, scheduling horizons, and a user-controlled percentage of unallocated free time.
- Support timezone changes and recurrence, DST when traveling, overlapping source calendars, cancellations, long events spanning midnight, and events across local dates.
- Work offline against cached calendar/task data; queue consented changes for later sync, with visible pending state and conflict resolution. Never silently clobber edits from elsewhere.

### 3.3 Optimizer implementation guidance

Start deterministic, inspectable and testable: a constraint/rule engine, potentially OR-Tools on a service if justified, rather than an LLM inventing time slots. Hard constraints must NEVER be broken. Soft objectives can be weighted by due date, task priority, preferred work hours, context switching, preserved free time, energy preference, plan stability, habits, and user intent. Expose conflict explanations and allow pinned blocks. A language model may extract scheduling intent and explain results, but validated typed constraints plus a deterministic engine decide feasibility.

Use actual feedback (task duration, no-show, postponement patterns) only after enough history, with transparent confidence, ability to reset learning, and no punitive labeling. Do not claim the model predicts mood or capacity with certainty.

### 3.4 Required schedule test scenarios

1. A 3-hour assignment due tomorrow; a flexible 1-hour gym block overlaps a newly accepted dinner. Keep deadline fixed, propose a new gym time and sufficient assignment time, never remove dinner without asking.
2. Due date changes from Monday to Friday **because of a confirmed extension**. Recalculate urgency, release unneeded buffers, preserve reasonable pacing and avoid dumping everything on Thursday.
3. I miss a 90-minute study block. Reschedule remaining work without marking it completed or changing the deadline; ask whether the work was partially done.
4. A lecture is cancelled by public holiday. Free that time only when the holiday and lecture cancellation are confirmed, respecting local state/region rules.
5. Social invitation from 10pm until 2am plus travel. Treat as cross-midnight; optionally move early-morning flexible blocks and show the budget impact.
6. Two genuine hard commitments overlap. Show a conflict needing manual resolution; don't falsely produce a valid plan.
7. Offline edits are made while Google Calendar changes from another device. Detect version conflict and prevent overwriting newer changes.
8. Google Task has a date but no time. Do not manufacture an exact time or confuse it with the LifeOS scheduled block.
9. A large task has prerequisite subtasks. Schedule dependency order and allow partial progress without equating checked boxes with real percentage of effort.
10. Habit targets conflict with an examination week. Offer minimum viable variants or user-approved pauses, not guilt or impossible plans.
11. User moves a block manually. Respect the move and do not immediately undo it through optimization.
12. Plan includes no feasible time for all tasks before the deadline. Explicitly surface overload and alternatives such as reducing scope, asking for help or choosing tradeoffs; never claim everything will fit.

## 4. Adaptive academic tutor and assignment management

The tutor must be **course-specific**, dynamic, and effective for university study, particularly C++, data structures, algorithms, mobile application development, software engineering and other uploaded course topics. Don't hardcode the current courses or presume their future syllabi.

- Import and review syllabi, assignment briefs, grading rubrics, tutorials, lecture PDFs, code snippets, slides or notes (supported formats via vetted parsers). Preserve page numbers/section references when possible. No silent hallucinated deadlines, marking criteria or course topics.
- Extract proposed assessments, deadlines, milestones, learning objectives, concepts and task dependencies; ask me to confirm detected dates and tasks before publishing them to planner.
- Build a per-course concept graph: prerequisite concepts, attempts, correct/incorrect answers, recurring mistakes, evidence of mastery, review due dates and confidence. Distinguish "not attempted" from "failed".
- Tutor modes: learn/explain, worked example, practice-from-memory, hints-only, quiz, debugging, code review, flashcard generation, retrieval practice, spaced revision, mock test, and exam countdown. Provide difficulty controls.
- Follow sound study ideas found in my imported books and notes, such as active recall, mental model building, code tracing and code reproduction. Attribute book-derived techniques to specific passage or note rather than claiming an author's exact advice without evidence.
- For programming, generate exercises aligned to the relevant language/standard and user-provided code. Support progressive hints, step-by-step test cases, expected behavior, edge cases, and marking of submitted code. Never present sample code as necessarily compilable without testing when a sandbox/runtime is not available.
- If adding code execution, it must be isolated and sandboxed with time/resource limits and no arbitrary host access. Never execute untrusted code in a privileged app process or backend.
- Assignment progress: hierarchies of subtasks and subtasks-within-subtasks, weighting by estimated effort, evidence from finished work, stages, blockers and real completion. Estimate progress separately from manually reported confidence. Integrate remaining work into schedule optimizer.
- Provide a weekly academic review: projects at risk, weakest concepts, revision recommendations and schedule proposals.

## 5. Fitness coaching: Hevy is the source of truth

I do **not** want to manually re-log workouts already tracked in Hevy. LifeOS analyzes logs and recommends the next session, exercise adjustments, recovery, progression and schedule changes. Workout recommendations should be grounded in permitted books and notes I provide plus my logged outcomes, equipment, preferences, and time available; do not fabricate an author's rules.

**Known real uploaded sample:** `workouts (1).csv` is a Hevy export with **437 set rows, 27 workout sessions, 34 distinct exercise titles**. The actual CSV header is:

```csv
title,start_time,end_time,description,exercise_title,superset_id,exercise_notes,set_index,set_type,weight_kg,reps,distance_km,duration_seconds,rpe
```

Dates in the sample resemble `Oct 13, 2026, 7:26 PM`. Set types include `normal`, `warmup`, `failure`; `weight_kg` can be blank. In THIS sample RPE is blank on every row; do not infer RPE or proximity to failure. `distance_km`, `duration_seconds`, and `superset_id` are also blank in the sample, though the parser should support them if populated in another export. The actual file is a *user-supplied private fixture*, not automatically present in the repository; if absent, use a synthetic fixture of the same schema and ask me to import the original privately.

Requirements:
- CSV import with file preview, header validation, date locale/timezone parsing, handling of empty values, encoding, duplicate detection, row-level diagnostics, transaction-based import, rollback, and incremental repeat-import without double-counting sessions/sets.
- Data model must preserve session, exercise instance, set order, set type, kg, reps, RPE when present, elapsed duration, exercise notes, source provenance and import batch ID.
- Analyses: sessions per week, exercise frequency, estimated working-set counts by muscle grouping (clearly label approximations), exercise progression, repetitions and load trends, hard-set volume, session duration, total training volume where meaningful, attendance/adherence, and records with clearly defined formulas. Exclude warmup sets by default from hard-set analysis; expose settings.
- Avoid treating exercise names as unique IDs across all providers; support an editable mapping and user-approved aliases.
- Give recommendations such as "repeat weight and build reps", "consider increasing load when prescribed rep targets are consistently met", "review unusually high recent volume", or "shorter session fits the calendar", with source/evidence and assumptions. Prefer conservative recommendations when training history, sleep, soreness or RPE data is incomplete.
- Equipment profiles for full gym, home dumbbells, machines, bodyweight, badminton/sports activity, etc.; only recommend exercises compatible with available equipment.
- Allow planned routines to be exported or manually copied to Hevy where supported. Do not claim direct workout modification or sync is available without a verified API and user permission.
- Future optional Hevy Pro API adapter, clearly marked gated by paid account/credential, and isolated from the CSV importer. Do not require Hevy Pro.

## 6. Knowledge library, book-to-action, and video assistant

I use books and videos to guide my life. Build a knowledge system that **understands the source before recommending actions**.

- Support imported notes/highlights and documents via Readwise APIs (when authorized) and local PDF, EPUB, TXT, Markdown, HTML or supported documents; support user-provided video transcripts and timestamps, URLs with verified available transcripts, and optional compliant transcription.
- Ingestion pipeline: extract text, clean and chunk, preserve book title, author, edition, file URI, page/chapter/section or video timestamp, source hash, copyright/permission status, update time and whether user authored notes or source text.
- Retrieval-augmented assistant (RAG): search original indexed passages, distinguish verbatim source content from interpretation and synthesized advice, cite precise user-provided evidence, answer "not found" when appropriate; never fabricate quotations, section references, or timestamps.
- Generate structured outputs: key idea, conditions under which it applies, cautions, actionable habit/task, expected time cost, relevance to user goal, suggested review date, and source references. Let me approve action cards before turning them into tasks or recurring habits.
- Compare apparently conflicting advice across books rather than silently blending it; ask me which framework to prioritize if tradeoffs matter.
- Provide goal alignment over months or years: concepts → experiments → weekly practices → scheduled tasks → outcomes → periodic reflection. Keep manual control; don't overstate causal impact.
- Allow favorite rules, context-triggered reminders (e.g. before studying, after missing a workout), reading review queues, provenance for AI claims, and removing/updating a source with downstream recommendations invalidated or tagged stale.
- Respect copyrights and provider terms. Do not rehost or redistribute full copyrighted books. Do not scrape behind paywalls or bypass technical access controls.

## 7. Habit engine, focus sessions and reflection

- Goals can create habits; habits can create finite scheduled task instances, either daily/weekly or context-triggered, without duplicate task storms.
- Habit schedules adapt around exam weeks, holidays, recovery and social nights; allow minimum viable habit and explicitly optional "pause" states.
- Track planned versus performed, current trend, useful consistency metrics and reasons for misses; do not use shame, misleading streaks or fake motivational science.
- A configurable Laser Focus mode: focus timer, intentional breaks, planned task, actual time, distraction notes, and end-of-day reflections such as "Did I do what I planned?", "Energy?", "Focus?", "Which tactic did I try?", "What could work tomorrow?".
- Daily, weekly, monthly review prompts tied to tasks, books, wellness, personal goals and activity history. Show correlations cautiously, without asserting causation.
- Let AI recommend small habit changes from my book-derived methods and historical adherence; explain source and provide a dismiss/never-suggest-again control.

## 8. Personal finance and decision support

I receive a weekly allowance/budget. I want help deciding if an activity or purchase fits my financial priorities, not just a categorized transaction list.

- Weekly budget amount, start day, carryover policy, reserve/savings targets, fixed committed expenses, optional costs, account balances, categories and forecasted upcoming payments. Use MYR initially and support future currencies.
- Import transactions from an official Wallet export (CSV/XLS depending on available format), plus manual entry. If Wallet is BudgetBakers, evaluate their documented Premium REST API as an optional later connection; do not assume my subscription or API key exists.
- Classify and correct transactions with transparent rules; persist user overrides and never silently infer spending from a calendar event as an actual transaction.
- For a proposed outing, estimate travel, food, tickets, drinks (if relevant), and discretionary buffer. Let me edit amounts. Calculate remaining funds after known commitments and show best-case, likely and conservative scenarios based on explicit assumptions.
- Support queries like "Can I spend RM70 tonight and still cover groceries?" and "What would I have left this week?" with arithmetic that is auditable and distinguish projected versus paid costs.
- When events change, optionally re-evaluate discretionary budget. Respect my choices, avoid moralizing about socializing, and never initiate a payment/purchase.
- Permit budgeting manual-only even if Wallet sync is unavailable.

## 9. Personal progress and health/fitness metrics

Build a unified **Progress** area with daily, weekly, monthly, custom-range, and long-range trend views. Every number must disclose its source, date, units, and completeness. The app cannot infer an unmeasured value.

**Manual input:** weight (kg), neck/waist/hip circumference (cm), steps, sleep start/end or duration, subjective energy/focus/soreness, workouts if Hevy unavailable, and other configurable measurements. Show measurement instructions and comparable units; avoid medical diagnosis.

**MyFitnessPal TXT sample:** `myfitnesspalReport.txt` has dated blocks such as `Nov 30, 2025` and `Dec 17, 2025`, separated by tabs, with columns: `FOODS`, `Calories`, `Carbs`, `Fat`, `Protein`, `Cholest`, `Sodium`, `Sugar`, `Fiber`, meal headings such as `Breakfast`, item rows, and `TOTALS` meal rows. Some values have unit suffixes (`7g`, `480mg`) or missing marker `--`. The sample includes **partial days**, not guaranteed full-day totals. Parse it as a specifically supported source format, preserving raw data. Do not sum meal `TOTALS` *and* item rows (double-counting). Do not label an incomplete day as fully compliant with a calorie target. Also support official MFP CSV files, which may have different columns and granularities; infer format only after inspection, with preview.

**Progress dashboard categories:**
- Body measurements: weight, neck, waist and hip trends, measurement frequency, optional user-defined goals.
- Nutrition: calorie and macro totals vs configurable targets, history and completeness flags; daily/weekly/monthly aggregates should not treat missing days as zero intake.
- Activity: step history; distinguish manual from Health Connect; deduplicate provider overlaps where appropriate.
- Sleep: duration/trend, optional consistency, missing and unusual entries; do not promise medical sleep quality diagnostics.
- Fitness: session frequency, set/rep/load progression, training consistency, estimated volume and trend windows from Hevy.
- Academics: assignment status, estimated weighted subtask completion, actual focus time, topics studied, retrieval correctness, spaced-repetition due queues.
- Habits and schedule: planned-versus-completed, on-time metrics, reschedule frequency, realistic duration estimate error, optional reflection scores.
- Finance: allowance, spent, committed, forecast and savings progress.

Charts must be crisp, interactive where meaningful, not decorative; provide accessible table/list alternatives and plain-language insights. Preserve raw imported records and aggregate deterministically. Allow exports of my own data in interoperable formats.

## 10. AI chat: the action interface, not just a chatbot

The AI assistant is accessible throughout LifeOS with optional text input and later voice. It can ingest user-provided text, share-sheet items, documents, links and transcript files, then create **typed proposals** for my review. Examples:

- "My friends invited me to badminton tonight at 8; rearrange what I was supposed to study."
- "My assignment was extended to next Friday. Spread the remaining subtasks out."
- "Import this lecture PDF and create a review plan based on my weak topics."
- "Based on this book's methods and my last four weeks, suggest a better routine."
- "Import this Hevy CSV, tell me which exercises are progressing and suggest next week's sessions."
- "This is a food report; update my nutrition charts and explain which days are incomplete."
- "Can I afford an RM85 outing this weekend while preserving my groceries budget?"
- "I missed today's morning study session; rebuild the rest of today realistically."

**Mandatory safety/agency contract:**
- The LLM NEVER directly mutates the database, calendar, budget, course or external account. It outputs a validated typed action proposal for a deterministic domain service.
- Show proposed changes with sources, assumptions, preview diffs, affected entities, projected tradeoffs, confidence/uncertainty and explicit approval. User approval triggers an idempotent, audited command; allow rollback/undo for LifeOS-owned reversible actions.
- Classify intent, select only permitted tools, request the minimum necessary data, and never expose unrelated personal records in an external model prompt.
- Make AI optional: offline non-AI workflows remain fully functional. For AI-unavailable states, give meaningful local alternatives (manual extraction, deterministic scheduling, last successful summary, existing task lists).
- Store model/provider configuration securely; expose token/cost estimates when relevant, allow model/provider replacement, data deletion and opting out of cloud analysis.
- Never imply a source was read if it wasn't, or that a task was scheduled if approval/sync did not succeed.

## 11. Information architecture and proposed later screens

**Do NOT build these screens now.** They are future scope only:

1. **Home / Today** — top 1–3 priorities, today's time blocks, conflicts, proposed adjustments, progress snapshot, quick capture, contextual AI insight.
2. **Plan** — day/week calendar, Google events vs LifeOS flexible blocks, backlogs, task/subtask detail, planning comparison and approval, upcoming deadlines, invitations.
3. **Focus / Learn** — study courses, concept mastery, practice sessions, flashcards, coding tutor, focus timer and reflection.
4. **Progress** — body/nutrition/activity/sleep/training/academic/habits/finance trends with source and completeness indicators.
5. **Coach / Library** — AI chat, source-grounded knowledge notes, books/videos, book-to-action proposals, recommendations and history.
6. **Settings & Integrations** — sources, file import jobs, sync state, privacy, exports, personal preferences, equipment, goal configuration, theme, accessibility.

Use contextual detail pages and bottom navigation of approximately 4–5 top-level destinations; do not make a separate permanent tab for every module. Keep task/goal/note creation quick and reversible. Final navigation should be reviewed with me before development.

## 12. DESIGN SYSTEM — FIRST AND ONLY AUTHORIZED STEP IN YOUR INITIAL RESPONSE

### Visual direction
- **Mood:** sexy, fashionable, premium, editorial, restrained, minimalistic. Think sophisticated task app plus polished workout analytics, not an exclusively workout aesthetic.
- **Dark base:** `#0E0E10` near-black.
- **Light base:** `#F5F2EE` warm off-white.
- **One brand accent:** deep crimson `#C8102E`, at **no more than ~10% of visible screen area**; reserve for primary CTAs, active states, rare meaningful highlights. Never use crimson as an all-over page background, a gradient wash, or for errors.
- **Error/warning family:** amber seeded by `#E0A030`, using contrast-safe text/surface variants. Avoid red error feedback; distinguish warning, error, success and info semantically using labels/icons as well as color.
- **Accessibility:** WCAG AA ≥ 4.5:1 for normal text; ≥ 3:1 where applicable for large text and meaningful non-text UI; touch target ≥ 48 logical px; readable at text scaling, screen reader labels, no color-only status.
- **Important verified contrast caveat:** `#C8102E` on `#0E0E10` is only approximately **3.28:1**, so do **not** use small crimson text directly on the dark base. Conversely, `#F5F2EE` text on `#C8102E` has approximately **5.27:1** contrast. The amber seed `#E0A030` against `#F5F2EE` is only about **2.04:1**, so don't use tiny amber text directly on off-white. Offer contrast-safe foreground/surface pairings and show computed contrast ratios for each role.
- Both fully considered **dark and light themes** with compatible component states; the same hierarchy and information density in both.

### Propose, explain, and specify
1. **Color roles**: one `brandAccent`, neutral palette, surfaces/elevation tiers, borders, text primary/secondary/disabled, focus ring, semantic feedback colors. Show light and dark values, actual contrast calculations, and usage restrictions. Keep semantics distinct from brand color.
2. **Typography**: choose **one** tasteful accessible font family (licensing and bundling considered) with 5–6 semantic sizes, weights, line heights, text scaling behavior. Large editorial headlines sparingly; body text is legible first.
3. **Spacing**: 4/8px foundation with explicit tokens (4, 8, 12, 16, 24, 32, 40, 48), breakpoint-responsive paddings, baseline alignment, limited corner radius scale, minimal elevation.
4. **Reusable components**: primary/secondary/text/destructive buttons, cards, task cards, editable list rows, progress chips, input fields, calendar blocks, segmented controls, tabs, app bars, sheets, dialogs, toasts/snackbars, badges, loading skeletons, empty states, error states. Each component needs hover/focus/disabled/loading/pressed rules where relevant and dark/light variants.
5. **Icons**: one consistent icon library and stroke weight, label logic, no decorative icon overload. Explain chosen Flutter icon dependency or built-in set.
6. **Data visualization**: accessible minimal chart rules, restrained palette use, axis readability and empty/missing values. Avoid loud rainbow charts.
7. **Motion**: micro 100–150ms, standard 200–300ms, page transitions ≤350ms; enter ease-out and exit ease-in, **never linear** for transitions; hero transitions only where meaningful; stagger list entrances ≤40ms between items and at most first 8 items; favor opacity/transform; no distracting loops; respect reduced-motion OS setting (and provide low-motion defaults).
8. **Performance**: local-first rendering; no full-screen network spinners; cached content and skeletons; optimistic UI with rollback on failure; prefetch likely next-screen data; aim navigation response <100ms where practical and smooth 60fps mid-range Android. Profile instead of falsely claiming guaranteed timings. Avoid expensive clipping, blur and rebuilds.

### STEP 1 output format
Produce **only** the following, in this order:
A. Read-only repository inspection summary and design reference availability.
B. Up to ~10 critical assumptions/decisions, grouped with recommended defaults and impact. Include: minimum Android SDK; authentication/local-only vs cloud sync; AI provider choice later; whether existing app integrations will be read-only initially; font licensing; and which initial screen I may choose later. Do not block proposing tokens on noncritical unknowns.
C. Short design rationale in plain language.
D. Tables for dark/light color tokens and accessibility contrast checks, typography, spacing/radius/elevation, iconography, motion.
E. A proposed file structure for design tokens and Flutter Material 3 theme, **plus an inline draft** of tokens/theme that I can review/paste (no repository changes yet). Use semantic names, ThemeExtensions where justified, no scattered hex literals in future UI.
F. Component specifications for buttons, cards, task lists, app bars, inputs, dialogs, calendar blocks, and chart colors/states.
G. Design accessibility/performance checklist and the exact questions requiring my approval.
H. End with **"Awaiting your design-system approval. I have not built any screens or changed project files."** Do not proceed further.

## 13. Engineering architecture — guidance for LATER phases, not permission to build now

- **Flutter** (Android-first; Web later) with a modular feature-first structure, strict separation between presentation, application/use cases, domain models and data adapters. Keep widgets small, reusable and testable.
- **Offline-first** storage: on-device relational database (e.g. SQLite/Drift after approval), repository pattern, schema migrations, import provenance, sync operation queue and full export/deletion. Render from local state immediately.
- **State**: choose one consistent typed, testable state management solution (e.g. Riverpod/Bloc) after explaining tradeoffs and obtaining approval. Do not scatter business logic in widgets.
- **Cloud**: optional, not a blocker for an entirely local personal V1. If multi-device sync eventually matters, propose a minimal service (e.g. Supabase/Postgres) and encryption/privacy requirements. No need for accounts/payment systems or team features now.
- **AI service boundary**: model-agnostic interface, provider adapters and privacy-filtered context assembly, structured validated outputs and safe commands. Do not embed production API secrets in mobile builds. A direct personal user-provided key would require explicit risk discussion; prefer a secure proxy when using paid cloud providers.
- **Optimization**: pure constraint/domain service independent of UI, deterministic results with seeded test fixtures, explainability and infeasibility reasons; introduce server-side OR-Tools only if justified by complexity and tradeoffs.
- **Integrations**: adapter pattern for Google Calendar, Google Tasks, Readwise, Hevy, Wallet, Health Connect and file import. Each adapter advertises capabilities (read, write, import-only), required authorization, provenance and sync health. Use OAuth PKCE or provider-supported secure mobile flows and least-privilege scopes where applicable.
- **Background work**: honor Android limits, battery/data usage, sync retry/backoff, and conflict policy. Do not promise unrestricted background automation. Prefer explicit refresh as fallback.
- **Time**: UTC storage plus IANA timezone and local-date intent; calendar event recurrence and multi-day events require dedicated tests. Store money in integer minor units or precise decimals, never floats.
- **Accessibility/i18n**: responsive layouts, dynamic text, screen-reader labels, meaningful error copy, high contrast, reduced motion, localization-ready strings.
- **Observability**: privacy-safe structured logs with redaction, user-visible import/sync audit trail, opt-in diagnostics; never log finance details, fitness data, entire documents, AI prompts or access tokens by default.

### Suggested domain entities (refine before implementation)
`UserPreferences`, `Goal`, `Project`, `Task`, `Subtask`, `TaskDependency`, `TaskEstimate`, `TaskActual`, `TimeBlock`, `ExternalCalendarEvent`, `RecurrenceRule`, `AvailabilityWindow`, `HolidaySource`, `Invitation`, `ScheduleScenario`, `ScheduleChangeProposal`, `ChangeApproval`, `AuditEvent`, `Habit`, `HabitOccurrence`, `FocusSession`, `DailyReflection`, `Course`, `LearningObjective`, `Concept`, `PracticeAttempt`, `Flashcard`, `ReviewSchedule`, `DocumentSource`, `SourcePassage`, `KnowledgePrinciple`, `BookToActionProposal`, `WorkoutSession`, `ExerciseInstance`, `WorkoutSet`, `ExerciseAlias`, `FitnessRecommendation`, `Measurement`, `NutritionEntry`, `NutritionDayCompleteness`, `ActivityEntry`, `SleepEntry`, `FinancialTransaction`, `WeeklyAllowance`, `Budget`, `ProjectedExpense`, `ImportBatch`, `SourceRecord`, `SyncCursor`, `IntegrationConnection`, `AIActionProposal`.

Every externally sourced entity should support `sourceProvider`, `externalId` or stable normalized identity, `importBatchId` if relevant, `sourceModifiedAt`, `lastSyncedAt`, `localModifiedAt`, `syncState`, deletion/tombstone semantics where applicable, and provenance. Avoid duplicate task/time-block creation on retries.

## 14. File-import quality and data contract requirements

- Local file picker and future Web drag-and-drop; CSV, TXT, and supported documents. Confirm MIME/extension, encoding, size, headers and parsing confidence; surface safe errors, not obscure stack traces.
- Before committing import: preview rows, field mapping, date formats, units, missing values, total records, detected duplicates, and whether input is complete/partial. Allow manual correction of mapping and locale.
- Import transactionally with explicit progress and cancellation if possible; preserve source checksum and raw filename metadata; avoid automatically uploading source documents to the cloud.
- Idempotent repeated imports: same original data must not inflate workout counts, calories, spending or tasks. Provide conflict/dedup preview and reversible import batch.
- Aggregate based on data semantics: macro item vs meal total vs day summary; gym warmup vs working set; money paid vs projected; submitted assignment vs checklist progress; manual steps vs Health Connect; prevent double counting.
- Store missing as missing; don't fill zeros unless source actually says zero. Clearly label tentative, estimated, derived and measured values.
- Testing: synthetic sanitized fixtures modeled on my Hevy CSV and MFP TXT layouts; unit tests for parsing, deduplication, sums, date handling and partial-day logic. Never commit raw private exports without my explicit permission.

## 15. Privacy, reliability and user agency

I will store sensitive personal information: finance, body measurements, routines, assignment files, possibly book extracts and conversation context.

- Local-first by default, secure storage for tokens, optional biometric/app lock, encryption-at-rest design review, clear export/delete controls, retention policy and backup/restore. Treat all imported files as untrusted.
- Explicit permission and revocation per integration. External AI receives only minimum relevant source snippets with visible controls; allow opt-out and deletion of conversational context.
- Untrusted PDFs/videos/notes and retrieved content must never be treated as system instructions or allowed to trigger tool calls directly. Maintain prompt-injection defenses and strict typed action schemas.
- No payment execution, no buying or ordering for me, no autonomous invitations to people, no unapproved irreversible external writes.
- Finance suggestions are informational calculations, not guaranteed advice. Fitness suggestions are general coaching, not medical diagnoses. Don't overstate the effect of books and behavioral methods.
- Non-judgmental treatment of rest, procrastination and nightlife; emphasize autonomy, safety, realistic tradeoffs, and long-term consistency.
- Accessibility, offline read access and graceful failures are **requirements**, not future polish.

## 16. Delivery roadmap and required approval gates

**Gate 0 — Now:** repository read-only audit, assumptions, and full **Step 1 design system proposal only**. Stop.

**Gate 1 — After I approve the palette and tokens:** implement theme/tokens and dedicated design token/contrast tests only. Stop.

**Gate 2 — After I choose the first screen:** implement one Home/Today or Plan screen against approved tokens with local fixture data, proper empty/loading/error states, and screenshot/tests. Stop.

**Gate 3 — After approval:** core local data model for goals/projects/tasks/subtasks/time blocks, task list, recurring habits and import infrastructure.

**Gate 4 — After approval:** schedule engine, conflict explanations, preview/approval/recovery, and exhaustive optimizer tests using supplied scenarios. This is the highest functional priority.

**Gate 5 — After approval:** Google Calendar/Tasks authorized adapters and offline conflict-safe sync.

**Gate 6 — After approval:** academic tutor and course/document importer; knowledge library and cited book-to-action workflow.

**Gate 7 — After approval:** Hevy CSV importer, workout analytics and safe recommendations; optional Hevy Pro API only if requested.

**Gate 8 — After approval:** MyFitnessPal TXT/CSV importer, manual measurements, steps/sleep tracking, unified progress dashboard.

**Gate 9 — After approval:** Wallet CSV/manual budget and outing-cost decisions; focus/reflection/habit recommender.

**Gate 10 — After approval:** AI action orchestrator with typed proposals, approvals, provenance, privacy, cost controls and audited execution.

**Gate 11 — After approval:** additional integrations (Readwise, Health Connect, Wallet/Hevy API if eligible), optional Web support optimized for file import, hardening and long-term personalization.

Dependencies may motivate a different ordering. **Propose any changes explicitly; do not reinterpret this document as authorization to build multiple gates at once.**

## 17. Implementation quality bar for every approved gate

Before coding: show exact scope, assumptions, packages proposed and why, relevant data contracts, UI states, risks and acceptance criteria. During coding: clean commits/diffs, no unrelated refactors, accessible widgets, local-first architecture, typed errors and clear data ownership. After coding: tests (unit/widget/integration as appropriate), static analysis/formatting, screenshots if UI, performance observations where measurable, changed-file list, known limitations, and concise manual verification steps. Be transparent if an SDK/tool/credential is absent. Never pretend tests ran if they did not.

**Definition of done for V1 (eventually):** I can import my real Hevy and MyFitnessPal exports without duplicate or inaccurate totals, manage tasks/deadlines and subtask progress, view/simulate schedule shifts from real interruptions, approve safe rescheduling, enter body and lifestyle metrics, see meaningful progress views, and use personalized course/book insights without fabricated sources. The core experience remains useful offline and respects the approved design system.

## 18. Final imperative for this first Codex turn

**RIGHT NOW, DO NOT BUILD LIFEOS.**

Read the repository read-only. Then respond ONLY with the design-system deliverables in §12 (including contrast checks and proposed Flutter token/theme file drafts), the critical decisions I need to make, and the explicit approval stop. Even though the rest of this document describes many modules, **they are future requirements, not today's work**.

**Finish your first response with exactly:**

> Awaiting your design-system approval. I have not built any screens or changed project files.
