import { protectWebhook } from './webhook_auth.js';

// Portable dependency-free cases. Deno can run this file; the same exported
// suite can also run in an isolated JS engine without network/env access.
export async function runWebhookAuthTests() {
  const secret = 'synthetic-only-webhook-secret-not-a-deployed-credential';
  const cases = [
    { name: 'unset server secret', expected: undefined, received: secret, want: 503 },
    { name: 'empty server secret', expected: '', received: secret, want: 503 },
    { name: 'blank server secret', expected: '   ', received: secret, want: 503 },
    { name: 'missing caller secret', expected: secret, received: null, want: 401 },
    { name: 'empty caller secret', expected: secret, received: '', want: 401 },
    { name: 'wrong equal-length secret', expected: secret, received: 'X' + secret.slice(1), want: 401 },
    { name: 'matching prefix only', expected: secret, received: secret.slice(0, -1), want: 401 },
    { name: 'secret with appended suffix', expected: secret, received: secret + 'X', want: 401 },
    { name: 'JWT alone is not webhook authorization', expected: secret, received: null, want: 401 },
    { name: 'correct secret', expected: secret, received: secret, want: 204 },
  ];
  for (const c of cases) {
    let calls = 0;
    let bodyReads = 0;
    const request = {
      headers: { get: (name) => name === 'x-webhook-secret' ? c.received : 'Bearer synthetic-jwt' },
      json: async () => { bodyReads++; return { synthetic: true }; },
    };
    const handler = protectWebhook(
      async (req) => { calls++; await req.json(); return { status: 204 }; },
      () => c.expected,
      (status) => ({ status }),
    );
    const result = await handler(request);
    const authorized = c.want === 204;
    if (result.status !== c.want || calls !== Number(authorized) || bodyReads !== Number(authorized)) {
      throw new Error(c.name + ': wrong response or unauthorized handler/body access');
    }
  }
  // Read the configuration for each invocation: no cached allow decision after
  // secret removal/rotation in a warm instance.
  let expected = secret;
  let calls = 0;
  const handler = protectWebhook(
    async () => { calls++; return { status: 204 }; },
    () => expected,
    (status) => ({ status }),
  );
  const request = { headers: { get: () => secret } };
  if ((await handler(request)).status !== 204) throw new Error('initial authorization failed');
  expected = undefined;
  if ((await handler(request)).status !== 503 || calls !== 1) {
    throw new Error('removed server secret did not fail closed');
  }
  return { passed: cases.length + 1 };
}

if (typeof Deno !== 'undefined') {
  Deno.test('send-push webhook authorization before handler/body access', async () => {
    await runWebhookAuthTests();
  });
}
