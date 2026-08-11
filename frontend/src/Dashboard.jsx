import { useEffect, useMemo, useState } from 'react';
import {
  LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
  PieChart, Pie, Cell, Legend,
} from 'recharts';
import { api } from './api';
import { colors, sentimentColors, styles } from './theme';

const AXIS = { stroke: colors.teal, fontSize: 11 };

export default function Dashboard() {
  const [snapshot, setSnapshot] = useState(null);
  const [error, setError] = useState(null);
  const [search, setSearch] = useState('');
  const [sortKey, setSortKey] = useState('bookingsCount');
  const [sortDir, setSortDir] = useState('desc');

  useEffect(() => {
    api.analyticsSummary().then(setSnapshot).catch((err) => setError(err.message));
  }, []);

  const rows = useMemo(() => {
    if (!snapshot) return [];
    const filtered = snapshot.eventsTable.filter((row) =>
      row.title.toLowerCase().includes(search.toLowerCase())
    );
    return [...filtered].sort((a, b) => {
      const dir = sortDir === 'asc' ? 1 : -1;
      return a[sortKey] > b[sortKey] ? dir : a[sortKey] < b[sortKey] ? -dir : 0;
    });
  }, [snapshot, search, sortKey, sortDir]);

  function toggleSort(key) {
    if (sortKey === key) {
      setSortDir((d) => (d === 'asc' ? 'desc' : 'asc'));
    } else {
      setSortKey(key);
      setSortDir('desc');
    }
  }

  if (error) {
    return <p style={styles.error}>Failed to load analytics: {error}</p>;
  }
  if (!snapshot) {
    return <p>Loading analytics…</p>;
  }

  const sentimentData = Object.entries(snapshot.sentimentTotals).map(([name, value]) => ({
    name,
    value,
  }));

  const columns = [
    ['title', 'Event'],
    ['bookingsCount', 'Bookings'],
    ['revenue', 'Revenue'],
    ['reviewCount', 'Reviews'],
    ['avgSentimentScore', 'Avg sentiment'],
  ];

  return (
    <div>
      <p style={styles.muted}>
        Last generated: {new Date(snapshot.generatedAt).toLocaleString()}
      </p>

      <div style={{ display: 'flex', gap: '1.5rem', flexWrap: 'wrap' }}>
        <div style={{ ...styles.card, flex: '1 1 340px', height: 300 }}>
          <h3 style={styles.cardTitle}>Bookings over time</h3>
          <ResponsiveContainer width="100%" height="88%">
            <LineChart data={snapshot.bookingsTimeseries}>
              <CartesianGrid strokeDasharray="3 3" stroke={colors.border} />
              <XAxis dataKey="date" tick={AXIS} stroke={AXIS.stroke} />
              <YAxis allowDecimals={false} tick={AXIS} stroke={AXIS.stroke} />
              <Tooltip contentStyle={{ background: colors.surface, border: `1px solid ${colors.border}`, borderRadius: 8 }} labelStyle={{ color: colors.primaryText }} itemStyle={{ color: colors.primaryText }} />
              <Line type="monotone" dataKey="bookings" stroke={colors.brand} strokeWidth={2} dot={false} />
            </LineChart>
          </ResponsiveContainer>
        </div>

        <div style={{ ...styles.card, flex: '1 1 280px', height: 300 }}>
          <h3 style={styles.cardTitle}>Review sentiment</h3>
          <ResponsiveContainer width="100%" height="88%">
            <PieChart>
              <Pie
                data={sentimentData}
                dataKey="value"
                nameKey="name"
                outerRadius={80}
                label={({ name, value }) => `${name} (${value})`}
              >
                {sentimentData.map((entry) => (
                  <Cell key={entry.name} fill={sentimentColors[entry.name] || sentimentColors.neutral} />
                ))}
              </Pie>
              <Legend wrapperStyle={{ color: colors.primaryText }} />
              <Tooltip contentStyle={{ background: colors.surface, border: `1px solid ${colors.border}`, borderRadius: 8 }} itemStyle={{ color: colors.primaryText }} />
            </PieChart>
          </ResponsiveContainer>
        </div>
      </div>

      <div style={{ ...styles.card, marginTop: '1rem' }}>
        <h3 style={styles.cardTitle}>Events</h3>
        <input
          placeholder="Filter by event title…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          style={{ ...styles.input, maxWidth: 320, marginBottom: '0.75rem' }}
        />
        <table style={{ borderCollapse: 'collapse', width: '100%' }}>
          <thead>
            <tr>
              {columns.map(([key, label]) => (
                <th
                  key={key}
                  onClick={() => toggleSort(key)}
                  style={{ cursor: 'pointer', textAlign: 'left', borderBottom: `1px solid ${colors.border}`, padding: '0.4rem', color: colors.primaryText }}
                >
                  {label}{sortKey === key ? (sortDir === 'asc' ? ' ^' : ' v') : ''}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => (
              <tr key={row.eventId}>
                <td style={{ padding: '0.4rem', borderBottom: `1px solid ${colors.border}` }}>{row.title}</td>
                <td style={{ padding: '0.4rem', borderBottom: `1px solid ${colors.border}` }}>{row.bookingsCount}</td>
                <td style={{ padding: '0.4rem', borderBottom: `1px solid ${colors.border}` }}>${row.revenue}</td>
                <td style={{ padding: '0.4rem', borderBottom: `1px solid ${colors.border}` }}>{row.reviewCount}</td>
                <td style={{ padding: '0.4rem', borderBottom: `1px solid ${colors.border}` }}>{row.avgSentimentScore}</td>
              </tr>
            ))}
          </tbody>
        </table>
        {rows.length === 0 && <p style={styles.muted}>No events match your filter.</p>}
      </div>
    </div>
  );
}