function apiBase() {
  if (window.SC_API_BASE) return window.SC_API_BASE.replace(/\/$/, '');
  const path = window.location.pathname;
  if (path.includes('/admin/')) return '../api';
  return 'api';
}

function apiUrl(path) {
  const clean = path.replace(/^\/+/, '');
  if (clean.startsWith('api/')) return clean;
  return apiBase() + '/' + clean;
}

async function readJsonResponse(res) {
  const text = await res.text();
  try { return JSON.parse(text); }
  catch (e) {
    throw new Error('API did not return JSON. Check URL/path and server error. First response bytes: ' + text.slice(0, 160));
  }
}

async function apiGet(path) {
  const res = await fetch(apiUrl(path), {headers: {'Accept': 'application/json'}});
  const json = await readJsonResponse(res);
  if (!res.ok || json.success === false) throw new Error(json.message || JSON.stringify(json));
  return json;
}

async function apiPost(path, body) {
  const res = await fetch(apiUrl(path), {
    method: 'POST',
    headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    body: JSON.stringify(body || {})
  });
  const json = await readJsonResponse(res);
  if (!res.ok || json.success === false) throw new Error(json.message || JSON.stringify(json));
  return json;
}
