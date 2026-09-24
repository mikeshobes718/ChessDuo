// In-app account deletion when DELETE /auth/me is available on the server.
// Deploy with verify=user so Berth passes Berth-User-Id.

function reply(status: number, payload: Record<string, unknown>): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

export default async (request: Request): Promise<Response> => {
  if (request.method !== "POST") return reply(405, { error: "method_not_allowed" });
  const apiUrl = Deno.env.get("BERTH_API_URL");
  const app = Deno.env.get("BERTH_APP");
  const secretKey = Deno.env.get("BERTH_SECRET_KEY");
  if (!apiUrl || !app || !secretKey) return reply(503, { error: "not_configured" });
  const uid = request.headers.get("Berth-User-Id");
  if (!uid || !/^[0-9a-f-]{36}$/i.test(uid)) return reply(401, { error: "unauthorized" });

  const base = `${apiUrl.replace(/\/+$/, "")}/apps/${app}`;
  const headers = { Authorization: `Bearer ${secretKey}`, "Content-Type": "application/json" };

  for (const table of ["game_records", "profiles"]) {
    const removed = await fetch(`${base}/tables/${table}/rows?owner_id=eq.${uid}`, { method: "DELETE", headers });
    if (!removed.ok) return reply(502, { error: `${table}_delete_failed` });
  }

  const user = await fetch(`${base}/auth/users/${uid}`, { method: "DELETE", headers });
  if (!user.ok && user.status !== 404) return reply(502, { error: "user_delete_failed" });

  return reply(200, { deleted: true });
};
