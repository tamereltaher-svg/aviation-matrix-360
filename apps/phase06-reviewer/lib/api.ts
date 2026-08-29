export async function apiFetch(path: string, init?: RequestInit) {
  const raw = localStorage.getItem("phase06_access_token");
  if (!raw) throw new Error("Not signed in.");

  const res = await fetch(path, {
    ...init,
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${raw}`,
      ...(init?.headers || {})
    }
  });

  const body = await res.json();
  if (!res.ok) throw new Error(body.error || "Request failed.");
  return body;
}
