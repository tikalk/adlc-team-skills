# Internationalization Perspective: [SUB_SYSTEM_NAME]

**Sub-System**: [SUB_SYSTEM_NAME]
**ADRs Referenced**: [ADR_IDS]
**Generated**: [DATE]

---

## Applicability (Rozanski & Woods)

> The ability of the system to be independent from any particular language, country, or cultural group.

**Include this perspective when:**
- System supports multiple languages
- System operates in multiple regions or countries
- System serves culturally diverse user bases
- System needs to comply with local regulations in different countries

**Skip this perspective when:**
- System is used in a single locale only
- No multi-language requirements

## View Applicability

| View | Internationalization Concerns |
|------|-------------------------------|
| Context | Multi-region user base |
| Functional | Localized text, culturally appropriate content |
| Information | Locale-specific data formats |
| Concurrency | N/A for this perspective |
| Development | i18n infrastructure, translation management |
| Deployment | Multi-region deployments |
| Operational | Localized operations, support |

## Integration

When generating views, add an **Internationalization Considerations** subsection if this perspective applies.

---

## Internationalization Perspective

### Language Support

| Language | Locale Code | Status | Launch Target |
|----------|-------------|--------|--------------|
| [LANG_1] | [CODE] | [Complete/In Progress] | [Target] |
| [LANG_2] | [CODE] | [Complete/In Progress] | [Target] |

### Regional Considerations

| Region | Locale-Specific Requirements |
|--------|--------------------------|
| [REGION_1] | [Requirements] |
| [REGION_2] | [Requirements] |

### i18n Implementation

- **Translation Management**: [e.g., gettext, crowdin, lokalise]
- **Locale Detection**: [Method]
- **Date/Time Formats**: [By locale]
- **Number Formats**: [By locale]
- **Currency**: [Multi-currency support]
- **RTL Support**: [Yes/No - Languages]

### Content Considerations

- Text expansion handling (different languages have different lengths)
- Cultural appropriateness (dates, colors, images)
- Time zone handling

---

**ADR Traceability:**

| ADR | Decision | Impact on Internationalization |
|-----|----------|-------------------------------|
| [ADR-XXX] | [Decision] | [How it affects i18n capability] |