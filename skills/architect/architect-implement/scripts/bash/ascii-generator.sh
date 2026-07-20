#!/usr/bin/env bash
# ASCII diagram generator for architecture views
# Generates ASCII art for all 7 Rozanski & Woods architectural views
#
# Core Views (always generated with --views=core):
#   - Context, Functional, Information, Development, Deployment
#
# Optional Views (only with --views=all or --views=concurrency,operational):
#   - Concurrency (3.4)
#   - Operational (3.7)

# Generate Context View diagram (system boundary)
# CRITICAL: System must be shown as a SINGLE BLACKBOX - no internal components
# Only show: Stakeholders (human actors) + External systems (third-party, outside your control)
# DO NOT show: Internal databases, services, caches (those go in Deployment/Functional views)
generate_context_ascii() {
    local system_name="${1:-System}"
    
    cat <<'EOF'
┌─────────────────────────────────────────────────────────────┐
│                     Context View Diagram                     │
│            (System shown as single blackbox)                 │
└─────────────────────────────────────────────────────────────┘

        STAKEHOLDERS                           EXTERNAL SYSTEMS
        ────────────                           ────────────────

    ┌──────────────┐                         ┌────────────────┐
    │    Users     │                         │    Payment     │
    │  (End Users) │                         │   Provider     │
    └──────┬───────┘                         │   (External)   │
           │                                 └───────┬────────┘
           │ Uses                                    │
           │                                         │ Processes
           ▼                                         │ payments
    ┌─────────────────────────────────────────────────────────┐
    │                                                         │
    │                    ┌─────────────────┐                  │
    │                    │                 │                  │
    │                    │     SYSTEM      │◄─────────────────┘
    │                    │   (This App)    │
    │                    │                 │──────────────────┐
    │                    └─────────────────┘                  │
    │                         ▲                               │
    │                         │                               │
    └─────────────────────────│───────────────────────────────┘
                              │ Manages                       │
    ┌──────────────┐          │                               ▼
    │    Admins    │──────────┘                    ┌────────────────┐
    │(Administrators)                              │   Identity     │
    └──────────────┘                               │   Provider     │
                                                   │   (External)   │
                                                   └────────────────┘

Legend:
  ─────►  Data/control flow crossing system boundary
  [SYSTEM] = Single blackbox (internal details in Functional/Deployment views)
  (External) = Third-party services outside your control
EOF
}

# Generate Functional View diagram (component interactions)
generate_functional_ascii() {
    cat <<'EOF'
┌─────────────────────────────────────────────────────────────┐
│                   Functional View Diagram                    │
└─────────────────────────────────────────────────────────────┘

          User Request
               │
               ▼
    ┌──────────────────────┐
    │    API Gateway       │
    └──────────┬───────────┘
               │
        ┏──────┴──────┓
        ▼             ▼
┌───────────────┐  ┌───────────────┐
│ Authentication│  │   Business    │
│    Service    │  │     Logic     │
└───────┬───────┘  └───────┬───────┘
        │                  │
        └──────────┬───────┘
                   ▼
        ┌──────────────────────┐
        │   Data Access Layer  │
        └──────────┬───────────┘
                   │
            ┏──────┴──────┓
            ▼             ▼
    ┌─────────────┐  ┌─────────────┐
    │  Database   │  │    Cache    │
    └─────────────┘  └─────────────┘
EOF
}

# Generate Information View diagram (data entities)
generate_information_ascii() {
    cat <<'EOF'
┌─────────────────────────────────────────────────────────────┐
│                  Information View Diagram                    │
└─────────────────────────────────────────────────────────────┘

┌──────────┐         ┌──────────┐         ┌──────────┐
│   User   │1      n │  Order   │1      n │OrderItem │
├──────────┤◄────────├──────────┤◄────────├──────────┤
│ id (PK)  │         │ id (PK)  │         │ id (PK)  │
│ email    │         │ user_id  │         │ order_id │
│ name     │         │ status   │         │product_id│
│created_at│         │ total    │         │ quantity │
└──────────┘         │created_at│         │ price    │
                     └──────────┘         └────┬─────┘
                                               │
                                               │n
                                               ▼
                                         ┌──────────┐
                                         │ Product  │
                                         ├──────────┤
                                         │ id (PK)  │
                                         │ name     │
                                         │ price    │
                                         │ sku      │
                                         └──────────┘

Key: PK = Primary Key, FK = Foreign Key
     1 = One, n = Many, ◄──── = Relationship
EOF
}

# Generate Concurrency View diagram (process timeline)
# OPTIONAL VIEW: Only generated when --views=all or --views=concurrency
generate_concurrency_ascii() {
    cat <<'EOF'
┌─────────────────────────────────────────────────────────────┐
│                  Concurrency View Diagram                    │
└─────────────────────────────────────────────────────────────┘

User    WebServer   AppServer    Worker    Database
  │         │           │           │          │
  │─Request─>│           │           │          │
  │         │           │           │          │
  │         │─Process──>│           │          │
  │         │           │           │          │
  │         │           │──Query───────────────>│
  │         │           │           │          │
  │         │           │<──Results─────────────│
  │         │           │           │          │
  │         │           │─Queue Job─>│          │
  │         │           │           │          │
  │         │           │           │──Update──>│
  │         │<─Response─│           │          │
  │         │           │           │<─Done────│
  │<─Result─│           │           │          │
  │         │           │           │          │

Processes run concurrently:
- Main Request/Response Flow (vertical)
- Background Worker Processing (parallel)
EOF
}

# Generate Development View diagram (module dependencies)
generate_development_ascii() {
    cat <<'EOF'
┌─────────────────────────────────────────────────────────────┐
│                  Development View Diagram                    │
└─────────────────────────────────────────────────────────────┘

Directory Structure:

project-root/
├── src/
│   ├── api/              ◄─── API Layer (Controllers)
│   │   └── routes/           │
│   │                          │ depends on
│   ├── services/         ◄───┘
│   │   └── business/      ◄─── Services Layer
│   │                          │
│   ├── repositories/          │ depends on
│   │   └── data/          ◄───┘
│   │                       ◄─── Data Access Layer
│   ├── models/                │
│   │   └── entities/      ◄───┘ depends on
│   │                       ◄─── Models (Shared)
│   └── utils/
│       └── helpers/       ◄─── Utilities (Shared)
│
├── tests/
│   ├── unit/
│   ├── integration/
│   └── e2e/
│
└── docs/

Dependency Rules:
- API → Services → Repositories → Models
- No circular dependencies
- Utilities shared across layers
EOF
}

# Generate Deployment View diagram (infrastructure)
generate_deployment_ascii() {
    cat <<'EOF'
┌─────────────────────────────────────────────────────────────┐
│                  Deployment View Diagram                     │
└─────────────────────────────────────────────────────────────┘

                        Internet
                            │
                            ▼
                   ┌────────────────┐
                   │ Load Balancer  │
                   │   (ALB/Nginx)  │
                   └────────┬───────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
┌───────────────┐  ┌───────────────┐  ┌───────────────┐
│  Web Server 1 │  │  Web Server 2 │  │  Web Server 3 │
│   (Public)    │  │   (Public)    │  │   (Public)    │
└───────┬───────┘  └───────┬───────┘  └───────┬───────┘
        │                   │                   │
        └───────────────────┼───────────────────┘
                            │
                            ▼
                   ┌────────────────┐
                   │   App Tier     │
                   │   (Private)    │
                   └────────┬───────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
┌───────────────┐  ┌───────────────┐  ┌───────────────┐
│   Database    │  │  Redis Cache  │  │    Object     │
│   (Primary)   │  │               │  │   Storage     │
│   (Private)   │  │   (Private)   │  │   (S3/Blob)   │
└───────┬───────┘  └───────────────┘  └───────────────┘
        │
        ▼
┌───────────────┐
│   Database    │
│   (Replica)   │
│   (Private)   │
└───────────────┘
EOF
}

# Generate Operational View diagram (operational workflow)
# OPTIONAL VIEW: Only generated when --views=all or --views=operational
generate_operational_ascii() {
    cat <<'EOF'
┌─────────────────────────────────────────────────────────────┐
│                 Operational View Diagram                     │
└─────────────────────────────────────────────────────────────┘

Deployment Workflow:

    START
      │
      ▼
┌──────────────┐
│  Run Tests   │──┐
│  & Build     │  │ Fail
└──────┬───────┘  │
       │ Pass     │
       ▼          │
┌──────────────┐  │
│  Deploy to   │  │
│   Staging    │  │
└──────┬───────┘  │
       │          │
       ▼          │
┌──────────────┐  │
│Run Staging   │──┤ Fail
│    Tests     │  │
└──────┬───────┘  │
       │ Pass     │
       ▼          │
┌──────────────┐  │
│   Manual     │──┤ Reject
│  Approval?   │  │
└──────┬───────┘  │
       │ Approve  │
       ▼          │
┌──────────────┐  │
│  Deploy to   │  │
│ Production   │  │
└──────┬───────┘  │
       │          │
       ▼          │
┌──────────────┐  │
│   Monitor    │  │
│   Health     │  │
└──────┬───────┘  │
       │          │
   ┌───┴───┐      │
   │Healthy│      │
   ▼       ▼      │
  YES      NO     │
   │        │     │
   │   ┌────────┐│
   │   │Rollback││
   │   └────┬───┘│
   │        │    │
   ▼        ▼    ▼
  END    Alert Team

Monitoring: Continuous
Backups: Daily automated
On-call: 24/7 rotation
EOF
}

# Main function to generate diagram for a specific view
# Usage: generate_ascii_diagram "context" "System Name"
generate_ascii_diagram() {
    local view_type="$1"
    local system_name="${2:-System}"
    
    case "$view_type" in
        context)
            generate_context_ascii "$system_name"
            ;;
        functional)
            generate_functional_ascii
            ;;
        information)
            generate_information_ascii
            ;;
        concurrency)
            generate_concurrency_ascii
            ;;
        development)
            generate_development_ascii
            ;;
        deployment)
            generate_deployment_ascii
            ;;
        operational)
            generate_operational_ascii
            ;;
        *)
            echo "Error: Unknown view type '$view_type'" >&2
            return 1
            ;;
    esac
}

# Export functions for use in other scripts
export -f generate_context_ascii
export -f generate_functional_ascii
export -f generate_information_ascii
export -f generate_concurrency_ascii
export -f generate_development_ascii
export -f generate_deployment_ascii
export -f generate_operational_ascii
export -f generate_ascii_diagram
