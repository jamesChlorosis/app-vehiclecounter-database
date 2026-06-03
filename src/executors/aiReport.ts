import fs from "node:fs";
import path from "node:path";
import Anthropic from "@anthropic-ai/sdk";
import { config } from "../config.js";
import { AppDatabase } from "../models/database.js";
import { ActionConfig, ActionExecutor, RunContext } from "../models/types.js";
import { renderTemplate } from "../utils/template.js";

export class AiReportExecutor implements ActionExecutor {
  constructor(private db: AppDatabase) {}

  async execute(actionConfig: ActionConfig["config"], context: RunContext) {
    if (!config.anthropicApiKey) return { success: false, error: "ANTHROPIC_API_KEY is not configured." };

    const windowHours = Number(actionConfig.window_hours || 24);
    const since = new Date(Date.now() - windowHours * 60 * 60 * 1000).toISOString();
    const taskId = String(actionConfig.task_id || context.task.id);
    const runs = this.db.getRunsSince(taskId, since);

    const prompt = String(
      renderTemplate(
        actionConfig.prompt ||
          "Generate a concise markdown report from these AutoPilot task run outputs. Include failures and useful links.",
        context.variables,
      ),
    );

    const client = new Anthropic({ apiKey: config.anthropicApiKey });
    const message = await client.messages.create({
      model: "claude-sonnet-4-20250514",
      max_tokens: Number(actionConfig.max_tokens || 2000),
      messages: [{ role: "user", content: `${prompt}\n\n${JSON.stringify(runs, null, 2).slice(0, 60000)}` }],
    });

    const report = message.content
      .map((block) => ("text" in block ? block.text : ""))
      .filter(Boolean)
      .join("\n");

    fs.mkdirSync(config.reportsDir, { recursive: true });
    const filename = String(actionConfig.filename || `report-${context.task.id}-${Date.now()}.md`);
    const fullPath = path.join(config.reportsDir, path.basename(filename));
    fs.writeFileSync(fullPath, report, "utf8");
    return { success: true, output: `Report saved to ${fullPath}\n\n${report}` };
  }
}
