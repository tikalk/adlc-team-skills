# Accessibility Perspective: [SUB_SYSTEM_NAME]

**Sub-System**: [SUB_SYSTEM_NAME]
**ADRs Referenced**: [ADR_IDS]
**Generated**: [DATE]

---

## Applicability (Rozanski & Woods)

> The ability of the system to be used by people with disabilities.

**Include this perspective when:**
- System is public-facing or used by external users
- System has accessibility compliance requirements (WCAG, ADA, Section 508)
- Users may have visual, hearing, motor, or cognitive disabilities
- Mobile applications or web applications

**Skip this perspective when:**
- Internal backoffice systems with no external user access
- Command-line interfaces or APIs only
- Systems where accessibility is not a requirement

## View Applicability

| View | Accessibility Concerns |
|------|------------------------|
| Context | User diversity, assistive technology needs |
| Functional | Clear interaction patterns, keyboard navigation |
| Information | Screen reader compatible content structure |
| Concurrency | N/A for this perspective |
| Development | Semantic HTML, ARIA attributes, accessible components |
| Deployment | N/A for this perspective |
| Operational | Accessibility testing, audit processes |

## Integration

When generating views (especially Context and Functional), add an **Accessibility Considerations** subsection if this perspective applies.

---

## Accessibility Perspective

### Accessible Design Requirements

- **WCAG Level**: [A, AA, or AAA]
- **Screen Reader Support**: [Yes/No]
- **Keyboard Navigation**: [Yes/No - All interactions]
- **Color Contrast**: [Minimum ratio, e.g., 4.5:1]
- **Text Scaling**: [Supports up to 200%]

### Assistive Technology Compatibility

| Technology | Support Level | Notes |
|------------|---------------|-------|
| Screen Readers | [Full/Partial/None] | [Details] |
| Voice Recognition | [Full/Partial/None] | [Details] |
| Switch Controls | [Full/Partial/None] | [Details] |
| Magnification | [Full/Partial/None] | [Details] |

### Accessibility Testing

- **Automated Testing**: [Tools and frequency]
- **Manual Testing**: [Frequency and testers]
- **User Testing**: [Include users with disabilities]

---

**ADR Traceability:**

| ADR | Decision | Impact on Accessibility |
|-----|----------|----------------------|
| [ADR-XXX] | [Decision] | [How it affects accessibility] |