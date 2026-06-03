import vm from "node:vm";
import { ActionConfig, ActionExecutor, RunContext } from "../models/types.js";

export class RunScriptExecutor implements ActionExecutor {
  async execute(actionConfig: ActionConfig["config"], context: RunContext) {
    const script = String(actionConfig.script || "");
    if (!script.trim()) return { success: false, error: "No script provided." };

    const sandbox = {
      variables: context.variables,
      task: context.task,
      result: context.triggerOutput,
      fetch,
      console: {
        log: (...values: unknown[]) => values.map(String).join(" "),
      },
    };
    const wrapped = `(async () => { ${script} })()`;
    const output = await vm.runInNewContext(wrapped, sandbox, {
      timeout: Number(actionConfig.timeout_ms || 5000),
    });

    return { success: true, output: typeof output === "string" ? output : JSON.stringify(output) };
  }
}
