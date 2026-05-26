# Launchpad - New Client Template

> **Purpose**: This is a master template that the AI Lead duplicates for each new client. Includes task lists, sync meeting templates, and lessons learned.
>
> **Instruction**: Copy this tab and rename it with the client name (e.g., "AppWorks") and fill in the details.

---

## General Information

| Field | Details |
|-------|---------|
| **Client Name** | |
| **Tikal AI Lead** | |
| **Additional Tikal Team** | |
| **Client Contact** | |
| **Client Tech Lead** | |
| **Kickoff Date** | |
| **Expected Handover** | (6 weeks from Kickoff) |

---

## Timeline - 6 Weeks from Kickoff

```
Week 1          | Weeks 2-3        | Weeks 4-5          | Week 6
Phase 1:        | Phase 2:         | Phase 3:           | Phase 4:
Scan, Baseline  | Workshop         | Embedded           | Handover
& Adaptation    | (4 sessions)     | Execution (Sprint) | & ROI
```

---

## Weekly Tasks (Task Tracker)

| Assignee | Task | Due Date | Status |
|----------|------|----------|--------|

### Phase 1 - Scan & Baseline (Week 1)

- [ ] Open shared Slack channel (External) for ongoing communication
- [ ] Send structured meeting summary for every meeting
- [ ] Create shared progress document (Google Doc with transcriptions)
- [ ] Select organizational KPI or use our baseline survey
- [ ] Create questionnaire/survey (Google Form) to map current AI usage habits
- [ ] Set up initial team-ai-directives repo (based on Tikal Open Source)
- [ ] Run `level up init` / scan client code to identify rules and personas
- [ ] Map personas/engineering groups and select tasks per persona
- [ ] Grant code access (GitHub/GitLab read-only)
- [ ] Send Tikal usernames on GitHub to client
- [ ] Prepare initial context and build Directives
- [ ] Create Scenario for Group 1 exercises
- [ ] Create Scenario for Group 2 exercises
- [ ] Create Scenario for Group 3 exercises

### Phase 2 - Workshop (Weeks 2-3)

- [ ] Arrange Google Classroom access in Admin
- [ ] Organize Google Classroom and invite participants
- [ ] Zoom link for recording including breakout rooms on training-zoom user
- [ ] Organize exercise slides in main presentation
- [ ] Prepare workspace (Phase B) - technical connection (MCP)
- [ ] Execute Scenario for Group 1 exercises
- [ ] Execute Scenario for Group 2 exercises
- [ ] Execute Scenario for Group 3 exercises
- [ ] Deliver training module 3 - level-up
- [ ] Deliver training module 4 - spec-kit

### Phase 3 - Embedded Execution (Weeks 4-5)

- [ ] Define sprint or timebox schedule
- [ ] Open separate Repositories for Directives (by teams/stacks)
- [ ] Prepare and send Cheat Sheet (reference/commands page) to developers
- [ ] Teach the client's AI-Lead how to use levelup
- [ ] Decide on using adlc-spec-kit
- [ ] Schedule regular Huddle meetings (2x per week, 30 min)

### Phase 4 - Handover & ROI (Week 6)

- [ ] Send updated Baseline survey to developers
- [ ] Summarize process including comparison between baseline surveys
- [ ] Invite new developers to Google Classroom (if needed)
- [ ] Coordinate and define work framework (Scoping) for ongoing support
- [ ] Close/transition Slack channel

---

## Sync Meeting Templates

### 1. Kickoff Meeting (Phase 1)

```
📅 [Date] | Kickoff Meeting - [Client Name]
👥 Attendees: [Tikal: ...] [Client: ...]

--- Agenda ---
1. Alignment
   - Present methodology (Agentic SDLC / 12 Factors)
   - Map Tech Stack & AI Maturity for each team/persona
   - Define Success Metrics / KPIs

2. Logistics Planning
   - Workshop dates (4 sessions x 3 hours)
   - Format: Physical / Online / Hybrid
   - Language: Hebrew / English

3. Access and Tools
   - GitHub/GitLab access (Read Only)
   - Existing AI licenses (Claude/Copilot/ChatGPT)
   - IDE check (Cursor/VS Code/IntelliJ)

--- Decisions ---
- [...]

--- Action Items ---
Tikal Responsible:
- [ ] ...
Client Responsible:
- [ ] ...

--- Next Meeting Date ---
[...]
```

---

### 2. Workshop Prep Meeting (Phase 1→2)

```
📅 [Date] | Workshop Prep - [Client Name]
👥 Attendees: [Tikal team only]

--- Agenda ---
1. Phase 1 Tasks Status
   - [ ] Code Access - received?
   - [ ] Baseline Survey - distributed/completed?
   - [ ] Directives repo - set up?
   - [ ] Scenarios - prepared?

2. Workshop Role Assignment
   - Lead (main presenter): [...]
   - Support/Shadow (technical support, breakout rooms): [...]

3. Exercise Scenarios Review
   - Group 1: [description + repo]
   - Group 2: [description + repo]
   - Group 3: [description + repo]

4. Logistics
   - [ ] Zoom links + Breakout rooms
   - [ ] Google Classroom ready
   - [ ] Presentation updated
```

---

### 3. Phase 3 Setup Meeting (Phase 2→3)

```
📅 [Date] | Phase 3 Setup - [Client Name]
👥 Attendees: [Tikal + Client Tech Leads]

--- Agenda ---
1. Workshops Recap
   - What worked well?
   - What needs strengthening?

2. Sprint/Timebox Definition
   - Sprint scope
   - Recommendation: Reduce Capacity by 15-20%
   - Process exceptions (teams/people not participating)

3. Directives Architecture
   - Single repo or split by teams?
   - Update mechanism: Tags + ZIP vs. Submodules
   - Who is the Curator for each repo?

4. Huddle Meeting Schedule
   - Fixed days and times (recommended: Mon + Wed, 17:30, 30 min)

5. Cheat Sheet Preparation for Developers
   - Setup process
   - Quick mode vs. Spec mode
   - Common commands

--- Decisions ---
- [...]

--- Action Items ---
Tikal Responsible:
- [ ] Send Huddle meeting invites
- [ ] Prepare and send Cheat Sheet
- [ ] Push initial settings to Directives repos
Client Responsible:
- [ ] Open separate repos (if decided)
- [ ] Define sprint scope
- [ ] Grant write permissions to Directives repos
```

---

### 4. Huddle (Phase 3 - Recurring Twice Weekly)

```
📅 [Date] | Huddle #[X] - [Client Name]

--- Status by Team ---
Team [A]:
- [ ] Started working with the tools?
- [ ] Bugs/blockers encountered?
- [ ] Directives updates needed?

Team [B]:
- [ ] ...

--- Technical Issues Raised ---
1. [Problem description + proposed solution]
2. [...]

--- Directives Updates ---
- [ ] New Rules to add
- [ ] Skills identified from developers' work
- [ ] Constitution needs update?

--- Action Items ---
- [ ] ...

--- Next Meeting ---
[Date + Time]
```

---

### 5. Handover Meeting (Phase 4)

```
📅 [Date] | Handover - [Client Name]
👥 Attendees: [Tikal + Leadership + Tech Leads]

--- Agenda ---
1. Success Measurement
   - Baseline comparison (before vs. after)
   - Toil Reduction (hours saved)
   - AI Trust & Confidence Delta
   - Maturity Progression (Level 1-2 → Level 5-6)

2. Deliverables Summary
   - team-ai-directives repo(s) - current state
   - Google Classroom - available materials
   - Rules/Skills created

3. Support and Continuation
   - Slack channel - remains open for [X] weeks
   - Support structure (Subscription)
   - Who is the internal AI Lead?

4. Future Expansion (Optional)
   - Product Engineering flow
   - Additional teams/departments
   - Additional tools

--- Decisions ---
- [...]

--- Completion Tasks ---
- [ ] Send updated baseline survey
- [ ] Prepare ROI report
- [ ] Transfer repo ownership
- [ ] Close Slack channel (end of support period)
```

---

## Lessons Learned & Guidelines

### From Precise and IVIX Experience:

1. **Resistance - Handle Humbly** (Shira's lesson from Precise): Senior developers may initially resist. Don't force - prove value through demonstration.

2. **Cognitive Overload** (CytoReason lesson): Don't flood everything at once. Teach spec-driven as a concept first, then add CLI and Git workflows later.

3. **Minimalist Constitution**: The Constitution must remain short and precise. Specific rules belong in Rules, not Constitution.

4. **Branch Names**: Add explicit rule for branch naming format in Constitution/Rules to prevent non-determinism.

5. **Automated Commits**: Ensure Git/Extension settings prevent automated commits.

6. **Personas and Scenarios**: Tailor exercises to the client's actual code, not generic scenarios.

7. **Allies (Champions)**: Identify strong developers early and turn them into internal ambassadors.

8. **Submodules vs. Tags**: Prefer Tags + ZIP over Submodules - simpler for developers.

9. **Google Classroom**: Ensure participants enter through Classroom, not direct links.

10. **Sprint Capacity**: Recommend client reduce capacity by 15-20% in the first sprint.

---

## Scenario Creation Process - Prompt Recipe

### Phase A: Code Scanning (`levelup init`)

**Action**: Run `level up init` on the client's workspace

```bash
levelup init
```

**Reference**: Based on workshop document (`@[client]-workshop.md`)

**Output**: `cdr.md` file with patterns identified from code

---

### Phase B: Creating Mission Brief

Use the following prompt:

```
I need to create a new Mission Brief for the objective: 
"[ONE PARAGRAPH SCENARIO DESCRIPTION]"


1. Propose a one-sentence Goal.
2. Measurable Success Criteria.
3. Define the key Constraints (e.g., must utilize existing reporting building blocks, ensure secure scheduling execution). 
4. Using web search, research best practices for this task. 
5. Help me choose the best components from our team's library for the Context Packet using @[client]-team-ai-directives/ (suggest an [Angular/Django/React/.NET/etc] persona, relevant style guides and a high-quality example).
6. Output the final result in a file named `mission-brief.md` 
```

**Example from Precise**:
```
"Implement a Report Templates and Scheduling mechanism in the Law-yal Billing system. 
Create a Django model to save report configurations (columns, filters, grouping) and 
scheduling rules, and build an Angular UI for users to create, save, and schedule these templates."
```

---

### Phase C: Creating Execution Plan (Plan)

Use the following prompt:

```
Generate a detailed step-by-step execution plan based on the `mission-brief.md`.


1. Break down the tasks across the [BACKEND] (e.g., Django models, scheduling logic) and [FRONTEND] (e.g., Angular dynamic template builder UI).
2. For each step, tag it as either [SYNC] (Interactive design of the dynamic template schema) or [ASYNC] (Delegated to Agent for boilerplate CRUD/Scheduling setup) and briefly explain why.
3. Format the output as a Markdown Checklist (using `- [ ]`) inside a code block.
4. Output the final result in a file named `plan.md` 
```

---

### Phase D: Risk-Based Tests

Use the following prompt:

```
Generate risk-based tests for `plan.md`.


The main risk: "[RISK DESCRIPTION - e.g.: The scheduling mechanism might fail or send reports to the wrong users, and the dynamic JSON configuration for the templates might break the Angular UI if parsed incorrectly.]"


Focus on:
1. Writing a [BACKEND FRAMEWORK] unit test to ensure [RISK AREA 1].
2. Writing a [FRONTEND FRAMEWORK] test to verify [RISK AREA 2].
3. Output the final result in a file named `risk-based-tests.md` 
```

---

### Phase E: Documentation (Trace Summary)

At the end of working on the scenario, use the following prompt:

```
The work for the "[FEATURE NAME]" feature is complete. Draft a Trace Summary including: 
1. Problem: A brief summary of the initial goal. 
2. Key Decisions: Outline choices made (e.g., how the dynamic JSON schema is stored in Django, state management in Angular for the builder, scheduling execution method). 
3. Final Solution: Briefly describe the final outcome.
4. Output the final result in a file named `trace-log.md` 
```

---

### Phase F: Multi-Persona Replication

To create scenarios for each persona based on a template document:

```
based on the scenarios tab in google doc id [SCENARIOS_DOC_ID] 
per persona create for me a new google doc with each persona in a tab 
using the precise document [TEMPLATE_DOC_ID] as a template, 
keep formats and styling
```

**Notes**:
- `[SCENARIOS_DOC_ID]` = Google Doc ID with the "scenarios" tab
- `[TEMPLATE_DOC_ID]` = Template document ID (e.g., Precise document)

---

## Example Timeline - Precise

| Date | Event |
|------|-------|
| Feb 16 | Initial sales meeting |
| Mar 2 | Kickoff |
| Mar 8-16 | Workshops (4 sessions) |
| Mar-Apr | Break due to security situation |
| Apr 23 - May 13 | Phase 3 Huddles (twice weekly) |
| May 24 | Final Handover |

> **Note**: Precise took longer than 6 weeks due to a security break. The standard timeline is 6 consecutive weeks.

---

## Recommended Reference Documents

- [The Twelve-Factor Agentic SDLC - Guide Tab](https://docs.google.com/document/d/1qH8wjVQr5anMRcGY74IvTQiLeS5E6CgcH28q_IH5ic4)
- [Precise Tab - Full Example](https://docs.google.com/document/d/1qH8wjVQr5anMRcGY74IvTQiLeS5E6CgcH28q_IH5ic4)
- [IVIX Tab - In-Progress Example](https://docs.google.com/document/d/1qH8wjVQr5anMRcGY74IvTQiLeS5E6CgcH28q_IH5ic4)

---

**Created**: [Date]  
**By**: [AI Lead Name]  
**Based on**: Launchpad Template v1.0
