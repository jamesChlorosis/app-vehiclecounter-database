import axios from "axios";
import Anthropic from "@anthropic-ai/sdk";
import { config } from "../config.js";
import { ActionConfig, ActionExecutor, RunContext } from "../models/types.js";
import { renderTemplate } from "../utils/template.js";

export class AiSummarizeExecutor implements ActionExecutor {
  async execute(actionConfig: ActionConfig["config"], context: RunContext) {
    if (!config.anthropicApiKey) return { success: false, error: "ANTHROPIC_API_KEY is not configured." };

    const client = new Anthropic({ apiKey: config.anthropicApiKey });
    const prompt = String(renderTemplate(actionConfig.prompt || "Summarize this content.", context.variables));
    let sourceText = String(renderTemplate(actionConfig.text || context.triggerOutput || "", context.variables));

    if (actionConfig.source_url) {
      const url = String(renderTemplate(actionConfig.source_url, context.variables));
      const response = await axios.get(url, { timeout: 15000 });
      sourceText = typeof response.data === "string" ? response.data : JSON.stringify(response.data);
    }

    const message = await client.messages.create({
      model: "claude-sonnet-4-20250514",
      max_tokens: Number(actionConfig.max_tokens || 1200),
      messages: [{ role: "user", content: `${prompt}\n\n${sourceText.slice(0, 50000)}` }],
    });

    const output = message.content
      .map((block) => ("text" in block ? block.text : ""))
      .filter(Boolean)
      .join("\n");

    return { success: true, output };
  }
}
