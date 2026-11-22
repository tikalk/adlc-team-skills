<!-- SYNC NOTE: Mirror of skills/authoring/references/ste-rules.md for flat-install resolution (only sibling skill directories ship). Do not edit directly; update the canonical file and re-copy. Collapses when adlc-workspace#34 lands. -->

# Simplified Technical English (STE) & Complex-Decision Map Contract

This shared reference defines the writing rules and decision-map schemas for clarification points across all clarification skills (`product-clarify`, `architect-clarify`, `change-clarify`, `evals-clarify`).

---

## 1. Simplified Technical English (STE) Rules

Every clarification point must follow these core writing principles distilled from ASD-STE100:

1. **Short Sentences**: Keep sentences $\le 20$ words.
2. **One Idea Per Sentence**: Express one thought, condition, or requirement per sentence.
3. **Active Voice**: The actor must precede the action. Avoid passive constructions.
4. **Imperative for the Ask**: When asking the human a question or requesting action, use direct imperative commands (e.g., "Choose an option", "Define the missing boundary").
5. **Named Referents**: Never use bare pronouns (`it`, `they`, `this`, `that`). Always repeat the specific noun (e.g., "the PDR", "the worker process", "the timeout").
6. **Plain Words**: Choose simple, direct, unambiguous words. Avoid idioms, jargon, and vague qualifiers. No licensed dictionary is enforced; focus on clarity and brevity.
7. **Present-Tense Verbs Only**: Use the present-tense verb form. Do not use gerunds (`-ing` forms) as verbs. Write "the worker writes the file", never "the worker is writing the file".
8. **One Command Per Sentence**: Give one instruction per sentence. Split compound commands into separate sentences.
9. **Approved words**: Use plain English words with one clear sense. No project dictionary file exists. Check each content word. Flag jargon inline. Replace the flagged word with a plain word.
10. **Short Noun Clusters**: Limit noun clusters to 3 words maximum. Expand longer clusters with prepositions (write "map of the decision", never "decision map rendering pipeline output").
11. **No Hedging in Maps**: Never write "maybe", "possibly", "TBD", or "to be determined" inside a map. Render the unknown slot as an explicit `?` instead.

### STE-Lite Subset (for Context Injections and Boots)
For session boots and context injections where tokens are constrained:
- Sentence length $\le 15$ words.
- Tables over paragraphs.
- Zero filler words.
- Subject-verb-object structure strictly enforced.

---

## 2. ASCII-first clarification tier rule

Every clarification renders its ASCII visual by default. Plain STE prose is the detail layer beneath the visual, never the only view. Classify the visual strictly by consequence scope, **not** by severity:

- **Complex Tier ($\ge 2$ Boundaries Crossed)**:
  Draw the full ASCII decision map. Invoke `skills/authoring/scripts/bash/render-decision-map.sh` (bash) or `skills/authoring/scripts/powershell/render-decision-map.ps1` (Windows) — `render_decision_map(...) -> str`. Never hand-draw the map.
- **Simple Tier (0 or 1 Boundary Crossed)**:
  Draw the compact 3-line ASCII status box via `render_status_box(...) -> str`, with plain STE prose beneath it. Never render prose alone, regardless of whether the gap is marked CRITICAL or HIGH. Severity determines presentation order; severity **never** upgrades a single-boundary item to a decision map.

Box width budget: every output line stays within 75 columns. Truncate long fields with `…` rather than break the border. A map that would exceed gate payload size caps renders its prose fallback plus `payload_status: map-omitted (size cap)`.

### The Four Boundaries

| Boundary | Definition | Example |
|----------|------------|---------|
| `record` | Affects other decision records, schemas, or memory indexes beyond the active file. | Modifies ADR frontmatter schema or PDR dependency chain. |
| `lane` | Crosses between functional execution lanes (e.g., product $\leftrightarrow$ architecture, verify $\leftrightarrow$ deploy). | Product requirement forces architectural pattern change. |
| `team` | Impacts team AI directives, shared constitution, or cross-repo developer workflows. | Amends team constitution or alters git commit conventions. |
| `now` | Introduces an immediate migration, breaking change, flag day, or irrecoverable state. | Drops command shims without aliases or removes active DB table. |

---

## 3. Decision Map Schema & Anatomy (for $\ge 2$ Boundaries)

When a clarification point crosses two or more boundaries, render the structured ASCII decision map below.

### Anatomy Checklist
1. **WHAT / WHY**: One-line STE problem statement and business/technical driver.
2. **Boundaries Crossed**: Explicit list of crossed boundaries (`record`, `lane`, `team`, `now`).
3. **Reach Fan-Out**: Visual ASCII box showing which boundary dimensions are touched.
4. **Options Matrix**: Candidates $\times$ discriminating axes.
5. **IF-UNDECIDED**: Explicit consequence if the human skips or defers the decision.
6. **Undrawn Slots (`?`)**: Any missing context, unstated trade-off, or unknown consequence must render as an undrawn slot (`?`), **never** as a prose complaint or conversational apology.

### Map Anatomy Template

```text
+-------------------------------------------------------------------------+
| DECISION MAP: [ID] - [Title]                                            |
| WHAT / WHY: [One STE sentence stating the issue and the reason]        |
| BOUNDARIES CROSSED: [List 2 or more: record | lane | team | now]        |
+-------------------------------------------------------------------------+
| REACH FAN-OUT:                                                          |
|   +-[record]  --> [Touched record/index or '?']                         |
|   +-[lane]    --> [Touched lane or '?']                                 |
|   +-[team]    --> [Touched team convention or '?']                      |
|   +-[now]     --> [Immediate breaking consequence or '?']               |
+-------------------------------------------------------------------------+
| CANDIDATES & TRADEOFFS:                                                 |
|                                                                         |
| Option A: [Title]                                                       |
|   + Pro: [STE pro]                                                      |
|   - Con: [STE con]                                                      |
|   * Cross-boundary impact: [Impact or '?']                              |
|                                                                         |
| Option B: [Title]                                                       |
|   + Pro: [STE pro]                                                      |
|   - Con: [STE con]                                                      |
|   * Cross-boundary impact: [Impact or '?']                              |
|                                                                         |
| [?] Missing Alternative: [Undrawn candidate slot if trade-offs incomplete]|
+-------------------------------------------------------------------------+
| IF-UNDECIDED: [Consequence if decision deferred; defaults to halt/safe] |
+-------------------------------------------------------------------------+
```

---

## 4. Plain STE Format (for 0 or 1 Boundary)

When a gap touches zero or one boundary (e.g., local file formatting, missing success metric in a single PDR, local phrasing), draw the compact status box first, then the prose beneath it:

```text
+---------------------------------------------------------------------------+
| CLARIFICATION: [ID] - [Gap Type]                                          |
+---------------------------------------------------------------------------+
| Context: [One STE sentence quoting the item]                              |
| Gap: [One STE sentence stating the missing element]                       |
| Ask: [One direct imperative STE question]                                 |
+---------------------------------------------------------------------------+
```

```markdown
## Clarification [N]: [ID] - [Gap Type]

**Context**: [One STE sentence quoting or identifying the item]
**Gap**: [One STE sentence describing the missing element]
**Question**: [One direct imperative STE question]
**Suggested Options**:
- **A**: [Option text]
- **B**: [Option text]
- **C**: [Custom response]
```
Do not draw a full decision map for 0 or 1 boundary, even if the gap is CRITICAL. Never render prose without the status box above it.
