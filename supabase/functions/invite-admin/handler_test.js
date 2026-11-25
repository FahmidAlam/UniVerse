import { createInvitationHandler } from './handler.js';

// Handler integration with synthetic SDK responses. This does not execute RLS,
// deliver mail, or assert anything about a hosted function deployment.
export async function runInvitationHandlerTests() {
  let checks = 0;
  const web = 'https://admin.example.invalid/app/';
  function fixture(options = {}) {
    const writes = [];
    const calls = [];
    const createClient = (_url, key) => {
      if (key === 'anon') return { auth: { getUser: async () => ({
        data: { user: options.invalidSession ? null : { id: 'caller' } },
        error: options.invalidSession ? { message: 'invalid' } : null,
      }) } };
      return {
        from: (table) => ({
          select: () => ({ eq: () => ({ maybeSingle: async () => ({
            data: options.noProfile ? null : { role: options.role ?? 'admin' },
          }) }) }),
          upsert: async (row) => {
            writes.push({ table, row });
            return { error: options.writeError ? { message: 'denied' } : null };
          },
        }),
        auth: { admin: { inviteUserByEmail: async (email, settings) => {
          calls.push({ email, settings });
          return { error: options.inviteError ? { message: 'mail unavailable' } : null };
        } } },
      };
    };
    const env = { SUPABASE_URL: 'http://localhost/', SUPABASE_ANON_KEY: 'anon',
      SUPABASE_SERVICE_ROLE_KEY: 'service', AUTH_WEB_CALLBACK_URLS: web };
    return { handler: createInvitationHandler({ createClient, getEnv: (key) => env[key] }), writes, calls };
  }
  async function expectCase(options, status, body, authenticated = true) {
    const instance = fixture(options);
    const response = await instance.handler(new Request('http://localhost/invite-admin', {
      method: 'POST', headers: authenticated ? { Authorization: 'Bearer synthetic' } : {},
      body: JSON.stringify(body ?? { email: 'new@example.invalid' }),
    }));
    if (response.status !== status) throw new Error(`Expected ${status}, got ${response.status}`);
    checks++;
    return instance;
  }
  for (const [options, status, authenticated] of [
    [{}, 401, false], [{ invalidSession: true }, 401, true],
    [{ role: 'teacher' }, 403, true], [{ role: 'student' }, 403, true],
    [{ noProfile: true }, 403, true],
  ]) {
    const result = await expectCase(options, status, undefined, authenticated);
    if (result.writes.length || result.calls.length) throw new Error('Denied caller caused side effects');
    checks++;
  }
  const rejected = await expectCase({}, 400, { email: 'new@example.invalid', redirect_to: 'https://evil.invalid/' });
  if (rejected.writes.length || rejected.calls.length) throw new Error('Unapproved callback caused side effects');
  checks++;
  const invalid = await expectCase({}, 400, { email: '' });
  if (invalid.writes.length || invalid.calls.length) throw new Error('Invalid email caused side effects');
  checks++;
  for (const callback of [undefined, 'com.example.universe://reset-callback/', web]) {
    const result = await expectCase({}, 200, { email: ' NEW@EXAMPLE.INVALID ', name: ' Test ', redirect_to: callback });
    if (result.writes.length !== 1 || result.calls.length !== 1 ||
        result.calls[0].email !== 'new@example.invalid' ||
        result.calls[0].settings.redirectTo !== (callback ?? 'com.example.universe://reset-callback/') ||
        result.writes[0].row.role !== 'admin' || result.writes[0].row.name !== 'Test') {
      throw new Error('Approved invitation contract changed');
    }
    checks++;
  }
  const deniedWrite = await expectCase({ writeError: true }, 400);
  if (deniedWrite.calls.length) throw new Error('Email sent after failed whitelist write');
  checks++;
  await expectCase({ inviteError: true }, 400);
  const options = fixture();
  if ((await options.handler(new Request('http://localhost/', { method: 'OPTIONS' }))).status !== 200 ||
      options.writes.length || options.calls.length) throw new Error('Preflight performed work');
  checks++;
  return checks;
}

if (typeof Deno !== 'undefined') Deno.test('invitation handler preserves authorization and callback boundaries', runInvitationHandlerTests);
