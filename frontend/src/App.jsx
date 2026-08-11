import { useEffect, useState } from 'react';
import { decodeToken, getToken, setToken } from './api';
import Auth from './Auth';
import Catalog from './Catalog';
import Bookings from './Bookings';
import Dashboard from './Dashboard';
import { colors, styles } from './theme';

const TABS = [
  { key: 'catalog', label: 'Catalog' },
  { key: 'bookings', label: 'My Bookings' },
  { key: 'dashboard', label: 'Dashboard' },
];

export default function App() {
  const [token, setTokenState] = useState(() => getToken());
  const [user, setUser] = useState(() => decodeToken(getToken()));
  const [tab, setTab] = useState('catalog');

  useEffect(() => {
    setUser(decodeToken(token));
  }, [token]);

  function handleAuthed(newToken) {
    setToken(newToken);
    setTokenState(newToken);
    setTab('catalog');
  }

  function handleLogout() {
    setToken(null);
    setTokenState(null);
    setUser(null);
  }

  return (
    <div style={styles.page}>
      <header style={styles.header}>
        <h1 style={styles.title}>EventHub</h1>
        {user && (
          <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
            <span style={styles.muted}>Signed in as {user.email}</span>
            <button style={{ ...styles.button, background: colors.secondary, color: colors.accentText }} onClick={handleLogout}>
              Log out
            </button>
          </div>
        )}
      </header>

      {!user ? (
        <Auth onAuthed={handleAuthed} />
      ) : (
        <>
          <div style={styles.tabRow}>
            {TABS.map(({ key, label }) => (
              <button
                key={key}
                style={styles.tab(tab === key)}
                onClick={() => setTab(key)}
                disabled={tab === key}
              >
                {label}
              </button>
            ))}
          </div>

          {tab === 'catalog' && <Catalog userId={user.sub} />}
          {tab === 'bookings' && <Bookings userId={user.sub} />}
          {tab === 'dashboard' && <Dashboard />}
        </>
      )}

      <p style={{ ...styles.muted, marginTop: '3rem', fontSize: '0.8rem' }}>
        EventHub — book a spot, get notified async, and read AI sentiment on reviews.
      </p>
    </div>
  );
}