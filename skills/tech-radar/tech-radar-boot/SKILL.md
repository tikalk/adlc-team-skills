---
name: tech-radar-boot
description: Use when choosing or evaluating a technology (framework, database, library, cloud tool) — injects Tikal Israeli Tech Radar context (adoption ring, quadrant, opinion, Keep/Start alternatives for Stop items) and pairs the selection with ADR capture via /architect-specify; invoked from team-boot's Class Boots catalog (formerly tech-radar-context).
---

# tech-radar-boot

## Overview

One of the five **class boots** surfaced by `team-boot`'s Class Boots
catalog, this skill handles **technology selection**. It surfaces
**Tikal's opinion** on the technologies relevant to the current prompt so a
tech stack choice is informed by the Israeli Tech Radar, and it pairs the
selection with decision capture: the chosen stack is an ADR-class decision
that should be recorded via `/architect-specify`.

The radar lookup works like `team-discover`, but its search surface is the
Tikal Tech Radar dataset (fetched live from `https://tikalk.com/radar.json`)
instead of the team CDR index: it extracts candidate technologies from the
prompt, matches them against radar **blips**, and injects a compact
**Tech Radar Context** table (ring, quadrant, Tikal's "Why?" opinion) plus
Tikal-aligned alternatives for anything on `Stop`.

The radar has four **quadrants** — `DevOps`, `Backend`, `AI/ML`,
`Web/Mobile` — and four adoption **rings**:

| Ring | Meaning | Guidance |
|------|---------|----------|
| `Try` | New stuff that on the surface seems good (good press, new solution) | Explore / evaluate; not yet endorsed for production use |
| `Start` | A good solution more companies should use; if in beta, active progress and contribution | Recommend adopting on new projects |
| `Keep` | Stable release (non-beta) with major supporter acceptance (large community, used by corporates) | Recommend by default for current & new work |
| `Stop` | Items we recommend companies stop using — better alternatives exist | Warn against; recommend a `Keep`/`Start` alternative |

Each blip's `description` embeds an HTML `<p>Why?</p>` block followed by a
`<p>Description</p>` block. The **Why?** text carries Tikal's explicit stance
and rationale — that is the opinion to surface. A technology may appear more
than once (different quadrants) with different rings; report each relevant
placement.

## When to Use

Model-invoke this skill whenever the prompt involves **choosing or
evaluating technology**, for example:

- Selecting a framework, library, database, message broker, or cloud tool.
- Comparing options ("X vs Y", "should we use Z").
- Designing a system, service, or pipeline where stack decisions are implied.
- Reviewing an existing stack for modernization or replacement.
- A tech stack choice emerges mid-session (the ADR detection trigger).

Do **not** invoke it for pure business/product questions with no technology
selection, or when the user explicitly says to ignore the radar.

Invoke at the START of a matching task — before planning the todo list and
before implementation — so the radar context informs planning.
Never defer to session end.

Manual invocation:
```
/tech-radar-boot               # inject radar context for the current prompt
/tech-radar-boot redis vs kafka
```

(`/tech-radar-context` still works as a deprecated alias for this skill.)

## Core Process

### Step 1: Extract Candidate Technologies

From the current prompt (or the description provided by an invoking skill),
extract every named or clearly implied technology: languages, frameworks,
libraries, databases, brokers, CI/CD tools, cloud services, AI/LLM tooling,
build tools, etc. Normalize obvious aliases (e.g. "postgres" → "PostgreSQL",
"k8s" → "Kubernetes", "GH Actions" → "GitHub Actions").

If the prompt implies a category without naming a product (e.g. "we need a
vector database", "pick a Python web framework"), treat the category as a query
and surface the radar's recommended options in that space.

### Step 2: Query the Live Radar Dataset

Execute the deterministic search helper script (relative to this skill directory):

POSIX (bash + jq):
```bash
bash scripts/radar-search.sh <tech1> [tech2 ...]
```

Windows (PowerShell):
```powershell
pwsh scripts/radar-search.ps1 <tech1> [tech2 ...]
```

Or for JSON output (add `--json` for bash, `-Json` for PowerShell).

The script fetches the radar JSON fresh from `https://tikalk.com/radar.json`,
handles alias mapping (`k8s` → `Kubernetes`, `postgres` → `PostgreSQL`, `gh actions` → `GitHub Actions`, etc.), extracts Tikal's `<p>Why?</p>` opinion, and formats the markdown table automatically.

If a technology appears in multiple placements with conflicting rings (e.g.,
`Node.js` is both `DevOps: Stop` and `DevOps: Keep`), the script detects and
flags it with a **Conflicting Guidance** note.

**Schema of the live radar JSON** (`https://tikalk.com/radar.json`):
```json
{
  "title": "Explore the Tech Radar",
  "quadrants": ["DevOps", "Backend", "AI/ML", "Web/Mobile"],
  "rings": ["Try", "Start", "Keep", "Stop"],
  "blips": [
    {
      "name": "FastAPI",
      "quadrant": "Backend",
      "ring": "Keep",
      "description": "<p>Why?</p>\n<p>...Tikal's opinion...</p>\n<p>Description</p>\n<p>...</p>",
      "isNew": false
    }
  ]
}
```

### Step 3: Match Blips

For each candidate from Step 1, find matching blips by `name` (case-insensitive,
alias-aware, allowing minor version suffixes like "Airflow 2" / "Airflow 3" and
partial matches like "Redux" → "Redux Toolkit"). A candidate may match multiple
blips across quadrants — keep them all.

For category queries (Step 1), select the strongest radar recommendations in
that space: prefer `Keep`/`Start` blips in the matching quadrant, and note any
`Stop` blips as things to avoid.

### Step 4: Extract Tikal's Opinion

For every matched blip, parse the `description` HTML:

- The text inside the `<p>Why?</p>` block (up to the next `<p>Description</p>`)
  is **Tikal's opinion / rationale** — the primary signal.
- The `<p>Description</p>` block is neutral background — use only if helpful.

Strip HTML tags to plain text and condense the "Why?" to one or two sentences
for the context table (quote it more fully when the ring is `Stop` or when the
user is directly weighing that technology).

### Step 5: Recommend Alternatives for `Stop`

When a candidate matches a `Stop` blip (or is a legacy technology the radar
clearly discourages), select Tikal-aligned replacements from the **same
quadrant** on `Keep` or `Start`, guided by the "Why?" text. Common examples the
dataset supports:

- Airflow 2 → Airflow 3 / Dagster
- Create React App → Vite / Next.js
- Jenkins → GitHub Actions / GitLab CI / Tekton
- requirements.txt / Poetry → uv
- Moment.js / Luxon → day.js / date-fns
- Redux / Redux Toolkit → Zustand / TanStack Query
- Ant Design / Styled Components → Tailwind CSS / shadcn/ui / Radix UI

Do not hardcode substitutions beyond what the loaded dataset supports — derive
alternatives from the radar's actual `Keep`/`Start` blips in that quadrant.

## Absent Context

If `team-boot` injected no team context this session (no Team Context & Decisions section in the first user message — unconfigured project or hook failure): say so in one line, emit the section heading with a `0 radar technologies matched (no team context injected — run /team-setup)` source line, and continue the task on the live radar lookup. Never treat a missing injection as an empty record set. Recovery: run `/team-diagnose`.

### Step 6: Inject Tech Radar Context (Output Contract)

The script's stdout goes to the tool channel — invisible to the user. ALWAYS
re-emit the full Tikal Tech Radar Context section in your visible response,
before the task answer (or, when 0 matched, the heading + `_Source:` line).
Emit it as markdown blocks — heading, table rows, guidance bullets, and source
line each on their own lines; never collapse the section into a single line.

```markdown
## Tikal Tech Radar Context

| Technology | Quadrant | Ring | Tikal's Opinion (Why?) |
|------------|----------|------|------------------------|
| FastAPI | Backend | Keep | Better alternative to Flask; async, fast, big and growing community. |
| Jenkins | Backend | Stop | Plugin hell + XML config; legacy vs GitHub Actions / GitLab CI / Tekton. |

**Radar guidance**
- ✅ Keep/Start: FastAPI — safe to adopt.
- ⚠️ Stop: Jenkins → consider GitHub Actions, GitLab CI, or Tekton (see Why? above).

_Source: Tikal Israeli Tech Radar (live: https://tikalk.com/radar.json) · N technologies matched._

_Searched N blips, K matched._
```

- One row per matched blip (include duplicates across quadrants when relevant).
- Group a short **Radar guidance** list: safe-to-adopt vs avoid-with-alternatives.
- Add a `_Source_` line noting the data came from the **live radar source** and
  how many technologies matched.
- `N` = blips scanned in the loaded dataset; `K` = rows shown in the table.
  **K MUST equal the table rows shown.** 0 rows matched → emit the section
  heading + the `_Source:` line only — no table. A 0-row table header collapses
  into unrendered single-line markdown; never emit one.

If no candidate technology matches any blip, state that plainly with the heading
+ `_Source:` line (e.g. `_Source: … · 0 technologies matched._`) — no table —
do not fabricate radar placements.

### Step 7: Capture the Selection (Decision Pairing)

A technology selection is an **ADR-class decision**. When no local memory index
exists in the current working directory and the directory sits inside a workspace
(detected via a `.gitmodules` marker in an ancestor), read the workspace root's
`docs/adlc/memory/` index instead (ADR-401 dual-read order applies:
`docs/adlc/memory` first, legacy `.adlc/memory` fallback).

| Trigger | Action |
|---------|--------|
| Tech stack chosen ("we'll use X") | ADR → suggest `/architect-specify`, citing the radar rows that informed it |
| "X vs Y" comparison resolved | ADR → suggest `/architect-specify` with the comparison outcome |
| `Stop`-ring technology retained anyway | ADR → suggest `/architect-specify` documenting why the radar guidance was overridden |

Add/refresh rows in **Team Context & Decisions** (ID | Name | Type | Rel |
Status | Clarify) for the selection, mirrored as a task-list todo (draft →
`/architect-specify` at session end); after code-modifying tasks, add a
trailing todo to sweep Team Context & Decisions until _Unrecorded: 0 pending · Unclarified: 0 drafts_ (a draft leaves Unclarified only via its clarify skill or an explicit user handoff to a named clarify or execute skill). If
`architect-boot` was already invoked this session, extend its ledger rows
with the radar evidence; at session end, deliver the clarify prompt naming
each captured tech-selection draft (ID + skill); if the user defers clarify,
mark those rows handed off.

## Failure Handling

- Live fetch fails (network error, timeout, invalid JSON) → the script exits
  non-zero with a clear error message to stderr. The skill must emit an empty
  context table noting the Tech Radar source was unreachable and continue the
  user's task without radar context — never substitute stale cached or
  bundled data as if it were current.
- No matches → heading + `0 technologies matched` source line only — no table.

## Red Flags

- Fabricating a ring, quadrant, or "Why?" opinion for a technology that is not
  in the loaded dataset — report `0 matches` instead.
- Silently substituting cached, bundled, or stale radar data when the live
  fetch fails — always report when the radar source is unreachable, never
  present old data as current.
- Hardcoding `Stop`→alternative substitutions not backed by the loaded radar.
- Reporting the neutral `<p>Description</p>` text as Tikal's opinion — the
  opinion lives in the `<p>Why?</p>` block.
- Ignoring duplicate blips: the same technology can sit in different quadrants
  with different rings; surface each relevant placement.
- Treating the skill load as the work — the Core Process must actually run and
  produce the Tech Radar Context table.
- Reading radar findings via the script and answering without re-emitting the
  context section (script stdout goes to the tool channel — invisible to the
  user) — the visible response MUST carry the findings.
- Collapsing the context section into a single line — heading, table rows,
  guidance, and source line each go on their own markdown lines.
- Injecting radar context but skipping the capture pairing — a tech selection
  that informed no ADR is a decision that evaporated.

## Verification

- Candidate technologies were extracted from the prompt (or category queries
  formed when no product was named).
- The radar dataset was fetched live from `https://tikalk.com/radar.json`.
- A **Tikal Tech Radar Context** table was produced with columns Technology /
  Quadrant / Ring / Tikal's Opinion (Why?), with the opinion sourced from the
  `<p>Why?</p>` block.
- `Stop`-ring matches include Tikal-aligned `Keep`/`Start` alternatives from the
  same quadrant, derived from the dataset.
- A `_Source_` line reports the live-radar source and the match count; a no-match
  run yields no table (heading + source line only) rather than fabricated
  data. On fetch failure, an error is reported and the skill continues without
  radar context.
- Tech selections made this session appear in Team Context & Decisions with
  `/architect-specify` as the capture skill.
## Configuration

- Data source: `https://tikalk.com/radar.json` (live-fetched on every invocation;
  no bundled snapshot or cache).
- Fetch timeout: 10 seconds. On fetch failure, the skill continues without radar
  context rather than blocking or substituting stale data.
