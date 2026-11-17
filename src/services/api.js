import axios from 'axios';

export const api = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || (window.location.pathname.startsWith('/clothes') ? '/clothes/backend/public' : '/api'),
  timeout: 10000,
  headers: { Accept: 'application/json' },
});

api.interceptors.request.use((config) => {
  const token = localStorage.getItem('cineverse-token');
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

export const authApi = {
  register: (payload) => api.post('/auth/register', payload),
  login: (identity, password) => api.post('/auth/login', { identity, password }),
  google: (credential) => api.post('/auth/google', { credential }),
  current: () => api.get('/auth/me'),
};
export const movieApi = {
  list: (params = {}) => api.get('/movies', { params }),
  details: (id) => api.get(`/movies/${id}`),
  create: (payload) => api.post('/movies', payload),
  update: (id, payload) => api.put(`/movies/${id}`, payload),
  archive: (id) => api.delete(`/movies/${id}`),
  recordView: (id, durationSeconds = 0) => api.post(`/movies/${id}/views`, { durationSeconds }),
  mediaToken: (id) => api.post(`/movies/${id}/media-token`),
  genres: () => api.get('/genres'),
};
export const watchlistApi = {
  list: () => api.get('/watchlist'),
  add: (movieId) => api.post('/watchlist/items', { movieId }),
  remove: (movieId) => api.delete(`/watchlist/items/${movieId}`),
};
export const subscriptionApi = {
  plans: () => api.get('/plans'),
  current: () => api.get('/subscriptions/me'),
  select: (planId, paymentMethod = 'Simulated') => api.post('/subscriptions', { planId, paymentMethod }),
  change: (id, planId) => api.post(`/subscriptions/${id}/change`, { planId }),
  cancel: (id) => api.post(`/subscriptions/${id}/cancel`),
  billing: () => api.get('/billing/me'),
};
export const adminApi = {
  analytics: () => api.get('/admin/analytics'),
  movies: (params = {}) => api.get('/admin/movies', { params }),
  genres: () => api.get('/genres'),
  createGenre: (payload) => api.post('/genres', payload),
  updateGenre: (id, payload) => api.put(`/genres/${id}`, payload),
  deleteGenre: (id) => api.delete(`/genres/${id}`),
  actors: () => api.get('/actors'),
  createActor: (payload) => api.post('/actors', payload),
  updateActor: (id, payload) => api.put(`/actors/${id}`, payload),
  deleteActor: (id) => api.delete(`/actors/${id}`),
  users: () => api.get('/admin/users'),
  setUserStatus: (id, status) => api.patch(`/admin/users/${id}/status`, { status }),
  subscriptions: () => api.get('/admin/subscriptions'),
  billing: () => api.get('/admin/billing'),
  setBillingStatus: (id, status) => api.patch(`/billing/${id}/status`, { status }),
};
export const mockService = {
  list: async (items) => ({ data: items }),
  save: async (key, value) => { localStorage.setItem(key, JSON.stringify(value)); return value; },
};
