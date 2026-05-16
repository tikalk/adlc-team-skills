# Technology Radar - April 2026

> Last Updated: April 2026
> Based on: Thoughtworks Radar Vol 34 + Internal Radar Comparison

## Theme: Building Resilient Agentic Systems

The technology landscape in 2026 is defined by the rise of AI agents and the need for new engineering practices. As AI transforms how we build software, we must retain the principles of good software engineering while adapting to agentic workflows.

### Key Themes

1. **Evaluating Technology in an Agentic World** - AI is changing not only technology but also how we assess and evaluate it. Semantic diffusion (rapid emergence of new terms) and the pace of change make traditional assessment harder.

2. **Retaining Principles, Relinquishing Patterns** - AI is pushing us to revisit foundational techniques: pair programming, zero trust architecture, mutation testing, and DORA metrics. This is not nostalgia but necessary counterweight to AI speed.

3. **Securing Permission-Hungry Agents** - Agents need broad access to be useful, but safeguards haven't caught up. Zero trust, least privilege, and defense in depth are essential.

4. **Putting Coding Agents on a Leash** - Harness engineering: controls that guide agent behavior before code is generated and provide feedback for self-correction.

---

## Adopt - Start Using

### Techniques

| Technology | Domain | Rationale |
|------------|--------|----------|
| **Context Engineering** | AI/ML | Treat the context window as a design surface. Progressive context disclosure loads info only when needed, preventing context rot. |
| **DORA Metrics** | DevOps | Measure delivery performance (lead time, deployment frequency, MTTR, change failure rate). Use for team learning, not dashboards. |
| **Passkeys** | Security | FIDO2 credentials, phishing-resistant. Backed by Apple, Google, Microsoft. 15B+ eligible accounts globally. |
| **Structured Output from LLMs** | AI/ML | Constrain model output to JSON/schema. Use Instructor or PydanticAI for validation and retries. |
| **Zero Trust Architecture** | Security | Never trust, always verify. Apply to all systems including agent deployments. |
| **Curated Shared Instructions** | AI/ML | Anchor AI guidance in repository templates (CLAUDE.md, AGENTS.md). Ensures consistent AI assistance from day one. |
| **Using GenAI to Understand Legacy Codebases** | Backend | Strong insights about the system form the foundation for effective AI use. |

### Platforms & Tools

| Technology | Domain | Rationale |
|------------|--------|----------|
| **Claude Code** | AI/ML | Agentic coding tool for planning/executing multi-step workflows. Benchmark for capability. Use with disciplined practices. |
| **Cursor** | AI/ML | Agentic IDE with plan mode, hooks, subagents. Inspect individual steps or rollback. |
| **Kubernetes** | DevOps | Container orchestration standard. Continue as default for container workloads. |
| **PostgreSQL** | Backend | Supports vector similarity queries. Solid choice for AI applications. |
| **Apache Iceberg** | Backend | Open table format, vendor-neutral. ACID transactions, time travel built-in. Lakehouse standard. |
| **mise** | DevOps | High-performance tool versioning (Rust-based). Consolidates tool management, env vars, and task execution. |
| **React Native** | Mobile | New Architecture (JSI, Fabric) addresses bridge bottlenecks. Deliver native responsiveness with single codebase. |
| **Svelte** | Web/Mobile | Compiles to optimized JS at build time. Small bundles, strong runtime performance. Simpler component model. |
| **SigNoz** | DevOps | OpenTelemetry-native observability. Self-hosted alternative to Datadog. |
| **ClickHouse** | Backend | Columnar database for analytics. High-performance, cost-effective. |

### Languages & Frameworks

| Technology | Domain | Rationale |
|------------|--------|----------|
| **React 19** | Web/Mobile | React Compiler handles memoization at build time. Removes manual useMemo burden. Strong ecosystem. |
| **PydanticAI** | AI/ML | Type-safe LLM interactions with Pydantic validation. Most Pythonic framework for production agents. |
| **OpenTelemetry** | DevOps | Vendor-agnostic telemetry. Standard for observability across systems. |
| **Pandas 2** | Backend | Copy-on-Write, Arrow-backed dtypes. Lowest friction for data manipulation. |
| **Polars** | Backend | Rust-based, faster than Pandas. Lazy evaluation for optimization. |

---

## Trial - Worth Pursuing

### Techniques

| Technology | Domain | Rationale |
|------------|--------|----------|
| **Agent Skills** | AI/ML | Modularize context with instructions/scripts. Load just-in-time, reducing token consumption. Alternative to MCP. |
| **Browser-Based Component Testing** | Web/Mobile | Playwright in real browser provides consistency. Performance hit now small, flakiness decreased. |
| **Feedback Sensors for Coding Agents** | AI/ML | Deterministic quality gates (compilers, linters, tests) wired into agent workflows. Failures trigger self-correction. |
| **Mapping Code Smells to Refactoring Techniques** | Backend | Instruct agents to handle specific issues with defined approaches. Effective for legacy stacks. |
| **Mutation Testing** | DevOps | Introduce deliberate bugs to verify tests catch regressions. Use Stryker, Pitest, cargo-mutants. |
| **Progressive Context Disclosure** | AI/ML | Give agents lightweight discovery phase, load detail only when relevant. Prevents instruction bloat. |
| **Sandboxed Execution for Coding Agents** | DevOps | Run agents in isolated environments. Use Dev Containers, Shuru, or Sprites. |
| **Semantic Layer** | Data | Shared business logic between raw data and consumers. Centralize metric definitions, joins, access rules. |

### Platforms

| Technology | Domain | Rationale |
|------------|--------|----------|
| **Graphiti** | AI/ML | Temporal knowledge graph. Tracks how facts change over time. MCP server available. |
| **Langfuse** | AI/ML | Open-source LLM engineering platform. Tracing, evaluations, prompt management. |
| **AWS Bedrock AgentCore** | AI/ML | Agentic platform for building/running agents at scale. Use with decoupled architecture. |
| **Port** | DevOps | Internal developer portal. Self-service for dev teams. |
| **Replit** | DevOps | Cloud-native collaborative development. Instant dev environments, AI assistance. |
| **AG-UI Protocol** | Web/Mobile | Standardize communication between rich UIs and back-end AI agents. |

### Tools

| Technology | Domain | Rationale |
|------------|--------|----------|
| **Dev Containers** | DevOps | Reproducible, containerized dev environments. Also useful for sandboxed agent execution. |
| **cargo-mutants** | Rust | Mutation testing for Rust. Zero-config, identifies missing edge cases. |
| **Figma Make** | Design | AI-powered prototyping. Uses actual components from design systems. |
| **OpenAI Codex** | AI/ML | Standalone agentic coding tool. High-velocity drafting for greenfield tasks. |
| **Typst** | Docs | Markup-based typesetting. Modern successor to LaTeX. Faster compilation, clearer errors. |
| **Claude Code Plugin Marketplace** | AI/ML | Distribute shared commands, prompts, skills via Git. Streamlined team workflows. |

### Languages & Frameworks

| Technology | Domain | Rationale |
|------------|--------|----------|
| **Agent Development Kit (ADK)** | AI/ML | Google's framework for building/operating AI agents. Maturing ecosystem. |
| **DeepEval** | AI/ML | Open-source LLM evaluation. Custom metrics, hallucination detection. |
| **Docling** | AI/ML | Convert unstructured documents to structured outputs. Computer vision approach. |
| **LangGraph** | AI/ML | State-multi-agent systems as stateful graphs. Powerful but not default for every use case. |
| **LiteLLM** | AI/ML | AI gateway. Retries, failover, load balancing, cost tracking. |
| **Modern.js** | Web/Mobile | ByteDance React meta-framework. Module Federation support. |

---

## Assess - Explore Further

### Techniques

| Technology | Domain | Rationale |
|------------|--------|----------|
| **Agentic Reinforcement Learning Environments** | AI/ML | Training ground for LLM-based agents. Reframes post-training for agentic behaviors. |
| **Architecture Drift Reduction with LLMs** | AI/ML | Detect structural/semantic violations, then help fix. Acts as "garbage collection." |
| **Code Intelligence as Agentic Tooling** | AI/ML | Give agents access to AST-aware tools (LSP). Fewer hallucinated edits, lower token consumption. |
| **Context Graph** | AI/ML | Model decisions, policies, precedents as first-class nodes. Vital for agent effectiveness. |
| **Feedback Flywheel** | AI/ML | Continuously improve coding agent harness. Spec → plan → implement → improve. |
| **Spec-Driven Development** | DevOps | Structure workflows and guide agents through planning, design, implementation. |

### Platforms

| Technology | Domain | Rationale |
|------------|--------|----------|
| **Agent Trace** | AI/ML | Open specification for AI code attribution. Vendor-neutral. |
| **ClickStack** | DevOps | OpenTelemetry-compatible observability on ClickHouse. Sub-second queries. |
| **Coder** | DevOps | Remote dev environments with local IDEs. Middle ground between local and pixel-streamed VDI. |
| **Databricks Agent Bricks** | AI/ML | Prebuilt components for common AI patterns. Declarative approach. |
| **DuckLake** | Backend | Integrated data lake and catalog format. Low-complexity lakehouse alternative. |
| **FalkorDB** | Backend | Redis-based graph database. Low operational friction. |
| **MCP Apps** | AI/ML | MCP extension returning interactive HTML interfaces. |
| **Monarch** | AI/ML | Distributed programming for GPU clusters. Makes distributed tensors behave like local. |
| **Sprites** | DevOps | Stateful sandbox environments with checkpoint/restore. Non-ephemeral agent execution. |
| **torchtitan** | AI/ML | PyTorch-native large-scale pre-training. 4D parallelism support. |

### Tools

| Technology | Domain | Rationale |
|------------|--------|----------|
| **Agent Scan** | Security | Security scanner for agent ecosystems. Discovers MCP servers/skills, flags risks. |
| **Beads** | AI/ML | Git-backed issue tracker for coding agents. Persistent memory layer. |
| **Bloom** | AI/ML | AI safety evaluation. Probes for behaviors like sycophancy. |
| **CDK Terrain** | DevOps | Community fork of CDKTF. Migration path for existing CDKTF users. |
| **CodeScene** | DevOps | Behavioral code analysis. Identifies hotspots and AI-friendly code design guidance. |
| **Git AI** | AI/ML | Track AI-generated code with Git Notes. Accountability and maintainability. |
| **Google Antigravity** | AI/ML | VS Code fork with multi-agent orchestration. Agent Manager for parallel tasks. |
| **Google Mainframe Assessment Tool** | Legacy | Reverse-engineer mainframe applications. AI summarization and modernization. |
| **OpenCode** | AI/ML | Open-source coding agent. Model flexibility, self-hosted support. |
| **OpenSpec** | DevOps | Spec-driven development framework. Lightweight spec layer. |
| **PageIndex** | AI/ML | Hierarchical document index for vectorless RAG. Explicit reasoning trace. |
| **Pencil** | Design | Design canvas with bidirection IDE integration. Design-to-code capabilities. |

### Languages & Frameworks

| Technology | Domain | Rationale |
|------------|--------|----------|
| **Agent Lightning** | AI/ML | Agent optimization and training framework. Continuous prompt improvement. |
| **GitHub Spec Kit** | DevOps | Spec-driven development. Constitution for project principles. |
| **Mastra** | AI/ML | TypeScript-native AI framework. Graph-based workflow engine. |
| **Pipecat** | AI/ML | Real-time voice and multimodal agents. Modular pipeline model. |
| **Superpowers** | AI/ML | Composable skills workflow for coding agents. Enforces TDD cycles. |
| **TanStack Start** | Web/Mobile | Full-stack framework with compile-time safety. Explicit configuration. |
| **TOON** | AI/ML | Token-oriented JSON encoding. Reduces token usage for LLMs. |
| **Unsloth** | AI/ML | LLM fine-tuning. Faster/more memory efficient. Consumer GPU support. |

---

## Hold / CAUTION - Proceed with Care

| Technology | Issue | Recommendation |
|-----------|-------|------------|
| **Poetry** | Slow dependency resolver, lacks workspace support. Rise of `uv` (orders of magnitude faster). | Consider uv for new Python projects. |
| **Lerna** | Ecosystem evolved with native package manager workspaces and Nx. | Use Nx or npm workspaces instead. |
| **Moment.js** | Legacy project, in maintenance mode. | Migrate to Luxon or date-fns. |
| **Python 2** | End-of-life since 2020. | Stop using completely. |
| **Python 3.9 and lower** | EOL October 2025. No security patches. | Upgrade to 3.11+. |
| **Pandas 1** | Lacks CoW, Arrow-backed performance. | Migrate to Pandas 2/3. |
| **Airflow 2** | Lacks event-driven, async-first support. | Migrate to Airflow 3. |
| **Akka** | BSL license issues. | Use Apache Pekko instead. |
| **Ant Design** | Excessive bundle size. | Consider lighter alternatives. |
| **OpenStack** | Dominated by K8s. Niche technology now. | Use K8s instead. |
| **MCP by Default** | Not all use cases need it. Agent Skills often sufficient. | Evaluate before defaulting. |
| **Coding Agent Swarms** | Unproven at scale. Coordination challenges. | Assess carefully. |

---

## Trends

### Agentic Architectures Powering Autonomous AI Systems
Beyond developer tools, there's a clear shift toward building more advanced autonomous AI systems and standardizing how they interact. This involves designing "Agentic Architectures," including patterns like Agentic RAG, where agents retrieve, process, and ground knowledge from diverse sources. Protocols like MCP and A2A are being introduced for consistent agent communication.

### AI Reshaping Software Development (Agentic SDLC)
From "vibe coding" to structured AI-assisted development. IDEs are becoming "Agentic IDEs" with persistent context, YAML-based prompts, and MCP integration. Developers are adopting workflows involving LLMs in ideation, planning, and execution. AI is automating DevOps tasks from code reviews to system monitoring.

### Modern Data Architectures for AI and Real-Time Analytics
Apache Iceberg is the standard for production-grade data lakes. OLAP databases like Apache Pinot, ClickHouse, StarRocks, and DuckDB support updatable/joinable operations for real-time AI. Vector databases rising for RAG systems.

---

## Appendix: Internal Additions

These items are specific to our organization:

| Technology | Ring | Domain | Notes |
|------------|------|--------|-------|
| **A2A Agents** | Try | Protocol for AI agent collaboration across platforms |
| **AI Driven IDE** | Keep | Cursor, Windsurf, JetBrains AI |
| **Agentic AI** | Keep | Autonomous, goal-driven systems |
| **Vercel AI SDK** | Start | Streaming LLM responses |
| **Spec-Driven Development** | Try | AI-assisted toolkit for specs |
| **Context Engineering** | Start | Right information, not maximum |
| **Apache Doris** | Start | Real-time analytical database |
| **Apache Gravitino** | Try | Unified metadata catalog |
| **Apache Polaris** | Keep | Open catalog for Iceberg |
| **AI Agents** | Start | Automation of multi-step work |
| **NotebookLM** | Keep | Research and note-taking |

---

*Generated: April 2026*
*Based on: Thoughtworks Technology Radar Vol 34 and Internal Radar Comparison*