import { useCallback, useEffect, useMemo, useState } from 'react';
import { api } from './api';
import { colors, sentimentColors, styles } from './theme';

const POLL_MS = 5000;

export default function Bookings({ userId }) {
  const [events, setEvents] = useState([]);
  const [bookings, setBookings] = useState([]);
  const [reviews, setReviews] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [drafts, setDrafts] = useState({});
  const [submitting, setSubmitting] = useState(null);
  const [submitMsg, setSubmitMsg] = useState({}); // bookingId -> message

  const eventsById = useMemo(() => new Map(events.map((e) => [e.id, e])), [events]);

  useEffect(() => {
    api
      .catalog()
      .then(setEvents)
      .catch(() => {});
  }, []);

  useEffect(() => {
    let cancelled = false;
    async function refresh() {
      try {
        const [b, r] = await Promise.all([api.bookings(), api.reviews()]);
        if (!cancelled) {
          setBookings(b);
          setReviews(r);
          setError(null);
        }
      } catch (err) {
        if (!cancelled) setError(err.message);
      } finally {
        if (!cancelled) setLoading(false);
      }
    }
    refresh();
    const timer = setInterval(refresh, POLL_MS);
    return () => {
      cancelled = true;
      clearInterval(timer);
    };
  }, []);

  const myBookings = useMemo(
    () =>
      bookings
        .filter((b) => String(b.userId) === String(userId))
        .sort((a, b) => (b.createdAt || '').localeCompare(a.createdAt || '')),
    [bookings, userId]
  );

  const reviewByBooking = useMemo(() => {
    const map = new Map();
    for (const r of reviews) map.set(r.bookingId, r);
    return map;
  }, [reviews]);

  const notifications = myBookings.slice(0, 5);

  const handleReview = useCallback(
    async (booking) => {
      const text = (drafts[booking.id] || '').trim();
      if (!text) return;
      setSubmitting(booking.id);
      setSubmitMsg((prev) => ({ ...prev, [booking.id]: null }));
      try {
        const created = await api.review(booking.id, text);
        setReviews((prev) => {
          const filtered = prev.filter((r) => r.bookingId !== booking.id);
          return [created, ...filtered];
        });
        setDrafts((prev) => ({ ...prev, [booking.id]: '' }));
        setSubmitMsg((prev) => ({ ...prev, [booking.id]: 'Review submitted — AI sentiment generated.' }));
      } catch (err) {
        setSubmitMsg((prev) => ({ ...prev, [booking.id]: err.message }));
      } finally {
        setSubmitting(null);
      }
    },
    [drafts]
  );

  if (loading) return <p>Loading your bookings…</p>;
  if (error) return <p style={styles.error}>Failed to load bookings: {error}</p>;

  return (
    <div>
      <section>
        <h2 style={styles.cardTitle}>Notifications</h2>
        {notifications.length === 0 && <p style={styles.muted}>No notifications yet. Book an event from the catalog.</p>}
        {notifications.map((b) => {
          const event = eventsById.get(b.eventId);
          return (
            <div key={b.id} style={styles.card}>
              <div style={{ display: 'flex', justifyContent: 'space-between', gap: '1rem', alignItems: 'center' }}>
                <div>
                  <span style={{ ...styles.badge, background: colors.accent, color: colors.accentText }}>
                    Booking confirmed
                  </span>{' '}
                  <strong>{event ? event.title : `Event #${b.eventId}`}</strong>
                </div>
                <span style={styles.muted}>{b.createdAt ? new Date(b.createdAt).toLocaleString() : ''}</span>
              </div>
            </div>
          );
        })}
      </section>

      <section style={{ marginTop: '1.5rem' }}>
        <h2 style={styles.cardTitle}>Your bookings</h2>
        {myBookings.length === 0 && <p style={styles.muted}>You have no bookings yet.</p>}
        {myBookings.map((b) => {
          const event = eventsById.get(b.eventId);
          const review = reviewByBooking.get(b.id);
          const msg = submitMsg[b.id];
          return (
            <div key={b.id} style={styles.card}>
              <div style={{ display: 'flex', justifyContent: 'space-between', gap: '1rem', flexWrap: 'wrap' }}>
                <div>
                  <strong>{event ? event.title : `Event #${b.eventId}`}</strong>
                  <p style={{ ...styles.muted, margin: '0.25rem 0 0' }}>
                    {event ? `$${event.price}` : '—'} · {b.status} ·{' '}
                    {b.createdAt ? new Date(b.createdAt).toLocaleString() : ''}
                  </p>
                  <p style={{ ...styles.muted, margin: '0.25rem 0 0', fontSize: '0.8rem' }}>Reference: {b.id}</p>
                </div>
                <span style={{ ...styles.badge, background: colors.secondary, color: colors.accentText }}>{b.status}</span>
              </div>

              {review ? (
                <div style={{ marginTop: '0.75rem', padding: '0.75rem', background: colors.surfaceAlt, borderRadius: '8px' }}>
                  <span style={{ ...styles.badge, background: sentimentColors[review.sentiment] || sentimentColors.neutral, color: colors.accentText }}>
                    {review.sentiment}
                  </span>
                  <p style={{ margin: '0.5rem 0 0' }}>
                    <em>{review.summary}</em>
                  </p>
                  {review.text && <p style={{ ...styles.muted, margin: '0.5rem 0 0', fontSize: '0.85rem' }}>“{review.text}”</p>}
                </div>
              ) : (
                <div style={{ marginTop: '0.75rem' }}>
                  <label style={styles.label}>Leave a review — AI will summarize the sentiment</label>
                  <textarea
                    style={styles.input}
                    rows={2}
                    placeholder="How was your experience?"
                    value={drafts[b.id] || ''}
                    onChange={(e) => setDrafts((prev) => ({ ...prev, [b.id]: e.target.value }))}
                  />
                  <button
                    style={{ ...styles.button, background: colors.secondary, color: colors.accentText }}
                    onClick={() => handleReview(b)}
                    disabled={submitting === b.id || !(drafts[b.id] || '').trim()}
                  >
                    {submitting === b.id ? 'Analyzing…' : 'Submit review'}
                  </button>
                  {msg && <p style={msg.includes('submitted') ? styles.success : styles.error}>{msg}</p>}
                </div>
              )}
            </div>
          );
        })}
      </section>
    </div>
  );
}