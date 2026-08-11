const BASE_URL =
  (typeof window !== 'undefined' && window.__ENV__ && window.__ENV__.API_BASE_URL) ||
  import.meta.env.VITE_API_BASE_URL ||
  'http://localhost:3000';

const TOKEN_KEY = 'eventhub_token';

export function getToken() {
  return localStorage.getItem(TOKEN_KEY) || null;
}

export function setToken(token) {
  if (token) localStorage.setItem(TOKEN_KEY, token);
  else localStorage.removeItem(TOKEN_KEY);
}

export function decodeToken(token) {
  if (!token) return null;
  try {
    const payload = JSON.parse(atob(token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')));
    return payload;
  } catch {
    return null;
  }
}

async function request(path, options = {}) {
  const token = getToken();
  const headers = { 'Content-Type': 'application/json', ...(options.headers || {}) };
  if (token) headers.Authorization = `Bearer ${token}`;

  const res = await fetch(`${BASE_URL}${path}`, { ...options, headers });
  if (!res.ok) {
    let detail = '';
    try {
      const body = await res.json();
      detail = body.error || body.detail || '';
    } catch {
      /* non-JSON error body */
    }
    throw new Error(`${options.method || 'GET'} ${path} failed: ${res.status}${detail ? ' — ' + detail : ''}`);
  }
  return res.json();
}

export const api = {
  login: (email, password) =>
    request('/api/auth/login', { method: 'POST', body: JSON.stringify({ email, password }) }),
  register: (email, password) =>
    request('/api/auth/register', { method: 'POST', body: JSON.stringify({ email, password }) }),
  catalog: () => request('/api/catalog'),
  book: (userId, eventId) =>
    request('/api/bookings', { method: 'POST', body: JSON.stringify({ userId, eventId }) }),
  bookings: () => request('/api/bookings'),
  review: (bookingId, text) =>
    request(`/api/bookings/${bookingId}/review`, { method: 'POST', body: JSON.stringify({ text }) }),
  reviews: () => request('/api/reviews'),
  analyze: (text) =>
    request('/api/analyze', { method: 'POST', body: JSON.stringify({ text }) }),
  analyticsSummary: () => request('/api/analytics/summary'),
};