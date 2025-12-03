// Funzione Edge Supabase: send-push-notification
// Invia notifiche push FCM a tutti gli utenti usando API HTTP v1

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import {
  createRemoteJWKSet,
  jwtVerify,
} from "https://deno.land/x/jose@v4.9.0/index.ts";
import { SignJWT, importPKCS8 } from "https://deno.land/x/jose@v4.9.0/index.ts";

// Genera access token OAuth2 da service account JSON
async function getAccessToken(serviceAccountJson: any): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  
  // Importa la chiave privata usando jose
  const privateKey = await importPKCS8(serviceAccountJson.private_key, "RS256");
  
  // Crea e firma JWT
  const jwt = await new SignJWT({
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(serviceAccountJson.client_email)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(privateKey);

  // Scambia JWT per access token
  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  const tokenData = await tokenResponse.json();
  
  if (!tokenData.access_token) {
    throw new Error(`OAuth2 failed: ${JSON.stringify(tokenData)}`);
  }
  
  return tokenData.access_token;
}

serve(async (req) => {
  const { title, body, data, target_user_id } = await req.json();
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  const projectId = Deno.env.get("FIREBASE_PROJECT_ID");

  if (!supabaseUrl || !supabaseKey || !serviceAccountJson || !projectId) {
    return new Response("Missing environment variables", { status: 500 });
  }

  let serviceAccount;
  try {
    serviceAccount = JSON.parse(serviceAccountJson);
  } catch (e) {
    return new Response("Invalid service account JSON", { status: 500 });
  }

  // Se target_user_id è specificato, invia solo a quell'utente, altrimenti a tutti
  const tokenQuery = target_user_id 
    ? `${supabaseUrl}/rest/v1/user_tokens?select=fcm_token&user_id=eq.${target_user_id}`
    : `${supabaseUrl}/rest/v1/user_tokens?select=fcm_token`;
  
  const { tokens, error } = await fetch(tokenQuery, {
    headers: {
      "apikey": supabaseKey,
      "Authorization": `Bearer ${supabaseKey}`,
    },
  })
    .then((res) => res.json())
    .then((data) => {
      if (Array.isArray(data)) {
        return { tokens: data.map((row: any) => row.fcm_token), error: null };
      } else {
        return { tokens: [], error: "Risposta non valida dalla tabella user_tokens" };
      }
    })
    .catch((err) => ({ tokens: [], error: err }));

  if (error) {
    return new Response(`Errore nel recupero token: ${error}`, { status: 500 });
  }

  // Filtra solo i token validi (non nulli e non vuoti)
  const validTokens = tokens.filter((t: string) => t && t.length > 0);
  console.log('TOKENS validi:', validTokens.length);
  
  if (validTokens.length === 0) {
    return new Response('Nessun token valido trovato', { status: 400 });
  }

  // Ottieni access token OAuth2
  let accessToken;
  try {
    accessToken = await getAccessToken(serviceAccount);
  } catch (e) {
    console.error('Errore generazione access token:', e);
    return new Response(`Errore OAuth2: ${e}`, { status: 500 });
  }

  // Invia notifica a tutti i token usando API HTTP v1
  const results = [];
  for (const token of validTokens) {
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
    const message = {
      message: {
        token: token,
        notification: {
          title: title,
          body: body,
        },
        data: data || {},
        android: {
          priority: "high",
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      },
    };

    try {
      const fcmRes = await fetch(fcmUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${accessToken}`,
        },
        body: JSON.stringify(message),
      });

      const fcmData = await fcmRes.json();
      
      if (fcmRes.ok) {
        results.push({ token: token.substring(0, 20) + "...", success: true });
      } else {
        console.error('Errore FCM per token:', token.substring(0, 20), fcmData);
        results.push({ token: token.substring(0, 20) + "...", success: false, error: fcmData });
      }
    } catch (e) {
      console.error('Errore invio a token:', token.substring(0, 20), e);
      results.push({ token: token.substring(0, 20) + "...", success: false, error: String(e) });
    }
  }

  const successCount = results.filter(r => r.success).length;
  console.log(`Notifiche inviate: ${successCount}/${validTokens.length}`);

  return new Response(
    JSON.stringify({ 
      success: true, 
      sent: successCount, 
      total: validTokens.length,
      results: results 
    }), 
    { 
      status: 200,
      headers: { "Content-Type": "application/json" }
    }
  );
});
