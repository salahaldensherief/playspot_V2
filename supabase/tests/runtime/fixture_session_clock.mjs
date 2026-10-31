// Writer/permit tests need an ordinary fixed session, not a DST ambiguity.
// Keep the original two-hour-old preference, moving backwards only when the
// database's own Cairo timezone rules cannot round-trip the two-hour reservation window (including adjacent sessions).
export async function fixtureSessionStart(db, now = Date.now()) {
  const preferred = Math.floor(now / 60000) * 60000 - 120 * 60000;
  const result = await db.query(`
    WITH candidates AS (
      SELECT $1::bigint - n * 3600000::bigint AS ms
      FROM generate_series(0, 20) AS n
    ), instants AS (
      SELECT ms, to_timestamp(ms / 1000.0) AS starts,
        to_timestamp((ms + 7200000) / 1000.0) AS ends FROM candidates
    )
    SELECT ms FROM instants
    WHERE ((starts AT TIME ZONE 'Africa/Cairo') AT TIME ZONE 'Africa/Cairo') = starts
      AND ((ends AT TIME ZONE 'Africa/Cairo') AT TIME ZONE 'Africa/Cairo') = ends
      AND (ends AT TIME ZONE 'Africa/Cairo') - (starts AT TIME ZONE 'Africa/Cairo') = interval '2 hours'
    ORDER BY ms DESC LIMIT 1`, [preferred]);
  if (!result.rows.length) throw new Error('No ordinary Cairo interval for isolated fixture');
  return Number(result.rows[0].ms);
}
