import crypto from "node:crypto";
import axios from "axios";
import { AppDatabase } from "../models/database.js";
import { ConditionChecker } from "../models/types.js";

export class PageChangedChecker implements ConditionChecker {
  constructor(private db: AppDatabase) {}

  async check(params: Record<string, unknown>) {
    const url = String(params.url || "");
    if (!url) return { passed: false, data: "Missing url." };

    const response = await axios.get(url, { timeout: Number(params.timeout_ms || 15000) });
    const body = typeof response.data === "string" ? response.data : JSON.stringify(response.data);
    const hash = crypto.createHash("sha256").update(body).digest("hex");
    const key = `page_changed:${url}`;
    const previous = this.db.getConditionState(key);
    this.db.setConditionState(key, hash);

    if (!previous) return { passed: false, data: "Baseline stored. No previous content to compare." };
    return {
      passed: previous !== hash,
      data: previous !== hash ? `Page changed at ${url}. New hash: ${hash}` : `No change for ${url}.`,
    };
  }
}
