import { spawn } from "node:child_process";
import fs from "node:fs";
import { createServer } from "node:net";
import path from "node:path";

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

async function expect(condition, message) {
  if (!condition) throw new Error(message);
}

const port = await getFreePort();
const dbPath = path.resolve("data", `smoke-${port}.sqlite`);
const baseUrl = `http://127.0.0.1:${port}`;

const server = spawn("node", ["dist/server.js"], {
  env: {
    ...process.env,
    PORT: String(port),
    NODE_ENV: "test",
    DATABASE_URL: dbPath,
    JWT_SECRET: "smoke-secret",
    ADMIN_EMAIL: "admin@autopilot.local",
    AUTOPILOT_ADMIN_PASSWORD: "autopilot",
  },
  stdio: ["ignore", "pipe", "pipe"],
});

let stderr = "";
server.stderr.on("data", (chunk) => {
  stderr += chunk.toString();
});

async function waitForServer() {
  const start = Date.now();
  while (Date.now() - start < 10000) {
    try {
      const response = await fetch(`${baseUrl}/api/health`);
      if (response.ok) return;
    } catch {
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
  }
  throw new Error(`Server did not start. ${stderr}`);
}

try {
  await waitForServer();

  const home = await fetch(baseUrl);
  await expect(home.ok && (await home.text()).includes("AutoPilot"), "Dashboard did not render.");

  const login = await fetch(`${baseUrl}/api/auth/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email: "admin@autopilot.local", password: "autopilot" }),
  });
  await expect(login.ok, "Login failed.");
  const { token } = await login.json();
  await expect(Boolean(token), "Login response missing token.");

  const create = await fetch(`${baseUrl}/api/tasks`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
    body: JSON.stringify({
      name: "Smoke task",
      description: "Local script action",
      trigger: { type: "time_once", run_at: new Date(Date.now() + 60_000).toISOString() },
      actions: [{ type: "run_script", config: { script: "return `hello ${task.name}`;" } }],
    }),
  });
  await expect(create.status === 201, "Task creation failed.");
  const { task } = await create.json();

  const run = await fetch(`${baseUrl}/api/tasks/${task.id}/run`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
  });
  await expect(run.ok, "Manual task run failed.");
  const runData = await run.json();
  await expect(runData.run.status === "success", "Task run did not succeed.");
  await expect(runData.run.output.includes("hello Smoke task"), "Task run output missing script result.");

  console.log("Smoke test passed.");
} finally {
  server.kill();
  if (fs.existsSync(dbPath)) fs.unlinkSync(dbPath);
}
