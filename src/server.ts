import express from "express";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { config } from "./config.js";
import { createApiRouter } from "./api/routes.js";
import { AppDatabase } from "./models/database.js";
import { SchedulerEngine } from "./scheduler/engine.js";
import { log } from "./utils/logger.js";

export async function createServer() {
  const db = new AppDatabase();
  await db.init();
  const scheduler = new SchedulerEngine(db);
  await scheduler.start();

  const app = express();
  app.disable("x-powered-by");
  app.use(express.json({ limit: "1mb" }));
  app.use("/api", createApiRouter(db, scheduler));
  app.use(express.static(path.join(config.root, "public")));
  app.get("*", (_req, res) => res.sendFile(path.join(config.root, "public", "index.html")));

  return { app, db, scheduler };
}

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  const { app } = await createServer();
  app.listen(config.port, () => log(`AutoPilot is running at http://localhost:${config.port}`));
}
