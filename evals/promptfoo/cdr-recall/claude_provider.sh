#!/usr/bin/env bash
# Local provider for the CDR recall eval: routes the prompt through the
# `claude` CLI (no API key needed on a logged-in machine). promptfoo's exec
# provider passes the rendered prompt as $1. Model: CDR_RECALL_CLAUDE_MODEL.
set -euo pipefail
exec claude -p --model "${CDR_RECALL_CLAUDE_MODEL:-claude-haiku-5-5}" --tools "" -- "$1" </dev/null 2>/dev/null
