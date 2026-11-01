// Recovered legacy recipient selection. Keep truthy-target/AND semantics;
// canonical scopes, shared groups and co-teacher audiences are later tasks.
export async function resolveNotificationTargets(admin, notification) {
  let query = admin.from('profiles').select('id');
  if (notification.target_role) query = query.eq('role', notification.target_role);
  if (notification.target_batch) query = query.eq('batch', notification.target_batch);
  if (notification.target_section) query = query.eq('section', notification.target_section);
  const { data: profiles, error: profileError } = await query;
  if (profileError) throw profileError;

  const userIds = (profiles ?? []).map(profile => profile.id);
  if (userIds.length === 0) return { tokens: [], reason: 'no audience' };

  const { data: tokenRows, error: tokenError } = await admin
    .from('device_tokens')
    .select('token')
    .in('user_id', userIds);
  if (tokenError) throw tokenError;

  const tokens = (tokenRows ?? []).map(row => row.token);
  if (tokens.length === 0) return { tokens, reason: 'no tokens' };
  return { tokens };
}
