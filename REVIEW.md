# Review Policy

## Review Passes

### pass: bugs
Description: Bugs and logical errors
Severity: Important
Checks:
- Null/undefined access paths
- Unhandled error paths
- Resource leaks

### pass: security
Description: Security vulnerabilities
Severity: Important
Checks:
- Injection vulnerabilities
- Secret exposure
- Authentication bypass

### pass: spec-compliance
Description: Compliance against design documents
Severity: Important
Checks:
- PRD requirement coverage (docs/adlc/product/PRD.md)
- AD architecture compliance (docs/adlc/architect/AD.md)

### pass: quality
Description: Code quality
Severity: Nit
Checks:
- Naming conventions
- Dead code
- Missing documentation

## Severity Weights
| Severity | Blocks merge? | Triggers fix? |
|----------|---------------|---------------|
| Important | Yes | Yes |
| Nit | No | No |

## Skip Lists
- vendor/
- node_modules/
- dist/
- *.generated.*
- .adlc/
