import nodemailer from "nodemailer";
import { config } from "../config.js";
import { ActionConfig, ActionExecutor, RunContext } from "../models/types.js";
import { renderTemplate } from "../utils/template.js";

export class EmailExecutor implements ActionExecutor {
  async execute(actionConfig: ActionConfig["config"], context: RunContext) {
    if (!config.smtp.host || !config.smtp.user || !config.smtp.pass) {
      return { success: false, error: "SMTP_HOST, SMTP_USER, and SMTP_PASS are required for email actions." };
    }

    const transporter = nodemailer.createTransport({
      host: config.smtp.host,
      port: config.smtp.port,
      secure: config.smtp.port === 465,
      auth: { user: config.smtp.user, pass: config.smtp.pass },
    });

    await transporter.sendMail({
      from: String(actionConfig.from || config.smtp.user),
      to: String(renderTemplate(actionConfig.to, context.variables)),
      subject: String(renderTemplate(actionConfig.subject || `AutoPilot: ${context.task.name}`, context.variables)),
      text: actionConfig.html ? undefined : String(renderTemplate(actionConfig.body || "", context.variables)),
      html: actionConfig.html ? String(renderTemplate(actionConfig.html, context.variables)) : undefined,
    });

    return { success: true, output: "Email sent." };
  }
}
