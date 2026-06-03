import { Router } from "express";
import { AppDatabase } from "../models/database.js";
import { TaskInput, TriggerConfig } from "../models/types.js";
import { SchedulerEngine } from "../scheduler/engine.js";
import { computeNextRunAt } from "../scheduler/time.js";
import { login, requireAuth } from "./auth.js";

function validateTaskInput(body: Partial<TaskInput>): TaskInput {
  if (!body.name || typeof body.name !== "string") throw new Error("Task name is required.");
  if (!body.trigger || typeof body.trigger !== "object") throw new Error("Trigger is required.");
  if (!Array.isArray(body.actions)) throw new Error("Actions must be an array.");

  const trigger = body.trigger as TriggerConfig;
  if (trigger.type === "time_once" && !trigger.run_at) throw new Error("time_once requires run_at.");
  if (trigger.type === "time_recurring" && !trigger.cron_expression) {
    throw new Error("time_recurring requires cron_expression.");
  }
  if (trigger.type === "event_poll" && (!trigger.poll_interval_seconds || !trigger.condition)) {
    throw new Error("event_poll requires poll_interval_seconds and condition.");
  }

  return {
    name: body.name,
    description: body.description || "",
    status: body.status,
    trigger,
    actions: body.actions,
  };
}

export function createApiRouter(db: AppDatabase, scheduler: SchedulerEngine) {
  const router = Router();

  router.get("/health", (_req, res) => {
    res.json({ ok: true, service: "AutoPilot", time: new Date().toISOString() });
  });

  router.post("/auth/login", login);

  router.use(requireAuth);

  router.post("/tasks", (req, res) => {
    try {
      const input = validateTaskInput(req.body);
      const task = db.createTask(input, computeNextRunAt(input.trigger));
      scheduler.register(task);
      res.status(201).json({ task });
    } catch (error) {
      res.status(400).json({ error: error instanceof Error ? error.message : String(error) });
    }
  });

  router.get("/tasks", (req, res) => {
    const limit = Math.min(100, Number(req.query.limit || 50));
    const offset = Number(req.query.offset || 0);
    res.json({ tasks: db.listTasks(limit, offset), limit, offset });
  });

  router.get("/tasks/:id", (req, res) => {
    const task = db.getTask(req.params.id);
    if (!task) return res.status(404).json({ error: "Task not found." });
    return res.json({ task, runs: db.listRunsForTask(task.id, 10) });
  });

  router.patch("/tasks/:id", (req, res) => {
    try {
      const existing = db.getTask(req.params.id);
      if (!existing) return res.status(404).json({ error: "Task not found." });
      const nextTrigger = req.body.trigger || existing.trigger;
      const task = db.updateTask(req.params.id, {
        ...req.body,
        next_run_at: computeNextRunAt(nextTrigger),
      });
      if (task) scheduler.register(task);
      return res.json({ task });
    } catch (error) {
      return res.status(400).json({ error: error instanceof Error ? error.message : String(error) });
    }
  });

  router.delete("/tasks/:id", (req, res) => {
    scheduler.unregister(req.params.id);
    db.deleteTask(req.params.id);
    res.json({ ok: true });
  });

  router.post("/tasks/:id/run", async (req, res) => {
    const task = db.getTask(req.params.id);
    if (!task) return res.status(404).json({ error: "Task not found." });
    const run = await scheduler.fire(task.id, "manual");
    return res.json({ run });
  });

  router.post("/tasks/:id/pause", (req, res) => {
    const task = db.updateTask(req.params.id, { status: "paused" });
    if (!task) return res.status(404).json({ error: "Task not found." });
    scheduler.unregister(task.id);
    return res.json({ task });
  });

  router.post("/tasks/:id/resume", (req, res) => {
    const existing = db.getTask(req.params.id);
    if (!existing) return res.status(404).json({ error: "Task not found." });
    const task = db.updateTask(req.params.id, {
      status: existing.trigger.type === "time_recurring" || existing.trigger.type === "event_poll" ? "recurring" : "pending",
      next_run_at: computeNextRunAt(existing.trigger),
    });
    if (task) scheduler.register(task);
    return res.json({ task });
  });

  router.get("/tasks/:id/runs", (req, res) => {
    const task = db.getTask(req.params.id);
    if (!task) return res.status(404).json({ error: "Task not found." });
    return res.json({ runs: db.listRunsForTask(task.id, Math.min(100, Number(req.query.limit || 50))) });
  });

  router.get("/runs/:id", (req, res) => {
    const run = db.getRun(req.params.id);
    if (!run) return res.status(404).json({ error: "Run not found." });
    return res.json({ run });
  });

  return router;
}
