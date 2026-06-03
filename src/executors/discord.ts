import axios from "axios";
import { config } from "../config.js";
import { ActionConfig, ActionExecutor, RunContext } from "../models/types.js";
import { renderTemplate } from "../utils/template.js";

export class DiscordExecutor implements ActionExecutor {
  async execute(actionConfig: ActionConfig["config"], context: RunContext) {
    const webhookUrl = String(actionConfig.webhook_url || config.discordWebhookUrl);
    if (!webhookUrl) return { success: false, error: "DISCORD_WEBHOOK_URL is not configured." };

    const content = renderTemplate(actionConfig.message_template || actionConfig.content, context.variables);
    await axios.post(webhookUrl, { content });
    return { success: true, output: "Discord webhook posted." };
  }
}
