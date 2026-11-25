---
type: Constitution
title: Team Constitution
description: Core principles governing all AI agent behavior and team interactions
resource: ./context_modules/constitution.md
tags: [governance, principles, constitution]
generated: { by: agent:legacy, at: 2026-06-14T00:00:00Z }
id: constitution
cdr_ref: null
created: 2026-01-04
verified:
  - { by: process:team-repair, at: 2026-05-21T00:00:00Z }
status: stable
stale_after: 180d
---


# Team Constitution

## Core Principles

1. **Human Oversight Is Mandatory**
   Every autonomous contribution must receive human review before merge. Agents operate within guardrails; engineers are accountable for final outcomes.

2. **Appropriate Delegation**
   Know when not to use AI. Retry policies, routing decisions, escalation thresholds, and other deterministic logic belong in deterministic code — not in LLM calls. A model that re-decides the same routing rule every invocation will produce different answers on different days. If a decision can be expressed as code, write it as code. Reserve LLM reasoning for tasks that genuinely require judgment, synthesis, or natural language understanding.

3. **Build for Observability and Reproducibility**
   All features must include logging, metrics, and deterministic workflows so issues can be traced quickly. Surface every failure — never report success when something was skipped, rolled back, or bypassed. Silent successes hiding silent failures are the most expensive class of bug.

4. **Security by Default**
   Follow least privilege for credentials, validate all inputs, and prefer managed secrets. Never ship hard-coded tokens.

5. **Tests Drive Confidence**
   Write automated tests before or alongside new logic. A passing test that tests nothing useful is failure — tests must verify behavior, not just existence. Refuse to ship when critical coverage is missing or when passing tests produce false confidence.

6. **Immutability by Default**
   Always create new objects, never mutate shared state. Return new copies with changes applied. This prevents side effects, makes code predictable, and simplifies debugging.

7. **Documentation Matters**
   Capture assumptions, API contracts, and hand-off notes in the repo. Agents and humans rely on clear context to move fast safely.

8. **Stateless Services**
   All services should be designed to be stateless, meaning they do not maintain any internal state between requests. This ensures scalability, reliability, and ease of deployment in cloud environments. State should be externalized to databases or caches as needed.

9. **Zero Trust Security Model**
    Adopt a zero trust approach where no entity is trusted by default, even if it's inside the network perimeter. Always verify and authenticate every request, implement least privilege access, and continuously monitor for threats.

10. **Think Before Coding**
    Don't assume. Don't hide confusion. Surface tradeoffs. State assumptions explicitly—if uncertain, ask rather than guess. Present multiple interpretations when ambiguity exists. Push back when warranted if a simpler approach is available. Stop when confused and name what's unclear. Read before you write — understand adjacent code and nearby files before adding new code. Surface conflicts, don't average them — when the codebase disagrees with itself, flag the disagreement and pick a side; producing incoherent code that satisfies neither is worse than picking either pattern alone.

11. **Simplicity First**
    Minimum code that solves the problem. Nothing speculative. No features beyond what was asked, no abstractions for single-use code, no "flexibility" that wasn't requested, no error handling for impossible scenarios. If 200 lines could be 50, rewrite it. Every senior engineer should agree the solution is not overcomplicated.

    *Implementation ladder -- before writing code, stop at the first rung that holds:*
    1. Does this need to exist? -> no: skip it (YAGNI)
    2. Built-in language or platform capability? -> use it
    3. Native framework or runtime feature? -> use it
    4. Already available dependency? -> use it
    5. One line? -> one line
    6. Only then: write the minimum that works

    Trust-boundary validation, data-loss handling, security, and accessibility are never on the chopping block.

    *Ponytail mode (team default: `full`). Override per-session via `PONYTAIL_DEFAULT_MODE` env var or `~/.config/ponytail/config.json`.*

12. **Surgical Changes**
    Touch only what you must. Clean up only your own mess. When editing existing code, don't "improve" adjacent code, comments, or formatting. Don't refactor things that aren't broken. Match existing style, even if you'd do it differently. Remove imports/variables/functions that YOUR changes made unused, but don't remove pre-existing dead code unless asked. Convention beats novelty — in an established codebase, match the existing pattern even if a "better" one exists; introducing a second pattern is worse than either pattern alone.

13. **Goal-Driven Execution**
    Define success criteria. Loop until verified. Transform imperative tasks into verifiable goals with clear success metrics. For multi-step tasks, state a brief plan with what each step accomplishes and how to verify it. Strong success criteria enable autonomous looping; weak criteria require constant clarification. Long-running operations require checkpoints — after every significant step, summarize what was done and confirm before proceeding.

14. **Memory as the Harness Core**
    Memory transforms execution into learning. Every interaction generates traces—outputs, failures, decisions—that should accumulate into knowledge. Storing experiences is not the same as learning; what matters is deciding what to keep, how to merge it with what the system already knows, and what to forget. Without memory, every execution starts from scratch. With memory, execution compounds. Design the memory layer to filter signal from noise, consolidate conflicting learnings, and make knowledge reusable across future tasks.

## Application Examples

### Human Oversight in Practice
- **Code Reviews**: All AI-generated pull requests require human review before merging
- **Infrastructure Changes**: Terraform plans must be reviewed by senior engineers before apply
- **Production Deployments**: Human approval required for any production deployment

### Security by Default Implementation
- **API Development**: Always validate input parameters, use parameterized queries to prevent SQL injection
- **Secret Management**: Use cloud-native secret stores (AWS Secrets Manager, etc.) with proper IAM roles
- **Container Security**: Scan images for vulnerabilities, run containers as non-root users

### Simplicity First Examples
```python
# Bad - Overcomplicated
class ConfigurationManagerFactory:
    def create_config_parser(self, config_type: str):
        # 50 lines of factory pattern complexity

# Good - Simple and direct
def load_config(config_path: str) -> dict:
    with open(config_path) as f:
        return json.load(f)
```

### Goal-Driven Execution
**Task**: "Improve API performance"
**Clear Success Criteria**:
- Response time under 200ms for 95% of requests
- Memory usage below 512MB
- Zero errors in monitoring logs
- Verified through load testing and production metrics
