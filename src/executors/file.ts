import fs from "node:fs";
import path from "node:path";
import { config } from "../config.js";
import { ActionConfig, ActionExecutor, RunContext } from "../models/types.js";
import { renderTemplate } from "../utils/template.js";

export class FileExecutor implements ActionExecutor {
  async execute(actionConfig: ActionConfig["config"], context: RunContext) {
    const filename = path.basename(String(renderTemplate(actionConfig.path || actionConfig.filename || "autopilot-output.md", context.variables)));
    const targetDir = actionConfig.directory ? String(actionConfig.directory) : path.join(config.root, "data", "files");
    const fullPath = path.join(targetDir, filename);
    const content = String(renderTemplate(actionConfig.content || "{{result}}", context.variables));
    fs.mkdirSync(targetDir, { recursive: true });

    if (actionConfig.mode === "append") {
      fs.appendFileSync(fullPath, `${content}\n`, "utf8");
    } else {
      fs.writeFileSync(fullPath, content, "utf8");
    }

    return { success: true, output: `File written: ${fullPath}` };
  }
}
