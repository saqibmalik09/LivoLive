const multer = require("multer");
const { uploadPublicBucketToR2 } = require("./r2");

const ALLOWED_BUCKETS = new Set([
  "profiles",
  "chat_assets",
  "posts_assets",
  "family-logos",
  "room_backgrounds",
  "support_attachments",
  "app_assets",
  "cp_nest_assets",
  "game-icons",
]);

const BLOCKED_BUCKETS = new Set(["real_name_kyc"]);

const MAX_BYTES = 25 * 1024 * 1024;

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_BYTES, files: 1 },
});

function safeObjectPath(raw, userId) {
  let path = String(raw || "")
    .replace(/\\/g, "/")
    .replace(/^\/+/, "")
    .replace(/\.\./g, "");
  if (!path) {
    path = `${userId}/${Date.now()}`;
  }
  if (!path.includes("/")) {
    path = `${userId}/${path}`;
  }
  return path.slice(0, 500);
}

function mount(app, { verifyToken }) {
  app.post("/v1/media/upload", (req, res) => {
    upload.single("file")(req, res, async (err) => {
      if (err) {
        const msg =
          err.code === "LIMIT_FILE_SIZE"
            ? `File too large (max ${MAX_BYTES} bytes)`
            : err.message || "Upload parse failed";
        return res.status(400).json({ ok: false, error: msg });
      }
      try {
        const auth = String(req.headers.authorization || "").replace(
          /^Bearer\s+/i,
          "",
        );
        const payload = await verifyToken(auth);
        const userId = payload?.sub ? String(payload.sub) : "";
        if (!userId || userId.startsWith("anon:")) {
          return res.status(401).json({ ok: false, error: "unauthorized" });
        }

        const bucket = String(req.body?.bucket || "").trim();
        if (!bucket) {
          return res.status(400).json({ ok: false, error: "bucket required" });
        }
        if (BLOCKED_BUCKETS.has(bucket) || bucket === "real_name_kyc") {
          return res.status(403).json({
            ok: false,
            error: "private bucket not allowed on public CDN",
          });
        }
        if (!ALLOWED_BUCKETS.has(bucket)) {
          return res.status(400).json({
            ok: false,
            error: `bucket not allowed: ${bucket}`,
          });
        }

        const file = req.file;
        if (!file || !file.buffer || file.buffer.length === 0) {
          return res.status(400).json({ ok: false, error: "file required" });
        }

        const objectPath = safeObjectPath(req.body?.path, userId);
        const contentType =
          String(req.body?.contentType || file.mimetype || "").trim() ||
          "application/octet-stream";

        const { publicUrl, key } = await uploadPublicBucketToR2({
          bucket,
          objectPath,
          body: file.buffer,
          contentType,
        });

        return res.json({
          ok: true,
          url: publicUrl,
          key,
          bucket,
          path: objectPath,
        });
      } catch (e) {
        console.error("[media/upload]", e.message || e);
        return res.status(500).json({
          ok: false,
          error: e.message || "upload failed",
        });
      }
    });
  });
}

module.exports = { mount, ALLOWED_BUCKETS };
