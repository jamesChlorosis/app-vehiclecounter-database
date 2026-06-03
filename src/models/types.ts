export type TaskStatus = "pending" | "running" | "completed" | "failed" | "paused" | "recurring";
export type TriggerType = "time_once" | "time_recurring" | "event_poll";
export type TaskRunStatus = "running" | "success" | "failed";

export type ConditionType = "http_contains" | "price_threshold" | "page_changed" | "custom_script";

export interface ConditionConfig {
  type: ConditionType;
  params: Record<string, unknown>;
}

export type TriggerConfig =
  | {
      type: "time_once";
      run_at: string;
    }
  | {
      type: "time_recurring";
      cron_expression: string;
      human_label: string;
    }
  | {
      type: "event_poll";
      poll_interval_seconds: number;
      condition: ConditionConfig;
    };

export type ActionType =
  | "send_telegram"
  | "send_email"
  | "send_discord"
  | "http_request"
  | "web_scrape"
  | "ai_summarize"
  | "ai_report"
  | "create_file"
  | "run_script";

export interface ActionConfig {
  id?: string;
  type: ActionType;
  config: Record<string, unknown>;
}

export interface Task {
  id: string;
  name: string;
  description: string;
  status: TaskStatus;
  trigger: TriggerConfig;
  actions: ActionConfig[];
  created_at: string;
  updated_at: string;
  last_run_at: string | null;
  next_run_at: string | null;
}

export interface TaskInput {
  name: string;
  description?: string;
  status?: TaskStatus;
  trigger: TriggerConfig;
  actions: ActionConfig[];
}

export interface TaskRun {
  id: string;
  task_id: string;
  started_at: string;
  completed_at: string | null;
  status: TaskRunStatus;
  output: string | null;
  error: string | null;
}

export interface RunContext {
  task: Task;
  run: TaskRun;
  triggerOutput?: string;
  variables: Record<string, unknown>;
}

export interface ActionResult {
  success: boolean;
  output?: string;
  error?: string;
}

export interface ActionExecutor {
  execute(config: ActionConfig["config"], context: RunContext): Promise<ActionResult>;
}

export interface ConditionResult {
  passed: boolean;
  data?: string;
}

export interface ConditionChecker {
  check(params: Record<string, unknown>): Promise<ConditionResult>;
}
