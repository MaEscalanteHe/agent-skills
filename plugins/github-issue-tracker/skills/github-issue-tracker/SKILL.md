---
name: github-issue-tracker
description: "Track edge cases, TODOs, and deferred work as GitHub issues using the gh CLI. Use this skill proactively whenever a development task surfaces an edge case, a bug to fix later, a refactor opportunity, or any work that should be handled in a separate session. Also use when the user asks to create issues from a TODO file (TODO.md, TODO.txt, TODO) found in the repository. Triggers include: discovering unexpected behavior during implementation, noting 'we should also handle X', finding tech debt, or when the user says 'create an issue', 'track this', 'log this for later', 'this needs its own PR', or similar phrases. Even if the user doesn't explicitly ask, suggest creating an issue when you notice work that clearly belongs in a separate session."
---

# GitHub Issue Tracker

Track deferred work, edge cases, and TODOs as GitHub issues directly from Claude Code
using the `gh` CLI — keeping the current session focused while ensuring nothing slips
through the cracks.

---

## Prerequisites

The `gh` CLI must be installed and authenticated. Verify before any issue creation:

```bash
gh auth status
```

If not authenticated, ask the user to run `gh auth login` and stop.

Detect the repo automatically from the working directory:

```bash
gh repo view --json nameWithOwner -q .nameWithOwner
```

If this fails (no git repo, no remote), ask the user for `owner/repo`.

### Language

Default to **English** for issue titles, bodies, and comments — GitHub issues are
a shared artifact and English keeps them accessible to any contributor. If the user
explicitly asks for another language, or the repository's existing issues are
consistently in a different language, follow that convention instead.

### Issue templates

Check if the repo has issue templates:

```bash
ls .github/ISSUE_TEMPLATE/ 2>/dev/null
```

Templates can be Markdown files (`bug_report.md`, `feature_request.md`) or YAML
form definitions (`bug_report.yml`). If templates exist, read them and use the one
that best fits the issue type. For YAML form templates, extract the field structure
and fill in the relevant sections. Fall back to the default structure below when no
template matches.

---

## Proactive behavior

### When to suggest

During development, suggest creating an issue when you notice:

- An edge case that's out of scope for the current task
- A bug or inconsistency that isn't blocking but should be fixed
- A refactor opportunity that would derail the current work
- Missing tests or validation that deserve dedicated attention
- Security concerns that need proper investigation
- Performance improvements that aren't urgent

Frame it naturally:

> "I noticed [X] — this seems like it deserves its own issue so we don't lose
> track of it. Want me to create one?"

The goal is traceability: every piece of deferred work gets a GitHub issue so it
can be prioritized, assigned, and tracked — rather than forgotten in a chat log.

### When NOT to suggest

Being proactive is valuable, but being noisy is not. Hold back when:

- The user already declined a similar suggestion in this session — don't insist
- The edge case is trivial and the user would clearly handle it inline
- You've already suggested 2+ issues in a short span — too much context-switching
  breaks flow. Batch them and offer at a natural pause instead
- The user is in the middle of debugging or a complex train of thought — wait
  for a resolution point before interrupting
- The observation is speculative ("this _might_ break if...") rather than concrete

If the user says "no" or "not now" to a suggestion, respect it for the rest of
the session. Don't bring up the same topic again unless the user explicitly
revisits it.

---

## Issue anatomy

These rules apply to every issue, whether from an edge case or a TODO file.

### Title

Concise, imperative, with a conventional prefix when the type is clear:

| Prefix      | When                         |
| ----------- | ---------------------------- |
| `fix:`      | Bug or broken behavior       |
| `feat:`     | New functionality            |
| `chore:`    | Cleanup, refactor, tech debt |
| `test:`     | Missing or broken tests      |
| `docs:`     | Documentation gaps           |
| `perf:`     | Performance improvement      |
| `security:` | Security concern             |

### Body

Use this structure, dropping sections that don't apply:

```markdown
## Context

Discovered while working on branch `<branch>` (PR #<number> if exists).

## Problem

<what the edge case / bug / improvement is — be specific>

## Suggested approach

<files, functions, or steps when known — omit if unclear>
```

The branch/PR reference gives bidirectional traceability — whoever picks up the
issue can see where and why it was discovered.

**Code snippets** — when the issue involves specific code, include a short snippet
(5-10 lines max) with file path and line numbers:

````markdown
## Problem

The rate limiter assumes `tenant_id` is always present:

```typescript
// src/middleware/rate-limit.ts:45-49
const key = `rate:${req.tenant_id}`; // null for unauthenticated requests
const count = await redis.incr(key);
```

Unauthenticated requests share a single `rate:null` key, bypassing per-tenant limits.
````

### Labels

Infer from content:

| Content signals                      | Label           |
| ------------------------------------ | --------------- |
| Bug, broken behavior, inconsistency  | `bug`           |
| New feature, new endpoint, new field | `enhancement`   |
| Auth, tokens, rate limiting          | `security`      |
| Infra, Docker, CI, backups           | `ops`           |
| Tests, coverage, assertions          | `testing`       |
| Docs, runbooks                       | `documentation` |
| Cleanup, refactor, tech debt         | `chore`         |

Apply multiple labels when appropriate. Stick to this list unless the user asks
for others.

---

## Duplicate and related issue search

Before creating any issue, search for similar ones. Extract 2-3 keywords from the
drafted title and search:

```bash
gh issue list --search "keyword1 keyword2" --state all --limit 5 \
  --json number,title,state,url
```

Then follow one of these paths:

| What you find                        | Action                                                                                                                                           |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Open issue that matches**          | Show it to the user. If confirmed as the same problem, add a comment to the existing issue with the new context instead of creating a duplicate. |
| **Closed issue that matches**        | The problem resurfaced. Create a new issue and reference the closed one: `Previously tracked in #X (closed).`                                    |
| **Related but distinct open issues** | Create the new issue and add `Related to #X, #Y` at the bottom of the body.                                                                      |
| **Nothing found**                    | Continue normally.                                                                                                                               |

### Commenting on an existing open issue

```bash
gh issue comment <number> --body "$(cat <<'EOF'
## Additional context

Discovered again while working on branch `<branch>` (PR #<number> if exists).

**Location:** `src/middleware/rate-limit.ts:47`

**Details:**
<edge case description, new information, etc.>
EOF
)"
```

After commenting, report it:

```
Added context to existing #38: fix: rate limiter bypass for unauthenticated requests
→ https://github.com/owner/repo/issues/38
```

Then offer the `TODO(#issue)` code comment (see "Link back to code" below).

---

## Link back to code

After creating an issue or commenting on one, offer to add a `TODO` comment at
the exact location in the code where the edge case was found:

```
Want me to add a TODO comment linking to this issue?
→ src/middleware/rate-limit.ts:47
```

If the user accepts, insert a comment in the appropriate language syntax:

```typescript
// TODO(#53): handle null tenant_id — bypasses rate limiting
```

```python
# TODO(#53): handle null tenant_id — bypasses rate limiting
```

This creates a two-way link: the issue references the code, the code references
the issue.

---

## Flow 1 — Issue from an edge case (primary)

This is the main use case: you're working on a task and something comes up that
should be handled separately.

### 1. Build context

You already have the context from the session — use it:

- **What**: the edge case, bug, or deferred task
- **Where**: affected files, functions, or lines
- **Why**: impact if left unaddressed
- **Origin**: what task was in progress when this surfaced

Also capture the current branch and any open PR:

```bash
git branch --show-current
gh pr view --json number,url -q '"PR #\(.number) → \(.url)"' 2>/dev/null
```

### 2. Draft the issue

Compose title, body, and labels following the rules in "Issue anatomy" above.

### 3. Search for duplicates

Follow the "Duplicate and related issue search" section. If the result is
commenting on an existing issue, skip to step 6.

### 4. Preview and confirm

Show what will be created and wait for explicit confirmation:

```
I'll create this issue in owner/repo:

  Title:  fix: handle null tenant_id in rate limiter
  Labels: bug, security

  ## Context
  Discovered while implementing the multi-tenant throttle (#42).

  ## Problem
  The rate limiter assumes tenant_id is always present, but
  unauthenticated requests have tenant_id=null, bypassing limits.

  ## Suggested approach
  Add a fallback key (IP-based) in src/middleware/rate-limit.ts:47
  when tenant_id is null.

Create this issue?
```

### 5. Create the issue

```bash
gh issue create \
  --title "fix: handle null tenant_id in rate limiter" \
  --body "$(cat <<'EOF'
...
EOF
)" \
  --label "bug" --label "security"
```

If a label doesn't exist in the repo, `gh` will error. Retry without that label
and tell the user which one was skipped.

After creation, offer optional metadata if the repo uses them:

- **Assignee**: "Want me to assign this to you?" (`gh issue edit <number> --add-assignee @me`)
- **Milestone**: if milestones exist (`gh api repos/{owner}/{repo}/milestones`), offer to attach one
- **Project**: if the user mentions a project board, use `gh issue edit <number> --add-project "Project Name"`

These are opt-in — don't add them silently, and don't ask about all three every time.
Offer only when contextually relevant (e.g., suggest assignee for the user's own TODOs,
suggest milestone if the user mentioned a release target).

### 6. Report

Report the result, then offer the code link (see "Link back to code").

```
Created #53: fix: handle null tenant_id in rate limiter
→ https://github.com/owner/repo/issues/53
```

---

## Flow 2 — Issues from a TODO file (secondary)

When the user asks to process a TODO file, or you detect one during exploration.

### 1. Find the file

Look in the repo root for common names: `TODO.md`, `TODO.txt`, `TODO`.
If not found and the user asked for it, ask where their TODO file is.

### 2. Parse and group items

Support common formats:

- Markdown checkboxes: `- [ ] task` (ignore checked `- [x]`)
- Plain list items: `- task` or `* task`
- Numbered lists: `1. task`

For each item, compose title, body, and labels following "Issue anatomy".

**Grouping**: if multiple items clearly belong to the same atomic change (same
file, same feature, would ship in one PR), group them into a single issue with
GitHub task lists in the body:

```markdown
## Tasks

- [ ] Validate email format on registration endpoint
- [ ] Add email format validation to profile update endpoint
- [ ] Add shared email validator utility
```

This lets the assignee track progress per sub-item, and GitHub shows a progress
bar on the issue card. Tell the user about any grouping before proceeding.

### 3. Search and preview

For each item, run the duplicate search (see "Duplicate and related issue search").
Then show a single combined preview with the results:

```
I'll process 4 items from TODO.md in owner/repo:

#  Title                                         Labels         Action
─  ────────────────────────────────────────────  ─────────────  ──────────────
1  fix: validate email format on signup          bug            create
2  feat: add CSV export to reports               enhancement    create
3  chore: remove deprecated v1 endpoints         chore          → comment #28
4  test: add integration tests for payment flow  testing        create (rel #31)

→ 3 new issues will be created
→ 1 comment will be added to #28

Proceed?
```

Wait for confirmation.

### 4. Execute

Create issues and add comments one at a time to avoid rate limits:

```bash
gh issue create --title "..." --body "..." --label "..."
gh issue comment 28 --body "..."
```

### 5. Summary

```
Processed 4 items from TODO.md:

  #12  fix: validate email format on signup          → .../issues/12  (created)
  #13  feat: add CSV export to reports               → .../issues/13  (created)
  #28  chore: remove deprecated v1 endpoints         → .../issues/28  (commented)
  #14  test: add integration tests for payment flow  → .../issues/14  (created, rel #31)
```

---

## Error handling

| Error                      | Action                             |
| -------------------------- | ---------------------------------- |
| `gh` not installed         | Tell the user to install it        |
| Not authenticated          | Ask user to run `gh auth login`    |
| Repo not found / no remote | Confirm `owner/repo` with the user |
| Label doesn't exist        | Retry without it, tell the user    |
| Network failure            | Report and stop                    |

When creating multiple issues, if one fails, report which succeeded and which
failed before stopping.

---

## Scope

This skill creates issues and adds comments — nothing else. It does not:

- Push code or create PRs
- Modify the TODO file after processing (the user decides what to do with it)
