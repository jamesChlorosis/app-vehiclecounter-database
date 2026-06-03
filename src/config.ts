import "dotenv/config";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

export const config = {
  root,
  port: Number(process.env.PORT || 3000),
  databaseUrl: process.env.DATABASE_URL || path.join(root, "data", "autopilot.sqlite"),
  redisUrl: process.env.REDIS_URL || "",
  telegramBotToken: process.env.TELEGRAM_BOT_TOKEN || "",
  smtp: {
    host: process.env.SMTP_HOST || "",
    port: Number(process.env.SMTP_PORT || 587),
    user: process.env.SMTP_USER || "",
    pass: process.env.SMTP_PASS || "",
  },
  discordWebhookUrl: process.env.DISCORD_WEBHOOK_URL || "",
  anthropicApiKey: process.env.ANTHROPIC_API_KEY || "",
  jwtSecret: process.env.JWT_SECRET || "dev-autopilot-secret-change-me",
  adminEmail: process.env.ADMIN_EMAIL || "admin@autopilot.local",
  adminPassword: process.env.AUTOPILOT_ADMIN_PASSWORD || "autopilot",
  reportsDir: process.env.REPORTS_DIR || path.join(root, "reports"),
};
