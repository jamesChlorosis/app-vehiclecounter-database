const crypto = require("crypto");
const fs = require("fs");
const os = require("os");
const path = require("path");
const { Readable } = require("stream");
const express = require("express");
const multer = require("multer");

const app = express();
const PORT = Number(process.env.PORT || 3000);
const ADMIN_KEY = process.env.ADMIN_KEY || (process.env.NODE_ENV === "production" ? "" : "SECRETKEY2077");
const ROOT = __dirname;
const PUBLIC_DIR = path.join(ROOT, "public");
const PRIVATE_DIR = path.join(ROOT, "private");
const UPLOADS_DIR =
  process.env.UPLOADS_DIR ||
  (process.env.VERCEL ? path.join(os.tmpdir(), "imagesafe-uploads") : path.join(ROOT, "uploads"));
const MAX_FILE_SIZE = 4 * 1024 * 1024;
const MAX_FILE_SIZE_LABEL = "4MB";
const BLOB_PREFIX = "uploads/";
const HAS_BLOB_STORAGE = Boolean(process.env.BLOB_READ_WRITE_TOKEN);

function ensureUploadsDir() {
  fs.mkdirSync(UPLOADS_DIR, { recursive: true });
}

ensureUploadsDir();

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_FILE_SIZE },
});

const allowedMime = new Set(["image/jpeg", "image/png", "image/webp", "image/gif"]);
const mimeToExt = {
  "image/jpeg": ".jpg",
  "image/png": ".png",
  "image/webp": ".webp",
  "image/gif": ".gif",
};

function wantsAdmin(req) {
  return Boolean(ADMIN_KEY) && req.query.key === ADMIN_KEY;
}

function sendNotFound(res) {
  res.status(404).type("html").send(`<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>404 Not Found</title>
  <style>
    body { margin: 0; min-height: 100vh; display: grid; place-items: center; background: #0c0f14; color: #c9d1d9; font: 14px/1.5 ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; }
    main { width: min(520px, calc(100vw - 32px)); border: 1px solid #252b36; padding: 28px; background: #111620; }
    h1 { margin: 0 0 10px; font-size: 18px; color: #f0f3f6; }
    p { margin: 0; color: #8b949e; }
  </style>
</head>
<body><main><h1>404 Not Found</h1><p>The requested resource could not be found on this server.</p></main></body>
</html>`);
}

function detectImage(buffer) {
  if (buffer.length >= 3 && buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) {
    return "image/jpeg";
  }
  if (
    buffer.length >= 8 &&
    buffer[0] === 0x89 &&
    buffer[1] === 0x50 &&
    buffer[2] === 0x4e &&
    buffer[3] === 0x47 &&
    buffer[4] === 0x0d &&
    buffer[5] === 0x0a &&
    buffer[6] === 0x1a &&
    buffer[7] === 0x0a
  ) {
    return "image/png";
  }
  if (
    buffer.length >= 12 &&
    buffer.toString("ascii", 0, 4) === "RIFF" &&
    buffer.toString("ascii", 8, 12) === "WEBP"
  ) {
    return "image/webp";
  }
  if (
    buffer.length >= 6 &&
    (buffer.toString("ascii", 0, 6) === "GIF87a" || buffer.toString("ascii", 0, 6) === "GIF89a")
  ) {
    return "image/gif";
  }
  return null;
}

function safeFilename(filename) {
  return /^[0-9]{8}T[0-9]{6}-[a-f0-9]{8}\.(jpg|png|webp|gif)$/.test(filename);
}

function formatTimestamp(date = new Date()) {
  return date.toISOString().replace(/[-:]/g, "").replace(/\.\d{3}Z$/, "");
}

async function getBlobStore() {
  return import("@vercel/blob");
}

function isBlobStorageEnabled() {
  return HAS_BLOB_STORAGE;
}

function storageUnavailableMessage() {
  return process.env.VERCEL
    ? "Upload storage is not configured. Add Vercel Blob to this project and redeploy."
    : "Upload storage is not configured.";
}

async function saveOriginal(filename, buffer, contentType) {
  if (isBlobStorageEnabled()) {
    const { put } = await getBlobStore();
    await put(`${BLOB_PREFIX}${filename}`, buffer, {
      access: "public",
      contentType,
      addRandomSuffix: false,
    });
    return;
  }

  if (process.env.VERCEL) {
    const error = new Error(storageUnavailableMessage());
    error.statusCode = 503;
    throw error;
  }

  ensureUploadsDir();
  await fs.promises.writeFile(path.join(UPLOADS_DIR, filename), buffer);
}

async function listOriginals(adminKey) {
  if (isBlobStorageEnabled()) {
    const { list } = await getBlobStore();
    const { blobs } = await list({ prefix: BLOB_PREFIX });
    return blobs
      .map((blob) => {
        const filename = path.basename(blob.pathname);
        if (!safeFilename(filename)) return null;
        return {
          filename,
          uploadedAt: blob.uploadedAt,
          size: blob.size,
          url: `/uploads/${encodeURIComponent(filename)}?key=${encodeURIComponent(adminKey)}`,
        };
      })
      .filter(Boolean);
  }

  if (process.env.VERCEL) {
    return [];
  }

  let entries = [];
  try {
    ensureUploadsDir();
    entries = await fs.promises.readdir(UPLOADS_DIR, { withFileTypes: true });
  } catch (error) {
    if (!error || error.code !== "ENOENT") {
      throw error;
    }
  }

  return Promise.all(
    entries
      .filter((entry) => entry.isFile() && safeFilename(entry.name))
      .map(async (entry) => {
        const stats = await fs.promises.stat(path.join(UPLOADS_DIR, entry.name));
        return {
          filename: entry.name,
          uploadedAt: stats.birthtime.toISOString(),
          size: stats.size,
          url: `/uploads/${encodeURIComponent(entry.name)}?key=${encodeURIComponent(adminKey)}`,
        };
      })
  );
}

async function deleteOriginal(filename) {
  if (isBlobStorageEnabled()) {
    const { del } = await getBlobStore();
    await del(`${BLOB_PREFIX}${filename}`);
    return true;
  }

  const target = path.join(UPLOADS_DIR, filename);
  try {
    await fs.promises.unlink(target);
    return true;
  } catch (error) {
    if (error && error.code === "ENOENT") {
      return false;
    }
    throw error;
  }
}

async function sendOriginal(req, res, filename) {
  if (isBlobStorageEnabled()) {
    const { list } = await getBlobStore();
    const { blobs } = await list({ prefix: `${BLOB_PREFIX}${filename}`, limit: 1 });
    const blob = blobs.find((item) => item.pathname === `${BLOB_PREFIX}${filename}`);
    if (!blob) return sendNotFound(res);

    const response = await fetch(blob.url);
    if (!response.ok || !response.body) return sendNotFound(res);

    res.status(response.status);
    res.type(response.headers.get("content-type") || "application/octet-stream");
    res.set("Cache-Control", "private, max-age=60");
    return Readable.fromWeb(response.body).pipe(res);
  }

  return res.sendFile(path.join(UPLOADS_DIR, filename));
}

app.disable("x-powered-by");

app.get("/admin", (req, res) => {
  if (!wantsAdmin(req)) {
    return sendNotFound(res);
  }
  res.sendFile(path.join(PRIVATE_DIR, "admin.html"));
});

app.post("/api/upload", upload.single("image"), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: "Please choose an image file to upload." });
    }

    const detectedMime = detectImage(req.file.buffer);
    if (!detectedMime || !allowedMime.has(detectedMime)) {
      return res.status(400).json({ error: "That file is not a supported image. Please use JPG, PNG, WEBP, or GIF." });
    }

    if (req.file.mimetype && req.file.mimetype !== detectedMime && allowedMime.has(req.file.mimetype)) {
      return res.status(400).json({ error: "The file type does not match its contents. Please try another image." });
    }

    const ext = mimeToExt[detectedMime];
    const filename = `${formatTimestamp()}-${crypto.randomBytes(4).toString("hex")}${ext}`;
    await saveOriginal(filename, req.file.buffer, detectedMime);

    res.status(201).json({ ok: true, filename });
  } catch (error) {
    if (error && error.code === "LIMIT_FILE_SIZE") {
      return res.status(413).json({ error: `That image is larger than ${MAX_FILE_SIZE_LABEL}. Please choose a smaller file.` });
    }
    res.status(error.statusCode || 500).json({ error: error.message || "The image could not be uploaded. Please try again." });
  }
});

app.get("/api/admin/images", async (req, res) => {
  if (!wantsAdmin(req)) {
    return sendNotFound(res);
  }

  const images = await listOriginals(req.query.key);

  images.sort((a, b) => new Date(b.uploadedAt) - new Date(a.uploadedAt));
  res.json({ images, storage: isBlobStorageEnabled() ? "blob" : "local" });
});

app.delete("/api/admin/images/:filename", async (req, res) => {
  if (!wantsAdmin(req)) {
    return sendNotFound(res);
  }
  if (!safeFilename(req.params.filename)) {
    return sendNotFound(res);
  }

  try {
    const deleted = await deleteOriginal(req.params.filename);
    if (!deleted) return sendNotFound(res);
    res.json({ ok: true });
  } catch (error) {
    res.status(500).json({ error: "Unable to delete that image." });
  }
});

app.get("/uploads/:filename", (req, res) => {
  if (!wantsAdmin(req) || !safeFilename(req.params.filename)) {
    return sendNotFound(res);
  }
  sendOriginal(req, res, req.params.filename).catch(() => {
    if (!res.headersSent) {
      res.status(500).json({ error: "Unable to load that image." });
    }
  });
});

app.use(express.static(PUBLIC_DIR));
app.use((req, res) => sendNotFound(res));

if (require.main === module) {
  app.listen(PORT, () => {
    if (process.env.NODE_ENV !== "production") {
      console.log(`ImageSafe Redactor is running at http://localhost:${PORT}`);
    }
  });
}

module.exports = app;
