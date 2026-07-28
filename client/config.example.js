// Copy this file to config.js and fill in your values.
// config.js is gitignored — never commit real tenant/client IDs alongside secrets,
// though note client_id and tenant_id are not secrets themselves (they're public
// in the redirect request); this separation is mainly for per-environment config.

window.CLIENT_CONFIG = {
  // Entra ID app registration (the SPA registration, not the API's app registration)
  tenantId: "<your-tenant-id>",
  clientId: "<your-spa-app-registration-client-id>",

  // Must exactly match a Redirect URI configured on the app registration
  // (Platform: Single-page application). For local testing this is typically
  // http://localhost:5500 or wherever you serve this folder from.
  redirectUri: "http://localhost:5500",

  // The scope exposed by your API's app registration, e.g.
  // api://<api-app-registration-client-id>/reports.access
  apiScope: "api://<your-api-app-registration-client-id>/reports.access",

  // Your APIM gateway base URL, e.g. https://reportportal-dev-apim.azure-api.net
  apimBaseUrl: "https://<your-apim-instance>.azure-api.net",
};
