---
title: Feature Dependencies Diagram
description: Dependency relationships between Agentic SDLC Ecosystem features
generated: 2026-05-19
source: PDR-078 to PDR-088
---

# Feature Dependencies

## Overview

This diagram shows the dependency relationships between features in the Agentic SDLC Ecosystem.

```mermaid
flowchart LR
    subgraph Foundation["🏗️ Foundation Layer"]
        direction TB
        F1["📄 Spec Format<br/>✅ Complete"]
        F2["🤖 Agent Abstraction<br/>✅ Complete"]
        F3["💻 Local Workspace<br/>✅ Complete"]
    end
    
    subgraph Execution["⚡ Execution Layer"]
        direction TB
        E1["🏷️ Markers [P]/[ASYNC]/[SYNC]<br/>✅ Complete"]
        E2["📊 DAG Builder<br/>✅ Complete"]
        E3["☁️ Remote Workspace<br/>🟡 In Progress"]
        E4["🔄 Git Strategy<br/>✅ Complete"]
    end
    
    subgraph Experience["🎨 Experience Layer"]
        direction TB
        X1["⌨️ CLI<br/>✅ Complete"]
        X2["🖱️ Visual UI<br/>🟡 In Progress"]
        X3["📋 Directives<br/>✅ Complete"]
    end
    
    subgraph Quality["✅ Quality Layer"]
        direction TB
        Q1["🧪 Verification<br/>🟡 In Progress"]
        Q2["📊 Eval Framework<br/>🟡 In Progress"]
    end
    
    subgraph Orchestration["🎮 Orchestration Layer"]
        direction TB
        O1["👥 Squad Mode<br/>🔴 Not Started"]
        O2["⚡ Spec Mode<br/>🟡 In Progress"]
    end
    
    %% Hard Dependencies
    F1 --> E1
    F1 --> X1
    F2 --> E2
    F3 --> E3
    E1 --> E2
    E2 --> Q1
    X1 --> X2
    X3 --> Q2
    Q1 --> O1
    Q1 --> O2
    E4 --> O2
    
    %% Soft Dependencies
    E3 -.->|extends| F3
    X2 -.->|complements| X1
    Q2 -.->|enhances| Q1
    O1 -.->|planned| O2
    
    %% Cross-cutting
    F1 -.->|used by| O1
    F1 -.->|used by| O2
    X3 -.->|guides| Q2
```

## Dependency Matrix

| Feature | Hard Depends On | Soft Depends On | Blocks |
|---------|----------------|-----------------|--------|
| **Markers** | Spec Format | - | DAG Builder |
| **DAG Builder** | Markers | - | Verification, Squad Mode, Spec Mode |
| **Remote Workspace** | Local Workspace | - | - |
| **Visual UI** | CLI | - | - |
| **Verification** | DAG Builder | Eval Framework | Squad Mode, Spec Mode |
| **Squad Mode** | Verification, Spec Format | Spec Mode | - |
| **Spec Mode** | Verification, Git Strategy | Squad Mode | - |

## Critical Path

The critical path for full ecosystem functionality:

```
Spec Format → Markers → DAG Builder → Verification → Squad Mode
                                                    ↘
                                              Git Strategy → Spec Mode
```

**Critical Path Duration**: Q2-Q4 2026 (6-8 months)

## Risk Areas

### High Risk Dependencies

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Remote Workspace delayed** | Blocks enterprise adoption | Local-first fallback; enterprise on-prem option |
| **Verification accuracy low** | Blocks autonomous execution | Human-in-the-loop fallback; continuous model improvement |
| **Visual UI delayed** | Blocks non-developer adoption | CLI-first with training program |

### Dependency Cycles

No circular dependencies detected. DAG is valid.

## Legend

| Arrow | Meaning |
|-------|---------|
| `-->` | Hard dependency (must complete first) |
| `-.->` | Soft dependency (can proceed in parallel) |
| `-.->\|planned\|` | Future planned dependency |

## Navigation

- [← Back to PRD](../../../../../PRD.md)
- [Feature Hierarchy ←](./feature-hierarchy.md)
- [User Flows →](./user-flows.md)
- [State Machine →](./state-machine.md)

---

*Generated: 2026-05-19 | Source: PDR-078 to PDR-088*
