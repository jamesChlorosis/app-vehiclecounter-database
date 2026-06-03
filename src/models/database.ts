import fs from "node:fs";
import path from "node:path";
import initSqlJs, { Database, SqlJsStatic } from "sql.js";
import { config } from "../config.js";
import { Task, TaskInput, TaskRun, TaskRunStatus, TaskStatus } from "./types.js";

type SqlValue = string | number | Uint8Array | null;

function nowIso() {
  return new Date().toISOString();
}

function json<T>(value: string): T {
  return JSON.parse(value) as T;
}

export class AppDatabase {
  private SQL!: SqlJsStatic;
  private db!: Database;
  private filePath: string;

  constructor(filePath = config.databaseUrl) {
    this.filePath = filePath.startsWith("file:") ? filePath.replace(/^file:/, "") : filePath;
  }

  async init() {
    fs.mkdirSync(path.dirname(this.filePath), { recursive: true });
    this.SQL = await initSqlJs({
      locateFile: (file) => path.join(config.root, "node_modules", "sql.js", "dist", file),
    });

    if (fs.existsSync(this.filePath)) {
      this.db = new this.SQL.Database(fs.readFileSync(this.filePath));
    } else {
      this.db = new this.SQL.Database();
    }

    this.migrate();
    this.persist();
  }

  close() {
    this.persist();
    this.db.close();
  }

  private persist() {
    fs.writeFileSync(this.filePath, Buffer.from(this.db.export()));
  }

  private migrate() {
    this.db.run(`
      PRAGMA foreign_keys = ON;

      CREATE TABLE IF NOT EXISTS tasks (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL,
        trigger_json TEXT NOT NULL,
        actions_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        last_run_at TEXT,
        next_run_at TEXT
      );

      CREATE TABLE IF NOT EXISTS task_runs (
        id TEXT PRIMARY KEY,
        task_id TEXT NOT NULL,
        started_at TEXT NOT NULL,
        completed_at TEXT,
        status TEXT NOT NULL,
        output TEXT,
        error TEXT,
        FOREIGN KEY(task_id) REFERENCES tasks(id) ON DELETE CASCADE
      );

      CREATE INDEX IF NOT EXISTS idx_task_runs_task_started
        ON task_runs(task_id, started_at DESC);

      CREATE TABLE IF NOT EXISTS condition_state (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS dead_letters (
        id TEXT PRIMARY KEY,
        task_id TEXT NOT NULL,
        run_id TEXT,
        reason TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL
      );
    `);
  }

  private query<T>(sql: string, params: SqlValue[] = []): T[] {
    const stmt = this.db.prepare(sql);
    try {
      stmt.bind(params);
      const rows: T[] = [];
      while (stmt.step()) {
        rows.push(stmt.getAsObject() as T);
      }
      return rows;
    } finally {
      stmt.free();
    }
  }

  private run(sql: string, params: SqlValue[] = []) {
    this.db.run(sql, params);
    this.persist();
  }

  private rowToTask(row: Record<string, unknown>): Task {
    return {
      id: String(row.id),
      name: String(row.name),
      description: String(row.description || ""),
      status: row.status as TaskStatus,
      trigger: json(String(row.trigger_json)),
      actions: json(String(row.actions_json)),
      created_at: String(row.created_at),
      updated_at: String(row.updated_at),
      last_run_at: row.last_run_at ? String(row.last_run_at) : null,
      next_run_at: row.next_run_at ? String(row.next_run_at) : null,
    };
  }

  createTask(input: TaskInput, nextRunAt: string | null) {
    const timestamp = nowIso();
    const task: Task = {
      id: crypto.randomUUID(),
      name: input.name,
      description: input.description || "",
      status: input.status || (input.trigger.type === "time_recurring" ? "recurring" : "pending"),
      trigger: input.trigger,
      actions: input.actions || [],
      created_at: timestamp,
      updated_at: timestamp,
      last_run_at: null,
      next_run_at: nextRunAt,
    };

    this.run(
      `INSERT INTO tasks
        (id, name, description, status, trigger_json, actions_json, created_at, updated_at, last_run_at, next_run_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        task.id,
        task.name,
        task.description,
        task.status,
        JSON.stringify(task.trigger),
        JSON.stringify(task.actions),
        task.created_at,
        task.updated_at,
        task.last_run_at,
        task.next_run_at,
      ],
    );
    return task;
  }

  listTasks(limit = 50, offset = 0) {
    return this.query<Record<string, unknown>>(
      "SELECT * FROM tasks ORDER BY created_at DESC LIMIT ? OFFSET ?",
      [limit, offset],
    ).map((row) => this.rowToTask(row));
  }

  getTask(id: string) {
    const [row] = this.query<Record<string, unknown>>("SELECT * FROM tasks WHERE id = ?", [id]);
    return row ? this.rowToTask(row) : null;
  }

  updateTask(id: string, patch: Partial<TaskInput> & { next_run_at?: string | null }) {
    const existing = this.getTask(id);
    if (!existing) return null;

    const task: Task = {
      ...existing,
      name: patch.name ?? existing.name,
      description: patch.description ?? existing.description,
      status: patch.status ?? existing.status,
      trigger: patch.trigger ?? existing.trigger,
      actions: patch.actions ?? existing.actions,
      updated_at: nowIso(),
      next_run_at: "next_run_at" in patch ? patch.next_run_at ?? null : existing.next_run_at,
    };

    this.run(
      `UPDATE tasks
       SET name = ?, description = ?, status = ?, trigger_json = ?, actions_json = ?, updated_at = ?, next_run_at = ?
       WHERE id = ?`,
      [
        task.name,
        task.description,
        task.status,
        JSON.stringify(task.trigger),
        JSON.stringify(task.actions),
        task.updated_at,
        task.next_run_at,
        id,
      ],
    );
    return task;
  }

  updateTaskRuntime(id: string, patch: Partial<Pick<Task, "status" | "last_run_at" | "next_run_at">>) {
    const existing = this.getTask(id);
    if (!existing) return null;
    const task = { ...existing, ...patch, updated_at: nowIso() };
    this.run(
      "UPDATE tasks SET status = ?, last_run_at = ?, next_run_at = ?, updated_at = ? WHERE id = ?",
      [task.status, task.last_run_at, task.next_run_at, task.updated_at, id],
    );
    return task;
  }

  deleteTask(id: string) {
    this.run("DELETE FROM tasks WHERE id = ?", [id]);
  }

  createRun(taskId: string) {
    const run: TaskRun = {
      id: crypto.randomUUID(),
      task_id: taskId,
      started_at: nowIso(),
      completed_at: null,
      status: "running",
      output: null,
      error: null,
    };
    this.run(
      "INSERT INTO task_runs (id, task_id, started_at, completed_at, status, output, error) VALUES (?, ?, ?, ?, ?, ?, ?)",
      [run.id, run.task_id, run.started_at, run.completed_at, run.status, run.output, run.error],
    );
    return run;
  }

  updateRun(id: string, patch: Partial<Pick<TaskRun, "completed_at" | "status" | "output" | "error">>) {
    const existing = this.getRun(id);
    if (!existing) return null;
    const run = { ...existing, ...patch };
    this.run("UPDATE task_runs SET completed_at = ?, status = ?, output = ?, error = ? WHERE id = ?", [
      run.completed_at,
      run.status,
      run.output,
      run.error,
      id,
    ]);
    return run;
  }

  listRunsForTask(taskId: string, limit = 50) {
    return this.query<TaskRun>(
      "SELECT * FROM task_runs WHERE task_id = ? ORDER BY started_at DESC LIMIT ?",
      [taskId, limit],
    );
  }

  getRun(id: string) {
    const [row] = this.query<TaskRun>("SELECT * FROM task_runs WHERE id = ?", [id]);
    return row || null;
  }

  getRunsSince(taskId: string, sinceIso: string) {
    return this.query<TaskRun>(
      "SELECT * FROM task_runs WHERE task_id = ? AND started_at >= ? ORDER BY started_at ASC",
      [taskId, sinceIso],
    );
  }

  setConditionState(key: string, value: string) {
    this.run(
      `INSERT INTO condition_state (key, value, updated_at)
       VALUES (?, ?, ?)
       ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at`,
      [key, value, nowIso()],
    );
  }

  getConditionState(key: string) {
    const [row] = this.query<{ value: string }>("SELECT value FROM condition_state WHERE key = ?", [key]);
    return row?.value ?? null;
  }

  createDeadLetter(taskId: string, runId: string | null, reason: string, payload: unknown) {
    this.run(
      "INSERT INTO dead_letters (id, task_id, run_id, reason, payload, created_at) VALUES (?, ?, ?, ?, ?, ?)",
      [crypto.randomUUID(), taskId, runId, reason, JSON.stringify(payload), nowIso()],
    );
  }
}
