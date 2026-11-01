// No I/O or environment access here. The entry point supplies the current
// configuration, existing handler, and generic rejection-response factory.
export function protectWebhook(handler, getSecret, reject) {
  return async (request) => {
    const expected = getSecret();
    if (typeof expected !== 'string' || expected.trim().length === 0) {
      return reject(503);
    }
    const received = request.headers.get('x-webhook-secret');
    if (typeof received !== 'string' || received.length === 0) {
      return reject(401);
    }
    // Compare all code units without an early mismatch exit. JS execution is
    // not a formal constant-time guarantee. Use a high-entropy random secret.
    let difference = expected.length ^ received.length;
    for (let i = 0; i < Math.max(expected.length, received.length); i++) {
      difference |= (expected.charCodeAt(i) || 0) ^ (received.charCodeAt(i) || 0);
    }
    if (difference !== 0) return reject(401);
    return handler(request);
  };
}
