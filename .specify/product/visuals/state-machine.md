---
title: State Machine Diagram
description: State transitions for tasks and workflows in the Agentic SDLC Ecosystem
generated: 2026-05-19
source: PDR-082, PDR-083, PDR-085, PDR-088
---

# State Machine

## Overview

This document defines the state machines governing task execution and workflow management in the Agentic SDLC Ecosystem.

## Task State Machine

```mermaid
stateDiagram-v2
    [*] --> Pending: Task Created
    
    Pending --> Classifying: Triage
    Classifying --> SYNC: Complex/Ambiguous
    Classifying --> ASYNC: Well-defined
    
    SYNC --> InProgress: Human Start
    ASYNC --> InProgress: Auto-start
    
    InProgress --> AwaitingVerification: Implementation Complete
    
    AwaitingVerification --> Verified: /goal Pass
    AwaitingVerification --> Retry: /goal Fail (attempt < 3)
    AwaitingVerification --> Failed: /goal Fail (attempt = 3)
    
    Retry --> InProgress: Auto-retry
    
    Verified --> Complete: Approved
    Verified --> InProgress: Revision Requested
    
    Failed --> ManualReview: Escalate
    ManualReview --> InProgress: Retry Approved
    ManualReview --> Abandoned: Cancelled
    
    InProgress --> Paused: User Interrupt
    Paused --> InProgress: Resume
    Paused --> Abandoned: Cancel
    
    Complete --> [*]: Done
    Abandoned --> [*]: Done
```

### Task States

| State | Description | Transitions |
|-------|-------------|-------------|
| **Pending** | Task created, awaiting classification | → Classifying |
| **Classifying** | Triage in progress (SYNC vs ASYNC) | → SYNC, → ASYNC |
| **SYNC** | Human-gated task, waiting for start | → InProgress |
| **ASYNC** | Autonomous task, auto-start | → InProgress |
| **InProgress** | Active implementation | → AwaitingVerification, → Paused |
| **AwaitingVerification** | Complete, being verified | → Verified, → Retry, → Failed |
| **Retry** | Failed verification, will retry | → InProgress |
| **Verified** | Passed verification | → Complete, → InProgress |
| **Failed** | Failed after max retries | → ManualReview |
| **ManualReview** | Human intervention required | → InProgress, → Abandoned |
| **Paused** | User interrupted | → InProgress, → Abandoned |
| **Complete** | Successfully finished | → [*] |
| **Abandoned** | Cancelled or rejected | → [*] |

## Squad Mode State Machine (Outer Loop)

```mermaid
stateDiagram-v2
    [*] --> Specifying: PRD Received
    
    Specifying --> NeedsClarification: Ambiguous
    NeedsClarification --> Specifying: Clarified
    Specifying --> Specified: Clear
    
    Specified --> Evaluating: Auto-eval
    Evaluating --> NeedsRevision: Eval Fail
    NeedsRevision --> Specifying: Revise
    Evaluating --> Evaluated: Eval Pass
    
    Evaluated --> Planning: Generate Plan
    Planning --> Planned: Plan Complete
    
    Planned --> Triaging: Create Tasks
    Triaging --> Triaged: tasks.md Generated
    
    Triaged --> Handoff: To Spec Mode
    Handoff --> [*]: Done
```

### Squad Mode States

| State | Description | Gates |
|-------|-------------|-------|
| **Specifying** | Creating specification from PRD | Human review |
| **NeedsClarification** | PRD has <3 ambiguity flags | Resolution required |
| **Specified** | Spec approved | Auto-eval triggers |
| **Evaluating** | Automated evaluation | Binary pass/fail |
| **NeedsRevision** | Spec failed evaluation | Revision required |
| **Evaluated** | Spec passed evaluation | Proceed to plan |
| **Planning** | Generating implementation plan | Human review |
| **Planned** | Plan approved | Proceed to triage |
| **Triaging** | Creating task breakdown | Auto-generation |
| **Triaged** | tasks.md generated | Handoff to Spec Mode |

## Spec Mode State Machine (Inner Loop)

```mermaid
stateDiagram-v2
    [*] --> TaskSelected: From tasks.md
    
    TaskSelected --> ModeDetermined: Classify
    
    ModeDetermined --> SYNC: Complex/Ambiguous
    ModeDetermined --> ASYNC: Mechanical
    
    SYNC --> SYNC_Implement: Human Start
    ASYNC --> ASYNC_Implement: Auto-start
    
    SYNC_Implement --> SYNC_Verify: Complete
    ASYNC_Implement --> ASYNC_Verify: Complete
    
    SYNC_Verify --> SYNC_Approved: Pass
    SYNC_Verify --> SYNC_Revise: Fail
    
    ASYNC_Verify --> ASYNC_Complete: Pass
    ASYNC_Verify --> ASYNC_Retry: Fail (retry < 3)
    ASYNC_Verify --> ASYNC_Escalate: Fail (retry = 3)
    
    SYNC_Revise --> SYNC_Implement: Revise
    ASYNC_Retry --> ASYNC_Implement: Auto-retry
    
    ASYNC_Escalate --> SYNC: Escalate to human
    
    SYNC_Approved --> Complete: Done
    ASYNC_Complete --> Complete: Done
    
    Complete --> [*]: Next Task
```

## Verification State Machine

```mermaid
stateDiagram-v2
    [*] --> Running: Milestone Complete
    
    Running --> Judging: Fast Model Eval
    
    Judging --> Passed: Goal Achieved
    Judging --> Failed: Goal Not Achieved
    Judging --> Uncertain: Low Confidence
    
    Uncertain --> HumanReview: Escalate
    HumanReview --> Passed: Human Confirms
    HumanReview --> Failed: Human Rejects
    
    Passed --> [*]: Continue
    Failed --> [*]: Retry
```

## State Transitions Summary

| From | To | Trigger | User Action Required |
|------|-----|---------|---------------------|
| Pending | Classifying | Task created | No |
| Classifying | SYNC | Complex detected | No (auto) |
| Classifying | ASYNC | Well-defined detected | No (auto) |
| SYNC | InProgress | Human starts | Yes |
| ASYNC | InProgress | Auto-start | No |
| InProgress | AwaitingVerification | Implementation done | No |
| AwaitingVerification | Verified | /goal pass | No |
| AwaitingVerification | Retry | /goal fail | No (auto if <3) |
| AwaitingVerification | Failed | /goal fail (3rd) | No |
| Verified | Complete | Approval | Yes (implicit) |
| Failed | ManualReview | Escalation | Yes |
| InProgress | Paused | Ctrl+C | Yes |

## Navigation

- [← Back to PRD](../../../../../PRD.md)
- [Feature Hierarchy ←](./feature-hierarchy.md)
- [Feature Dependencies ←](./feature-deps.md)
- [User Flows ←](./user-flows.md)

---

*Generated: 2026-05-19 | Source: PDR-082, PDR-083, PDR-085, PDR-088*
