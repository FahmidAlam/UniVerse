import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";

interface RgbColor {
  r: number;
  g: number;
  b: number;
}

function clamp01(v: number): number {
  return Math.max(0, Math.min(1, v));
}

function linearToSrgbChannel(c: number): number {
  const x = clamp01(c);
  if (x <= 0.0031308) return 12.92 * x;
  return 1.055 * x ** (1 / 2.4) - 0.055;
}

function srgbChannelToLinear(c: number): number {
  const x = clamp01(c);
  if (x <= 0.04045) return x / 12.92;
  return ((x + 0.055) / 1.055) ** 2.4;
}

function oklchToSrgb(L: number, C: number, Hdeg: number): {
  rgb: RgbColor;
  inGamut: boolean;
} {
  const hRad = (Hdeg * Math.PI) / 180;
  const a = C * Math.cos(hRad);
  const b = C * Math.sin(hRad);

  const l_ = L + 0.3963377774 * a + 0.2158037573 * b;
  const m_ = L - 0.1055613458 * a - 0.0638541728 * b;
  const s_ = L - 0.0894841775 * a - 1.2914855480 * b;

  const l = l_ * l_ * l_;
  const m = m_ * m_ * m_;
  const s = s_ * s_ * s_;

  const rLin = +4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s;
  const gLin = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s;
  const bLin = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s;

  const inGamut =
    rLin >= -0.0005 &&
    rLin <= 1.0005 &&
    gLin >= -0.0005 &&
    gLin <= 1.0005 &&
    bLin >= -0.0005 &&
    bLin <= 1.0005;

  return {
    rgb: {
      r: Math.round(linearToSrgbChannel(rLin) * 255),
      g: Math.round(linearToSrgbChannel(gLin) * 255),
      b: Math.round(linearToSrgbChannel(bLin) * 255),
    },
    inGamut,
  };
}

function relativeLuminance(rgb: RgbColor): number {
  const r = srgbChannelToLinear(rgb.r / 255);
  const g = srgbChannelToLinear(rgb.g / 255);
  const b = srgbChannelToLinear(rgb.b / 255);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

function contrastRatio(fg: RgbColor, bg: RgbColor): number {
  const l1 = relativeLuminance(fg);
  const l2 = relativeLuminance(bg);
  const lighter = Math.max(l1, l2);
  const darker = Math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

function parseRootOklchTokens(cssSource: string): Record<string, RgbColor> {
  const rootMatch = cssSource.match(/:root\s*\{([\s\S]*?)\n\}/);
  if (!rootMatch) throw new Error("Missing :root token block in tokens.css");
  const rootBody = rootMatch[1]!;

  const tokenRegex =
    /(--[a-z0-9-]+)\s*:\s*oklch\(\s*([0-9.]+)\s+([0-9.]+)\s+([0-9.]+)\s*\)\s*;/gi;
  const parsed: Record<string, RgbColor> = {};

  for (const match of rootBody.matchAll(tokenRegex)) {
    const [, name, Lstr, Cstr, Hstr] = match;
    if (!name || !Lstr || !Cstr || !Hstr) continue;
    const { rgb, inGamut } = oklchToSrgb(
      Number.parseFloat(Lstr),
      Number.parseFloat(Cstr),
      Number.parseFloat(Hstr),
    );
    expect(inGamut, `Token ${name} must fit inside sRGB gamut`).toBe(true);
    parsed[name] = rgb;
  }
  return parsed;
}

describe("UniVerse Academic Ledger tokens.css WCAG 2.1 AA sRGB verification", () => {
  const tokensPath = path.resolve(__dirname, "../../src/styles/tokens.css");
  const css = fs.readFileSync(tokensPath, "utf8");
  const tokens = parseRootOklchTokens(css);

  it("enforces single light-first design system with accessibility media rules and zero Spatial Orbit dark rules", () => {
    expect(css).not.toContain('data-theme="dark"');
    expect(css).not.toContain("--bg-dark");
    expect(css).toContain("@media (prefers-contrast: more)");
    expect(css).toContain("@media (forced-colors: active)");
    expect(css).toContain("@media (prefers-reduced-motion: reduce)");
  });

  const requiredPairs: readonly [string, string, number, string][] = [
    ["--ink-primary", "--bg-canvas", 4.5, "Primary text on canvas"],
    ["--ink-primary", "--bg-surface", 4.5, "Primary text on surface"],
    ["--ink-primary", "--bg-elevated", 4.5, "Primary text on elevated"],
    ["--ink-secondary", "--bg-canvas", 4.5, "Secondary text on canvas"],
    ["--ink-secondary", "--bg-surface", 4.5, "Secondary text on surface"],
    ["--ink-secondary", "--bg-elevated", 4.5, "Secondary text on elevated"],
    ["--ink-muted", "--bg-canvas", 4.5, "Muted text on canvas"],
    ["--ink-muted", "--bg-surface", 4.5, "Muted text on surface"],
    ["--ink-muted", "--bg-elevated", 4.5, "Muted text on elevated"],
    ["--action-primary-ink", "--action-primary", 4.5, "Primary button text"],
    ["--action-primary-ink", "--action-primary-hover", 4.5, "Primary hover button text"],
    ["--action-primary", "--bg-elevated", 3.0, "Primary button outline on elevated"],
    ["--accent-pine", "--bg-canvas", 4.5, "Accent pine text on canvas"],
    ["--accent-pine", "--bg-surface", 4.5, "Accent pine text on surface"],
    ["--accent-pine", "--bg-elevated", 4.5, "Accent pine text on elevated"],
    ["--accent-pine", "--accent-pine-soft", 4.5, "Accent pine text on soft wash"],
    ["--accent-pine-ink", "--accent-pine", 4.5, "Accent pine pill text"],
    ["--focus-ring", "--bg-elevated", 3.0, "Focus ring on elevated"],
    ["--focus-ring", "--bg-canvas", 3.0, "Focus ring on canvas"],
    ["--border-control", "--bg-elevated", 3.0, "Control border on elevated"],
    ["--border-control", "--bg-surface", 3.0, "Control border on surface"],
    ["--sem-theory-ink", "--sem-theory-bg", 4.5, "Theory cell ink on fill"],
    ["--sem-theory-bar", "--bg-elevated", 3.0, "Theory accent bar on elevated"],
    ["--sem-lab-ink", "--sem-lab-bg", 4.5, "Lab cell ink on fill"],
    ["--sem-lab-bar", "--bg-elevated", 3.0, "Lab accent bar on elevated"],
    ["--sem-joint-ink", "--sem-joint-bg", 4.5, "Joint cell ink on fill"],
    ["--sem-joint-bar", "--bg-elevated", 3.0, "Joint accent bar on elevated"],
    ["--sem-conflict-ink", "--sem-conflict-bg", 4.5, "Conflict cell ink on fill"],
    ["--sem-conflict-bar", "--bg-elevated", 3.0, "Conflict accent bar on elevated"],
  ];

  it.each(requiredPairs)(
    "%s on %s meets >= %s:1 (%s)",
    (fgName, bgName, minRatio, description) => {
      const fg = tokens[fgName];
      const bg = tokens[bgName];
      expect(fg, `Missing token ${fgName}`).toBeDefined();
      expect(bg, `Missing token ${bgName}`).toBeDefined();
      const ratio = contrastRatio(fg!, bg!);
      expect(ratio, `${description} (${ratio.toFixed(2)}:1)`).toBeGreaterThanOrEqual(minRatio);
    },
  );
});
