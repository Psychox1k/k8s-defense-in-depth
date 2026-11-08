# Roadmap

Engineering thesis: multi-layer detection and automatic response to web application
attacks in Kubernetes on AWS. Final deadline: **end of February 2027** (project, experiments
and thesis text).

The plan is a sequence of stages, not a calendar. Stages are done in order; each one ends
with something that can be shown to the supervisor ("Demo") and a short note for the thesis
("Thesis"). Actual dates are not planned in advance: they come from git (commit and tag dates)
and are filled into the progress log at the end of the project.

Each weekly meeting: show whatever was finished since the last one and write it down in
`docs/progress/week-NN.md`.

If time runs short, cut in this order: optional extras, then paranoia level 3 and extra
cluster scenarios. The core (three layers, responder, experiments, thesis text) stays.

## Git workflow

- `main` always works: `make up` and `make attack` must succeed on it.
- One branch per stage or piece of work, created from an up-to-date `main`:
  `feat/...` new functionality, `fix/...` bug fix, `docs/...` documentation only,
  `chore/...` maintenance (versions, cleanup).
- Commit messages follow Conventional Commits: `feat(waf): add socket.io exclusion`,
  `fix(scripts): fail when kubectl is unavailable`, `docs: week 3 progress`.
- Small commits, one logical change each. Never commit secrets, `.tfstate`, `.tfvars`, kubeconfig.
- Finish a branch with a pull request on GitHub, review the diff yourself, merge, delete the branch.
- Tag milestones on `main`, so every stage can be reproduced and dated later.

```bash
git switch main && git pull
git switch -c feat/<name>
# ...work, commit...
git push -u origin feat/<name>
# open a pull request on GitHub, merge, then:
git switch main && git pull && git branch -d feat/<name>
```

## Milestones

| Tag | Content |
|---|---|
| `v0.1-layer1` | WAF prototype over Juice Shop on k3d |
| `v0.2-layer1` | tuned WAF, rate limiting, Grafana, own vulnerable API |
| `v0.3-runtime` | Falco, Cilium, NetworkPolicy, cluster attack scenarios |
| `v0.4-aws` | whole lab on AWS from Terraform + Ansible, Suricata |
| `v0.5-responder` | automatic response working end to end on AWS |
| `v1.0` | experiments done, results and charts in the repo |

## Phase 0. Prototype (done)

### 0.1 Layer 1 prototype
- [x] Repository structure, Makefile, README, CLAUDE.md
- [x] k3d cluster on OrbStack, OWASP Juice Shop
- [x] nginx + ModSecurity + OWASP CRS in front of the app
- [x] `attack-demo.sh` (direct vs through WAF), `waf-log.sh`
- Demo: SQLi, XSS, path traversal pass directly, get 403 through the WAF; matched CRS rules.
- Findings: false positive of rule 920420 on `/socket.io/`; WAF sees the node IP instead of the client IP.

## Phase 1. Application layer

Learn: how CRS works (anomaly scoring, paranoia levels, rule exclusions), nginx configuration,
Helm, log pipelines.

### 1.1 WAF tuning - `feat/waf-tuning`
- [ ] Pin image versions (Juice Shop, WAF) instead of `latest`
- [ ] `make stop` / `make start`; `waf-log.sh` fails loudly when kubectl does not work
- [ ] Rule exclusion for the `/socket.io/` false positive (custom rules file via ConfigMap)
- [ ] Verify which image env variables really apply (`PARANOIA`, `ANOMALY_INBOUND`)
- [ ] Compare paranoia levels 1 and 2 (3 optional): what each blocks, how many false positives
- Demo: false positive gone; table "attacks blocked / false positives" per paranoia level.
- Thesis: WAF and OWASP CRS section.

### 1.2 Rate limiting and client IP - `feat/rate-limit`
- [ ] Preserve the real client IP (`externalTrafficPolicy: Local` or `X-Forwarded-For`)
- [ ] nginx `limit_req` on the login endpoint
- [ ] Brute force demo (hydra or ffuf): direct vs through WAF
- Demo: brute force throttled, real attacker IP in the WAF log.

### 1.3 Observability - `feat/observability`
- [ ] Loki + Grafana (+ log collector) via Helm in a `monitoring` namespace
- [ ] WAF JSON audit log parsed into Loki with labels (rule id, client IP, status)
- [ ] Grafana dashboard: blocked requests over time, top rules, top IPs
- Demo: run `make attack`, events appear on the dashboard.
- Thesis: chapter 1 (introduction, goal, scope).

### 1.4 Own vulnerable API - `feat/vuln-api`
- [ ] Small FastAPI app with 2-3 deliberate vulnerabilities (SQLi, command injection, SSRF)
- [ ] Dockerfile (arm64), manifests, routed through the WAF; pytest for normal behaviour
- [ ] Extend `attack-demo.sh` with these attacks
- Demo: own app exploited directly, protected through the WAF. Tag `v0.2-layer1`.
- Thesis: threat model (OWASP Top 10 relevant to the lab).

## Phase 2. Runtime layer

Learn: eBPF basics, Falco rules, CNI and Cilium, NetworkPolicy, Kubernetes RBAC and service accounts.

### 2.1 Falco - `feat/falco`
- [ ] Falco via Helm; check if it works in the local VM (if not, note it and do it on AWS)
- [ ] Default rules: shell in a container, reading sensitive files, unexpected network tools
- [ ] Falco events to Loki (Falcosidekick)
- Demo: `kubectl exec` into the app pod, Falco alert appears in Grafana.
- Thesis: Kubernetes architecture and container threats.

### 2.2 Cilium and NetworkPolicy - `feat/cilium-netpol`
- [ ] k3d cluster with Cilium as CNI (flannel disabled), Hubble UI
- [ ] NetworkPolicy: the app accepts traffic only from the WAF (closes the WAF bypass)
- [ ] Default deny in `defense-lab`, explicit allows
- Demo: request from another pod straight to `juiceshop:3000` blocked, visible in Hubble.
- Thesis: IDS/IPS, WAF and runtime security theory.

### 2.3 Cluster attack scenarios - `feat/k8s-attacks`
- [ ] Scenarios: service account token abuse, lateral movement between pods, kube-hunter scan
- [ ] Custom Falco rules for these scenarios
- [ ] kube-bench baseline, RBAC and `securityContext` hardening (non-root, read-only FS)
- Demo: each scenario detected by Falco or stopped by policy. Tag `v0.3-runtime`.
- Thesis: chapter 3 (review of existing solutions).

## Phase 3. AWS

Learn: Terraform, AWS VPC and security groups, Ansible roles, Suricata, VPC Traffic Mirroring.

### 3.1 AWS foundations - `feat/terraform-base`
- [ ] AWS Budgets alerts, IAM user for Terraform (no root keys)
- [ ] Terraform: VPC, public subnet, security groups (access only from my IP), EC2 Graviton nodes
- [ ] `lab-up.sh`, `lab-down.sh`, `cost-guard.sh`; `make aws-up` / `make aws-down`
- Demo: `terraform apply` and `destroy`, cost so far.

### 3.2 Ansible and k3s on EC2 - `feat/ansible-k3s`
- [ ] Ansible role: node hardening (SSH, sysctl, firewall, auditd)
- [ ] Ansible role: k3s server + agents, kubeconfig to the Mac
- [ ] Deploy the whole stack from Phases 1-2 to AWS
- Demo: whole lab on AWS from two commands, `make attack` against it.
- Thesis: chapter 2 (theory) finished.

### 3.3 Suricata - `feat/suricata`
- [ ] Check that the chosen instance types are supported as Traffic Mirroring sources
- [ ] Suricata sensor EC2, mirror session from the nodes, ET Open rules, `eve.json` to Loki
- [ ] Own Suricata rules for the lab scenarios
- [ ] Grafana dashboard with all three layers
- Demo: nmap scan and web attacks seen by several layers on one dashboard. Tag `v0.4-aws`.
- Thesis: chapter 4 (architecture and design).

## Phase 4. Automatic response

Learn: event-driven design, FastAPI background tasks, Kubernetes Python client, least-privilege RBAC.

### 4.1 Responder core and correlation - `feat/responder-core`
- [ ] FastAPI service, endpoints for WAF, Suricata and Falco events
- [ ] Common event model (source, time, IP, pod, severity, rule), pytest
- [ ] Correlation rules (N WAF hits from one IP in a window, scan followed by exploit, shell in pod)
- [ ] Alert-only mode, Telegram notifications
- Demo: an attack chain produces one high-priority Telegram alert.

### 4.2 Response actions, end to end - `feat/responder-actions`
- [ ] Block an IP on nginx (deny list via ConfigMap and reload, with expiry)
- [ ] Isolate a pod with a NetworkPolicy, label it for investigation
- [ ] Service account with minimal RBAC permissions for the responder
- [ ] Responder deployed on AWS, all layers connected
- Demo: attack blocked automatically, pod isolated, alert sent. Tag `v0.5-responder`.
- Thesis: chapter 5 (implementation).

## Phase 5. Experiments

Learn: experiment design, statistics basics (repeats, mean, spread), Pandas and Matplotlib.

### 5.1 Framework and runs - `feat/experiments`
- [ ] Attack catalogue: scenario id, tool, MITRE ATT&CK technique, expected layer
- [ ] `experiment_runner.py` with start and end timestamps, raw results to `results/`
- [ ] Normal traffic generator (k6 or Locust) for false positive measurement
- [ ] Runs in all five configurations, several repeats each
- [ ] Latency and throughput with and without the WAF
- Demo: result tables.

### 5.2 Analysis - `feat/analysis`
- [ ] `analyze.py`: detection rate per category, false positives, time to detect/respond, overhead; charts
- [ ] `terraform destroy`, final AWS cost
- Demo: final results. Tag `v1.0`.

## Phase 6. Thesis text and defense

- [ ] Chapter 6 (experiments and results) with charts and tables
- [ ] Chapter 7 (conclusions, limitations, future work)
- [ ] Full draft to the supervisor, corrections, bibliography, formatting to WSEI rules
- [ ] Final README with results and how to reproduce
- [ ] Defense presentation, recorded demo video, final tag

## Optional extras (only if time allows)

- Paranoia level 3 comparison
- ML-based anomaly detection on Suricata/Zeek flows, compared with signatures
- Honeypot segment collecting real internet scans
- CI pipeline: Terraform validate, tfsec/Trivy, ShellCheck, pytest on every pull request

## Progress log

Filled in from git at the end (or whenever convenient). Dates come from the repository:

```bash
git for-each-ref --sort=creatordate --format='%(creatordate:short) %(refname:short)' refs/tags
git log --reverse --date=short --pretty=format:'%ad %s'
```

| Stage | Branch | Started | Finished | Tag |
|---|---|---|---|---|
| 0.1 Layer 1 prototype | `main` | | | `v0.1-layer1` |
| 1.1 WAF tuning | `feat/waf-tuning` | | | |
| 1.2 Rate limiting and client IP | `feat/rate-limit` | | | |
| 1.3 Observability | `feat/observability` | | | |
| 1.4 Own vulnerable API | `feat/vuln-api` | | | `v0.2-layer1` |
| 2.1 Falco | `feat/falco` | | | |
| 2.2 Cilium and NetworkPolicy | `feat/cilium-netpol` | | | |
| 2.3 Cluster attack scenarios | `feat/k8s-attacks` | | | `v0.3-runtime` |
| 3.1 AWS foundations | `feat/terraform-base` | | | |
| 3.2 Ansible and k3s on EC2 | `feat/ansible-k3s` | | | |
| 3.3 Suricata | `feat/suricata` | | | `v0.4-aws` |
| 4.1 Responder core | `feat/responder-core` | | | |
| 4.2 Response actions | `feat/responder-actions` | | | `v0.5-responder` |
| 5.1 Experiments | `feat/experiments` | | | |
| 5.2 Analysis | `feat/analysis` | | | `v1.0` |
| 6 Thesis and defense | `docs/...` | | | |