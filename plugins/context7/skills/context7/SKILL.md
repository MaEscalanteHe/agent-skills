---
name: context7
description: "Retrieve up-to-date, version-specific documentation and real code examples for any software library, framework, or API by querying the Context7 REST API with curl (works with no API key). Use this skill whenever you need to look up how a library actually works, find current usage examples for a specific feature or API, verify the correct signature or options of a function, or check whether an API changed after your training cutoff — e.g. React, Next.js, FastAPI, Prisma, Tailwind, Django, axios, LangChain, or any other library. Prefer this over relying on possibly-stale training knowledge whenever the user asks about library or framework usage, setup, configuration, errors, or migration. Reach for it proactively before writing non-trivial code against a third-party library."
---

# Context7

Fetch current documentation straight from the source instead of trusting training data that may be months or years out of date. Library APIs drift — signatures change, options get renamed, idioms get replaced. When you're about to write code against a third-party library and there's any doubt about the current shape of its API, look it up here first, and treat what comes back as more authoritative than your own recollection when they conflict.

Context7 is a plain REST API over HTTPS. You query it with `curl`; it works with no API key, no MCP server, and no install beyond tools you already have.

Base URL: `https://context7.com`. Official API guide: https://context7.com/docs/api-guide

## Prerequisites

Just `curl`. The examples pipe through `jq` to pull single fields cleanly — if `jq` isn't available, drop the pipe and read the raw JSON yourself, or request `type=txt` (see below).

## Authentication (optional)

The API works without a key but at **low rate limits**. For heavier use, get a key at https://context7.com/dashboard and pass it as a bearer token. Keep it in an environment variable — never hardcode it in a command, a file, or a commit:

```bash
curl -s -H "Authorization: Bearer $CONTEXT7_API_KEY" "https://context7.com/api/v2/..."
```

If `CONTEXT7_API_KEY` isn't set, just omit the `-H` flag — every example below works keyless.

## Workflow

Two steps: resolve the library to its Context7 ID, then fetch docs for a topic within that library.

### Step 1 — Resolve the library ID

Library names aren't used directly; each library has a Context7 ID like `/vercel/next.js` or `/websites/react_dev_reference`. Search to find it:

```bash
curl -s "https://context7.com/api/v2/libs/search?libraryName=LIBRARY_NAME&query=TOPIC" | jq '.results[0]'
```

- `libraryName` (required) — the library to search for, e.g. `react`, `nextjs`, `fastapi`, `axios`.
- `query` (required) — a short natural-language description of what you're after; it ranks results by relevance.

Each result includes `id` (the ID you need next), `title`, `description`, `totalSnippets` (how much doc coverage exists), and `versions` (available pinnable versions, if any). The top hit is usually right, but if the `title`/`description` don't match what you meant, scan the rest of `.results` and pick the correct one — don't blindly take `.results[0]` if it's clearly a different project that happens to share the name.

### Step 2 — Fetch the documentation

Use the resolved ID to pull docs scoped to your topic:

```bash
curl -s "https://context7.com/api/v2/context?libraryId=LIBRARY_ID&query=TOPIC&type=txt"
```

- `libraryId` (required) — the `id` from Step 1.
- `query` (required) — the specific thing you want docs for (`useState`, `app router`, `dependency injection`, …). Specific beats vague; it drives which snippets come back.
- `type` (optional) — `json` (default) or `txt`. Use `txt` when you just want to read the docs; use `json` to process the result programmatically.

**Version pinning.** When a library exposes versions and you care about a specific one, pin it in the `libraryId` with either `@tag` or a trailing `/tag`:

```bash
curl -s "https://context7.com/api/v2/context?libraryId=/vercel/next.js@v15.1.8&query=app+router&type=txt"
```

Use the exact tag string — they usually carry a `v` prefix (`v15.1.8`, `v13.5.11`). Find valid tags in the `versions` array from Step 1; if you guess wrong you get a `404` whose `message` conveniently lists the available tags, so you can retry. Pinning is the single most effective way to get consistent, correct answers — unpinned queries float to the latest docs, which may not match the version the project actually uses.

## Examples

**React hooks**
```bash
curl -s "https://context7.com/api/v2/libs/search?libraryName=react&query=hooks" | jq -r '.results[0].id'
# → /websites/react_dev_reference

curl -s "https://context7.com/api/v2/context?libraryId=/websites/react_dev_reference&query=useState&type=txt"
```

**FastAPI dependency injection (authenticated)**
```bash
curl -s -H "Authorization: Bearer $CONTEXT7_API_KEY" \
  "https://context7.com/api/v2/context?libraryId=/fastapi/fastapi&query=dependency+injection&type=txt"
```

## Best practices

Straight from the official guide, with the reasoning:

- **Write detailed, natural-language queries.** "how do I revalidate a cached fetch in the app router" returns far better snippets than "cache". Vague terms rank poorly.
- **Pin to a specific version** for consistent results — see Step 2.
- **Cache what you fetch.** Documentation changes infrequently, so it's fine to reuse a result across a working session rather than re-querying the same topic repeatedly. This also keeps you well under rate limits.
- **URL-encode spaces** in query params — use `+` or `%20` (e.g. `query=app+router`).

## Rate limits and errors

Responses carry rate-limit headers: `RateLimit-Limit`, `RateLimit-Remaining`, and `RateLimit-Reset` (Unix timestamp). When you exceed the limit you get HTTP `429` with a `Retry-After` header (seconds until reset) — back off and retry, ideally with exponential backoff rather than hammering.

Errors return JSON with `error` and `message` fields. A `301` means the library moved — follow the `redirectUrl` in the response and retry with the new ID.

## Beyond lookups

This skill covers the read path (search + fetch docs), which is what you want >95% of the time. Context7 also exposes write/admin endpoints — submitting a repo, website, OpenAPI spec, or `llms.txt` for indexing (`POST /api/v2/add/...`), refreshing docs, and managing teamspace policies. Those require an API key; see the official guide if you need them.
