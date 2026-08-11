import { useState } from 'react';
import { api } from './api';
import { colors, styles } from './theme';

export default function Auth({ onAuthed }) {
  const [mode, setMode] = useState('login');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState(null);
  const [info, setInfo] = useState(null);
  const [busy, setBusy] = useState(false);

  async function handleSubmit(e) {
    e.preventDefault();
    setError(null);
    setInfo(null);
    setBusy(true);
    try {
      if (mode === 'register') {
        await api.register(email, password);
        setInfo('Registered successfully — you can now log in.');
        setMode('login');
      } else {
        const { token } = await api.login(email, password);
        onAuthed(token);
      }
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div style={{ maxWidth: 420 }}>
      <div style={styles.card}>
        <h2 style={styles.cardTitle}>{mode === 'login' ? 'Log in' : 'Sign up'}</h2>
        <form onSubmit={handleSubmit}>
          <label style={styles.label}>Email</label>
          <input
            style={styles.input}
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
            placeholder="you@example.com"
          />
          <label style={styles.label}>Password</label>
          <input
            style={styles.input}
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
            minLength={6}
            placeholder="••••••"
          />
          <button
            type="submit"
            disabled={busy}
            style={{ ...styles.button, background: colors.accent, color: colors.accentText, width: '100%' }}
          >
            {busy ? 'Please wait…' : mode === 'login' ? 'Log in' : 'Sign up'}
          </button>
        </form>

        {info && <p style={styles.success}>{info}</p>}
        {error && <p style={styles.error}>{error}</p>}

        <p style={{ ...styles.muted, marginTop: '1rem', fontSize: '0.9rem' }}>
          {mode === 'login' ? "Don't have an account?" : 'Already have an account?'}{' '}
          <button
            style={{ ...styles.button, background: colors.secondary, color: colors.accentText, padding: '0.3rem 0.7rem' }}
            onClick={() => {
              setMode((m) => (m === 'login' ? 'register' : 'login'));
              setError(null);
              setInfo(null);
            }}
          >
            {mode === 'login' ? 'Sign up' : 'Log in'}
          </button>
        </p>
      </div>
    </div>
  );
}