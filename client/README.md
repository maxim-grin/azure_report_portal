# Report Portal — Client (minimal)

A static HTML/JS test client for exercising the full flow: Entra ID login →
JWT → API Management → Function → SAS download URL → email. No build step,
no framework — plain MSAL.js loaded from CDN.

This is a test harness, not a production frontend. It exists so you can click
through the flow described in the main README's "Testing the flow" section
without hand-crafting JWTs.

## Files

```
client/
├── index.html          # UI: sign in, generate report, send email, request log
├── app.js              # MSAL auth (redirect flow) + fetch calls to APIM
├── config.example.js   # Copy to config.js and fill in your values
└── README.md           # This file
```

## 1. Register a second app registration (the SPA)

Your Terraform (`identity.tf`) already creates an app registration for the
*API*. The client needs its **own** app registration, of type "Single-page
application", so the browser can run the auth code + PKCE flow without a
client secret.

In the Entra ID portal (or via `az ad app create`):

1. **App registrations → New registration**
   - Name: `report-portal-client` (or similar)
   - Supported account types: same tenant as your API registration
   - Redirect URI: platform **Single-page application**, value
     `http://localhost:5500` (or wherever you'll serve this folder)
2. Under **API permissions**, add a permission to your existing API app
   registration's exposed scope (e.g. `reports.access`), then grant admin
   consent.
3. Under **Expose an API** (on the *API* app registration, not this new one),
   confirm the scope exists and note its full URI, e.g.:
   ```
   api://<api-app-registration-client-id>/reports.access
   ```
4. No client secret is needed — SPA registrations use PKCE, not a secret.

## 2. Enable CORS on APIM

The browser will call your APIM endpoint directly, so APIM needs a CORS
policy allowing the client's origin. Add this to your APIM API policy
(`apim.tf` or the policy XML it references):

```xml
<cors allow-credentials="false">
  <allowed-origins>
    <origin>http://localhost:5500</origin>
  </allowed-origins>
  <allowed-methods>
    <method>POST</method>
    <method>OPTIONS</method>
  </allowed-methods>
  <allowed-headers>
    <header>*</header>
  </allowed-headers>
</cors>
```

Update the origin to match wherever you actually host this client (add the
production origin too, once you have one).

## 3. Configure the client

```bash
cd client
cp config.example.js config.js
```

Edit `config.js`:

| Field           | Value                                                        |
| --------------- | ------------------------------------------------------------- |
| `tenantId`      | Your Entra ID tenant ID                                       |
| `clientId`      | The **SPA** app registration's client ID (from step 1)       |
| `redirectUri`   | Must exactly match the redirect URI registered in step 1     |
| `apiScope`      | The API's exposed scope URI (from step 1.3)                  |
| `apimBaseUrl`   | Your APIM gateway base URL, e.g. `https://reportportal-dev-apim.azure-api.net` |

`config.js` is gitignored — it's not committed, both to keep environments
separate and as a matter of habit, even though these particular values aren't
secrets (they're visible in any browser network tab).

## 4. Serve it locally

Redirect-based auth flows require a real origin — `file://` won't work.
Any static file server is fine, e.g.:

```bash
npx serve . -l 5500
# or
python3 -m http.server 5500
```

Then open `http://localhost:5500`.

## 5. Use it

1. **Sign in with Entra ID** — redirects to the Microsoft login page, then
   back to this app with a session.
2. Paste a `report_id` from `functions/scripts/seed.sql` (after you've run
   the seed script) and click **POST /reports/generate**.
3. The returned `download_url` appears as a link — click to confirm the PDF
   renders.
4. Click **POST /reports/send-report-email** to trigger the email step.
5. The **Request log** panel shows the raw request/response for each call,
   which is useful for confirming the JWT is actually being validated at
   APIM rather than just trusted.

## Notes

- This client only ever holds an access token in `sessionStorage` (cleared
  on tab close) — see `cacheLocation` in `app.js` if you want to change that.
- If you deploy this beyond localhost, add the real origin to both the
  Entra ID redirect URI list and the APIM CORS policy — both must match
  exactly (scheme, host, port).
