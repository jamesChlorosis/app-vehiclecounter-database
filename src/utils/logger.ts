export function log(message: string, details?: Record<string, unknown>) {
  const suffix = details ? ` ${JSON.stringify(details)}` : "";
  console.log(`[${new Date().toISOString()}] ${message}${suffix}`);
}
