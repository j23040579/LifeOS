# Optional Gemini gateway

The Flutter app talks to your own gateway. The gateway sends selected text to the
Gemini API with a server-held key. Your phone/laptop receives only model results.
The app optionally remembers a **gateway access token**, never the Gemini API key.
Do not put either secret in `config/example.json`, Dart defines, a browser bundle,
Git, screenshots, logs, or chat. Disconnect in Coach revokes local remembered
access; rotate the gateway token server-side to revoke a lost device.

Cloud checks use synthetic provider replies and have not independently validated
your live deployment. You need a Google AI project/key, an eligible model, and a
gateway on your laptop or your own HTTPS host. Existing offline app features do
not depend on any of these.

## Free-only setup

Check the current official [Gemini pricing](https://ai.google.dev/gemini-api/docs/pricing),
[rate limits](https://ai.google.dev/gemini-api/docs/rate-limits),
[models](https://ai.google.dev/gemini-api/docs/models), and
[terms/data use](https://ai.google.dev/gemini-api/terms). Free eligibility depends
on model, account and region and is not unlimited. A paid Gemini consumer chat
subscription is not evidence of free API access. Keep billing disabled; do not
activate a paid tier to make an error disappear. Free-tier submitted data may have
different handling from paid API data; review the current terms before sharing
private study, finance or health information.

Set `GEMINI_FREE_PROJECT_CONFIRMED=true` only after checking a currently eligible
free **no-billing** project/model. This is your attestation, not an API billing
verification. The code cannot prevent charges if you supply a billed project.
There is no automatic provider/model fallback or retry. Quota/auth/provider errors
leave local workflows available. Stop using live generation if free access ceases.

Google's official [model catalog](https://ai.google.dev/gemini-api/docs/models) and
[pricing](https://ai.google.dev/gemini-api/docs/pricing), checked 26 October 2026,
list `gemini-3.8-flash` (the user's intended model) and `gemini-3.5-flash-lite` with
free-tier standard input/output. Account/region eligibility and usable quota still
need checking; no successful credential-backed generation was verified here.

**New projects:** Google's catalog and
[deprecation guidance](https://ai.google.dev/gemini-api/docs/deprecations) restrict
2.5 Flash/Flash-Lite access to users who actively used them previously. They are
not shut down, but a new project may see them in discovery and receive generation
404. Use the documented new-project choices, 3.5 Flash-Lite or 3.8 Flash. Do not
infer project access from discovery alone or automatically switch models.

With `GEMINI_API_KEY` configured securely in the server environment:

```powershell
dart run tool/list_gemini_models.dart
```

This read-only command prints `generateContent` model names; it neither chooses a
model nor proves free eligibility. For `models/<id>` output, configure only `<id>`.

## Zero-key development

The app includes Coach → **Try chat demo (offline)**. It makes no network request,
uses no model, and labels every response as a demo. No server is needed.

For testing the gateway protocol on your Windows laptop, open another terminal in
the repo root:

```powershell
$env:LIFEOS_AI_PROVIDER = 'mock'
dart run tool/ai_gateway.dart
```

In Coach configure `http://127.0.0.1:8787` and the **public non-secret development
value** `lifeos-public-mock-token`. The loopback-only server uses no model/key.
All responses say they are demo output. Stop it with Ctrl+C. Clear the temporary
provider variable before real use:

```powershell
Remove-Item Env:LIFEOS_AI_PROVIDER
```

The server binds only to the laptop loopback address. It is not a public service.
Android release builds disallow cleartext HTTP; use the in-app offline demo or an
HTTPS gateway for Android. Do not expose port 8787 or your key to the LAN.

## Live generation on your laptop

Supply `GEMINI_API_KEY` and a random `LIFEOS_GATEWAY_TOKEN` (at least 16 characters)
through your local secret manager or secure environment configuration. The example
`server/.env.example` lists names only; the Dart server does not automatically read
.env files. Never paste actual values into commands that are saved/shared.

Set these non-secret selections after verification:

```powershell
$env:LIFEOS_AI_PROVIDER = 'gemini'
$env:LIFEOS_AI_MODEL = '<verified-free-model-id>'
$env:GEMINI_FREE_PROJECT_CONFIRMED = 'true'
$env:LIFEOS_AI_DAILY_LIMIT = '20'
dart run tool/ai_gateway.dart
```

Configure the loopback URL and your gateway token in Coach. **Check gateway** checks
readiness only; it does not generate a response or validate Google credentials.
Then ask one short non-sensitive question to verify the provider. A real successful
response is labelled with its returned provider/model; gateway errors are not AI
answers. Local limits are 4 requests/minute and 20/day by default; they reset on
process restart and do not replace Google's quota/billing controls.

## Optional Android HTTPS gateway

`gemini-worker.mjs` is a deployment template for a user-owned Cloudflare Worker.
It uses standard Worker APIs and no paid storage/service. Cloudflare account, plan
limits and Gemini eligibility still need verification. No account was connected
and nothing was deployed. Review `wrangler.example.toml` before creating a deployment
configuration; deploying is a separate external publication step.

Use the dashboard secret settings for `GEMINI_API_KEY` and
`LIFEOS_GATEWAY_TOKEN`; set the model and confirmation as non-secret variables.
Use a long random token unique to this single-user gateway. CORS accepts local
browser development origins and optional exact `APP_ORIGIN`; authentication is
required regardless of CORS. Request bodies are limited to 32 KiB, source to
6,000 characters, question to 12,000, and output to 2,048 model tokens. The Worker
relies on provider/account quotas; it does not implement a durable per-user quota.
Select Workers Free only and never enable a paid fallback. Do not configure a
billed Gemini project under the assumption that this template can cap charges.

Configure the resulting HTTPS base URL and gateway token in Coach on Android.
Avoid shared public gateways: their operator can read your selected prompt/source.
Rotate/revoke both secrets when needed. Deleting local chat does not request
provider-side deletion; follow Google's account controls and applicable terms.

## Diagnose configured-but-failing generation

The `/health` check verifies configured values and gateway authentication. It does
not send a generation request to Google or validate the key/model's access. Model
discovery also does not establish generation quota or free eligibility. A Home score
labelled **Local calculation / Local fallback** is not a Gemini result.

After confirming that the Google project/model is free and unbilled, run this in
**Bash / Git Bash**, in the checkout root:

```bash
git pull --ff-only
flutter pub get
read -r -s -p "Paste Gemini API key, then press Enter: " GEMINI_API_KEY
printf '\n'
export GEMINI_API_KEY
export LIFEOS_AI_MODEL=gemini-3.8-flash
export GEMINI_FREE_PROJECT_CONFIRMED=true
dart run tool/check_gemini.dart
unset GEMINI_API_KEY
```

Use your exact discovered, free-eligible model ID if different. This sends one
fixed greeting with the gateway's JSON settings directly to Google. It sends no
personal records or gateway token, makes no retry/model switch, and does not print
raw provider errors, answer content or keys. It consumes generation quota. The
confirmation flag cannot verify billing. Missing configuration sends no request.

| Result/code | Next step |
|---|---|
| `PASS` | Direct Gemini generation works for this test; compare the Cloudflare key/model and deploy the updated Worker. This does not verify the Cloudflare path. |
| `gemini_key` | Correct/replace the API key and update the Worker secret. |
| `gemini_permission` | Check key restrictions, API/project access and free eligibility; keep billing disabled. |
| `gemini_model` | Check the exact model ID and generation access for the project. |
| `gemini_request` | Google rejected a request/configuration value. This alone does not prove that JSON output is unsupported; compare the direct test and Worker configuration. |
| `gemini_precondition` | Google returned `FAILED_PRECONDITION`; check account/project/region/free-tier eligibility. Keep billing disabled. |
| `gemini_quota` | Check AI Studio free quota and reset time; discovery does not prove usable free quota. |
| `gemini_output_limit` | Output budget was exhausted; request a shorter answer. Further budget configuration needs the model's documented capabilities. |
| `gemini_blocked` / `gemini_empty` | Try a short text-only question and check model compatibility. |
| `gateway_timeout` / `gemini_unavailable` | Timeout/provider failure; no automatic retry occurred. |

If 3.8 repeatedly returns 503, a manual diagnostic run with
`LIFEOS_AI_MODEL=gemini-3.5-flash-lite` can check the current recommended alternative.
If it succeeds and you choose to use it, update the Worker's `LIFEOS_AI_MODEL`,
deploy the variable change, and reconnect LifeOS with the existing URL/token to
refresh its displayed model. Do not test 2.5 as a default fallback for a new project.
Google's [API error guidance](https://ai.google.dev/gemini-api/docs/api-errors)
describes 503 as temporary overload/downtime; this does not establish a wider outage
or prove that every error body came from a structured Google RPC response.

The updated Worker returns allowlisted codes and an upstream HTTP status, never raw
Google errors that could contain keys/prompts/account metadata. Flutter displays the
safe diagnostics in Coach and Home. Legacy/unknown errors stay generic. The laptop
gateway uses the same Dart classifications.

### Direct test passes but Worker generation returns HTTP 400

The user reported a direct `gemini-3.5-flash-lite` JSON probe **PASS**, followed by
Worker generation HTTP 400. That establishes that the locally entered key/model
can handle this test's JSON settings. It does not validate the key stored in the
Worker or Google's handling of the request from its hosting region.

First edit the Worker's **GEMINI_API_KEY secret** and replace it with the exact key
used for the successful direct test. Paste only the key value, with no quotes,
assignment prefix or surrounding whitespace. Deploy the secret change; preserve
the gateway token and the selected model. Re-test with a short question.

The updated diagnostics also recognize known invalid-key messages when Google's
error has no `ErrorInfo.reason`. Allowlisted Google RPC statuses such as
`INVALID_ARGUMENT` and `FAILED_PRECONDITION` now travel through the Worker and app.
No raw message, key, region name, project identifier or prompt is reflected. A
remaining generic 400 is not automatically labelled a JSON compatibility problem.

If the problem persists after replacing the secret, deploy the latest Worker code
and run the updated app. Share its safe code, HTTP status and Google RPC status;
do not keep switching models or enable billing to diagnose a precondition.

**Pulling Git does not update a deployed Worker.** In Cloudflare **Edit code**,
replace the code with the current entire `server/gemini-worker.mjs`, and **Deploy**.
Keep the existing secret bindings. Restart the updated app and test one short
question. No new dependency, billing upgrade, automatic model switch or logging of
keys/prompts is introduced. Share only the tool's safe result/code and HTTP status.

No actual Gemini account key or deployed Worker access was available for cloud
validation. Synthetic tests exercise the protocol, not live provider eligibility.

## Data and action boundary

Only the question and explicitly selected task fields/source excerpt/summary leave
the app. Training is a bounded recent summary; finance shares totals without
transaction descriptions. Notes/documents are never uploaded during local import.
Source text is marked untrusted and cannot invoke tools. The model returns an
answer plus an optional typed task proposal. The client validates action type,
selected task identity, duration and strict dates, then requires review. Original
deadline changes need an explicit source/reason. A stale revision blocks applying
old proposals. No calendar, payment, invitation or external write tool exists.

Chat is session-only and can be cleared. There is no code execution sandbox; the
model must not claim it compiled or ran code. Cited claims need your source review.
Prompt text alone does not prove correctness or completely prevent model mistakes.

## Protocol checks

```powershell
node --test server/gemini-worker.test.mjs
flutter test test/domain/ai_gateway_test.dart
flutter test test/features/workspace/ai_proposal_test.dart
flutter test test/features/workspace/credentials_test.dart
```

These use synthetic responses, not Google credentials. Native secure storage and
real provider generation still need Windows/Android manual testing. Cloud setup
saves an optional `GEMINI_API_KEY` secret requirement for secure entry in environment
settings; a saved requirement is not an actual configured key or deployment.
