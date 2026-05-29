import { spawn } from "node:child_process";
import { createServer } from "node:net";

async function getFreePort() {
  return new Promise((resolve, reject) => {
    const server = createServer();
    server.once("error", reject);
    server.listen(0, "127.0.0.1", () => {
      const address = server.address();
      server.close(() => resolve(address.port));
    });
  });
}

const port = await getFreePort();
const baseUrl = `http://127.0.0.1:${port}`;
const pngBytes = Buffer.from(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/l7xO6QAAAABJRU5ErkJggg==",
  "base64"
);

const server = spawn("node", ["server.js"], {
  env: { ...process.env, PORT: String(port), NODE_ENV: "test" },
  stdio: ["ignore", "pipe", "pipe"],
});

let stderr = "";
server.stderr.on("data", (chunk) => {
  stderr += chunk.toString();
});

async function waitForServer() {
  const start = Date.now();
  while (Date.now() - start < 5000) {
    try {
      const response = await fetch(baseUrl);
      if (response.ok) return;
    } catch {
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
  }
  throw new Error(`Server did not start. ${stderr}`);
}

async function expect(condition, message) {
  if (!condition) throw new Error(message);
}

async function uploadValidImage() {
  const form = new FormData();
  form.append("image", new Blob([pngBytes], { type: "image/png" }), "smoke.png");
  return fetch(`${baseUrl}/api/upload`, { method: "POST", body: form });
}

async function uploadInvalidFile() {
  const form = new FormData();
  form.append("image", new Blob(["not an image"], { type: "text/plain" }), "notes.txt");
  return fetch(`${baseUrl}/api/upload`, { method: "POST", body: form });
}

try {
  await waitForServer();

  const home = await fetch(baseUrl);
  await expect(home.ok && (await home.text()).includes("ImageSafe Redactor"), "Home page did not render.");

  const blockedAdmin = await fetch(`${baseUrl}/admin`);
  await expect(blockedAdmin.status === 404, "Admin route without key should return 404.");

  const invalid = await uploadInvalidFile();
  await expect(invalid.status === 400, "Invalid upload should return 400.");

  const upload = await uploadValidImage();
  await expect(upload.status === 201, "Valid upload should return 201.");
  const uploadData = await upload.json();
  await expect(Boolean(uploadData.filename), "Upload response missing filename.");

  const list = await fetch(`${baseUrl}/api/admin/images?key=SECRETKEY2077`);
  await expect(list.ok, "Admin image list failed.");
  const listData = await list.json();
  const saved = listData.images.find((image) => image.filename === uploadData.filename);
  await expect(Boolean(saved), "Saved image not present in admin list.");

  const blockedImage = await fetch(`${baseUrl}/uploads/${encodeURIComponent(uploadData.filename)}`);
  await expect(blockedImage.status === 404, "Image file without key should return 404.");

  const image = await fetch(`${baseUrl}${saved.url}`);
  await expect(image.ok && image.headers.get("content-type")?.startsWith("image/"), "Keyed image file did not load.");

  const remove = await fetch(
    `${baseUrl}/api/admin/images/${encodeURIComponent(uploadData.filename)}?key=SECRETKEY2077`,
    { method: "DELETE" }
  );
  await expect(remove.ok, "Delete image failed.");

  console.log("Smoke test passed.");
} finally {
  server.kill();
}
