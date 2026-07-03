# Testing the functions

Two functions: `generate_report` (builds PDF, uploads to blob, returns SAS URL) and `send_report_email` (sends that URL by email). Both sit behind APIM — JWT validated there, claims forwarded as headers.

---

## Prerequisites

- Infra deployed (`terraform apply` from repo root)
- Sample data seeded (`scripts/seed.sql` run via Azure Portal Query editor — see main README)
- Function code deployed (see "Deploying" section in main README)
- Azure CLI logged in (`az login`)

---

## 1. Local testing (before deploying)

Catches bugs before they hit Azure. Bypasses APIM entirely — no JWT validation locally.

```bash
cd functions
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

cp local.settings.json.example local.settings.json
# edit local.settings.json — fill in your actual Key Vault URI and storage account name

func start
```

Since there's no APIM in front locally, `x-ms-client-principal-id` won't be set automatically. Fake it manually:

```bash
curl -X POST http://localhost:7071/api/generate \
  -H "Content-Type: application/json" \
  -H "x-ms-client-principal-id: user-001" \
  -d '{"report_id": "<uuid-from-seed-data>"}'
```

> Note: seed data uses `user-001` as a placeholder `user_id`. Real auth flow uses Entra ID `oid` (a GUID) — update seed data once you have a real test user, or keep using `user-001` for local-only testing.

Expected response:

```json
{
  "report_id": "...",
  "download_url": "https://....blob.core.windows.net/reports/...",
  "expires_in_hours": 48
}
```

Open `download_url` in a browser — should download a PDF with the seeded expense line items and a total.

---

## 2. Smoke test after deploy (direct Function URL, bypasses APIM)

Confirms the Function App itself works in Azure — managed identity, Key Vault access, SQL connection, blob upload. Still no JWT validation at this stage.

```bash
curl -X POST https://reportportal-dev-func.azurewebsites.net/api/generate \
  -H "Content-Type: application/json" \
  -H "x-ms-client-principal-id: user-001" \
  -d '{"report_id": "<uuid-from-seed-data>"}'
```

If this fails, check in order: Function App logs (Application Insights), managed identity role assignments (`rbac.tf`), Key Vault secret names match `app_settings`.

---

## 3. Full flow test through APIM (real auth)

This is the actual production path — JWT validated, claims forwarded, both functions chained.

**Get a token**

```bash
TOKEN=$(az account get-access-token \
  --resource <api-client-id> \
  --query accessToken -o tsv)
```

Replace `<api-client-id>` with the value from `terraform output api_client_id`.

**Generate the report**

```bash
RESPONSE=$(curl -s -X POST https://reportportal-dev-apim.azure-api.net/reports/generate \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"report_id": "<uuid-from-seed-data>"}')

echo $RESPONSE
DOWNLOAD_URL=$(echo $RESPONSE | jq -r '.download_url')
```

**Send the email**

```bash
curl -X POST https://reportportal-dev-apim.azure-api.net/reports/send-report-email \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"download_url\": \"$DOWNLOAD_URL\", \"expires_in_hours\": 48}"
```

Check the inbox tied to your test account's `preferred_username` claim. If nothing arrives, check ACS delivery reports in the Azure Portal before assuming the Function failed — ACS sometimes delays or queues under free-tier limits.

---

## Common failure points

| Symptom | Likely cause |
|---|---|
| 401 on APIM call | Token audience doesn't match `api_client_id`, or token expired |
| 404 on generate | `report_id` doesn't exist, or doesn't belong to the authenticated user — same response for both, by design |
| 500 on generate | SQL connection failure — check managed identity has `SQL DB Contributor` role, check Key Vault secret name matches |
| PDF downloads but is empty/broken | Check `reportlab` installed correctly — remote build sometimes misses system deps, check deployment logs |
| Email never arrives | Check ACS delivery report in Portal; check `ACS_SENDER_ADDRESS` matches actual provisioned domain |
| `x-ms-client-principal-id` empty in Function | APIM policy not forwarding claim — check `set-header` policy in `apim.tf` is applied (`terraform apply` again if recently added) |

---

## Cleaning up test data

```sql
DELETE FROM expense_line_items WHERE report_id = '<test-report-id>';
DELETE FROM expense_reports WHERE id = '<test-report-id>';
```

Run via Query editor. Re-run `seed.sql` to reset to known state.
