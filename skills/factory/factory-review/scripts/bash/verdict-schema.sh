#!/usr/bin/env bash
# verdict-schema.sh — build and check a factory-review verdict against one
# schema (SF-SKILL-02). PowerShell twin: ../powershell/verdict-schema.ps1.
#
# Why: live verdicts drifted. Lane runs typed invented run ids into the
# marker (run=local, run=mr-1335, run=factory-review-1332,
# run=mission-1517-manual) although the lane passes the real one in
# WORKFLOW_INPUTS; !1321 said findings=0 with nits=1; headings changed per
# run; interactive wording ("nothing posted yet", "not yet posted (needs your
# confirm)") leaked into posted verdicts. The marker is now generated, never
# typed, and post-verdict lints every body before it is sent.
#
# Usage:
#   verdict-schema marker --iter <k> --important <n> --nits <n> --head <sha40> [--status completed|failed]
#       prints the ONE canonical marker line. run= is resolved, never passed:
#       ADLC_RUN_ID, else the lane's WORKFLOW_INPUTS.run_id, else
#       "interactive" (a local session). outcome= and findings= are derived:
#       merge-ready exactly when status=completed and important=0.
#   verdict-schema lint <body-file>
#       exit 0 = the body follows the schema; 1 = it does not (one
#       "verdict-schema: <rule>: <problem>" line per violation); 2 = usage.
#   verdict-schema run-id
#       prints the run id a marker would carry.
#
# The schema (lint enforces every line):
#   1. The first non-blank line is the only `<!-- factory-review:step=review … -->` marker.
#   2. Marker tokens, in this order, nothing else:
#      step=review run=<id> iter=<k> status=<completed|failed>
#      outcome=<merge-ready|not-merge-ready> findings=<n> important=<n> nits=<n> head=<sha40>
#   3. findings = important + nits; outcome=merge-ready exactly when
#      status=completed and important=0; head= is lowercase.
#   4. run= equals the resolved run id (see marker).
#   5. Exactly one `## Verdict`, `## Important findings` and `## Nits`, in that
#      order. `## Verdict` holds `**Outcome:** <the marker's outcome>`. Each
#      finding is one `### ` heading under its section, so their counts equal
#      important= and nits=; a heading inside a finding uses `#### `; an empty
#      section says `None.`. Project sections (other `## ` headings) may sit
#      before, between or after them.
#   6. No interactive hand-off wording ("nothing posted yet", "not yet
#      posted", "needs your confirm", "post all … comments", "proposed
#      comments"): in a factory run nobody answers. Only the reviewer's own
#      words are checked: text inside a fenced code block, a block quote or a
#      code span is a quotation (a review of a skill file cites such lines)
#      and passes (SF-FIX-11).
#
# node runs the checks: the same script text is embedded in both twins.
set -uo pipefail

die() { echo "verdict-schema: $*" >&2; exit 2; }
command -v node >/dev/null 2>&1 || die "node is required"
case "${1:-}" in
  marker|lint|run-id) ;;
  *) die "usage: verdict-schema.sh marker --iter <k> --important <n> --nits <n> --head <sha40> [--status completed|failed] | lint <body-file> | run-id" ;;
esac

VERDICT_JS='
const fs = require("fs");
const SAFE = /^[A-Za-z0-9][A-Za-z0-9._-]*$/;
const ORDER = ["step", "run", "iter", "status", "outcome", "findings", "important", "nits", "head"];
const die = msg => { process.stderr.write("verdict-schema: " + msg + "\n"); process.exit(2); };
// The run id: ADLC_RUN_ID, else the lane WORKFLOW_INPUTS.run_id (not the
// chart placeholder "pending"), else "interactive" (a local session, as in
// commit-step Run-Id). Same order as factory-runbook run-context.sh; vendored
// because a skill never sources another skill script.
const runId = () => {
  const a = process.env.ADLC_RUN_ID || "";
  if (a && SAFE.test(a)) return a;
  let v = "";
  try {
    const o = JSON.parse(process.env.WORKFLOW_INPUTS || "");
    if (o && typeof o === "object" && !Array.isArray(o) && typeof o.run_id === "string") v = o.run_id;
  } catch (e) { v = ""; }
  return v && v !== "pending" && SAFE.test(v) ? v : "interactive";
};
const outcomeFor = (status, important) => (status === "completed" && important === 0 ? "merge-ready" : "not-merge-ready");
const [cmd, ...rest] = process.argv.slice(1);
if (cmd === "run-id") {
  if (rest.length) die("usage: verdict-schema run-id");
  console.log(runId());
} else if (cmd === "marker") {
  const opt = { status: "completed" };
  const known = ["--iter", "--important", "--nits", "--head", "--status"];
  for (let i = 0; i < rest.length; i += 2) {
    if (!known.includes(rest[i])) die(`unknown argument ${JSON.stringify(rest[i])}`);
    if (rest[i + 1] === undefined || rest[i + 1] === "") die(`${rest[i]} requires a value`);
    opt[rest[i].slice(2)] = rest[i + 1];
  }
  for (const k of ["iter", "important", "nits"]) {
    if (!/^[0-9]+$/.test(opt[k] || "")) die("--iter, --important and --nits take non-negative integers");
  }
  if (!/^[0-9a-fA-F]{40}$/.test(opt.head || "")) die("--head must be the full 40-character SHA");
  if (!["completed", "failed"].includes(opt.status)) die("--status is completed or failed");
  const imp = Number(opt.important), nits = Number(opt.nits);
  console.log(`<!-- factory-review:step=review run=${runId()} iter=${Number(opt.iter)} status=${opt.status} ` +
    `outcome=${outcomeFor(opt.status, imp)} findings=${imp + nits} important=${imp} nits=${nits} head=${opt.head.toLowerCase()} -->`);
} else if (cmd === "lint") {
  if (rest.length !== 1) die("usage: verdict-schema lint <body-file>");
  let s;
  try { s = fs.readFileSync(rest[0], "utf8"); } catch (e) { die(`cannot read ${rest[0]}`); }
  const errs = [];
  const lines = s.split(/\r?\n/);
  const markers = [...s.matchAll(/<!--\s*(factory-review:step=review(?=\s|-->)[\s\S]*?)-->/g)];
  const first = (lines.find(l => l.trim() !== "") || "").trim();
  if (markers.length !== 1) errs.push(`marker: expected exactly one factory-review:step=review marker, found ${markers.length}`);
  if (!/^<!--\s*factory-review:step=review(?=\s|-->).*-->$/.test(first)) errs.push("marker: the first non-blank line must be the marker");
  const m = {};
  if (markers.length >= 1) {
    const toks = markers[0][1].trim().replace(/^factory-review:/, "").split(/\s+/);
    const keys = toks.map(t => t.split("=")[0]);
    if (keys.join(" ") !== ORDER.join(" ")) errs.push(`marker: tokens must be exactly "${ORDER.join(" ")}" in that order, got "${keys.join(" ")}"`);
    for (const t of toks) { const i = t.indexOf("="); if (i > 0 && !(t.slice(0, i) in m)) m[t.slice(0, i)] = t.slice(i + 1); }
    const int = k => (/^[0-9]+$/.test(m[k] || "") ? Number(m[k]) : NaN);
    const want = runId();
    if (!SAFE.test(m.run || "")) errs.push("marker: run= is missing or not a safe id");
    else if (m.run !== want) errs.push(`marker: run=${m.run} but this run is ${want} (generate the marker with verdict-schema marker; never type it)`);
    if (Number.isNaN(int("iter"))) errs.push("marker: iter= must be a non-negative integer");
    if (!["completed", "failed"].includes(m.status)) errs.push("marker: status= must be completed or failed");
    if (!["merge-ready", "not-merge-ready"].includes(m.outcome)) errs.push("marker: outcome= must be merge-ready or not-merge-ready");
    const f = int("findings"), im = int("important"), n = int("nits");
    if ([f, im, n].some(Number.isNaN)) errs.push("marker: findings=, important= and nits= must be non-negative integers");
    else {
      if (f !== im + n) errs.push(`marker: findings=${f} but important+nits=${im + n}`);
      if (m.outcome && m.outcome !== outcomeFor(m.status, im)) errs.push(`marker: outcome=${m.outcome} contradicts status=${m.status} important=${im} (merge-ready exactly when status=completed and important=0)`);
    }
    if (!/^[0-9a-f]{40}$/.test(m.head || "")) errs.push("marker: head= must be the full lowercase 40-character SHA");
  }
  // Headings outside fenced code blocks.
  const heads = []; let fence = false;
  lines.forEach((l, i) => {
    const t = l.trim();
    if (/^(```|~~~)/.test(t)) { fence = !fence; return; }
    if (!fence && /^#{2,3} /.test(t)) heads.push({ level: t.startsWith("### ") ? 3 : 2, text: t, line: i });
  });
  const h2 = heads.filter(h => h.level === 2);
  const named = name => h2.filter(h => h.text === name);
  const sections = ["## Verdict", "## Important findings", "## Nits"];
  for (const name of sections) {
    if (named(name).length !== 1) errs.push(`headings: expected exactly one "${name}", found ${named(name).length}`);
  }
  const at = name => (named(name).length === 1 ? h2.indexOf(named(name)[0]) : -1);
  const [iv, ii, inn] = sections.map(at);
  if (iv >= 0 && ii >= 0 && inn >= 0 && !(iv < ii && ii < inn)) errs.push("headings: \"## Verdict\", \"## Important findings\" and \"## Nits\" must come in that order");
  const body = k => {
    if (k < 0) return [];
    const start = h2[k].line + 1, end = k + 1 < h2.length ? h2[k + 1].line : lines.length;
    return lines.slice(start, end);
  };
  if (iv >= 0) {
    const oc = body(iv).join("\n").match(/\*\*Outcome:\*\*\s*(merge-ready|not-merge-ready)\b/);
    if (!oc) errs.push("verdict: \"## Verdict\" must hold \"**Outcome:** merge-ready|not-merge-ready\"");
    else if (m.outcome && oc[1] !== m.outcome) errs.push(`verdict: **Outcome:** ${oc[1]} differs from the marker outcome=${m.outcome}`);
  }
  const count = k => {
    if (k < 0) return 0;
    const start = h2[k].line, end = k + 1 < h2.length ? h2[k + 1].line : lines.length;
    return heads.filter(h => h.level === 3 && h.line > start && h.line < end).length;
  };
  for (const [k, key, name] of [[ii, "important", "Important findings"], [inn, "nits", "Nits"]]) {
    if (k < 0 || !/^[0-9]+$/.test(m[key] || "")) continue;
    const c = count(k), want = Number(m[key]);
    if (c !== want) errs.push(`counts: ${c} "### " finding(s) under "## ${name}" but ${key}=${want} (every "### " heading in the section is one finding; a heading inside a finding uses "#### ")`);
    if (want === 0 && !body(k).some(l => l.trim() === "None.")) errs.push(`counts: an empty "## ${name}" section must say "None."`);
  }
  // The wording check reads only what the reviewer wrote. A fenced code
  // block, a block quote and a code span are quotations: a review of a skill
  // or doc file cites lines such as "Proposed comments" without saying them.
  let quoted = false;
  const prose = lines.map(l => {
    const t = l.trim();
    if (/^(```|~~~)/.test(t)) { quoted = !quoted; return ""; }
    if (quoted || t.startsWith(">")) return "";
    return l.replace(/(`+).*?\1/g, "");
  }).join("\n");
  const risks = [...prose.matchAll(/\*\*Merge risk:\s*(low|medium|high)\*\*/gi)];
  if (risks.length !== 1) errs.push(`risk: expected exactly one "**Merge risk: <low|medium|high>**" band line, found ${risks.length}`);
  for (const p of [/nothing posted yet/i, /not yet posted/i, /needs your confirm/i, /post all (critical |the )?comments/i, /proposed comments/i]) {
    const hit = prose.match(p);
    if (hit) errs.push(`phrasing: interactive hand-off text "${hit[0]}" (in a factory run nobody answers; the verdict is posted now; to cite such a line from a file, put it in a code span, a fenced block or a block quote)`);
  }
  if (errs.length) { for (const e of errs) console.log("verdict-schema: " + e); process.exit(1); }
  console.log("verdict-schema: OK");
} else {
  die("usage: verdict-schema marker --iter <k> --important <n> --nits <n> --head <sha40> [--status completed|failed] | lint <body-file> | run-id");
}
'

node -e "$VERDICT_JS" "$@"
