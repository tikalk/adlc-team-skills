# Usability Perspective: [SUB_SYSTEM_NAME]

**Sub-System**: [SUB_SYSTEM_NAME]
**ADRs Referenced**: [ADR_IDS]
**Generated**: [DATE]

---

## Applicability (Rozanski & Woods)

> The ease with which people who interact with the system can work effectively.

**Include this perspective when:**
- System has significant user interaction (web, mobile applications)
- User experience is a competitive differentiator
- System is customer-facing or directly used by end users
- Usability affects user adoption or success

**Skip this perspective when:**
- API-only or machine-to-machine systems
- Internal CLI tools with limited UI
- Systems where ease of use is not a concern

## View Applicability

| View | Usability Concerns |
|------|---------------------|
| Context | User base characteristics |
| Functional | User workflows, task completion |
| Information | Data presentation |
| Concurrency | N/A for this perspective |
| Development | UX testing, design systems |
| Deployment | N/A for this perspective |
| Operational | Usage analytics, feedback collection |

## Integration

When generating views (especially Context and Functional), add a **Usability Considerations** subsection if this perspective applies.

---

## Usability Perspective

### User Characteristics

| Characteristic | Assessment | Design Implications |
|----------------|------------|---------------------|
| Technical level | [Low/Medium/High] | [Complexity tolerance] |
| Frequency of use | [Occasional/Regular/Power] | [Learning curve considerations] |
| Task complexity | [Simple/Complex] | [Information architecture] |
| Time pressure | [Low/High] | [Efficiency considerations] |

### Usability Requirements

| Requirement | Target | Measurement |
|--------------|--------|-------------|
| Task completion rate | [Target%] | [User testing] |
| Time to complete task | [Target] | [User testing] |
| Error rate | [Target%] | [Analytics] |
| User satisfaction | [Target score] | [Surveys] |

### Design Principles

- **Consistency**: [UI patterns, interaction patterns]
- **Feedback**: [Confirmation, progress indicators]
- **Error Handling**: [Clear messages, recovery paths]
- **Efficiency**: [Shortcuts for power users]
- **Accessibility**: [See Accessibility perspective if applicable]

### User Research

| Activity | Findings | Design Impact |
|----------|----------|----------------|
| [Research 1] | [Findings] | [Design impact] |

---

**ADR Traceability:**

| ADR | Decision | Impact on Usability |
|-----|----------|--------------------|
| [ADR-XXX] | [Decision] | [How it affects user experience] |