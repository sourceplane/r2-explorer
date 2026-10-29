import { describe, expect, it } from "vitest";
import { configFor, credentialsOf, modeOf } from "@/src/config";

// What R2-Explorer is told, per environment, from the two optional secrets.
describe("the explorer's configuration (apps/web/src/config.ts)", () => {
  it("is read-only and asks for no sign-in with no secrets — upstream's default", () => {
    expect(configFor({})).toEqual({ readonly: true, emailRouting: false });
    expect(modeOf({})).toBe("read-only");
    expect(credentialsOf({})).toBeUndefined();
  });

  it("is not credentials with only one of the two, or a blank one", () => {
    for (const env of [
      { BASIC_AUTH_USERNAME: "sam" },
      { BASIC_AUTH_PASSWORD: "s3cret" },
      { BASIC_AUTH_USERNAME: "   ", BASIC_AUTH_PASSWORD: "s3cret" },
      { BASIC_AUTH_USERNAME: "sam", BASIC_AUTH_PASSWORD: "" },
    ]) {
      expect(configFor(env)).toEqual({ readonly: true, emailRouting: false });
      expect(modeOf(env)).toBe("read-only");
    }
  });

  it("asks for HTTP Basic sign-in and allows changes with both", () => {
    const env = { BASIC_AUTH_USERNAME: " sam ", BASIC_AUTH_PASSWORD: "s3cret pass" };
    expect(configFor(env)).toEqual({
      readonly: false,
      emailRouting: false,
      basicAuth: { username: "sam", password: "s3cret pass" },
    });
    expect(modeOf(env)).toBe("read-write");
  });

  it("never turns on Email Routing (it has no composition here)", () => {
    expect(configFor({ BASIC_AUTH_USERNAME: "sam", BASIC_AUTH_PASSWORD: "x" }).emailRouting).toBe(false);
  });
});
