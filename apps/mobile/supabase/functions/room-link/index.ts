import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function safeRoomId(raw: string): string {
  return raw.replace(/[^a-zA-Z0-9-]/g, "");
}

function buildHtml(roomId: string): string {
  const safeId = safeRoomId(roomId);
  if (!safeId) {
    return `<!DOCTYPE html><html><body style="font-family:sans-serif;text-align:center;padding:40px"><h1>SK LIVE</h1><p>Invalid room link.</p></body></html>`;
  }

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Open SK LIVE Room</title>
  <style>
    body { font-family: system-ui, sans-serif; text-align: center; padding: 48px 24px; background: #1a0a2e; color: #fff; margin: 0; }
    a.btn { display: inline-block; margin-top: 24px; padding: 14px 28px; background: #ffeb3b; color: #111; border-radius: 28px; text-decoration: none; font-weight: 700; }
    p.hint { color: #ffffff99; font-size: 14px; margin-top: 16px; }
  </style>
</head>
<body>
  <h1>SK LIVE</h1>
  <p id="msg">Opening your room…</p>
  <a id="open" class="btn" href="#">Open in App</a>
  <p class="hint">If nothing happens, tap the button above.</p>
  <script>
    (function () {
      var roomId = "${safeId}";
      var appUrl = "sklive://room/" + roomId;
      var androidIntent = "intent://room/" + roomId + "#Intent;scheme=sklive;package=com.sklive.app;end";
      function tryOpen() {
        var ua = navigator.userAgent || "";
        if (/android/i.test(ua)) {
          window.location.href = androidIntent;
          setTimeout(function () { window.location.href = appUrl; }, 400);
        } else { window.location.href = appUrl; }
      }
      document.getElementById("open").href = appUrl;
      document.getElementById("open").onclick = function (e) { e.preventDefault(); tryOpen(); };
      tryOpen();
    })();
  </script>
</body>
</html>`;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const url = new URL(req.url);
  const roomId = url.searchParams.get("id") ?? url.searchParams.get("roomId") ?? "";

  return new Response(buildHtml(roomId), {
    headers: {
      ...corsHeaders,
      "Content-Type": "text/html; charset=utf-8",
    },
  });
});
