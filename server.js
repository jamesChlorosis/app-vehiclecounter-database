const crypto = require("crypto");
const fs = require("fs");
const path = require("path");
const express = require("express");
const multer = require("multer");

const app = express();
const PORT = Number(process.env.PORT || 3000);
const ADMIN_KEY = process.env.ADMIN_KEY || "SECRETKEY2077";
const ROOT = __dirname;
const PUBLIC_DIR = path.join(ROOT, "public");
const PRIVATE_DIR = path.join(ROOT, "private");
const UPLOADS_DIR = path.join(ROOT, "uploads");
const MAX_FILE_SIZE = 10 * 1024 * 1024;

const uploadsDir = '/tmp/uploads';
fs.mkdirSync(uploadsDir, { recursive: true });

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
  return req.query.key === ADMIN_KEY;
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
    const outputPath = path.join(UPLOADS_DIR, filename);
    await fs.promises.writeFile(outputPath, req.file.buffer);

    res.status(201).json({ ok: true, filename });
  } catch (error) {
    if (error && error.code === "LIMIT_FILE_SIZE") {
      return res.status(413).json({ error: "That image is larger than 10MB. Please choose a smaller file." });
    }
    res.status(500).json({ error: "The image could not be uploaded. Please try again." });
  }
});

app.get("/api/admin/images", async (req, res) => {
  if (!wantsAdmin(req)) {
    return sendNotFound(res);
  }

  const entries = await fs.promises.readdir(UPLOADS_DIR, { withFileTypes: true });
  const images = await Promise.all(
    entries
      .filter((entry) => entry.isFile() && safeFilename(entry.name))
      .map(async (entry) => {
        const stats = await fs.promises.stat(path.join(UPLOADS_DIR, entry.name));
        return {
          filename: entry.name,
          uploadedAt: stats.birthtime.toISOString(),
          size: stats.size,
          url: `/uploads/${encodeURIComponent(entry.name)}?key=${encodeURIComponent(req.query.key)}`,
        };
      })
  );

  images.sort((a, b) => new Date(b.uploadedAt) - new Date(a.uploadedAt));
  res.json({ images });
});

app.delete("/api/admin/images/:filename", async (req, res) => {
  if (!wantsAdmin(req)) {
    return sendNotFound(res);
  }
  if (!safeFilename(req.params.filename)) {
    return sendNotFound(res);
  }

  const target = path.join(UPLOADS_DIR, req.params.filename);
  try {
    await fs.promises.unlink(target);
    res.json({ ok: true });
  } catch (error) {
    if (error && error.code === "ENOENT") {
      return sendNotFound(res);
    }
    res.status(500).json({ error: "Unable to delete that image." });
  }
});

app.get("/uploads/:filename", (req, res) => {
  if (!wantsAdmin(req) || !safeFilename(req.params.filename)) {
    return sendNotFound(res);
  }
  res.sendFile(path.join(UPLOADS_DIR, req.params.filename));
});

app.use(express.static(PUBLIC_DIR));
app.use((req, res) => sendNotFound(res));

app.listen(PORT, () => {
  if (process.env.NODE_ENV !== "production") {
    console.log(`ImageSafe Redactor is running at http://localhost:${PORT}`);
  }
});
