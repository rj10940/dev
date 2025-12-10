# Cloudways Developer Environment

A Docker-based multi-developer environment that replicates the full Cloudways platform architecture, allowing each developer to have isolated services with their own branch configurations on a shared host.

---

## Cloudways Platform Architecture

### High-Level System Overview

```mermaid
flowchart TB
    subgraph Users["End Users"]
        Customer[Customer Browser]
        API_Client[API Client]
    end

    subgraph Frontend["Frontend Layer"]
        PUI[platformui-frontend<br/>React + TypeScript]
        Legacy[cg-console-new<br/>Laravel + AngularJS]
    end

    subgraph Gateway["API Gateway"]
        Traefik[Traefik<br/>Reverse Proxy]
    end

    subgraph Middleware["Middleware Layer"]
        CGApi[cg-apiserver<br/>CodeIgniter 2.x<br/>Operations & Steps]
        FlexMW[flexible-middleware<br/>Laravel 10<br/>Modern API]
        FMOE[flexible-operation-engine<br/>Laravel Horizon<br/>Queue Workers]
    end

    subgraph Backend["Backend Services"]
        Ansible[ansible-api-v2<br/>Flask + Celery<br/>Server Automation]
        Events[cg-event-service<br/>Node.js<br/>Analytics Events]
        Comms[cg-comms-service<br/>Laravel<br/>Alerts & Notifications]
    end

    subgraph Playbooks["Ansible Playbooks"]
        AnsServer[ansible-cg-server<br/>Server Provisioning]
        AnsServerOther[ansible-cg-server-other<br/>Server Operations]
        AnsApps[ansible-cg-php-apps<br/>App Provisioning]
        AnsAppsOther[ansible-cg-php-apps-other<br/>App Operations]
    end

    subgraph DataStores["Data Stores"]
        MySQL[(MySQL 8.0<br/>Primary DB)]
        Redis[(Redis 7<br/>Cache & Queues)]
        PostgreSQL[(PostgreSQL 15<br/>Events DB)]
    end

    subgraph CloudProviders["Cloud Providers"]
        DO[DigitalOcean]
        AWS[Amazon AWS]
        GCE[Google Cloud]
        Vultr[Vultr]
        Linode[Linode]
    end

    subgraph CustomerServers["Customer Servers"]
        Server1[Customer Server 1]
        Server2[Customer Server 2]
        ServerN[Customer Server N]
    end

    Customer --> Traefik
    API_Client --> Traefik
    Traefik --> PUI
    Traefik --> Legacy
    PUI --> Legacy
    Legacy --> FlexMW
    Legacy --> CGApi
    FlexMW --> FMOE
    CGApi --> Ansible
    FMOE --> Ansible
    Legacy --> Events
    Legacy --> Comms
    FlexMW --> Redis
    CGApi --> MySQL
    FlexMW --> MySQL
    FMOE --> MySQL
    FMOE --> Redis
    Events --> PostgreSQL
    Events --> Redis
    Ansible --> AnsServer
    Ansible --> AnsApps
    Ansible --> CloudProviders
    AnsServer --> CustomerServers
    AnsApps --> CustomerServers
```

---

### Request Flow: Server Provisioning

```mermaid
sequenceDiagram
    autonumber
    participant User as Customer
    participant UI as Platform UI
    participant API as cg-console-new
    participant MW as cg-apiserver
    participant Queue as Redis Queue
    participant FMOE as Operation Engine
    participant Ansible as ansible-api-v2
    participant Cloud as Cloud Provider
    participant Server as New Server

    User->>UI: Click "Launch Server"
    UI->>API: POST /server/create
    API->>API: Validate request
    API->>MW: Create server operation
    MW->>MW: Create operation record
    MW->>MW: Generate steps with dependencies
    MW->>Queue: Push steps to queue
    
    loop Process Steps
        FMOE->>Queue: Poll for ready steps
        Queue-->>FMOE: Return step
        FMOE->>FMOE: Execute step logic
        
        alt Cloud Step
            FMOE->>Cloud: Create VM instance
            Cloud-->>FMOE: Instance ID
        else Ansible Step
            FMOE->>Ansible: POST /server/provision
            Ansible->>Server: Run playbook
            Server-->>Ansible: Result
            Ansible-->>FMOE: Callback
        end
        
        FMOE->>MW: Update step state
    end
    
    MW->>API: Operation complete
    API->>UI: Server ready
    UI->>User: Show success
```

---

### Operation & Step Processing

```mermaid
flowchart LR
    subgraph Operations["Operations"]
        Op1[ADD_SERVER]
        Op2[CLONE_SERVER]
        Op3[ADD_APP]
        Op4[BACKUP]
    end

    subgraph Steps["Step Types"]
        S1[CREATE_INSTANCE]
        S2[CHECK_PORT]
        S3[EXECUTE_SCRIPT]
        S4[INSTALL_APP]
        S5[ALLOW_SENSU]
    end

    subgraph States["Step States"]
        NOT_STARTED
        PENDING
        CONFIRMED
        ERROR
        ERROR_IGNORED
    end

    subgraph Queue["Queue System"]
        ActionQ[Action Queue<br/>Execute Steps]
        WaiterQ[Waiter Queue<br/>Check Results]
    end

    Op1 --> S1
    Op1 --> S2
    Op1 --> S3
    Op1 --> S4
    Op1 --> S5

    S1 --> NOT_STARTED
    NOT_STARTED --> ActionQ
    ActionQ --> PENDING
    PENDING --> WaiterQ
    WaiterQ --> CONFIRMED
    WaiterQ --> ERROR
```

---

### Service Dependencies

```mermaid
flowchart TD
    subgraph Core["Core Services"]
        Platform[cg-console-new<br/>Port 5000]
        Middleware[cg-apiserver<br/>Port 8000]
        Flexible[flexible-middleware<br/>Port 8081]
    end

    subgraph Workers["Background Workers"]
        FMOE[flexible-operation-engine<br/>Horizon Workers]
        PlatformWorker[Platform Queue Worker]
        MWWorker[Middleware Cron]
    end

    subgraph External["External Services"]
        Ansible[ansible-api-v2<br/>Port 5000]
        Events[cg-event-service<br/>Port 3000]
        Comms[cg-comms-service<br/>Port 8082]
    end

    subgraph Data["Data Layer"]
        MySQL[(MySQL)]
        Redis[(Redis)]
        Postgres[(PostgreSQL)]
    end

    Platform -->|API calls| Middleware
    Platform -->|API calls| Flexible
    Platform -->|Events| Events
    Platform -->|Alerts| Comms
    
    Middleware -->|Ansible calls| Ansible
    Flexible -->|Ansible calls| Ansible
    FMOE -->|Ansible calls| Ansible
    
    Platform --> MySQL
    Middleware --> MySQL
    Flexible --> MySQL
    FMOE --> MySQL
    
    Platform --> Redis
    Flexible --> Redis
    FMOE --> Redis
    Events --> Redis
    
    Events --> Postgres
```

---

## Developer Environment Architecture

### Multi-Developer Setup

```mermaid
flowchart TB
    subgraph Droplet["DigitalOcean Droplet - 16GB+ RAM"]
        subgraph Traefik["Traefik Reverse Proxy :80/:443"]
            Router[Domain Router]
        end

        subgraph Shared["Shared Infrastructure"]
            MySQL[(MySQL 8.0<br/>:3306)]
            Redis[(Redis 7<br/>:6379)]
            Postgres[(PostgreSQL 15<br/>:5432)]
            Adminer[Adminer<br/>:8081]
        end

        subgraph DevRahul["Developer: rahul"]
            RP[rahul-platform]
            RM[rahul-middleware]
            RF[rahul-flexible]
            RA[rahul-ansible]
            RFM[rahul-fmoe]
        end

        subgraph DevJohn["Developer: john"]
            JP[john-platform]
            JM[john-middleware]
            JF[john-flexible]
            JA[john-ansible]
            JFM[john-fmoe]
        end

        subgraph DevSarah["Developer: sarah"]
            SP[sarah-platform]
            SM[sarah-middleware]
            SF[sarah-flexible]
        end
    end

    Internet((Internet))
    
    Internet -->|rahul.dev.cw.local| Router
    Internet -->|john.dev.cw.local| Router
    Internet -->|sarah.dev.cw.local| Router
    
    Router --> RP
    Router --> JP
    Router --> SP
    
    RP --> MySQL
    JP --> MySQL
    SP --> MySQL
    
    RP --> Redis
    JP --> Redis
    SP --> Redis
```

---

### Database Isolation Strategy

```mermaid
flowchart LR
    subgraph MySQL["MySQL Server"]
        subgraph RahulDBs["Rahul's Databases"]
            RDB1[(cw_rahul_platform)]
            RDB2[(cw_rahul_middleware)]
        end
        
        subgraph JohnDBs["John's Databases"]
            JDB1[(cw_john_platform)]
            JDB2[(cw_john_middleware)]
        end
        
        subgraph SarahDBs["Sarah's Databases"]
            SDB1[(cw_sarah_platform)]
            SDB2[(cw_sarah_middleware)]
        end
    end
    
    subgraph Redis["Redis Server"]
        RK[rahul:* keys]
        JK[john:* keys]
        SK[sarah:* keys]
    end
    
    RP[rahul-platform] --> RDB1
    RM[rahul-middleware] --> RDB2
    RP --> RK
    
    JP[john-platform] --> JDB1
    JM[john-middleware] --> JDB2
    JP --> JK
```

---

### Branch Management Flow

```mermaid
flowchart TD
    subgraph Config["Developer Config: rahul.yml"]
        Branches["branches:<br/>  cg-console-new: feature/dashboard<br/>  cg-apiserver: develop<br/>  flexible-middleware: main"]
    end

    subgraph Repos["Shared Repositories"]
        R1[cg-console-new<br/>All branches available]
        R2[cg-apiserver<br/>All branches available]
        R3[flexible-middleware<br/>All branches available]
    end

    subgraph Containers["Rahul's Containers"]
        C1[rahul-platform<br/>feature/dashboard]
        C2[rahul-middleware<br/>develop]
        C3[rahul-flexible<br/>main]
    end

    Config -->|dev-env.sh create| Repos
    Repos -->|git checkout| C1
    Repos -->|git checkout| C2
    Repos -->|git checkout| C3
    
    subgraph Update["Branch Update"]
        CLI[dev-env.sh update-branch<br/>rahul cg-console-new feature/new]
        Git[git fetch && checkout]
        Restart[docker restart]
    end
    
    CLI --> Git --> Restart
```

---

### Container Communication

```mermaid
flowchart TB
    subgraph Network["Docker Network: cw-shared"]
        subgraph Developer["rahul's containers"]
            Platform["rahul-platform<br/>APP_API_SERVER=http://rahul-middleware"]
            Middleware["rahul-middleware<br/>ANSIBLE_HOST=http://rahul-ansible:5000"]
            Flexible["rahul-flexible<br/>PLATFORM_API_URL=http://rahul-platform"]
            Ansible["rahul-ansible<br/>DB_HOST=shared-mysql"]
            FMOE["rahul-fmoe<br/>MIDDLEWARE_URL=http://rahul-flexible"]
        end

        subgraph Shared["Shared Services"]
            MySQL["shared-mysql:3306"]
            Redis["shared-redis:6379"]
            Postgres["shared-postgres:5432"]
        end
    end

    Platform -->|HTTP| Middleware
    Platform -->|HTTP| Flexible
    Middleware -->|HTTP| Ansible
    Flexible -->|HTTP| Ansible
    FMOE -->|HTTP| Ansible
    FMOE -->|HTTP| Flexible

    Platform --> MySQL
    Middleware --> MySQL
    Flexible --> MySQL
    Ansible --> MySQL
    FMOE --> MySQL

    Platform --> Redis
    Flexible --> Redis
    FMOE --> Redis
```

---

## Repository Overview

| Repository | Technology | Purpose |
|------------|------------|---------|
| `cg-console-new` | Laravel 5.2 + AngularJS | Main platform backend & legacy UI |
| `cg-apiserver` | CodeIgniter 2.x | Middleware - operations & cloud integrations |
| `flexible-middleware` | Laravel 10 | Modern API layer |
| `flexible-operation-engine` | Laravel + Horizon | Background job processing |
| `ansible-api-v2` | Python Flask + Celery | Ansible automation API |
| `cg-event-service` | Node.js + Express | Analytics event processing |
| `cg-comms-service` | Laravel/Lumen | Alerts & notifications |
| `platformui-frontend` | React + TypeScript | Modern React UI |
| `ansible-cg-server` | Ansible Playbooks | Server provisioning roles |
| `ansible-cg-php-apps` | Ansible Playbooks | Application provisioning |

---

## Quick Start

```bash
# 1. Setup the droplet (run on fresh DigitalOcean droplet)
sudo ./scripts/setup-droplet.sh

# 2. Generate deploy key for GitHub
sudo ./scripts/generate-deploy-key.sh

# 3. Add the deploy key to GitHub (see output from step 2)

# 4. Clone all repositories
./scripts/clone-repos.sh

# 5. Start shared services (MySQL, Redis, PostgreSQL, Traefik)
docker compose -f shared/docker-compose.yml up -d

# 6. Create your developer environment
./scripts/dev-env.sh create <your-name>
```

---

## Directory Structure

```
/opt/cloudways-dev/
├── keys/                           # SSH deploy keys
│   ├── github_deploy_key
│   └── config
├── developers/                     # Per-developer config files
│   ├── rahul.yml
│   └── john.yml
├── repos/                          # Cloned repositories (shared)
│   ├── cg-console-new/
│   ├── cg-apiserver/
│   ├── flexible-middleware/
│   └── ...
├── shared/                         # Shared infrastructure
│   ├── docker-compose.yml
│   ├── mysql-init/
│   └── postgres-init/
├── scripts/                        # CLI tools
│   ├── dev-env.sh                  # Main CLI
│   ├── setup-droplet.sh
│   ├── generate-deploy-key.sh
│   └── clone-repos.sh
├── docker-compose.template.yml     # Service template
└── docker-compose.<developer>.yml  # Generated per developer
```

---

## CLI Commands

| Command | Description |
|---------|-------------|
| `./scripts/dev-env.sh create <name>` | Create new developer environment |
| `./scripts/dev-env.sh destroy <name>` | Remove developer environment |
| `./scripts/dev-env.sh update-branch <name> <repo> <branch>` | Update branch for a repo |
| `./scripts/dev-env.sh pull <name>` | Pull latest code for all repos |
| `./scripts/dev-env.sh status [name]` | Show environment status |
| `./scripts/dev-env.sh logs <name> [service]` | Show container logs |
| `./scripts/dev-env.sh restart <name> [service]` | Restart services |
| `./scripts/dev-env.sh exec <name> <service> <cmd>` | Execute command in container |

---

## Developer Configuration

Each developer has a YAML config file in `developers/`:

```yaml
developer: rahul
email: rahul@cloudways.com

branches:
  cg-console-new: feature/new-dashboard
  cg-apiserver: develop
  flexible-middleware: main
  flexible-operation-engine: main
  ansible-api-v2: master
  cg-event-service: main
  cg-comms-service: main

environment:
  APP_DEBUG: "true"
```

---

## Access URLs

| Service | URL |
|---------|-----|
| Platform UI | `http://<dev>.dev.cw.local` |
| API | `http://api-<dev>.dev.cw.local` |
| Flexible MW | `http://flexible-<dev>.dev.cw.local` |
| Traefik Dashboard | `http://DROPLET_IP:8080` |
| Adminer (DB) | `http://DROPLET_IP:8081` |

Add to your local `/etc/hosts`:
```
DROPLET_IP  rahul.dev.cw.local api-rahul.dev.cw.local flexible-rahul.dev.cw.local
```

---

## Requirements

- **DigitalOcean Droplet**: 16GB+ RAM recommended
- **Docker**: 20.10+
- **Docker Compose**: v2
- **yq**: YAML processor
- **jq**: JSON processor
