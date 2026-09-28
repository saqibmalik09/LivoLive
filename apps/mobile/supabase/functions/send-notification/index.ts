import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import * as jose from "https://deno.land/x/jose@v4.11.1/index.ts"

const privateKeyPEM = `-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQD7EzqM3hWE7I/E
R3hWLkDuFaABH/LCMREeil7BESbGuQB5/2hr+Kts36bXfI4D61V2byr/6OcRbMW/
dTypwjR6vfme8j5iTKr4MHk+NiDfH2s2FXD2thIDzHtybsLm9KUTCSuSvb8rRp/i
xIZgnyL4sfvtIp9A3VNMM42fOpo/VgW0+o+R/FWGkmiAysLcyrHxLUhD1avr6Aoa
JB4yRat47COar8bpERXKDL1A4W7qdsbuZ6f36b+488/GITaBmGqyBZf2v+qhEANW
Shpgy9R9VV0tghV/pyMvsymhajDIAs/6uf5kR/pn9IcUBhtfHZnSIadQJG3zOfB5
qQeHSQhFAgMBAAECggEAD4IQi8Lr8VnrR2RiunAA8rPDPk6K4BPHyushDyvQCVZE
AUUVXhXuALuPwp+e5f8TOE2FimkIXLsrO7gyFwo3050IXhj4YXn61XmpA360aRO3
u493esWkNzfaKCdPQpS53YMjfdzaggHKvmcFJdKuhk34EZ2h2I/TJVHJ3ZvxCxhV
0AE0NCNBI9ZNmVdfbVuRaMUCbNbdw18Alw6FQJ6ozboYdkywUvxAbAvaI5Y/E+vP
N5TgTNuyfy4QDZWutQ59RzStC8XBJAyH0kXbWj9sP8G0Nqgk3GSWj7i/wm4mVHbU
200pzWRgid60qJaw4J18RiN9D0pPrVuZRvrY9OX8AQKBgQD/Gk4ohYJIGGMZFcIf
kcvi4j3T7lNDtAAAYI7RDNA+4wG0OMkp47CS/3nMUtzZpYwA0TtYi3fjvAs3WnVX
F4Qiu2EKB6uxBhM9HI2cFJ3pCs4fMd6c7njhKmHlaUbCPMTX0Ecz9nrpS3mbYx9v
QvnP5v0roVesGCYQi329eBh4lQKBgQD79UwCiXm3/GLS+2o7yMg/Gajto9jBoFUR
b8Yam5lBTeP4+FeFxNWrwLDn28ez/mkOwNXNy9AAvSBLy29lT/K9/ZoqvlUt2uG3
H5MoSHZc08vMIEu5CgGMoCzfVqBZIS0wseja9oRYDVmfVyPMBv6L90zBU0Q4xR2S
3bfxCCx08QKBgEWUFCtDNuSZGjZWU+suZfDNClYKk9VMfA+eRnXIS+hLHETelCeD
vb5qRfsvwqLuX0A90TT2XU3VFS4U0xpdBKJAf1gv/Wk8IfUyG4GtseBFHTEu9evR
s1CesbLTwwPpdTrzyOfoW1/UQSfbolBDcUV+WCEVUYdT0tYCZdpOrkX9AoGBAMu8
hKQgil4uJbM5PaPuLY5or2LJ9MJNZbxdx7FIVNqro0Z1ekBe8/CYNfSmkYuIk2cs
ozZwMlgGlpDzhbZEuaLL6NfbZIFZ1t7/Fz2hqqRRVyBOlSyhXLNb6i0GnU61NxeD
JSm54TZaRThFfFrE5RxE8rn5HNdS/SD/THgJBfnhAoGATbPSylGR99Ybs7G+Rtop
9Y/fpYmKfo1iePe71qYa3jhIAAGu35kNuoMkOgvkJq8Y+Me9XwqRBvfdXMyv+z9W
fn87ifJX7jwOuRMXJqoeoY5+KgwxW/LPAesWrz2q3Lulxa01G66bz+SZ87x921X9
DG7mmUpCs672YylnyK2UiVg=
-----END PRIVATE KEY-----`.trim();

const serviceAccount = {
  "project_id": "sk-live-1f547",
  "client_email": "firebase-adminsdk-fbsvc@sk-live-1f547.iam.gserviceaccount.com"
};

async function getAccessToken() {
  // Clean the key strings to ensure no trailing data/whitespace
  const cleanKey = privateKeyPEM
    .replace(/-----BEGIN PRIVATE KEY-----/g, '')
    .replace(/-----END PRIVATE KEY-----/g, '')
    .replace(/\s/g, '');
  
  const formattedKey = `-----BEGIN PRIVATE KEY-----\n${cleanKey}\n-----END PRIVATE KEY-----`;
  
  const privateKey = await jose.importPKCS8(formattedKey, 'RS256');

  const jwt = await new jose.SignJWT({
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  })
    .setProtectedHeader({ alg: 'RS256' })
    .setIssuer(serviceAccount.client_email)
    .setAudience('https://oauth2.googleapis.com/token')
    .setExpirationTime('1h')
    .setIssuedAt()
    .sign(privateKey);

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });

  const data = await res.json();
  return data.access_token;
}

serve(async (req) => {
  try {
    const payload = await req.json();
    const { record } = payload;
    console.log("New notification record:", record);

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const accessToken = await getAccessToken();

    const { title, content, user_id, type, metadata } = record;

    // If it's a chat message, wait a bit to see if user reads it immediately
    if (type === 'chat' && metadata?.message_id) {
      console.log(`Checking read status for message ${metadata.message_id}...`);
      await new Promise(resolve => setTimeout(resolve, 2000));
      
      const { data: msg } = await supabaseClient
        .from('chat_messages')
        .select('is_read')
        .eq('id', metadata.message_id)
        .single();

      if (msg?.is_read) {
        console.log("Message already read, skipping notification.");
        return new Response("Message already read", { status: 200 });
      }
    }

    let target: { token?: string; topic?: string } = {};

    if (user_id) {
      const { data: user, error: userError } = await supabaseClient
        .from('users')
        .select('fcm_token')
        .eq('id', user_id)
        .single();

      if (userError || !user?.fcm_token) {
        return new Response("No token found", { status: 200 });
      }
      target.token = user.fcm_token;
    } else {
      target.topic = "all";
    }

    // FCM data payloads require every value to be a string.
    // Reserved keys (e.g. "from") must not appear in data or FCM returns 400.
    const RESERVED_DATA_KEYS = new Set([
      'from',
      'message_type',
      'notification',
      'message_id',
    ]);
    const dataPayload: Record<string, string> = {
      type: String(type || 'info'),
      id: String(record.id ?? ''),
    };
    const meta = record.metadata && typeof record.metadata === 'object'
      ? record.metadata as Record<string, unknown>
      : {};
    for (const [key, value] of Object.entries(meta)) {
      if (value === null || value === undefined) continue;
      if (RESERVED_DATA_KEYS.has(key) || key.startsWith('google.') || key.startsWith('gcm.')) {
        continue;
      }
      dataPayload[key] =
        typeof value === 'string' ? value : JSON.stringify(value);
    }

    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;
    
    const fcmResponse = await fetch(fcmUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${accessToken}`,
      },
      body: JSON.stringify({
        message: {
          ...target,
          notification: { title, body: content },
          data: dataPayload,
          android: {
            priority: "high",
            notification: {
              sound: "default",
              channel_id: "high_importance_channel"
            }
          }
        },
      }),
    });

    const result = await fcmResponse.json();
    console.log("FCM Response:", result);

    return new Response(JSON.stringify(result), { status: 200 });

  } catch (error) {
    console.error("Critical Error:", error.message);
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }
});
