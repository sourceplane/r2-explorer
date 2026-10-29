// The two pure halves of the dashboard's build (build-dashboard.mjs), apart
// so the tests can hold them: reading the product's name out of src/site.ts,
// and writing it into a page's <title>, HTML-escaped.

/** SITE_NAME from src/site.ts, which the rebrand writes as a JSON string. */
export function siteNameOf(siteTs) {
  const m = /export const SITE_NAME = ("(?:[^"\\]|\\.)*");/.exec(siteTs);
  if (!m) throw new Error("src/site.ts declares no SITE_NAME string");
  return JSON.parse(m[1]);
}

export function escapeHtml(s) {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

/** The page with its first <title> set to `name`; null when it has none. */
export function withTitle(html, name) {
  if (!/<title>[^<]*<\/title>/.test(html)) return null;
  return html.replace(/<title>[^<]*<\/title>/, () => `<title>${escapeHtml(name)}</title>`);
}
