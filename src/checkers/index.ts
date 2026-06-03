import { AppDatabase } from "../models/database.js";
import { ConditionChecker, ConditionConfig } from "../models/types.js";
import { CustomScriptChecker } from "./customScript.js";
import { HttpContainsChecker } from "./httpContains.js";
import { PageChangedChecker } from "./pageChanged.js";
import { PriceThresholdChecker } from "./priceThreshold.js";

export class ConditionRegistry {
  private checkers = new Map<string, ConditionChecker>();

  constructor(db: AppDatabase) {
    this.checkers.set("http_contains", new HttpContainsChecker());
    this.checkers.set("price_threshold", new PriceThresholdChecker());
    this.checkers.set("page_changed", new PageChangedChecker(db));
    this.checkers.set("custom_script", new CustomScriptChecker());
  }

  async check(condition: ConditionConfig) {
    const checker = this.checkers.get(condition.type);
    if (!checker) throw new Error(`Unsupported condition type: ${condition.type}`);
    return checker.check(condition.params);
  }
}
