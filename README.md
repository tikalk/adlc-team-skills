# Agentic SDLC Ecosystem

The **Agentic SDLC Ecosystem** is a comprehensive suite of tools, methodologies, and infrastructure for integrating AI coding agents into the software development lifecycle. Built on the **Twelve-Factor Agentic SDLC** methodology, the ecosystem enables teams to systematically leverage AI agents for specification, planning, implementation, and quality assurance.

## Abstract

This ecosystem addresses the fundamental challenges of AI-assisted software development:

- **Ad-hoc Integration** — Each developer uses AI differently, leading to inconsistent quality
- **Context Loss** — AI agents lose coherence over long sessions due to context window limits
- **Verification Gaps** — No systematic way to verify AI-generated code meets requirements
- **Knowledge Silos** — AI guidance isn't shared or versioned across teams
- **Scalability Limits** — Local execution constrains parallel and autonomous work

The Agentic SDLC provides a structured methodology that treats specifications as the primary artifact throughout the development lifecycle, with AI agents executing against verified specs in isolated, observable environments.

## Documentation

| Document | Description |
|----------|-------------|
| [AD.md](./AD.md) | **Architecture Description** — System architecture, functional elements, deployment topology, security perspective, and 19 system ADRs documenting key architectural decisions |
| [PRD.md](./PRD.md) | **Product Requirements Document** — Product overview, six products (Spec Kit, Runner, Team Directives, Agents Workspaces, Agent Runner, Evals Extension), functional requirements, roadmap, and 78+ PDRs |

## Key Components

| Product | Purpose |
|---------|---------|
| **Spec Kit** | Methodology toolkit for Spec-Driven Development |
| **Runner** | Kubernetes-based async agent execution infrastructure |
| **Team Directives** | Version-controlled AI behavior configuration |
| **Agents Workspaces** | Cloud-native persistent development environments |
| **Agent Runner** | Unified Squad + Spec orchestration |
| **Evals Extension** | Eval-Driven Development (EDD) with PromptFoo |

## Version

- **AD.md**: v1.4 | Last Updated: 2026-04-06 | 19 system ADRs
- **PRD.md**: v1.9.0 | 78+ Product Decision Records

## Related Repositories

- [agentic-sdlc-spec-kit](https://github.com/tikalk/agentic-sdlc-spec-kit) — Spec Kit (Open Source)
- [agentic-sdlc-agent-runner](https://github.com/tikalk/agentic-sdlc-agent-runner) — Agent Runner (Open Source)
- [adlc-agent-workspaces](https://gitlab.tikalk.dev/tikalk/engineering/agentic-sdlc/adlc-agent-workspaces) — Workspaces Infrastructure (Commercial)

## References

- [Twelve-Factor Agentic SDLC](https://tikalk.github.io/agentic-sdlc-12-factors/)
- [Research: Building AI Coding Agents for the Terminal (arXiv:2603.05344v1)](https://arxiv.org/abs/2603.05344)
- [Eval-Driven Development (Braintrust)](https://www.braintrustdata.com/blog/evals-replace-prds)