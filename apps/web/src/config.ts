// What R2-Explorer is told, per environment, from the Worker's secrets.
//
// READ-ONLY BY DEFAULT, as upstream ships it (`readonly: true`): with no
// credentials stored the explorer is a public, read-only view of the bucket.
// Store BOTH `BASIC_AUTH_USERNAME` and `BASIC_AUTH_PASSWORD` (Orun secrets,
// handed to the Worker as Worker secrets on deploy) and every `/api/*` route
// asks for HTTP Basic authentication, and the signed-in user may upload,
// move, rename and delete. One of the two alone is not credentials: the
// explorer stays read-only, and the health route says so.
//
// Cloudflare Access, upstream's other way in (`cfAccessTeamName`), is left
// out: an Access application is a Zero Trust resource no Orun composition
// provisions. Email Routing (`emailRouting`, the bucket receiving mail) is
// left out the same way, and the Worker exports no `email` handler.

export type Credentials = { username: string; password: string };

export type ExplorerEnv = {
  BASIC_AUTH_USERNAME?: string;
  BASIC_AUTH_PASSWORD?: string;
};

export type ExplorerConfig = {
  readonly: boolean;
  emailRouting: false;
  basicAuth?: Credentials;
};

export function credentialsOf(env: ExplorerEnv): Credentials | undefined {
  const username = (env.BASIC_AUTH_USERNAME ?? "").trim();
  const password = env.BASIC_AUTH_PASSWORD ?? "";
  if (username.length === 0 || password.length === 0) return undefined;
  return { username, password };
}

export function configFor(env: ExplorerEnv): ExplorerConfig {
  const credentials = credentialsOf(env);
  if (!credentials) return { readonly: true, emailRouting: false };
  return { readonly: false, emailRouting: false, basicAuth: credentials };
}

export type Mode = "read-only" | "read-write";

export function modeOf(env: ExplorerEnv): Mode {
  return credentialsOf(env) ? "read-write" : "read-only";
}
