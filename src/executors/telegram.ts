import axios from "axios";
import { config } from "../config.js";
import { ActionConfig, ActionExecutor, RunContext } from "../models/types.js";
import { renderTemplate } from "../utils/template.js";

export class TelegramExecutor implements ActionExecutor {
  async execute(actionConfig: ActionConfig["config"], context: RunContext) {
    const token = String(actionConfig.bot_token || config.telegramBotToken);
    if (!token) return { success: false, error: "TELEGRAM_BOT_TOKEN is not configured." };

    const chatId = renderTemplate(actionConfig.chat_id, context.variables);
    const text = renderTemplate(actionConfig.message_template || actionConfig.message, context.variables);
    await axios.post(`https://api.telegram.org/bot${token}/sendMessage`, {
      chat_id: chatId,
      text,
      parse_mode: actionConfig.parse_mode || undefined,
    });
    return { success: true, output: "Telegram message sent." };
  }
}
