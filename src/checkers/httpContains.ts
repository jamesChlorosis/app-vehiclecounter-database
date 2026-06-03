import axios from "axios";
import { ConditionChecker } from "../models/types.js";

export class HttpContainsChecker implements ConditionChecker {
  async check(params: Record<string, unknown>) {
    const url = String(params.url || "");
    const keyword = String(params.keyword || "");
    if (!url || !keyword) return { passed: false, data: "Missing url or keyword." };

    const response = await axios.get(url, { timeout: Number(params.timeout_ms || 15000) });
    const body = typeof response.data === "string" ? response.data : JSON.stringify(response.data);
    const index = body.toLowerCase().indexOf(keyword.toLowerCase());
    if (index === -1) return { passed: false, data: `Keyword not found: ${keyword}` };

    return { passed: true, data: body.slice(Math.max(0, index - 240), index + keyword.length + 240) };
  }
}
