import axios from "axios";
import { ActionConfig, ActionExecutor, RunContext } from "../models/types.js";
import { renderTemplate } from "../utils/template.js";

export class WebScrapeExecutor implements ActionExecutor {
  async execute(actionConfig: ActionConfig["config"], context: RunContext) {
    const url = String(renderTemplate(actionConfig.url, context.variables));
    const selector = actionConfig.selector ? String(actionConfig.selector) : "";

    try {
      const { chromium } = await import("playwright");
      const browser = await chromium.launch({ headless: true });
      try {
        const page = await browser.newPage();
        await page.goto(url, { waitUntil: "networkidle", timeout: Number(actionConfig.timeout_ms || 30000) });
        const output = selector
          ? await page.locator(selector).evaluateAll((nodes) => nodes.map((node) => node.textContent?.trim()).filter(Boolean))
          : await page.locator("body").innerText();
        return { success: true, output: JSON.stringify(output, null, 2) };
      } finally {
        await browser.close();
      }
    } catch (error) {
      const response = await axios.get(url, { timeout: Number(actionConfig.timeout_ms || 15000) });
      return {
        success: true,
        output: typeof response.data === "string" ? response.data.slice(0, 20000) : JSON.stringify(response.data),
      };
    }
  }
}
