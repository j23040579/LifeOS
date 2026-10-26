# Home and calendar redesign

The supplied calendar/task reference informs the calendar, event drill-down and
nested task cards. The supplied statistics reference informs Home's large greeting,
stacked panels and current-state score. Approved warm light/dark, crimson and rose
tokens remain in use; no fictional comparison with other users is displayed.

## Use the calendar

Open **Plan**. Select **Day**, **Week**, or **Month**. In Day, tap an empty hour,
enter a title and save; its start/end are prefilled. **Create event** is also
available above the calendar. Week provides dated agendas; Month opens the selected
local date's timeline. Use **Agenda** for a readable list. Enlarged text automatically
uses the agenda instead of fitting large text into small time slots.

Tap an event once to expand **tasks inside that calendar event**. Tap its header
again to collapse. The checklist, effort-weighted progress, and **Create task** stay
in the card. Use a task's **…** menu to edit it or add a nested subtask. Checkboxes
save locally; completed task titles are struck through. Linking a parent and one
of its children never counts the same work twice. Adding tasks does not lengthen
the appointment or cover neighboring events; the time grid continues below.

Choose **Color: …** inside an expanded event, or **Event color** when creating or
editing it. Rose, Lavender, Plum, Ocean, Teal, Sage, Sand, Peach, and Slate all have
light/dark variants with tested text contrast. Names and selection checks accompany
the colors; color does not imply urgency or completion. Colors survive reload,
backup/restore, and replanning; older records use Rose.

| Event text/surface pairing | Light contrast | Dark contrast |
|---|---:|---:|
| Rose | 8.77:1 | 10.07:1 |
| Lavender | 8.46:1 | 9.60:1 |
| Plum | 8.10:1 | 8.86:1 |
| Ocean | 7.20:1 | 9.41:1 |
| Teal | 6.54:1 | 9.59:1 |
| Sage | 6.71:1 | 8.92:1 |
| Sand | 6.30:1 | 8.23:1 |
| Peach | 7.07:1 | 8.34:1 |
| Slate | 7.05:1 | 9.27:1 |

Ratios use WCAG relative luminance from the sRGB token values; every pair exceeds
4.5:1. Automated checks also cover shared action-label contrast on these surfaces.

**Event details** deliberately opens the optional detail sheet. **Add task to event**
there also creates and links atomically. **Edit / move event** links existing groups
or changes the event. Removing an event keeps the tasks. Optimizing preserves
fixed/pinned events and their task links. Linking a group does not count the entire
appointment as work on every child; the separate allocated-work-task field remains.

Simultaneous events render in adjacent lanes. Events spanning midnight are clipped
visually to the selected day without modifying their actual instants. DST days use
23/25 real hours where appropriate. Repeated daylight-saving hours show their offsets, and timeline creation uses an
explicit instant for either occurrence. Manually entered ambiguous local times
still require a UTC offset in the form. An overlapping manually created commitment is
kept visible; deterministic scheduling reports the conflict instead of deleting it.

## Compare schedules

Select **Propose a schedule**, enter available hours, a planning horizon, and free
time to reserve. The review offers **Deadline first**, **Importance first**, and
**Spread the work**. The last policy caps new flexible work per planning date; it
can leave work unplanned even when another policy fits. Each policy keeps hard
commitments, dependencies, and true deadlines.

Ranking compares hard-conflict count, unplanned-task count, peak daily new flexible
minutes, then changed/added/removed flexible-block count, in that order. These are
inspectable greedy alternatives, not a claim of global optimality. Choose an option
to see its explanation and before/after list. **Cancel** saves nothing. **Approve
changes** is enabled only for a feasible option; changed records invalidate a stale
proposal. Settings → **Undo last saved change** restores the previous local plan.

## Today's to-dos and current check-in

Home lists unfinished leaf work due today, overdue, or linked to today's events
(including descendants of linked groups). Upcoming work is labelled separately.
Goals/habits are inside **Goals & daily anchors**; general task/project editing is
inside **Plan → Backlog & projects**. Destination scroll positions are separate.

The score measures **current recorded planning pace**, not total progress, personal
worth or medical wellbeing. Local calculation:

`100 × recorded completed estimated effort / eligible estimated effort`

Eligible work is due by now, has an allocated work block ending today by now, or
was recorded complete today. Parent containers and paused work are excluded. Explicit
reductions to remaining effort contribute partial credit. Future work is not a
failure. No observations means **— / 100**, not a fabricated zero or average.
Old completed tasks do not inflate today's evidence. Legacy completions without a
timestamp are treated conservatively. New task completions record their UTC instant.

**Refresh check-in** uses the configured Gemini gateway when sufficient evidence is
available. Before sending, it shows the exact aggregate counts/effort and asks for
in-app sharing consent. It sends no titles, source documents, health, finance, focus
notes or reflections. The response must provide a valid 0–100 integer, bounded
feedback and limited/moderate confidence, and identify a live Gemini provider.
Invalid, demo, quota, network or provider responses fall back to the labelled local
calculation without retries or a paid fallback. No automatic background model calls
occur. A changed revision/date or assessment older than 15 minutes shows a fresh
local snapshot until the user refreshes Gemini. Check-in text is session-only.

A live Gemini connection still needs the user's server-side key, verified model
access/free eligibility and running gateway. Tests use synthetic Gemini responses;
they do not establish a real connection. Never put the API key in the Flutter app.
The user's intended model is `gemini-3.8-flash`; verify it against the account's model
list and current official free-tier terms before enabling generation.

## Focus and reflection

In Learn, save a timer or **Record manually** and optionally select a task. Actual
minutes update atomically and repeated saves of the same session do not add time
twice. Remaining effort/deadlines/completion require separate confirmation. Cancelling
the save dialog preserves the paused timer for resuming or saving later. **Daily
reflection** stores an editable local note and self-reported energy for the date.
Recent focus sessions and reflections are visible in Learn and included in local
record backups; they are excluded from the Home Gemini summary.

## Motion and verification

Destination fade/slide, calendar-view changes, expanding task groups, score changes,
Material interaction states and dialogs provide restrained transitions. Added motion
uses the system reduced-motion preference; it never changes durations in business
logic or animates a fictional score when evidence is missing.
Event expansion uses eased height transitions. Primary, outlined, text, elevated,
segmented and chip controls keep capsule shapes while pressed, focused, hovered or
disabled; icon buttons are circular. Event cards retain their larger rounded corners.

The changes use existing dependencies. See validation.md for executed checks and
status.md for the remaining full-product work. Live account connections, native
Windows/device acceptance and unimplemented roadmap items are not silently marked
complete by this redesign.
