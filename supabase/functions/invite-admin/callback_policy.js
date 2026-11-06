// Match the Flutter AuthCallbackPolicy contract. Configure exact callback URLs,
// including any deployment path prefix, in AUTH_WEB_CALLBACK_URLS on both sides.
// No request header (including Origin) supplies callback authority.
export const nativeInvitationCallback = 'com.example.universe://reset-callback/';

function isSafeWebCallback(value) {
  try {
    const url = new URL(value);
    const loopback = ['localhost', '127.0.0.1', '[::1]'].includes(url.hostname);
    return (url.protocol === 'https:' || (url.protocol === 'http:' && loopback)) &&
      !url.username && !url.password && !url.search && !url.hash &&
      !value.includes('?') && !value.includes('#') && !value.includes('*') &&
      url.href === value;
  } catch {
    return false;
  }
}

export function resolveInvitationCallback(requested, configuredWebCallbacks = '') {
  if (requested === undefined || requested === null) return nativeInvitationCallback;
  if (requested === nativeInvitationCallback) return nativeInvitationCallback;
  if (typeof requested !== 'string' || !isSafeWebCallback(requested)) {
    throw new Error('Invalid invitation callback.');
  }
  const approved = configuredWebCallbacks.split(',').map((value) => value.trim());
  if (!approved.includes(requested)) {
    throw new Error('Invitation callback is not approved.');
  }
  return requested;
}
