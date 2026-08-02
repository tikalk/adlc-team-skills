#!/usr/bin/env python3
"""
radar-search.py — Deterministic search and alias normalization for Tikal Tech Radar.

Usage:
  python3 radar-search.py <query1> [query2 ...] [--json]
  
Examples:
  python3 radar-search.py postgresql redis
  python3 radar-search.py k8s "gh actions"
  python3 radar-search.py --json flask
"""

import sys
import os
import json
import re
import html
from pathlib import Path

# Common technology alias normalization map
ALIASES = {
  "k8s": "Kubernetes",
  "kube": "Kubernetes",
  "postgres": "PostgreSQL",
  "postgresql": "PostgreSQL",
  "pg": "PostgreSQL",
  "gh actions": "GitHub Actions",
  "github-actions": "GitHub Actions",
  "cra": "Create React App",
  "create-react-app": "Create React App",
  "next": "Next.js",
  "nextjs": "Next.js",
  "vue": "Vue.js",
  "vuejs": "Vue.js",
  "node": "Node.js",
  "nodejs": "Node.js",
  "ts": "TypeScript",
  "typescript": "TypeScript",
  "mongo": "Beanie (mongo ORM)",
  "mongodb": "Beanie (mongo ORM)",
  "pydantic": "PydanticAI",
  "iac": "Infrastructure as Code (IaC)",
  "mcp": "Model Context Protocol (MCP)",
  "rsc": "React Server Components",
  "rtk": "Redux Toolkit",
  "idp": "Internal Developer Portals (IDPs) (e.g., Port.io. Backstage)",
  "eso": "External Secrets Operator",
  "gke": "GKE Workload Identity",
  "airflow": "Airflow 3",
  "spark": "Apache Spark 4.0",
}


def clean_html(text: str) -> str:
  """Strip HTML tags and unescape entities to return clean text."""
  if not text:
    return ""
  plain = re.sub(r"<[^>]+>", " ", text)
  plain = html.unescape(re.sub(r"\s+", " ", plain)).strip()
  return plain


def extract_why(description: str) -> str:
  """Extract the Tikal opinion inside <p>Why?</p> block."""
  if not description:
    return ""
  match = re.search(
      r"<p>Why\?</p>(.*?)(?=<p>Description</p>|$)", description, re.DOTALL
  )
  if match:
    return clean_html(match.group(1))
  return clean_html(description)


def extract_desc(description: str) -> str:
  """Extract neutral background text from <p>Description</p> block."""
  if not description:
    return ""
  match = re.search(r"<p>Description</p>(.*)$", description, re.DOTALL)
  if match:
    return clean_html(match.group(1))
  return clean_html(description)


def load_radar() -> dict:
  """Load resources/radar.json relative to this script."""
  script_dir = Path(__file__).parent.resolve()
  resource_path = script_dir.parent / "resources" / "radar.json"
  if not resource_path.exists():
    # Fallback search path
    resource_path = (
        Path.cwd()
        / "skills"
        / "tech-radar"
        / "tech-radar-context"
        / "resources"
        / "radar.json"
    )

  with open(resource_path, "r", encoding="utf-8") as f:
    return json.load(f)


def search_blips(queries: list[str], radar_data: dict) -> list[dict]:
  """Search blips by queries, using alias mapping and case-insensitive matching."""
  blips = radar_data.get("blips", [])
  results = []
  seen = set()

  for raw_q in queries:
    q_norm = raw_q.strip().lower()
    if not q_norm:
      continue

    # Resolve alias if present
    target_term = ALIASES.get(q_norm, q_norm)

    for blip in blips:
      name = blip.get("name", "")
      name_lower = name.lower()
      why_text = extract_why(blip.get("description", ""))
      desc_text = extract_desc(blip.get("description", ""))

      # Match criteria and scoring
      target_lower = target_term.lower()
      score = 0
      if name_lower == target_lower:
        score = 100
      elif name_lower.startswith(target_lower):
        score = 80
      elif target_lower in name_lower or q_norm in name_lower:
        score = 60
      elif len(q_norm) >= 4 and (q_norm in why_text.lower() or q_norm in desc_text.lower()):
        score = 20

      if score > 0:
        blip_key = (name, blip.get("quadrant"), blip.get("ring"))
        if blip_key not in seen:
          seen.add(blip_key)
          results.append(({
              "name": name,
              "quadrant": blip.get("quadrant", ""),
              "ring": blip.get("ring", ""),
              "why": why_text,
              "description": desc_text,
              "isNew": blip.get("isNew", False),
          }, score))

  # Sort by match score descending
  results.sort(key=lambda item: item[1], reverse=True)
  return [r[0] for r in results]

  return results


def format_markdown_table(results: list[dict]) -> str:
  """Format search results as Markdown table and Guidance notes."""
  if not results:
    return (
        "## Tikal Tech Radar Context\n\n| Technology | Quadrant | Ring | Tikal's"
        " Opinion (Why?) |\n|------------|----------|------|------------------------|\n\n_Source:"
        " Tikal Israeli Tech Radar (local snapshot) · 0 technologies"
        " matched._"
    )

  lines = [
      "## Tikal Tech Radar Context",
      "",
      "| Technology | Quadrant | Ring | Tikal's Opinion (Why?) |",
      "|------------|----------|------|------------------------|",
  ]

  rings_by_tech = {}
  for r in results:
    tech = r["name"]
    ring = r["ring"]
    if tech not in rings_by_tech:
      rings_by_tech[tech] = []
    rings_by_tech[tech].append((ring, r["quadrant"]))

    # Truncate why text if very long for table display
    why_summary = r["why"]
    if len(why_summary) > 160:
      why_summary = why_summary[:157] + "..."

    lines.append(
        f"| {tech} | {r['quadrant']} | {ring} | {why_summary} |"
    )

  lines.append("")
  lines.append("**Radar Guidance**")

  for tech, placements in rings_by_tech.items():
    rings_set = {p[0] for p in placements}
    if "Stop" in rings_set and ("Keep" in rings_set or "Start" in rings_set):
      lines.append(
          f"- ⚡ **Conflicting Placements**: `{tech}` has multiple placements"
          f" across categories ({', '.join(f'{q}: {rg}' for rg, q in placements)})."
          " Check specific quadrant context."
      )
    elif "Stop" in rings_set:
      lines.append(
          f"- ⚠️ **Stop**: `{tech}` — Tikal advises against usage; seek"
          " Keep/Start alternatives in the same quadrant."
      )
    elif "Keep" in rings_set or "Start" in rings_set:
      lines.append(
          f"- ✅ **Adopt**: `{tech}` — Recommended standard ({', '.join(f'{q}: {rg}' for rg, q in placements)})."
      )
    elif "Try" in rings_set:
      lines.append(
          f"- 🧪 **Try**: `{tech}` — Promising technology; suitable for"
          " low-risk trials or POCs."
      )

  lines.append("")
  lines.append(
      f"_Source: Tikal Israeli Tech Radar (local snapshot) · {len(results)} blip placement(s) matched._"
  )

  return "\n".join(lines)


def main():
  args = [a for a in sys.argv[1:] if a != "--json"]
  output_json = "--json" in sys.argv

  if not args:
    print("Usage: python3 radar-search.py <tech1> [tech2 ...] [--json]")
    sys.exit(1)

  radar_data = load_radar()
  results = search_blips(args, radar_data)

  if output_json:
    print(json.dumps(results, indent=2))
  else:
    print(format_markdown_table(results))


if __name__ == "__main__":
  main()
