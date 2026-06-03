export function renderTemplate(input: unknown, variables: Record<string, unknown>): unknown {
  if (typeof input === "string") {
    return input.replace(/\{\{\s*([\w.-]+)\s*\}\}/g, (_, key: string) => {
      const value = key.split(".").reduce<unknown>((acc, part) => {
        if (acc && typeof acc === "object" && part in acc) {
          return (acc as Record<string, unknown>)[part];
        }
        return undefined;
      }, variables);
      return value === undefined || value === null ? "" : String(value);
    });
  }

  if (Array.isArray(input)) {
    return input.map((item) => renderTemplate(item, variables));
  }

  if (input && typeof input === "object") {
    return Object.fromEntries(
      Object.entries(input as Record<string, unknown>).map(([key, value]) => [key, renderTemplate(value, variables)]),
    );
  }

  return input;
}
