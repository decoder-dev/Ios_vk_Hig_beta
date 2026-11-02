import test from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPairSync, verify } from 'node:crypto';
import { EventEmitter } from 'node:events';
import { configuration, providerJWT, notificationRequest, send } from './apns-smoke.mjs';

const env = { VK_APPLE_TEAM_ID: 'TEAM123456', VK_APNS_KEY_ID: 'KEY1234567', VK_APNS_KEY_PATH: '/fixture/key.p8', VK_APNS_DEVICE_TOKEN: 'ab'.repeat(32), VK_APNS_ENVIRONMENT: 'development' };
test('development and production select exact Apple hosts', () => {
  assert.equal(configuration(env).host, 'https://api.sandbox.push.apple.com');
  assert.equal(configuration({ ...env, VK_APNS_ENVIRONMENT: 'production' }).host, 'https://api.push.apple.com');
  assert.throws(() => configuration({ ...env, VK_APNS_ENVIRONMENT: '' }));
  assert.throws(() => configuration({ ...env, VK_APNS_TOPIC: 'invalid\nheader' }));
  assert.throws(() => configuration({ ...env, VK_APNS_DEVICE_TOKEN: 'not-a-token' }));
  assert.equal(configuration({ ...env, VK_APNS_DEVICE_TOKEN: 'aa'.repeat(64) }).token.length, 128);
});
test('provider token is an ES256 JWT with a valid P1363 signature', () => {
  const { privateKey, publicKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
  const config = configuration(env);
  const jwt = providerJWT(config, privateKey, 1700000000000);
  const [header, claims, signature] = jwt.split('.');
  assert.deepEqual(JSON.parse(Buffer.from(header, 'base64url')), { alg: 'ES256', kid: env.VK_APNS_KEY_ID });
  assert.deepEqual(JSON.parse(Buffer.from(claims, 'base64url')), { iss: env.VK_APPLE_TEAM_ID, iat: 1700000000 });
  assert.equal(Buffer.from(signature, 'base64url').length, 64);
  assert.ok(verify('sha256', Buffer.from(`${header}.${claims}`), { key: publicKey, dsaEncoding: 'ieee-p1363' }, Buffer.from(signature, 'base64url')));
});
test('request sends an alert to the correct app topic and device', () => {
  const config = configuration(env);
  const request = notificationRequest(config, 'fixture-jwt');
  assert.equal(request.headers[':path'], `/3/device/${env.VK_APNS_DEVICE_TOKEN}`);
  assert.equal(request.headers['apns-topic'], 'com.decoderdev.vkhig');
  assert.equal(request.headers['apns-push-type'], 'alert');
  assert.equal(request.headers['apns-expiration'], '0');
  assert.ok(JSON.parse(request.payload).aps.alert.body.includes('VK'));
});
test('transport returns APNs rejection and closes connection without real network', async () => {
  let destroyed = false;
  const connect = host => {
    assert.equal(host, 'https://api.sandbox.push.apple.com');
    const client = new EventEmitter();
    client.destroy = () => { destroyed = true; };
    client.request = headers => {
      assert.equal(headers.authorization, 'bearer fixture-jwt');
      const stream = new EventEmitter();
      stream.setEncoding = () => {};
      stream.end = () => queueMicrotask(() => {
        stream.emit('response', { ':status': 400 });
        stream.emit('data', '{"reason":"BadDeviceToken"}');
        stream.emit('end');
        stream.emit('close');
      });
      return stream;
    };
    return client;
  };
  assert.deepEqual(await send(configuration(env), 'fixture-jwt', connect), { status: 400, reason: 'BadDeviceToken' });
  assert.equal(destroyed, true);
});
