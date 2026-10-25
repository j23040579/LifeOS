# Local import contracts

Use the native/browser file chooser. Maximum file size is 5 MiB. Select a format,
review diagnostics and records, then confirm the atomic save. UTF-8 text is expected.
Set the source timezone in Settings before interpreting local timestamps. Imported
files never upload automatically. All examples committed here are synthetic.

| Format | Supported contract | Deliberate limits |
|---|---|---|
| Hevy CSV | Exact 14-column schema in the master spec; optional blank kg/reps/RPE/distance/duration; original notes/raw fields; stable session/set identity | Confirm export timezone; no API sync, inferred RPE or provider aliases |
| MyFitnessPal TXT | Dated tab-separated blocks, FOODS header, meal headings, item rows; numeric g/mg suffixes and `--` | TOTALS excluded; all days partial; malformed nutrients diagnosed; official CSV variants need inspected headers before support |
| Transactions CSV | `date,description,amount,category`; YYYY-MM-DD; MYR decimal amounts to 2 places; positive expense, negative credit | Map your Wallet export first; no XLS parser, bank connection or invented Wallet API |
| iCalendar ICS | Explicit VEVENT occurrences with UID, DTSTART, DTEND; UTC, selected local time, or IANA TZID; all-day exclusive end supported | RRULE/RDATE/EXDATE, cancellation updates, transparent events and ambiguous DST times require review; not silently expanded/applied |
| TXT / Markdown | User-provided source note and editable reference | No hidden URL fetch/transcript service; avoid repeated manual note imports |
| PDF | Text extraction with page references | 200 pages, 1 million text characters; no OCR or DRM bypass |
| EPUB | OPF reading order, title/author and section path retained | No encrypted resources, external fetch, >300 sections, or >32 MiB declared expansion; bounded decompression per resource |
| LifeOS JSON | Schema 1 record backup; validated before replacement | User confirms replacement; credentials/audit/chat excluded; keep a separate export first |

SHA-256 identifies batches; reimporting the same batch does nothing. Stable row IDs
support incremental imports. New rows are saved; duplicates and changed existing
rows are shown and skipped. A source correction must be reviewed manually; the app
does not silently overwrite prior imports. Identity uses provider session/set keys
for Hevy, date/meal/food occurrence for nutrition, and normalized row/occurrence for
transactions. Similar text alone does not prove two foods/transactions are the same.

The weekly budget is an allocation, not a cash-account balance. Negative transaction
amounts reduce spending (for example, refunds). Exclude allowance/income rows already
represented by your weekly budget so that they do not increase available money twice.

A rejected row is never converted into zeros. Valid new rows can be approved with
diagnostics visible. Undo reverts a retained import transaction. Audit retention is
50 revisions; JSON backups cover current records rather than historical snapshots.

Use `test/fixtures/workouts.csv`, `nutrition.txt`, `transactions.csv`,
`calendar.ics`, `lecture_sample.pdf`, and `book_sample.epub` for laptop tests.
The private uploaded workout and food exports are deliberately absent from Git.

ICS export includes only LifeOS-owned blocks and uses UTC timestamps. Exporting
never writes to Google Calendar. Importing your own exported blocks as outside
calendar data is a separate action and can duplicate them; inspect the preview.
