# CLAUDE.md Update Guidelines

## Core Principle

Only add information that will genuinely help future Claude sessions. The context window is precious — every line must earn its place.

**The litmus test:** "Would Claude make mistakes without this instruction?" If the answer is no, the line is wasting context.

## What TO Add

### 1. Commands/Workflows Discovered

```markdown
## Build

`npm run build:prod` - Full production build with optimization
`npm run build:dev` - Fast dev build (no minification)
```

Why: Saves future sessions from discovering these again.

### 2. Gotchas and Non-Obvious Patterns

```markdown
## Gotchas

- Tests must run sequentially (`--runInBand`) due to shared DB state
- `yarn.lock` is authoritative; delete `node_modules` if deps mismatch
```

Why: Prevents repeating debugging sessions.

### 3. Package Relationships

```markdown
## Dependencies

The `auth` module depends on `crypto` being initialized first.
Import order matters in `src/bootstrap.ts`.
```

Why: Architecture knowledge that isn't obvious from code.

### 4. Testing Approaches That Worked

```markdown
## Testing

For API endpoints: Use `supertest` with the test helper in `tests/setup.ts`
Mocking: Factory functions in `tests/factories/` (not inline mocks)
```

Why: Establishes patterns that work.

### 5. Configuration Quirks

```markdown
## Config

- `NEXT_PUBLIC_*` vars must be set at build time, not runtime
- Redis connection requires `?family=0` suffix for IPv6
```

Why: Environment-specific knowledge.

## What NOT to Add

### 1. Obvious Code Info

Bad:

```markdown
The `UserService` class handles user operations.
```

The class name already tells us this.

### 2. Generic Best Practices

Bad:

```markdown
Always write tests for new features.
Use meaningful variable names.
```

This is universal advice, not project-specific.

### 3. One-Off Fixes

Bad:

```markdown
We fixed a bug in commit abc123 where the login button didn't work.
```

Won't recur; clutters the file.

### 4. Verbose Explanations

Bad:

```markdown
The authentication system uses JWT tokens. JWT (JSON Web Tokens) are
an open standard (RFC 7519) that defines a compact and self-contained
way for securely transmitting information between parties as a JSON
object. In our implementation, we use the HS256 algorithm which...
```

Good:

```markdown
Auth: JWT with HS256, tokens in `Authorization: Bearer <token>` header.
```

## Anti-Patterns to Flag

When auditing a CLAUDE.md, flag these common mistakes:

### 1. The Kitchen Sink

Including everything about the project — architecture deep-dives, full API docs, coding tutorials.

**Fix:** Keep under 200 lines. Move detail to skills, `@imports`, or `.claude/rules/`.

### 2. Over-Specification

Too many rules, some contradicting each other. Claude gets confused and follows none consistently.

**Fix:** Ruthlessly prune. If Claude does it right without the instruction, delete it.

### 3. Task-Specific Guidance

Instructions that only apply to certain kinds of work ("when building a dashboard, always use Chart.js").

**Fix:** Move to skills that load on-demand, not CLAUDE.md that loads every session.

### 4. CLAUDE.md as a Linter

Style rules like "use 2-space indentation" or "always use semicolons" that a linter should enforce.

**Fix:** Configure ESLint/Prettier/Black/etc. and let deterministic tools handle formatting. Claude can run the linter but shouldn't be the linter.

### 5. Stale Code Snippets

Copy-pasted code examples that drift from the actual implementation over time.

**Fix:** Use `file:line` references instead of embedding code: "See `src/lib/auth.ts:45` for the token validation pattern." The reference stays current even as the code evolves.

## When to Suggest Modern Features

During updates, consider recommending:

- **`.claude/rules/`** — when CLAUDE.md exceeds ~200 lines and covers multiple domains
- **`@imports`** — when CLAUDE.md duplicates content from README, contributing guides, or other docs
- **Path-specific rules** — when some instructions only apply to specific file types or directories
- **Hooks** — when an instruction says "always do X" and failure to do it would be catastrophic
- **Skills** — when an instruction describes a complex, infrequent workflow

See [modern-features.md](modern-features.md) for details on each feature.

## Diff Format for Updates

For each suggested change:

### 1. Identify the File

```
File: ./CLAUDE.md
Section: Commands (new section after ## Architecture)
```

### 2. Show the Change

```diff
 ## Architecture
 ...

+## Commands
+
+| Command | Purpose |
+|---------|---------|
+| `npm run dev` | Dev server with HMR |
+| `npm run build` | Production build |
+| `npm test` | Run test suite |
```

### 3. Explain Why

> **Why this helps:** The build commands weren't documented, causing
> confusion about how to run the project. This saves future sessions
> from needing to inspect `package.json`.

## Validation Checklist

Before finalizing an update, verify:

- [ ] Each addition is project-specific (not generic advice)
- [ ] No generic advice or obvious info
- [ ] Commands are tested and work
- [ ] File paths are accurate
- [ ] Would a new Claude session find this helpful?
- [ ] Is this the most concise way to express the info?
- [ ] Total CLAUDE.md stays under 200 lines (300 max)
- [ ] No stale code snippets (use `file:line` references instead)
- [ ] No instructions a linter should handle
