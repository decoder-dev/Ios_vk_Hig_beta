#!/usr/bin/env node
// Direct APNs diagnostic. It does not subscribe to VK events or configure VK's provider.
import { readFile } from 'node:fs/promises';
import { sign } from 'node:crypto';
import { connect } from 'node:http2';
import { pathToFileURL } from 'node:url';
import { resolve } from 'node:path';

export function configuration(env) {
  const required = name => {
    const value = env[name]?.trim();
    if (!value) throw new Error(`Missing ${name}`);
    return value;
  };
  const team = required('VK_APPLE_TEAM_ID');
  const keyID = required('VK_APNS_KEY_ID');
  const keyPath = required('VK_APNS_KEY_PATH');
  const token = required('VK_APNS_DEVICE_TOKEN');
  const environment = required('VK_APNS_ENVIRONMENT');
  const topic = env.VK_APNS_TOPIC?.trim() || 'com.decoderdev.vkhig';
  if (!/^[A-Z0-9]{10}$/.test(team) || !/^[A-Z0-9]{10}$/.test(keyID)) throw new Error('Invalid Apple Team ID or Key ID');
  // APNs tokens have variable length. Do not assume exactly 32 bytes.
  if (!/^[a-f0-9]{32,512}$/i.test(token) || token.length % 2) throw new Error('Invalid APNs device token');
  if (!['development', 'production'].includes(environment)) throw new Error('Invalid APNs environment');
  if (!/^[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$/.test(topic)) throw new Error('Invalid APNs topic');
  return {
    team, keyID, keyPath, token: token.toLowerCase(), topic,
    host: environment === 'development' ? 'https://api.sandbox.push.apple.com' : 'https://api.push.apple.com',
  };
}

export function providerJWT(config, key, now = Date.now()) {
  const encode = object => Buffer.from(JSON.stringify(object)).toString('base64url');
  const unsigned = `${encode({ alg: 'ES256', kid: config.keyID })}.${encode({ iss: config.team, iat: Math.floor(now / 1000) })}`;
  const signature = sign('sha256', Buffer.from(unsigned), { key, dsaEncoding: 'ieee-p1363' });
  return `${unsigned}.${signature.toString('base64url')}`;
}

export function notificationRequest(config, jwt) {
  return {
    headers: {
      ':method': 'POST', ':path': `/3/device/${config.token}`,
      authorization: `bearer ${jwt}`, 'apns-topic': config.topic,
      'apns-push-type': 'alert', 'apns-priority': '10', 'apns-expiration': '0',
    },
    payload: JSON.stringify({ aps: { alert: { title: 'VK HIG', body: 'Проверка доставки APNs. События VK проверяются отдельно.' }, sound: 'default' } }),
  };
}

export async function send(config, jwt, connection = connect) {
  const { headers, payload } = notificationRequest(config, jwt);
  const client = connection(config.host);
  try {
    return await new Promise((resolveResult, reject) => {
      let stream;
      let body = '';
      let response;
      let settled = false;
      const rejectRequest = message => { if (!settled) { settled = true; clearTimeout(timer); reject(new Error(message)); } };
      const timer = setTimeout(() => { rejectRequest('APNs request timed out'); stream?.close(); }, 15000);
      const fail = () => rejectRequest('APNs connection failed');
      client.once('error', fail);
      try { stream = client.request(headers); } catch { rejectRequest('APNs request failed'); return; }
      stream.setEncoding('utf8');
      stream.once('response', value => { response = value; });
      stream.on('data', value => { if (body.length < 4096) body += value.slice(0, 4096 - body.length); });
      stream.once('error', fail);
      stream.once('end', () => {
        if (settled) return;
        settled = true;
        clearTimeout(timer);
        let reason = '';
        try { reason = JSON.parse(body).reason || ''; } catch { /* Non-JSON failure remains a failure. */ }
        resolveResult({ status: Number(response?.[':status'] || 0), reason });
      });
      stream.once('close', () => { if (!settled) rejectRequest('APNs connection closed before response'); });
      stream.end(payload);
    });
  } finally { client.destroy(); }
}

async function main() {
  const config = configuration(process.env);
  const key = await readFile(config.keyPath);
  const result = await send(config, providerJWT(config, key));
  if (result.status !== 200) {
    // Only print Apple's documented reason field, never the token, JWT, key, or payload.
    const safeReason = /^[A-Za-z0-9]+$/.test(result.reason) ? result.reason : 'UnknownError';
    throw new Error(`APNs rejected request: HTTP ${result.status} ${safeReason}`);
  }
  console.log('APNs accepted the notification. Confirm delivery on the device; VK event delivery is a separate check.');
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  main().catch(error => {
    // File-system/crypto errors may contain paths or key fragments; do not echo them.
    const safe = /^(Missing VK_|Invalid |APNs )/.test(error.message) ? error.message : 'Unable to read APNs signing key or sign the request';
    console.error(safe);
    process.exitCode = 1;
  });
}
