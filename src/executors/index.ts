import { AppDatabase } from "../models/database.js";
import { ActionConfig, ActionExecutor } from "../models/types.js";
import { withRetry } from "../utils/retry.js";
import { AiReportExecutor } from "./aiReport.js";
import { AiSummarizeExecutor } from "./aiSummarize.js";
import { DiscordExecutor } from "./discord.js";
import { EmailExecutor } from "./email.js";
import { FileExecutor } from "./file.js";
import { HttpRequestExecutor } from "./httpRequest.js";
import { RunScriptExecutor } from "./runScript.js";
import { TelegramExecutor } from "./telegram.js";
import { WebScrapeExecutor } from "./webScrape.js";

export class ActionRegistry {
  private executors = new Map<string, ActionExecutor>();

  constructor(db: AppDatabase) {
    this.executors.set("send_telegram", new TelegramExecutor());
    this.executors.set("send_email", new EmailExecutor());
    this.executors.set("send_discord", new DiscordExecutor());
    this.executors.set("http_request", new HttpRequestExecutor());
    this.executors.set("web_scrape", new WebScrapeExecutor());
    this.executors.set("ai_summarize", new AiSummarizeExecutor());
    this.executors.set("ai_report", new AiReportExecutor(db));
    this.executors.set("create_file", new FileExecutor());
    this.executors.set("run_script", new RunScriptExecutor());
  }

  get(action: ActionConfig) {
    const executor = this.executors.get(action.type);
    if (!executor) throw new Error(`Unsupported action type: ${action.type}`);
    return executor;
  }

  async execute(action: ActionConfig, contextParameters: Parameters<ActionExecutor["execute"]>[1]) {
    const executor = this.get(action);
    return withRetry(() => executor.execute(action.config, contextParameters));
  }
}
