// DEPLOY ONLY as send-push-audience-test in universe-timetable-test.
// Standalone synthetic probe endpoint: no Supabase client, database, OAuth or FCM.
// Dashboard files: index.ts (this file), audience_cases.js, audience.js,
// webhook_auth.js. Never copy the production send-push/index.ts into this probe.
import { runAudienceTests } from './audience_cases.js';
import { protectWebhook } from './webhook_auth.js';

Deno.serve(protectWebhook(async (req: Request) => {
  if (req.method !== 'POST') {
    return new Response('POST required', { status: 405 });
  }
  let payload;
  try {
    payload = await req.json();
  } catch {
    return new Response('Empty JSON object required', { status: 400 });
  }
  if (!payload || Array.isArray(payload) || typeof payload !== 'object'
      || Object.keys(payload).length !== 0) {
    return new Response('Empty JSON object required', { status: 400 });
  }
  try {
    const result = await runAudienceTests();
    return new Response(JSON.stringify({
      passed: result.passed,
      data: 'synthetic_only',
      delivery: 'not_attempted',
    }), { status: 200, headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' } });
  } catch {
    return new Response('Synthetic audience checks failed', { status: 500 });
  }
}, () => Deno.env.get('PUSH_WEBHOOK_SECRET'), (status: number) =>
  new Response(status === 503 ? 'Webhook authorization unavailable' : 'Unauthorized', {
    status, headers: { 'Cache-Control': 'no-store' },
  })
));
