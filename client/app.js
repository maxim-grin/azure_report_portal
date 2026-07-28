// Minimal MSAL.js (browser, redirect flow) + calls to the Report Portal API.
// No build step, no framework — open index.html via a static file server
// (redirect flows don't work over file://).

const cfg = window.CLIENT_CONFIG;

const msalConfig = {
  auth: {
    clientId: cfg.clientId,
    authority: `https://login.microsoftonline.com/${cfg.tenantId}`,
    redirectUri: cfg.redirectUri,
  },
  cache: {
    cacheLocation: "sessionStorage",
    storeAuthStateInCookie: false,
  },
};

const msalInstance = new msal.PublicClientApplication(msalConfig);

let account = null;
let lastDownloadUrl = null;

// ---- DOM refs ----
const el = {
  loginBtn: document.getElementById("loginBtn"),
  logoutBtn: document.getElementById("logoutBtn"),
  who: document.getElementById("who"),
  authPill: document.getElementById("authPill"),
  reportId: document.getElementById("reportId"),
  generateBtn: document.getElementById("generateBtn"),
  downloadRow: document.getElementById("downloadRow"),
  downloadLink: document.getElementById("downloadLink"),
  sendEmailBtn: document.getElementById("sendEmailBtn"),
  log: document.getElementById("log"),
};

function log(message, kind = "") {
  const line = document.createElement("div");
  line.className = "line";
  const ts = new Date().toLocaleTimeString();
  line.innerHTML = `<span class="ts">[${ts}]</span> <span class="${kind}">${escapeHtml(message)}</span>`;
  el.log.appendChild(line);
  el.log.scrollTop = el.log.scrollHeight;
}

function escapeHtml(str) {
  return str.replace(/[&<>"']/g, (c) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
  }[c]));
}

function setSignedInUI(acct) {
  account = acct;
  if (acct) {
    el.who.innerHTML = `<span class="name">${escapeHtml(acct.name || acct.username)}</span>
      <span class="email">${escapeHtml(acct.username)}</span>`;
    el.authPill.textContent = "signed in";
    el.authPill.classList.add("signed-in");
    el.loginBtn.style.display = "none";
    el.logoutBtn.style.display = "block";
    el.generateBtn.disabled = false;
  } else {
    el.who.innerHTML = `<span class="name">Not signed in</span>`;
    el.authPill.textContent = "signed out";
    el.authPill.classList.remove("signed-in");
    el.loginBtn.style.display = "block";
    el.logoutBtn.style.display = "none";
    el.generateBtn.disabled = true;
    el.sendEmailBtn.disabled = true;
  }
}

async function acquireToken() {
  const request = { scopes: [cfg.apiScope], account };
  try {
    const result = await msalInstance.acquireTokenSilent(request);
    return result.accessToken;
  } catch (err) {
    log(`Silent token acquisition failed, falling back to redirect: ${err.message}`, "err");
    await msalInstance.acquireTokenRedirect(request);
    // page will redirect away; nothing after this runs
  }
}

async function callApi(path, body) {
  const token = await acquireToken();
  log(`POST ${path} ${JSON.stringify(body)}`);
  const res = await fetch(`${cfg.apimBaseUrl}${path}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify(body),
  });

  const text = await res.text();
  let data;
  try { data = JSON.parse(text); } catch { data = text; }

  if (!res.ok) {
    log(`${res.status} ${res.statusText}: ${text}`, "err");
    throw new Error(`Request failed: ${res.status}`);
  }

  log(`${res.status} OK — ${JSON.stringify(data)}`, "ok");
  return data;
}

// ---- Event handlers ----

el.loginBtn.addEventListener("click", async () => {
  try {
    await msalInstance.loginRedirect({ scopes: [cfg.apiScope] });
  } catch (err) {
    log(`Login failed: ${err.message}`, "err");
  }
});

el.logoutBtn.addEventListener("click", async () => {
  await msalInstance.logoutRedirect();
});

el.generateBtn.addEventListener("click", async () => {
  const reportId = el.reportId.value.trim();
  if (!reportId) {
    log("Enter a report_id first (see functions/scripts/seed.sql)", "err");
    return;
  }
  el.generateBtn.disabled = true;
  try {
    const data = await callApi("/reports/generate", { report_id: reportId });
    lastDownloadUrl = data.download_url;
    el.downloadLink.href = lastDownloadUrl;
    el.downloadLink.textContent = lastDownloadUrl;
    el.downloadRow.style.display = "flex";
    el.sendEmailBtn.disabled = false;
  } catch (err) {
    // already logged in callApi
  } finally {
    el.generateBtn.disabled = false;
  }
});

el.sendEmailBtn.addEventListener("click", async () => {
  if (!lastDownloadUrl) return;
  el.sendEmailBtn.disabled = true;
  try {
    await callApi("/reports/send-report-email", { download_url: lastDownloadUrl });
    log("Email dispatch requested — check ACS delivery report if it doesn't arrive.");
  } catch (err) {
    // already logged
  } finally {
    el.sendEmailBtn.disabled = false;
  }
});

// ---- Init: handle redirect response, restore session ----

(async function init() {
  try {
    const response = await msalInstance.handleRedirectPromise();
    if (response && response.account) {
      setSignedInUI(response.account);
      log(`Signed in as ${response.account.username}`, "ok");
      return;
    }
  } catch (err) {
    log(`Redirect handling error: ${err.message}`, "err");
  }

  const accounts = msalInstance.getAllAccounts();
  if (accounts.length > 0) {
    setSignedInUI(accounts[0]);
  } else {
    setSignedInUI(null);
  }
})();
