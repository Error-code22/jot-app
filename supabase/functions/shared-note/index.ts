import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

/**
 * Public renderer for revocable note share links.
 *
 * GET /functions/v1/shared-note?token=<token>
 *
 * The snapshot is read with the service role and never returned raw. All
 * user-controlled text is HTML-escaped, and only http(s) media URLs are
 * embedded. PIN hashes and user ids are never rendered.
 */

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};

const securityHeaders = {
  "Content-Type": "text/html; charset=utf-8",
  "Cache-Control": "no-store",
  "Referrer-Policy": "no-referrer",
  "X-Content-Type-Options": "nosniff",
  "X-Robots-Tag": "noindex, nofollow, noarchive",
  "Content-Security-Policy":
    "default-src 'none'; img-src https: http: data:; media-src https: http:; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
};

function escapeHtml(value: unknown): string {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function safeUrl(value: unknown): string | null {
  if (typeof value !== "string") return null;
  try {
    const url = new URL(value);
    if (url.protocol !== "https:" && url.protocol !== "http:") return null;
    return escapeHtml(url.href);
  } catch {
    return null;
  }
}

function safeAccent(value: unknown): string | null {
  if (typeof value !== "string") return null;
  return /^#[0-9a-fA-F]{6}$/.test(value) ? value : null;
}

function formatDate(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  return date.toISOString().slice(0, 10);
}

function renderChecklist(content: unknown): string | null {
  if (typeof content !== "string" || content.trim() === "") return null;
  let parsed: unknown;
  try {
    parsed = JSON.parse(content);
  } catch {
    return null;
  }
  if (!Array.isArray(parsed)) return null;

  const items = parsed
    .filter((item) => item && typeof item === "object")
    .map((item) => {
      const row = item as Record<string, unknown>;
      const text = typeof row.text === "string" ? row.text.trim() : "";
      if (text === "") return null;
      const checked = row.isChecked === true;
      return `<li class="${checked ? "done" : ""}">
        <span class="box" aria-hidden="true">${checked ? "&#10003;" : ""}</span>
        <span class="item-text">${escapeHtml(text)}</span>
      </li>`;
    })
    .filter((item): item is string => item !== null);

  if (items.length === 0) return null;
  return `<ul class="checklist">${items.join("")}</ul>`;
}

function layout(options: {
  title: string;
  accent: string | null;
  body: string;
  footer?: string;
}): string {
  const accent = options.accent ?? "#7C5CFF";
  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow, noarchive">
<title>${escapeHtml(options.title)}</title>
<style>
  :root {
    color-scheme: light dark;
    --accent: ${accent};
    --bg: #f7f6fb;
    --card: #ffffff;
    --text: #1c1b22;
    --muted: #6b6878;
    --line: #e5e2ee;
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --bg: #121118;
      --card: #1c1a25;
      --text: #f2f0f7;
      --muted: #a6a2b5;
      --line: #2e2b3a;
    }
  }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    min-height: 100vh;
    padding: 32px 18px 56px;
    background: var(--bg);
    color: var(--text);
    font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
    line-height: 1.55;
  }
  .wrap { width: 100%; max-width: 720px; margin: 0 auto; }
  .brand {
    display: flex;
    align-items: center;
    gap: 10px;
    margin-bottom: 18px;
    color: var(--muted);
    font-size: 14px;
    font-weight: 600;
    letter-spacing: .02em;
  }
  .dot {
    width: 12px; height: 12px; border-radius: 4px;
    background: var(--accent);
  }
  article {
    background: var(--card);
    border: 1px solid var(--line);
    border-left: 5px solid var(--accent);
    border-radius: 16px;
    padding: 28px 26px;
    box-shadow: 0 18px 40px rgba(10, 8, 20, .08);
  }
  h1 {
    margin: 0 0 6px;
    font-size: clamp(24px, 5vw, 32px);
    line-height: 1.25;
    overflow-wrap: anywhere;
  }
  .meta {
    margin: 0 0 20px;
    color: var(--muted);
    font-size: 13px;
  }
  .meta span + span::before { content: " · "; }
  .content {
    font-size: 17px;
    overflow-wrap: anywhere;
  }
  .tags { margin: 22px 0 0; padding: 0; list-style: none; display: flex; flex-wrap: wrap; gap: 8px; }
  .tags li {
    padding: 3px 10px;
    border-radius: 999px;
    border: 1px solid var(--line);
    color: var(--muted);
    font-size: 12px;
  }
  .media { margin-top: 24px; }
  .media h2 {
    margin: 0 0 10px;
    font-size: 12px;
    text-transform: uppercase;
    letter-spacing: .09em;
    color: var(--muted);
  }
  .media img {
    display: block;
    width: 100%;
    height: auto;
    border-radius: 12px;
    margin-bottom: 12px;
    border: 1px solid var(--line);
  }
  audio { width: 100%; margin-bottom: 10px; }
  .checklist { list-style: none; margin: 0; padding: 0; }
  .checklist li {
    display: flex;
    gap: 10px;
    align-items: flex-start;
    padding: 5px 0;
  }
  .box {
    flex: 0 0 auto;
    width: 20px; height: 20px;
    margin-top: 2px;
    border: 2px solid var(--accent);
    border-radius: 6px;
    color: var(--accent);
    font-size: 13px;
    line-height: 17px;
    text-align: center;
  }
  .checklist li.done .item-text { color: var(--muted); text-decoration: line-through; }
  footer {
    margin-top: 22px;
    text-align: center;
    color: var(--muted);
    font-size: 12px;
  }
  .empty { color: var(--muted); }
</style>
</head>
<body>
  <div class="wrap">
    <div class="brand"><span class="dot"></span>Jot</div>
    ${options.body}
    <footer>${options.footer ?? "Shared from Jot"}</footer>
  </div>
</body>
</html>`;
}

function messagePage(status: number, title: string, message: string): Response {
  const body = `<article>
    <h1>${escapeHtml(title)}</h1>
    <p class="content empty">${escapeHtml(message)}</p>
  </article>`;
  return new Response(layout({ title, accent: null, body }), {
    status,
    headers: { ...securityHeaders, ...corsHeaders },
  });
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (req.method !== "GET") {
    return messagePage(405, "Method not allowed", "This link can only be opened in a browser.");
  }

  try {
    const token = new URL(req.url).searchParams.get("token")?.trim() ?? "";
    if (!/^[A-Za-z0-9_-]{16,128}$/.test(token)) {
      return messagePage(404, "Link not found", "This share link is invalid or has been removed.");
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (supabaseUrl === "" || serviceKey === "") {
      console.error("shared-note: missing Supabase environment");
      return messagePage(500, "Something went wrong", "This note could not be loaded. Please try again later.");
    }

    const supabase = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data, error } = await supabase
      .from("shared_notes")
      .select("snapshot, revoked, expires_at")
      .eq("token", token)
      .maybeSingle();

    if (error) {
      console.error("shared-note lookup failed", error.message);
      return messagePage(500, "Something went wrong", "This note could not be loaded. Please try again later.");
    }
    if (!data) {
      return messagePage(404, "Link not found", "This share link is invalid or has been removed.");
    }
    if (data.revoked === true) {
      return messagePage(410, "Link revoked", "The owner has revoked this share link.");
    }
    if (data.expires_at) {
      const expiresAt = new Date(data.expires_at);
      if (!Number.isNaN(expiresAt.getTime()) && expiresAt.getTime() <= Date.now()) {
        return messagePage(410, "Link expired", "This share link is no longer available.");
      }
    }

    const snapshot = (data.snapshot ?? {}) as Record<string, unknown>;
    const title = typeof snapshot.title === "string" && snapshot.title.trim() !== ""
      ? snapshot.title.trim()
      : "Untitled note";

    let contentHtml: string;
    const checklistHtml = snapshot.type === "checklist" ? renderChecklist(snapshot.content) : null;
    if (checklistHtml !== null) {
      contentHtml = checklistHtml;
    } else {
      const text = typeof snapshot.content === "string" ? snapshot.content : "";
      contentHtml = text.trim() === ""
        ? '<p class="empty">This note has no text.</p>'
        : `<div class="content">${escapeHtml(text).replace(/\r\n|\r|\n/g, "<br>")}</div>`;
    }

    const images = Array.isArray(snapshot.imageIds) ? snapshot.imageIds : [];
    const imageHtml = images
      .map(safeUrl)
      .filter((url): url is string => url !== null)
      .map((url) => `<img src="${url}" alt="Note image" loading="lazy">`)
      .join("");

    const audio = Array.isArray(snapshot.audioIds) ? snapshot.audioIds : [];
    const audioHtml = audio
      .map(safeUrl)
      .filter((url): url is string => url !== null)
      .map((url) => `<audio controls preload="metadata" src="${url}"></audio>`)
      .join("");

    const tags = Array.isArray(snapshot.tags)
      ? snapshot.tags
          .filter((tag): tag is string => typeof tag === "string" && tag.trim() !== "")
          .slice(0, 30)
      : [];
    const tagsHtml = tags.length === 0
      ? ""
      : `<ul class="tags">${tags.map((tag) => `<li>${escapeHtml(tag)}</li>`).join("")}</ul>`;

    const created = formatDate(snapshot.createdAt);
    const modified = formatDate(snapshot.modifiedAt);
    const metaParts: string[] = [];
    if (created) metaParts.push(`<span>Created ${escapeHtml(created)}</span>`);
    if (modified && modified !== created) metaParts.push(`<span>Updated ${escapeHtml(modified)}</span>`);
    const metaHtml = metaParts.length === 0 ? "" : `<p class="meta">${metaParts.join("")}</p>`;

    let body = `<article>
      <h1>${escapeHtml(title)}</h1>
      ${metaHtml}
      ${contentHtml}
      ${tagsHtml}`;
    if (imageHtml !== "") {
      body += `<div class="media"><h2>Images</h2>${imageHtml}</div>`;
    }
    if (audioHtml !== "") {
      body += `<div class="media"><h2>Audio</h2>${audioHtml}</div>`;
    }
    body += `</article>`;

    return new Response(layout({
      title,
      accent: safeAccent(snapshot.color),
      body,
    }), {
      status: 200,
      headers: { ...securityHeaders, ...corsHeaders },
    });
  } catch (error) {
    console.error("shared-note failed", error);
    return messagePage(500, "Something went wrong", "This note could not be loaded. Please try again later.");
  }
});
