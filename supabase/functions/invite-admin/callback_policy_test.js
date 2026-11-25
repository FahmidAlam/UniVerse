import { resolveInvitationCallback } from './callback_policy.js';

// Pure contract suite: no Supabase, network, account writes or email delivery.
export function runCallbackPolicyTests() {
  let checks = 0;
  const native = 'com.example.universe://reset-callback/';
  const approved = 'https://admin.example.invalid/app/';
  const local = 'http://localhost:8765/';
  function accepts(value, config, expected) {
    const actual = resolveInvitationCallback(value, config);
    if (actual !== expected) throw new Error(`Unexpected callback: ${actual}`);
    checks++;
  }
  function rejects(value, config = approved) {
    let rejected = false;
    try { resolveInvitationCallback(value, config); } catch { rejected = true; }
    if (!rejected) throw new Error(`Accepted unsafe callback: ${value}`);
    checks++;
  }
  accepts(undefined, '', native);
  accepts(null, '', native);
  accepts(native, '', native);
  accepts(approved, approved, approved);
  accepts(local, ` ${approved}, ${local} `, local);
  accepts('http://127.0.0.1:8765/app/', 'http://127.0.0.1:8765/app/', 'http://127.0.0.1:8765/app/');
  accepts('http://[::1]:8765/', 'http://[::1]:8765/', 'http://[::1]:8765/');
  for (const value of [
    '', 42, {}, [], 'https://evil.example.invalid/',
    approved + 'other', approved + '?next=https://evil.invalid', approved + '#token',
    'https://admin.example.invalid/', 'https://admin.example.invalid/app',
    'https://admin.example.invalid/app/../app/', 'https://admin.example.invalid:443/app/',
    'https://user:pass@admin.example.invalid/app/', '//admin.example.invalid/app/',
    'com.example.universe://reset-callback/other', native + '?next=evil',
  ]) rejects(value);
  rejects(approved, '');
  // Even a misconfigured allowlist cannot authorize unsafe URL forms.
  for (const value of [
    'http://admin.example.invalid/app/', 'javascript:alert(1)',
    'https://user@admin.example.invalid/', 'https://admin.example.invalid/?next=evil',
    'https://admin.example.invalid/#fragment', 'https://*.example.invalid/',
    'https://admin.example.invalid/app/../app/', 'https://admin.example.invalid:443/app/',
  ]) rejects(value, value);
  return checks;
}

if (typeof Deno !== 'undefined') {
  Deno.test('invitation callbacks require exact explicit approval', runCallbackPolicyTests);
}
