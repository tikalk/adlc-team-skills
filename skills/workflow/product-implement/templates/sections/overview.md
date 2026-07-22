<!-- 
TEMPLATE COMPLIANCE v1.5.2 - THIS IS A TEMPLATE, MUST BE FILLED:
✓ Use Mermaid diagrams (NOT ASCII art)
✓ Fill ALL [PLACEHOLDERS] with actual content
✓ Trace content to source PDRs
✓ Validate with: ./scripts/validate-prd.sh --strict
NOTE: In final PRD, this becomes Section 2 (after Executive Summary and Document Info)
-->

# Overview: [FEATURE_AREA_NAME]

**Feature Area**: [FEATURE_AREA_NAME]
**PDRs Referenced**: [PDR_IDS]
**Generated**: [DATE]
**Section Number**: 2 (in final PRD)

---

## 2. Overview

**Purpose**: High-level description of the product - what it is and why it exists

### 2.1 Product Description

[High-level description derived from Problem PDRs and Vision/Constitution]

### 2.2 Purpose

[Describe the business/technical problem this product solves]

### 2.3 Scope

**In Scope:**

- [Core capability 1]
- [Core capability 2]

**Out of Scope:**

- [Explicitly excluded capability 1]
- [Explicitly excluded capability 2]

---

**PDR Traceability:**

| PDR | Category | Impact on Overview |
|-----|----------|-------------------|
| [PDR-XXX] | Problem | [How it affects this section] |
| [PDR-XXX] | Business Model | [How it affects this section] |

### 2.4 Feature Hierarchy

Visual representation of the product's feature areas and their relationships:

```mermaid
flowchart TD
    Product["[PRODUCT_NAME]"]
    
    Product --> FA1["[Feature Area 1]"]
    Product --> FA2["[Feature Area 2]"]
    Product --> FA3["[Feature Area 3]"]
    
    FA1 --> F1A["[Feature 1A]"]
    FA1 --> F1B["[Feature 1B]"]
    
    FA2 --> F2A["[Feature 2A]"]
    FA2 --> F2B["[Feature 2B]"]
    
    FA3 --> F3A["[Feature 3A]"]
    FA3 --> F3B["[Feature 3B]"]
```

### 2.5 Architecture Overview

Visual representation of the system architecture:

```mermaid
flowchart TB
    subgraph "Frontend Layer"
        Web["🌐 Web App"]
        Mobile["📱 Mobile App"]
        Admin["🔧 Admin Panel"]
    end
    
    subgraph "API Gateway"
        Gateway["🔀 API Gateway<br/>Auth/Rate Limiting"]
    end
    
    subgraph "Backend Services"
        AuthSvc["🔐 Auth Service"]
        CoreSvc["👤 Core Service"]
        BusinessSvc["💳 Business Service"]
        GrowthSvc["📈 Growth Service"]
    end
    
    subgraph "Data Layer"
        DB[("📦 Primary DB")]
        Cache[("⚡ Cache")]
        Queue[("📨 Message Queue")]
    end
    
    subgraph "External"
        ThirdParty["🔗 Third-Party APIs"]
        CDN["🚀 CDN"]
    end
    
    Web --> Gateway
    Mobile --> Gateway
    Admin --> Gateway
    
    Gateway --> AuthSvc
    Gateway --> CoreSvc
    Gateway --> BusinessSvc
    Gateway --> GrowthSvc
    
    AuthSvc --> DB
    CoreSvc --> DB
    CoreSvc --> Cache
    BusinessSvc --> DB
    BusinessSvc --> Queue
    GrowthSvc --> DB
    GrowthSvc --> Queue
    
    BusinessSvc --> ThirdParty
    Web --> CDN
    Mobile --> CDN
    
    classDef frontend fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef gateway fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef backend fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px
    classDef data fill:#f3e5f5,stroke:#6a1b9a,stroke-width:2px
    classDef external fill:#fce4ec,stroke:#c2185b,stroke-width:2px
    
    class Web,Mobile,Admin frontend
    class Gateway gateway
    class AuthSvc,CoreSvc,BusinessSvc,GrowthSvc backend
    class DB,Cache,Queue data
    class ThirdParty,CDN external
```

**Architecture Notes**:
- Frontend layer serves multiple client types
- API Gateway handles cross-cutting concerns
- Backend services are organized by feature area
- Data layer provides persistence and messaging
- External integrations are abstracted behind service layer

### 2.6 Cross-Area Interactions

<!-- CONDITIONAL: Include when product has multiple feature areas with dependencies -->

| Feature Area A | Feature Area B | Interaction Type | Description |
|----------------|----------------|------------------|-------------|
| [Area 1] | [Area 2] | [Data flow / Event / Shared service] | [How they interact] |
| [Area 2] | [Area 3] | [Data flow / Event / Shared service] | [How they interact] |
