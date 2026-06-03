import cron, { ScheduledTask } from "node-cron";
import { ConditionRegistry } from "../checkers/index.js";
import { ActionRegistry } from "../executors/index.js";
import { AppDatabase } from "../models/database.js";
import { ActionResult, Task, TaskRun } from "../models/types.js";
import { log } from "../utils/logger.js";
import { withRetry } from "../utils/retry.js";
import { computeNextRunAt } from "./time.js";
import { DeadLetterQueue } from "./deadLetterQueue.js";

const MAX_TIMEOUT_MS = 2_147_483_647;

export class SchedulerEngine {
  private cronJobs = new Map<string, ScheduledTask>();
  private timeouts = new Map<string, NodeJS.Timeout>();
  private pollers = new Map<string, NodeJS.Timeout>();
  private actions: ActionRegistry;
  private conditions: ConditionRegistry;
  private deadLetters: DeadLetterQueue;

  constructor(private db: AppDatabase) {
    this.actions = new ActionRegistry(db);
    this.conditions = new ConditionRegistry(db);
    this.deadLetters = new DeadLetterQueue(db);
  }

  async start() {
    log("AutoPilot scheduler starting.");
    this.reload();
  }

  reload() {
    this.stopAll();
    const tasks = this.db.listTasks(1000, 0);
    for (const task of tasks) {
      this.register(task);
    }
    log("Scheduler loaded active tasks.", { count: tasks.length });
  }

  register(task: Task) {
    this.unregister(task.id);
    if (task.status === "paused" || task.status === "completed") return;

    if (task.trigger.type === "time_recurring") {
      if (!cron.validate(task.trigger.cron_expression)) {
        log("Skipping invalid cron expression.", { taskId: task.id, cron: task.trigger.cron_expression });
        return;
      }
      const job = cron.schedule(task.trigger.cron_expression, () => void this.fire(task.id, "cron"));
      this.cronJobs.set(task.id, job);
      this.db.updateTaskRuntime(task.id, { status: "recurring", next_run_at: computeNextRunAt(task.trigger) });
      log("Registered recurring task.", { taskId: task.id, cron: task.trigger.cron_expression });
      return;
    }

    if (task.trigger.type === "time_once") {
      const runAt = new Date(task.trigger.run_at).getTime();
      if (Number.isNaN(runAt)) {
        log("Skipping invalid one-time run_at.", { taskId: task.id, runAt: task.trigger.run_at });
        return;
      }
      const delay = Math.max(0, runAt - Date.now());
      const timeout = setTimeout(() => void this.fire(task.id, "time_once"), Math.min(delay, MAX_TIMEOUT_MS));
      this.timeouts.set(task.id, timeout);
      this.db.updateTaskRuntime(task.id, { next_run_at: new Date(runAt).toISOString() });
      log("Registered one-time task.", { taskId: task.id, runAt: task.trigger.run_at });
      return;
    }

    const intervalMs = Math.max(5, task.trigger.poll_interval_seconds) * 1000;
    const poller = setInterval(() => void this.poll(task.id), intervalMs);
    this.pollers.set(task.id, poller);
    this.db.updateTaskRuntime(task.id, { status: "recurring", next_run_at: computeNextRunAt(task.trigger) });
    log("Registered polling task.", { taskId: task.id, intervalMs });
  }

  unregister(taskId: string) {
    this.cronJobs.get(taskId)?.stop();
    this.cronJobs.delete(taskId);

    const timeout = this.timeouts.get(taskId);
    if (timeout) clearTimeout(timeout);
    this.timeouts.delete(taskId);

    const poller = this.pollers.get(taskId);
    if (poller) clearInterval(poller);
    this.pollers.delete(taskId);
  }

  stopAll() {
    for (const taskId of [...this.cronJobs.keys(), ...this.timeouts.keys(), ...this.pollers.keys()]) {
      this.unregister(taskId);
    }
  }

  async poll(taskId: string) {
    const task = this.db.getTask(taskId);
    if (!task || task.status === "paused" || task.trigger.type !== "event_poll") return;
    const trigger = task.trigger;

    log("Checking event condition.", { taskId });
    try {
      const result = await withRetry(() => this.conditions.check(trigger.condition));
      this.db.updateTaskRuntime(task.id, { next_run_at: computeNextRunAt(trigger) });
      if (!result.passed) {
        log("Condition did not pass.", { taskId, data: result.data });
        return;
      }
      await this.fire(taskId, "event_poll", result.data);
    } catch (error) {
      log("Condition check failed.", { taskId, error: error instanceof Error ? error.message : String(error) });
      this.deadLetters.record(task, null, "Condition failed after retries.", {
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  async fire(taskId: string, source = "manual", triggerOutput?: string) {
    const task = this.db.getTask(taskId);
    if (!task || task.status === "paused") return null;

    log("Task fired.", { taskId, source });
    const run = this.db.createRun(taskId);

    try {
      const finalRun = await this.executeTask(task, run, triggerOutput);
      const nextRunAt = task.trigger.type === "time_recurring" || task.trigger.type === "event_poll" ? computeNextRunAt(task.trigger) : null;
      this.db.updateTaskRuntime(task.id, {
        status: task.trigger.type === "time_once" ? "completed" : "recurring",
        last_run_at: finalRun.completed_at || new Date().toISOString(),
        next_run_at: nextRunAt,
      });
      if (task.trigger.type === "time_once") this.unregister(task.id);
      return finalRun;
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      const completedAt = new Date().toISOString();
      const failedRun = this.db.updateRun(run.id, {
        status: "failed",
        completed_at: completedAt,
        error: message,
      });
      const nextRunAt = task.trigger.type === "time_recurring" || task.trigger.type === "event_poll" ? computeNextRunAt(task.trigger) : null;
      this.db.updateTaskRuntime(task.id, {
        status: task.trigger.type === "time_once" ? "failed" : "recurring",
        last_run_at: completedAt,
        next_run_at: nextRunAt,
      });
      this.deadLetters.record(task, run.id, "Task failed after retries.", { error: message });
      log("Task failed.", { taskId, runId: run.id, error: message });
      return failedRun;
    }
  }

  private async executeTask(task: Task, run: TaskRun, triggerOutput?: string) {
    const outputs: ActionResult[] = [];
    let lastOutput = triggerOutput || "";
    const variables: Record<string, unknown> = {
      task,
      run,
      result: lastOutput,
      triggerOutput: lastOutput,
      url: "",
    };

    for (const action of task.actions) {
      log("Executing action.", { taskId: task.id, runId: run.id, type: action.type });
      const result = await this.actions.execute(action, {
        task,
        run,
        triggerOutput,
        variables,
      });
      outputs.push(result);
      if (!result.success) throw new Error(result.error || `Action failed: ${action.type}`);
      lastOutput = result.output || "";
      variables.result = lastOutput;
      variables[`action_${outputs.length}`] = lastOutput;
    }

    const completedAt = new Date().toISOString();
    return this.db.updateRun(run.id, {
      status: "success",
      completed_at: completedAt,
      output: JSON.stringify(outputs, null, 2),
      error: null,
    })!;
  }
}
