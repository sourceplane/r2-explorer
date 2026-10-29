import { describe, expect, it } from "vitest";
import { SITE_NAME } from "@/src/site";
import { escapeHtml, siteNameOf, withTitle } from "@/scripts/dashboard-title.mjs";

// The identity seam a product's bootstrap rewrites, and what the build makes
// of it: the dashboard's <title>.
describe("site identity (apps/web/src/site.ts)", () => {
  it("names the site", () => {
    expect(SITE_NAME.trim()).not.toBe("");
  });

  it("is read back by the build exactly as the rebrand writes it", () => {
    expect(siteNameOf(`export const SITE_NAME = ${JSON.stringify(SITE_NAME)};`)).toBe(SITE_NAME);
    const awkward = `Sam's "Files" & <Photos>`;
    expect(siteNameOf(`export const SITE_NAME = ${JSON.stringify(awkward)};\n`)).toBe(awkward);
    expect(() => siteNameOf("export const NAME = 1;")).toThrow(/SITE_NAME/);
  });
});

describe("the dashboard's <title> (apps/web/scripts/dashboard-title.mjs)", () => {
  const page = "<!DOCTYPE html><html><head><title>R2-Explorer</title><meta charset=utf-8></head><body><div id=q-app></div></body></html>";

  it("is the product's name, HTML-escaped, and nothing else changes", () => {
    const out = withTitle(page, "Sam's Photos & Files")!;
    expect(out).toContain("<title>Sam&#39;s Photos &amp; Files</title>");
    expect(out.replace(/<title>[^<]*<\/title>/, "")).toBe(page.replace(/<title>[^<]*<\/title>/, ""));
  });

  it("writes a name with a `$&` in it literally", () => {
    expect(withTitle(page, "Pay $& go")).toContain("<title>Pay $&amp; go</title>");
  });

  it("refuses a page with no title rather than shipping the upstream name", () => {
    expect(withTitle("<html><head></head></html>", "x")).toBeNull();
  });

  it("escapes every HTML-special character", () => {
    expect(escapeHtml(`<a href="x">&'`)).toBe("&lt;a href=&quot;x&quot;&gt;&amp;&#39;");
  });
});
