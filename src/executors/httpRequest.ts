import axios from "axios";
import { ActionConfig, ActionExecutor, RunContext } from "../models/types.js";
import { renderTemplate } from "../utils/template.js";

export class HttpRequestExecutor implements ActionExecutor {
  async execute(actionConfig: ActionConfig["config"], context: RunContext) {
    const rendered = renderTemplate(actionConfig, context.variables) as Record<string, unknown>;
    const response = await axios.request({
      method: String(rendered.method || "GET"),
      url: String(rendered.url),
      headers: rendered.headers as Record<string, string> | undefined,
      data: rendered.body,
      timeout: Number(rendered.timeout_ms || 15000),
    });
    return {
      success: true,
      output: typeof response.data === "string" ? response.data : JSON.stringify(response.data, null, 2),
    };
  }
}
