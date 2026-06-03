import axios from "axios";
import { ConditionChecker } from "../models/types.js";

export class PriceThresholdChecker implements ConditionChecker {
  async check(params: Record<string, unknown>) {
    const ticker = String(params.ticker || "").toUpperCase();
    if (!ticker) return { passed: false, data: "Missing ticker." };

    const response = await axios.get(`https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(ticker)}`, {
      params: { range: "1d", interval: "1m" },
      timeout: Number(params.timeout_ms || 15000),
    });
    const result = response.data?.chart?.result?.[0];
    const prices = result?.indicators?.quote?.[0]?.close?.filter((value: unknown) => typeof value === "number") || [];
    const price = prices.at(-1);
    if (typeof price !== "number") return { passed: false, data: `Unable to read latest price for ${ticker}.` };

    const above = typeof params.above === "number" ? params.above : undefined;
    const below = typeof params.below === "number" ? params.below : undefined;
    const passed = (above !== undefined && price > above) || (below !== undefined && price < below);
    return { passed, data: `${ticker} latest price: ${price}` };
  }
}
