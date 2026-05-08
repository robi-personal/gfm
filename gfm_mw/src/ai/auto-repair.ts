// Pure text → parsed-object pipeline. Does NOT call Zod — that is the caller's job.

const VALID_TYPES = new Set([
  "SHORT_ANSWER", "PARAGRAPH", "MULTIPLE_CHOICE", "CHECKBOXES",
  "DROPDOWN", "LINEAR_SCALE", "DATE", "TIME", "RATING",
]);

const OPTION_TYPES = new Set(["MULTIPLE_CHOICE", "CHECKBOXES", "DROPDOWN"]);
const SCALE_FIELDS = ["scaleMin", "scaleMax", "scaleMinLabel", "scaleMaxLabel"] as const;

function isObject(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

// camelCase / PascalCase → UPPER_SNAKE_CASE normalization for enum values.
function normalizeEnumValue(raw: string): string {
  return raw.replace(/([a-z])([A-Z])/g, "$1_$2").toUpperCase();
}

function extractBalancedBlock(text: string, startIdx: number): string | null {
  let depth = 0;
  let inString = false;
  let escape = false;

  for (let i = startIdx; i < text.length; i++) {
    const ch = text[i]!;
    if (escape) { escape = false; continue; }
    if (ch === "\\" && inString) { escape = true; continue; }
    if (ch === '"') { inString = !inString; continue; }
    if (inString) continue;
    if (ch === "{") depth++;
    else if (ch === "}") {
      depth--;
      if (depth === 0) return text.slice(startIdx, i + 1);
    }
  }
  return null;
}

function addRule(rules: string[], rule: string): void {
  if (!rules.includes(rule)) rules.push(rule);
}

export interface AutoRepairResult {
  candidate: unknown;
  appliedRules: string[];
}

export function parseAndAutoRepair(rawText: string): AutoRepairResult {
  const appliedRules: string[] = [];

  // Step 1: Strip ZWSP, BOM, and non-printable control chars (keep \t \n \r).
  let text = rawText
    .replace(/[​﻿]/g, "")
    .replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, "");

  // Step 2: Replace smart quotes — do this before extraction so balanced-brace
  // scanning and JSON.parse both see straight ASCII quotes.
  const beforeQuotes = text;
  text = text
    .replace(/[“”]/g, '"')   // " "
    .replace(/[‘’]/g, "'");  // ' '
  if (text !== beforeQuotes) addRule(appliedRules, "smart_quotes");

  // Step 3: Strip code fences (```json … ``` or ``` … ```).
  const fenceMatch = text.match(/```(?:json)?\s*\n?([\s\S]*?)\n?```/);
  if (fenceMatch?.[1] !== undefined) {
    text = fenceMatch[1].trim();
    addRule(appliedRules, "fence_strip");
  }

  // Step 4: Find the first balanced { } block and strip leading/trailing prose.
  const braceIdx = text.indexOf("{");
  if (braceIdx !== -1) {
    const block = extractBalancedBlock(text, braceIdx);
    if (block !== null && block !== text.trim()) {
      text = block;
      addRule(appliedRules, "prose_strip");
    } else if (block !== null) {
      text = block;
    }
  }

  // Step 5: JSON.parse; on failure strip trailing commas and retry.
  let candidate: unknown;
  try {
    candidate = JSON.parse(text);
  } catch {
    const stripped = text.replace(/,(\s*[}\]])/g, "$1");
    try {
      candidate = JSON.parse(stripped);
      addRule(appliedRules, "trailing_comma");
    } catch {
      return { candidate: null, appliedRules };
    }
  }

  // Step 6: Structural auto-repairs (§6.1).
  candidate = repairCandidate(candidate, appliedRules);

  return { candidate, appliedRules };
}

function repairCandidate(value: unknown, rules: string[]): unknown {
  if (!isObject(value)) return value;

  const obj: Record<string, unknown> = { ...value };

  // Top-level string trims and null-description drop.
  for (const field of ["title", "description"] as const) {
    if (obj[field] === null) {
      delete obj[field];
      addRule(rules, "drop_null_description");
    } else if (typeof obj[field] === "string") {
      const trimmed = (obj[field] as string).trim();
      if (trimmed !== obj[field]) {
        obj[field] = trimmed;
        addRule(rules, "trim_strings");
      }
    }
  }

  if (Array.isArray(obj["questions"])) {
    obj["questions"] = (obj["questions"] as unknown[]).map((q) =>
      repairQuestion(q, rules),
    );
  }

  return obj;
}

function repairQuestion(q: unknown, rules: string[]): unknown {
  if (!isObject(q)) return q;

  const question: Record<string, unknown> = { ...q };

  // Drop description: null.
  if (question["description"] === null) {
    delete question["description"];
    addRule(rules, "drop_null_description");
  }

  // Trim known string fields.
  const stringFields = [
    "title", "description", "scaleMinLabel", "scaleMaxLabel",
  ] as const;
  for (const field of stringFields) {
    if (typeof question[field] === "string") {
      const trimmed = (question[field] as string).trim();
      if (trimmed !== question[field]) {
        question[field] = trimmed;
        addRule(rules, "trim_strings");
      }
    }
  }

  // Enum casing normalization for `type`.
  if (typeof question["type"] === "string") {
    const normalized = normalizeEnumValue(question["type"]);
    if (normalized !== question["type"] && VALID_TYPES.has(normalized)) {
      question["type"] = normalized;
      addRule(rules, "enum_casing");
    }
  }

  // Default `required` to false when absent or null.
  if (
    !("required" in question) ||
    question["required"] === null ||
    question["required"] === undefined
  ) {
    question["required"] = false;
    addRule(rules, "default_required");
  }

  // Repair options array: coerce non-strings, trim, dedupe.
  if (Array.isArray(question["options"])) {
    let opts = question["options"] as unknown[];

    // Coerce non-string entries.
    let coerced = false;
    opts = opts.map((opt) => {
      if (typeof opt !== "string") { coerced = true; return String(opt); }
      return opt;
    });
    if (coerced) addRule(rules, "coerce_option_string");

    // Trim each entry.
    opts = (opts as string[]).map((opt) => {
      const t = opt.trim();
      if (t !== opt) addRule(rules, "trim_strings");
      return t;
    });

    // Dedupe after casefold — only apply if result stays >= 2.
    const seen = new Set<string>();
    const deduped: string[] = [];
    for (const opt of opts as string[]) {
      if (!seen.has(opt.toLowerCase())) {
        seen.add(opt.toLowerCase());
        deduped.push(opt);
      }
    }
    if (deduped.length !== opts.length) {
      if (deduped.length >= 2) {
        opts = deduped;
        addRule(rules, "dedupe_options");
      }
      // If below 2 after dedup, leave the array intact for Zod to catch.
    }

    question["options"] = opts;
  }

  // Strip type-irrelevant fields (only when type is a known valid type).
  const qType = typeof question["type"] === "string" ? question["type"] : null;
  if (qType !== null && VALID_TYPES.has(qType)) {
    if (!OPTION_TYPES.has(qType) && "options" in question) {
      delete question["options"];
      addRule(rules, "strip_irrelevant_fields");
    }
    if (qType !== "LINEAR_SCALE") {
      for (const f of SCALE_FIELDS) {
        if (f in question) {
          delete question[f];
          addRule(rules, "strip_irrelevant_fields");
        }
      }
    }
    if (qType !== "RATING" && "ratingScale" in question) {
      delete question["ratingScale"];
      addRule(rules, "strip_irrelevant_fields");
    }
  }

  return question;
}
