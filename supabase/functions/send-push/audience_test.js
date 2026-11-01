import { runAudienceTests } from './audience_cases.js';

Deno.test('legacy notification audience recipient contracts', async () => {
  await runAudienceTests();
});
