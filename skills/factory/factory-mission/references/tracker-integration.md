# Tracker-Agnostic Integration Layer

## Overview

This is the shared reference for all tracker-aware factory skills (`factory-mission`, `factory-queue`, `factory-review`). It details how the platform integrates with any issue tracker (GitHub, GitLab, Linear, Jira) without holding proprietary queue state.

---

## Configuration & Discovery

### 1. Provider Resolution
1. Read `.specify/taskstoissues-provider.yml` from the project root.
2. Parse `provider: github | gitlab | linear | jira` (fall back to `github` if absent).
3. Read field mappings (`project_key`, `team_id`, `priority_map`, `issue_types`).

### 2. Credentials & Tools Discovery
1. Check environment variables: `GITHUB_TOKEN`, `GITLAB_TOKEN`, `LINEAR_API_KEY`, `JIRA_API_TOKEN` / `JIRA_URL` + `JIRA_EMAIL`.
2. Discover available tools:
   - MCP servers (e.g., `github`, `gitlab-mcp`, `linear`, `atlassian-mcp-server`).
   - CLI tools (`gh`, `glab`, `linear`, `jira`).
3. If no credential or tool is found for the resolved provider, halt with an error.

---

## Core Operations

### 1. Pull Brief
Retrieve issue summary, description, and comments via MCP or CLI. Use this raw text as input to compile the Mission Brief.

### 2. Label Gate & Gating Dimensions (ADR-318)
Every ticket carries three label dimensions:
- **Automation-gating**: `agent-can-execute` | `human-required`
- **Dispatch**: `autonomous` | `supervised` | `interactive`
- **Lifecycle-stage**: `intent` | `spec-gated` | `executing` | `validation` | `done` | `cancelled`

**Rule**: If dispatch is `interactive` or automation-gating is `human-required`, the agent must halt and refuse auto-execution.

### 3. Write-Back & Comments
Post status updates, iteration logs, and findings directly onto the ticket thread. When opening PRs, stamp `agent-authored` (PDR-030).

---

## Safety Constraints

1. **Dry-Run & Explicit Confirm**: Every write action (creating tickets, stamping labels, posting comments) must default to a dry-run preview showing the exact diff of what will be written, requiring explicit user confirmation before proceeding.
2. **Never approves or merges**: `factory-review` is strictly advisory. Branch protection and human code-owner approval are mandatory.
3. **No parallel state**: The external tracker is the single source of truth.
