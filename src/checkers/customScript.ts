import vm from "node:vm";
import { ConditionChecker } from "../models/types.js";

export class CustomScriptChecker implements ConditionChecker {
  async check(params: Record<string, unknown>) {
    const script = String(params.script || "");
    if (!script.trim()) return { passed: false, data: "No script provided." };

    const output = await vm.runInNewContext(
      `(async () => {
        const params = input;
        ${script}
      })()`,
      { input: params, fetch },
      { timeout: Number(params.timeout_ms || 5000) },
    );

    if (typeof output === "boolean") return { passed: output, data: String(output) };
    if (output && typeof output === "object" && "passed" in output) {
      return {
        passed: Boolean((output as Record<string, unknown>).passed),
        data: String((output as Record<string, unknown>).data || JSON.stringify(output)),
      };
    }
    return { passed: Boolean(output), data: typeof output === "string" ? output : JSON.stringify(output) };
  }
}
