import { resolveNotificationTargets } from './audience.js';

// In-memory substitute for the external Supabase query boundary. It evaluates
// equality/IN filters before projecting selected columns; no network or FCM.
function fixtureClient(options = {}) {
  const profiles = [
    { id: 's1', role: 'student', batch: '66', section: 'A' },
    { id: 's2', role: 'student', batch: '66', section: 'B' },
    { id: 's3', role: 'student', batch: '67', section: 'A' },
    { id: 't1', role: 'teacher', batch: null, section: null },
    { id: 'a1', role: 'admin', batch: null, section: null },
    { id: 's4', role: 'student', batch: '66', section: 'A' },
  ];
  const device_tokens = [
    { user_id: 's1', token: 'student-a-phone' },
    { user_id: 's1', token: 'student-a-tablet' },
    { user_id: 's2', token: 'student-b-phone' },
    { user_id: 's3', token: 'other-batch-phone' },
    { user_id: 't1', token: 'teacher-phone' },
  ];
  const reads = [];
  return {
    reads,
    from(table) {
      if (!['profiles', 'device_tokens'].includes(table)) throw new Error('Unexpected table');
      const predicates = [];
      let column;
      const query = {
        select(value) { column = value; return query; },
        eq(key, value) { predicates.push(row => row[key] === value); return query; },
        in(key, values) { predicates.push(row => values.includes(row[key])); return query; },
        then(resolve, reject) {
          reads.push(table);
          const error = options[table + 'Error'] || null;
          const rows = table === 'profiles' ? profiles : device_tokens;
          const data = options[table + 'Null'] ? null : rows
            .filter(row => predicates.every(predicate => predicate(row)))
            .map(row => ({ [column]: row[column] }));
          return Promise.resolve({ data, error }).then(resolve, reject);
        },
      };
      return query;
    },
  };
}

export async function runAudienceTests() {
  // Expectations are hand-written recipients, independent of query construction.
  const cases = [
    { name: 'null means everyone', n: {}, want: ['student-a-phone', 'student-a-tablet', 'student-b-phone', 'other-batch-phone', 'teacher-phone'] },
    { name: 'role only', n: { target_role: 'teacher' }, want: ['teacher-phone'] },
    { name: 'batch only', n: { target_batch: '66' }, want: ['student-a-phone', 'student-a-tablet', 'student-b-phone'] },
    { name: 'section only', n: { target_section: 'A' }, want: ['student-a-phone', 'student-a-tablet', 'other-batch-phone'] },
    { name: 'combined dimensions AND', n: { target_role: 'student', target_batch: '66', target_section: 'A' }, want: ['student-a-phone', 'student-a-tablet'] },
    { name: 'do not leak another section', n: { target_batch: '66', target_section: 'B' }, want: ['student-b-phone'] },
    { name: 'unmatched audience', n: { target_batch: 'unknown' }, want: [], reason: 'no audience' },
    { name: 'matching profile without device', n: { target_role: 'admin' }, want: [], reason: 'no tokens' },
    { name: 'legacy empty target ignored', n: { target_role: '', target_batch: '66', target_section: 'A' }, want: ['student-a-phone', 'student-a-tablet'] },
    { name: 'null profiles response', n: {}, options: { profilesNull: true }, want: [], reason: 'no audience' },
    { name: 'null tokens response', n: {}, options: { device_tokensNull: true }, want: [], reason: 'no tokens' },
  ];
  for (const c of cases) {
    const client = fixtureClient(c.options);
    const result = await resolveNotificationTargets(client, c.n);
    if (JSON.stringify([...result.tokens].sort()) !== JSON.stringify([...c.want].sort())
        || result.reason !== c.reason) {
      throw new Error(c.name + ': recipient set or empty-result reason differs');
    }
    if (c.reason === 'no audience' && client.reads.includes('device_tokens')) {
      throw new Error(c.name + ': unnecessary token query without audience');
    }
  }
  for (const table of ['profiles', 'device_tokens']) {
    const error = new Error('synthetic database failure');
    const client = fixtureClient({ [table + 'Error']: error });
    let caught;
    try { await resolveNotificationTargets(client, {}); } catch (e) { caught = e; }
    if (caught !== error) throw new Error(table + ': database error was hidden/replaced');
    if (table === 'profiles' && client.reads.includes('device_tokens')) {
      throw new Error('Token query continued after profile query failed');
    }
  }
  return { passed: cases.length + 2 };
}
