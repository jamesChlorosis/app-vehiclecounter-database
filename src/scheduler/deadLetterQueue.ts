import { AppDatabase } from "../models/database.js";
import { Task } from "../models/types.js";

export class DeadLetterQueue {
  constructor(private db: AppDatabase) {}

  record(task: Task, runId: string | null, reason: string, payload: unknown) {
    this.db.createDeadLetter(task.id, runId, reason, payload);
  }
}
