import { CronExpressionParser } from "cron-parser";
import { TriggerConfig } from "../models/types.js";

export function computeNextRunAt(trigger: TriggerConfig): string | null {
  if (trigger.type === "time_once") {
    return trigger.run_at;
  }

  if (trigger.type === "time_recurring") {
    try {
      return CronExpressionParser.parse(trigger.cron_expression).next().toDate().toISOString();
    } catch {
      return null;
    }
  }

  return new Date(Date.now() + trigger.poll_interval_seconds * 1000).toISOString();
}

export function triggerSummary(trigger: TriggerConfig) {
  if (trigger.type === "time_once") return `Once at ${trigger.run_at}`;
  if (trigger.type === "time_recurring") return trigger.human_label || trigger.cron_expression;
  return `Every ${trigger.poll_interval_seconds}s when ${trigger.condition.type} passes`;
}
