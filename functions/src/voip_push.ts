import * as crypto from 'crypto';
import * as http2 from 'http2';
import { logger } from 'firebase-functions';

const APNS_HOST = 'api.push.apple.com';
const APNS_HOST_SANDBOX = 'api.sandbox.push.apple.com';

type VoipPushPayload = {
  callId: string;
  nameCaller: string;
  handle: string;
  isVideo: boolean;
  chatId: string;
  callerId: string;
  callType: string;
  agoraChannelName: string;
};

function getApnsConfig():
  | { keyId: string; teamId: string; keyP8: string; bundleId: string; useSandbox: boolean }
  | null {
  const keyId = (process.env.APNS_KEY_ID ?? '').trim();
  const teamId = (process.env.APNS_TEAM_ID ?? '').trim();
  const keyP8 = (process.env.APNS_KEY_P8 ?? '').trim().replace(/\\n/g, '\n');
  const bundleId = (process.env.APNS_BUNDLE_ID ?? 'com.vyooo').trim();
  const useSandbox = (process.env.APNS_USE_SANDBOX ?? 'false').trim() === 'true';
  if (!keyId || !teamId || !keyP8) return null;
  return { keyId, teamId, keyP8, bundleId, useSandbox };
}

function createApnsJwt(keyId: string, teamId: string, keyP8: string): string {
  const header = Buffer.from(JSON.stringify({ alg: 'ES256', kid: keyId })).toString(
    'base64url',
  );
  const now = Math.floor(Date.now() / 1000);
  const payload = Buffer.from(JSON.stringify({ iss: teamId, iat: now })).toString(
    'base64url',
  );
  const unsigned = `${header}.${payload}`;
  const sign = crypto.createSign('SHA256');
  sign.update(unsigned);
  sign.end();
  const signature = sign.sign(keyP8).toString('base64url');
  return `${unsigned}.${signature}`;
}

function sendVoipToDevice(
  deviceToken: string,
  body: Record<string, unknown>,
  config: ReturnType<typeof getApnsConfig>,
): Promise<void> {
  if (!config) return Promise.resolve();

  return new Promise((resolve, reject) => {
    const client = http2.connect(
      `https://${config.useSandbox ? APNS_HOST_SANDBOX : APNS_HOST}`,
    );
    client.on('error', reject);

    const jwt = createApnsJwt(config.keyId, config.teamId, config.keyP8);
    const topic = `${config.bundleId}.voip`;

    const req = client.request({
      ':method': 'POST',
      ':path': `/3/device/${deviceToken}`,
      authorization: `bearer ${jwt}`,
      'apns-topic': topic,
      'apns-push-type': 'voip',
      'apns-priority': '10',
      'apns-expiration': '0',
    });

    req.setEncoding('utf8');
    let response = '';
    req.on('response', (headers) => {
      const status = headers[':status'];
      req.on('data', (chunk) => {
        response += chunk;
      });
      req.on('end', () => {
        client.close();
        if (status === 200) {
          resolve();
        } else {
          reject(new Error(`APNs VoIP ${status}: ${response}`));
        }
      });
    });

    req.on('error', (err) => {
      client.close();
      reject(err);
    });

    req.write(JSON.stringify(body));
    req.end();
  });
}

export async function sendVoipCallPushes(
  deviceTokens: string[],
  payload: VoipPushPayload,
): Promise<{ sent: number; failed: number }> {
  const config = getApnsConfig();
  if (!config) {
    logger.warn(
      'VoIP push skipped: set APNS_KEY_ID, APNS_TEAM_ID, APNS_KEY_P8 in functions env',
    );
    return { sent: 0, failed: deviceTokens.length };
  }

  const body = {
    aps: { 'content-available': 1 },
    id: payload.callId,
    callId: payload.callId,
    nameCaller: payload.nameCaller,
    handle: payload.handle,
    isVideo: payload.isVideo,
    chatId: payload.chatId,
    callerId: payload.callerId,
    callType: payload.callType,
    agoraChannelName: payload.agoraChannelName,
    type: 'incoming_call',
  };

  let sent = 0;
  let failed = 0;
  for (const token of deviceTokens) {
    try {
      await sendVoipToDevice(token, body, config);
      sent++;
    } catch (e) {
      // Profile/dev builds use sandbox APNs; retry when production endpoint fails.
      if (!config.useSandbox) {
        try {
          await sendVoipToDevice(token, body, { ...config, useSandbox: true });
          sent++;
          continue;
        } catch (sandboxError) {
          logger.warn('VoIP push failed (production and sandbox)', {
            tokenPrefix: token.substring(0, 8),
            productionError: String(e),
            sandboxError: String(sandboxError),
          });
        }
      } else {
        logger.warn('VoIP push failed', {
          tokenPrefix: token.substring(0, 8),
          error: String(e),
        });
      }
      failed++;
    }
  }
  return { sent, failed };
}
