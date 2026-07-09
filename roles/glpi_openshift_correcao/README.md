README salvo!
# GLPI - Correção de Vulnerabilidades com AAP

Automação para correção de vulnerabilidades via GLPI + OpenShift Virtualization + Ansible Automation Platform (AAP) com workflow de aprovação no Microsoft Teams.

---

## Arquitetura do Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│                     WORKFLOW NO AAP                              │
├─────────────────────────────────────────────────────────────────┤
│  Job 1: Detectar e Notificar                                    │
│  │   Busca tickets do GLPI, detecta pacotes críticos           │
│  │   Envia card no Teams com link de aprovação                 │
│  ▼                                                               │
│  [Approval Node] ←──── PAUSA AQUI                               │
│       │         Você aprova/rejeita na interface web do AAP      │
│       ▼                                                          │
│  Job 2: Snapshot e Update (só roda se aprovado)                 │
│       │   Cria snapshot KubeVirt + dnf update --security       │
│       ▼                                                          │
│  Job 3: Fechar Ticket                                           │
│           Adiciona follow-up e fecha chamado no GLPI             │
└─────────────────────────────────────────────────────────────────┘
```

---

## Estrutura de Arquivos

```
playbooks/
├── glpi-workflow-detectar.yml          # Job 1 - Playbook
├── glpi-workflow-snapshot-update.yml   # Job 2 - Playbook
└── glpi-workflow-fechar.yml            # Job 3 - Playbook

roles/glpi_openshift_correcao/
├── defaults/
│   └── main.yml                        # Variáveis padrão
├── tasks/
│   ├── main.yml                        # Dispatcher (entrypoint)
│   ├── buscar_group_ticket_pagina.yml  # Paginação GLPI API
│   ├── detectar_e_classificar.yml      # Job 1 - Tasks
│   ├── verificar_pacotes_por_ticket.yml# Job 1 - Loop de verificação
│   ├── snapshot_e_update.yml         # Job 2 - Tasks
│   ├── snapshot_update_single.yml      # Job 2 - Processa 1 ticket
│   ├── fechar_no_glpi.yml              # Job 3 - Tasks
│   └── fechar_single.yml               # Job 3 - Fecha 1 ticket
└── templates/
    └── teams_card.json.j2              # Template do card no Teams
```

---

## Playbooks

### glpi-workflow-detectar.yml
Chama a role no modo `detectar_e_classificar`.

```yaml
---
- name: "GLPI Workflow | Job 1 — Detectar e classificar tickets"
  hosts: localhost
  gather_facts: false
  vars_files:
    - roles/glpi_openshift_correcao/defaults/main.yml
  tasks:
    - name: "Executar detectar e classificar"
      ansible.builtin.include_tasks: roles/glpi_openshift_correcao/tasks/detectar_e_classificar.yml
```

### glpi-workflow-snapshot-update.yml
Chama a role no modo `snapshot_e_update`.

```yaml
---
- name: "GLPI Workflow | Job 2 — Snapshot e Update"
  hosts: localhost
  gather_facts: false
  vars_files:
    - roles/glpi_openshift_correcao/defaults/main.yml
  tasks:
    - name: "Executar snapshot e update"
      ansible.builtin.include_tasks: roles/glpi_openshift_correcao/tasks/snapshot_e_update.yml
```

### glpi-workflow-fechar.yml
Chama a role no modo `fechar_no_glpi`.

```yaml
---
- name: "GLPI Workflow | Job 3 — Fechar tickets"
  hosts: localhost
  gather_facts: false
  vars_files:
    - roles/glpi_openshift_correcao/defaults/main.yml
  tasks:
    - name: "Executar fechar no GLPI"
      ansible.builtin.include_tasks: roles/glpi_openshift_correcao/tasks/fechar_no_glpi.yml
```

---

## Configuração no AAP

### 1. Criar 3 Job Templates

| Campo | Job 1 | Job 2 | Job 3 |
|-------|-------|-------|-------|
| **Name** | `GLPI - Detectar e Notificar` | `GLPI - Snapshot e Update` | `GLPI - Fechar Ticket` |
| **Job Type** | Run | Run | Run |
| **Inventory** | `localhost` | `localhost` | `localhost` |
| **Project** | Seu projeto Git | Seu projeto Git | Seu projeto Git |
| **Playbook** | `playbooks/glpi-workflow-detectar.yml` | `playbooks/glpi-workflow-snapshot-update.yml` | `playbooks/glpi-workflow-fechar.yml` |
| **Execution Environment** | Padrão | Padrão | Padrão |
| **Credentials** | GLPI + Teams | OpenShift + VM | GLPI |

### 2. Criar 1 Workflow Template

1. **Automation → Templates → Add → Add workflow template**
2. **Name:** `GLPI - Correção de Vulnerabilidades`
3. **Inventory:** `localhost`
4. Clique em **Visualizer**

### 3. Montar o Workflow no Visualizer

```
START
  │
  ▼
┌─────────────────────────┐
│  GLPI - Detectar e      │
│  Notificar (Job 1)      │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│  Approval Node          │
│  "Aprovar correção de   │
│   vulnerabilidades?"    │
│  Timeout: 120 min     │
└────────┬────────────────┘
         │ (On Success)
         ▼
┌─────────────────────────┐
│  GLPI - Snapshot e      │
│  Update (Job 2)         │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│  GLPI - Fechar Ticket   │
│  (Job 3)                │
└─────────────────────────┘
```

---

## Variáveis

### defaults/main.yml (não precisa colocar no AAP)

```yaml
---
# GLPI
glpi_url: "https://glpi-glpi.apps.cluster-48fnf.dynamic.redhatworkshops.io"
glpi_user: "glpi"
glpi_pass: "glpi"
glpi_search_filter: "Correção"
glpi_group_name: "ansible"

# OpenShift
openshift_namespace: "linuxvm"
snapshot_api_version: "snapshot.kubevirt.io/v1beta1"

# Snapshot
snapshot_prefix: "glpi"

# VM update
vm_become: yes
vm_become_user: root
vm_ssh_timeout: 600

# Pacotes críticos (regex)
pacotes_criticos_regex: "(httpd|haproxy|nfs-utils|nfs-server)"
```

### Extra Variables no AAP (colocar no Job 1)

```yaml
aap_base_url: "https://aap-aap.apps.cluster-<id>.dynamic.redhatworkshops.io"
teams_webhook_url: "<token>"
```

> **Importante:** O `aap_base_url` e `teams_webhook_url` são sensíveis. Recomenda-se usar **Credentials** no AAP ao invés de Extra Variables.

---

## Fluxo de Execução

| Etapa | O que acontece | Onde você interage |
|-------|---------------|-------------------|
| **1. Detectar** | Ansible busca tickets do grupo, filtra status 2, verifica pacotes | — |
| **2. Notificar** | Envia card no Teams com todos os tickets + link do AAP | **Teams** (você vê a notificação) |
| **3. Pausar** | Workflow para no **Approval Node** | **AAP Web** (você clica Aprovar/Rejeitar) |
| **4. Snapshot** | Se aprovado, cria snapshot KubeVirt para cada VM | — |
| **5. Update** | Roda `dnf update --security` em cada VM | — |
| **6. Fechar** | Adiciona follow-up e fecha chamado no GLPI | — |

---

## Card no Teams

### Com críticos
```
🔒 Aprovação necessária — 4 ticket(s) — ⚠️ 2 CRÍTICO(S)
Workflow Job ID: 129
Total tickets: 4
Com críticos: 2

⚠️ ATENÇÃO: 2 ticket(s) contêm pacotes CRÍTICOS.

🔴 CRÍTICO — Ticket #5223 | VM: app-prod-02 (10.132.0.15)
Pacotes: httpd.x86_64, httpd-core.x86_64

✅ Seguro — Ticket #5224 | VM: web-prod-01 (10.132.0.11)
Pacotes: nginx, openssl

[🔗 Ver aprovações pendentes no AAP]
```

### Sem críticos
```
🔒 Aprovação necessária — 2 ticket(s)
Workflow Job ID: 130
Total tickets: 2
Com críticos: 0

✅ Nenhum pacote crítico detectado.

✅ Seguro — Ticket #5225 | VM: web-dev-01 (10.132.0.20)
Pacotes: curl, vim

[🔗 Ver aprovações pendentes no AAP]
```

---

## Troubleshooting

| Problema | Causa | Solução |
|----------|-------|---------|
| `_workflow_id` undefined | Variável não persiste entre Jobs | Usar `tower_workflow_job_id` direto |
| Arquivo `/tmp/...` não encontrado | Jobs rodam em containers separados | Usar `set_stats` ao invés de arquivos |
| Card quebrado no Teams | JSON malformado | Usar template Jinja2 separado |
| VS Code mostra erro YAML | Jinja complexo inline | Dividir em tasks menores |

---

## Autor
Lucas Marins do Nascimento