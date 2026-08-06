---
name: tech-radar-context
description: Discover and inject Tikal Israeli Tech Radar context — adoption ring, quadrant, and Tikal's opinion — for any technology, framework, database, library, or cloud tool implied by the current prompt. Model-invoked whenever a tech stack choice is being made or evaluated, similar to team-discover but scoped to the Tikal Tech Radar.
---

# tech-radar-context

## Overview

Surface **Tikal's opinion** on the technologies relevant to the current prompt so
a tech stack choice is informed by the Israeli Tech Radar. This skill works like
`team-discover`, but its search surface is the Tikal Tech Radar dataset
(`radar.json`) instead of the team CDR index: it extracts candidate technologies
from the prompt, matches them against radar **blips**, and injects a compact
**Tech Radar Context** table (ring, quadrant, Tikal's "Why?" opinion) plus
Tikal-aligned alternatives for anything on `Stop`.

The radar has four **quadrants** — `DevOps`, `Backend`, `AI/ML`, `Web/Mobile` —
and four adoption **rings**:

| Ring | Meaning | Guidance |
|------|---------|----------|
| `Try` | New stuff that on the surface seems good (good press, new solution) | Explore / evaluate; not yet endorsed for production use |
| `Start` | A good solution more companies should use; if in beta, active progress and contribution | Recommend adopting on new projects |
| `Keep` | Stable release (non-beta) with major supporter acceptance (large community, used by corporates) | Recommend by default for current & new work |
| `Stop` | Items we recommend companies stop using — better alternatives exist | Warn against; recommend a `Keep`/`Start` alternative |

Each blip's `description` embeds an HTML `<p>Why?</p>` block followed by a
`<p>Description</p>` block. The **Why?** text carries Tikal's explicit stance and
rationale — that is the opinion to surface. A technology may appear more than
once (different quadrants) with different rings; report each relevant placement.

## When to Use

Model-invoke this skill whenever the prompt involves **choosing or evaluating
technology**, for example:

- Selecting a framework, library, database, message broker, or cloud tool.
- Comparing options ("X vs Y", "should we use Z").
- Designing a system, service, or pipeline where stack decisions are implied.
- Reviewing an existing stack for modernization or replacement.

Do **not** invoke it for pure business/product questions with no technology
selection, or when the user explicitly says to ignore the radar.

Manual invocation:
```
/tech-radar-context               # inject radar context for the current prompt
/tech-radar-context redis vs kafka
```

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

### Step 2: Load and Query the Radar Dataset

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

The script handles alias mapping (`k8s` → `Kubernetes`, `postgres` → `PostgreSQL`, `gh actions` → `GitHub Actions`, etc.), matches against `resources/radar.json`, extracts Tikal's `<p>Why?</p>` opinion, and formats the markdown table automatically.

If a technology appears in multiple placements with conflicting rings (e.g.,
`Node.js` is both `DevOps: Stop` and `DevOps: Keep`), the script detects and
flags it with a **Conflicting Guidance** note.

**Schema of `resources/radar.json`**:
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

### Step 6: Inject Tech Radar Context (Output Contract)

Emit a **Tikal Tech Radar Context** section in the visible response, before the
task answer, so downstream reasoning is grounded in the radar:

```markdown
## Tikal Tech Radar Context

| Technology | Quadrant | Ring | Tikal's Opinion (Why?) |
|------------|----------|------|------------------------|
| FastAPI | Backend | Keep | Better alternative to Flask; async, fast, big and growing community. |
| Jenkins | Backend | Stop | Plugin hell + XML config; legacy vs GitHub Actions / GitLab CI / Tekton. |

**Radar guidance**
- ✅ Keep/Start: FastAPI — safe to adopt.
- ⚠️ Stop: Jenkins → consider GitHub Actions, GitLab CI, or Tekton (see Why? above).

_Source: Tikal Israeli Tech Radar (local snapshot) · N technologies matched._
```

- One row per matched blip (include duplicates across quadrants when relevant).
- Group a short **Radar guidance** list: safe-to-adopt vs avoid-with-alternatives.
- Add a `_Source_` line noting the data came from the **local snapshot** and
  how many technologies matched.

If no candidate technology matches any blip, state that plainly with an empty
table and a `_Source_` line (e.g. `_Source: … · 0 technologies matched._`) —
do not fabricate radar placements.

## Failure Handling

- Local `resources/radar.json` missing/unparseable → emit an empty context
  table noting the radar was unavailable, and continue; never block the
  user's task.
- No matches → empty table + `0 technologies matched` line.

## Red Flags

- Fabricating a ring, quadrant, or "Why?" opinion for a technology that is not
  in the loaded dataset — report `0 matches` instead.
- Blocking on the live fetch instead of falling through to the local snapshot.
- Hardcoding `Stop`→alternative substitutions not backed by the loaded radar.
- Reporting the neutral `<p>Description</p>` text as Tikal's opinion — the
  opinion lives in the `<p>Why?</p>` block.
- Ignoring duplicate blips: the same technology can sit in different quadrants
  with different rings; surface each relevant placement.
- Treating the skill load as the work — the Core Process must actually run and
  produce the Tech Radar Context table.

## Verification

- Candidate technologies were extracted from the prompt (or category queries
  formed when no product was named).
- The radar dataset was loaded from `resources/radar.json`.
- A **Tikal Tech Radar Context** table was produced with columns Technology /
  Quadrant / Ring / Tikal's Opinion (Why?), with the opinion sourced from the
  `<p>Why?</p>` block.
- `Stop`-ring matches include Tikal-aligned `Keep`/`Start` alternatives from the
  same quadrant, derived from the dataset.
- A `_Source_` line reports live-vs-snapshot and the match count; a no-match run
  yields an empty table plus `0 technologies matched` rather than fabricated data.

## Configuration

- Local source: `resources/radar.json` (bundled full radar snapshot; the only source the search script uses).
- Canonical source: `https://www.tikalk.com/radar/` (for periodic manual snapshot regeneration; not fetched by the script at runtime).
- Regenerate the snapshot periodically from the canonical Tikal radar dataset to
  stay current.
