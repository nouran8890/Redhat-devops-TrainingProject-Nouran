import { useCallback, useEffect, useState } from 'react';
import { api } from './api';
import { colors, styles } from './theme';

export default function Catalog({ userId }) {
  const [events, setEvents] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [booking, setBooking] = useState({}); // eventId -> status message
  const [busyId, setBusyId] = useState(null);

  useEffect(() => {
    api
      .catalog()
      .then(setEvents)
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false));
  }, []);

  const handleBook = useCallback(
    async (event) => {
      setBusyId(event.id);
      setBooking((prev) => ({ ...prev, [event.id]: null }));
      try {
        const created = await api.book(String(userId), event.id);
        setBooking((prev) => ({
          ...prev,
          [event.id]: `Booking confirmed — reference ${created.id}`,
        }));
      } catch (err) {
        setBooking((prev) => ({
          ...prev,
          [event.id]: err.message,
        }));
      } finally {
        setBusyId(null);
      }
    },
    [userId]
  );

  if (loading) return <p>Loading events…</p>;
  if (error) return <p style={styles.error}>Failed to load catalog: {error}</p>;

  return (
    <div>
      <h2 style={styles.cardTitle}>Browse events</h2>
      {events.map((event) => {
        const msg = booking[event.id];
        return (
          <div key={event.id} style={styles.card}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '1rem' }}>
              <div>
                <strong style={{ fontSize: '1.05rem' }}>{event.title}</strong>
                <p style={{ ...styles.muted, margin: '0.25rem 0 0' }}>${event.price}</p>
              </div>
              <button
                style={{ ...styles.button, background: colors.accent, color: colors.accentText }}
                onClick={() => handleBook(event)}
                disabled={busyId === event.id}
              >
                {busyId === event.id ? 'Booking…' : 'Book a spot'}
              </button>
            </div>
            {msg && (
              <p style={msg.startsWith('Booking confirmed') ? styles.success : styles.error}>{msg}</p>
            )}
          </div>
        );
      })}
    </div>
  );
}