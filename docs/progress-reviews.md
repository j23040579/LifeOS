# Review recorded food and exercise data

Open **Progress**. Local records work without a backend or credentials. No new
package or paid service is required for these controls.

## Food records

- **Nutrition targets** saves your own optional daily calorie/protein/carbohydrate/
  fat targets. Blank fields remove a target; invalid numbers are rejected. Editing
  targets preserves the budget, timezone and appearance settings. These values are
  entered preferences, not AI or medical prescriptions.
- **Weekly food** / **Monthly food** and the period arrows select calendar periods
  in your configured timezone. The chart and day list use that same period.
- Summaries show recorded intake, average per **recorded day**, known macros,
  marked-complete days, and dates without entries. Partial days contribute only
  their recorded values. Dates without entries, including future dates, are never
  treated as zero intake. One missing macro keeps that aggregate macro unknown.
- **Review day completeness** asks whether you recorded all food for that date.
  It does not invent missing nutrients or add an extra day-total entry. **Mark as
  partial** reverses the classification. Adding, changing, moving, or deleting food
  records resets the affected date's confirmation. A stale review is rejected.

Confirmed dates, targets and underlying food entries are included in local JSON
backups. Restore preserves the saved confirmation. Undo restores the records and
classification together. Imported TOTALS remain excluded from item sums.

## Exercise names

Use **Exercise name mappings**, choose the original provider/name, enter a grouping
name, review, and confirm. Two known aliases from the same provider can use the
same group name. Different providers stay separate even when session identifiers
and display names match. The raw Hevy set rows are never rewritten, and no change
is sent to Hevy. Warmups remain excluded from working-set summaries by default.

Saved mappings offer **Edit mapping** and **Remove mapping**. Both changes appear
in local audit/undo and backups. Removing a mapping restores the original analytics
name without deleting any workouts. A change in maximum recorded load is an
observation, not proof of improved technique or a prescribed load increase.
