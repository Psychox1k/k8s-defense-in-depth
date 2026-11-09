# Roadmap

Engineering thesis: multi-layer detection and automatic response to web application
attacks in Kubernetes on AWS. Final deadline: **end of February 2027** (project, experiments
and thesis text).

There are two targets:

1. **Beta, 15 December 2026.** Everything works end to end locally on k3d (see "Beta plan").
2. **Final, end of February 2027.** The beta moved to AWS, experiments done, thesis written.

Each stage ends with something that can be shown to the supervisor ("Demo") and a short note for
the thesis ("Thesis"). Each weekly meeting: show whatever was finished since the last one and
write it down in `docs/progress/week-NN.md`.

Nothing is removed from the final scope. The beta only changes the order: what is needed for a
working end-to-end demo comes first, the rest follows (see "After the beta").

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
| `v0.1-layer1` | WAF prototype over Juice Shop on k3d (done) |
| `v0.2-waf-tuning` | socket.io false positive fixed, stop/start targets (done) |
| `v0.3-layer1` | pinned images, attacker pod, rate limiting: layer 1 complete |
| `v0.4-observability` | Loki + Grafana, WAF dashboard |
| `v0.5-runtime` | NetworkPolicy and Falco (local) |
| `v0.6-network` | Suricata (local) and a dashboard with all layers |
| `v0.9-beta` | beta: responder blocks the attacker, Telegram alert, `make demo` |
| `v1.0-rc1` | the whole lab on AWS from Terraform + Ansible, full responder |
| `v1.0` | experiments done, results and charts in the repo |

## Beta plan (target: 15 December 2026)

**Beta = one command shows the whole idea locally:** an attacker pod inside the cluster attacks
the app, the WAF, Suricata and Falco see it, events appear in Grafana, a NetworkPolicy closes the
WAF bypass, and the responder blocks the attacker IP and sends a Telegram alert.

Weekly targets (Monday to Sunday). They are targets, not promises: if a week slips, the stage
moves, the scope of the beta shrinks (see the cut line), the final deadline does not change.

| Week | Window | Stage | Result |
|---|---|---|---|
| 3 | 9-15 Nov | 1.2 pinned images, attacker pod, rate limiting | `v0.3-layer1` |
| 4 | 16-22 Nov | 1.3 Loki + Grafana, WAF dashboard | `v0.4-observability` |
| 5 | 23-29 Nov | 2.2 NetworkPolicy, 2.1 Falco | `v0.5-runtime` |
| 6 | 30 Nov-6 Dec | 3.3a Suricata on k3d, dashboard with all layers | `v0.6-network` |
| 7 | 7-13 Dec | 4.1 responder core, 4.2a block IP + Telegram | demo works |
| 8 | 14-15 Dec | freeze: `make demo`, README, bug fixes | `v0.9-beta` |

Decisions for the beta (all revisited after it):
- Local first (k3d), AWS after the beta. Nothing in the beta may depend on AWS.
- Attacks come from a pod inside the cluster, so the WAF sees a real client IP.
- NetworkPolicy with the controller built into k3s. Cilium and Hubble come after the beta.
- Suricata runs as a DaemonSet on the node. VPC Traffic Mirroring is the AWS version of the same idea.
- Juice Shop is the only target. The own vulnerable API comes after the beta.

Risks and the cut line:
- Falco needs eBPF support in the OrbStack VM. Check it at the start of week 5 (one hour). If it does
  not work, Falco moves to AWS and the beta shows two layers plus NetworkPolicy.
- Suricata on k3d is the least certain part. If by 1 December the responder core is not started,
  Suricata moves after the beta first.
- The responder is never cut: even with WAF events only, it is the part that makes the system "automatic".

## After the beta (16 December - end of February)

Suggested checkpoints (they move with git dates, like everything else):

| By | What |
|---|---|
| mid January | the lab runs on AWS from Terraform + Ansible, Suricata with Traffic Mirroring, `v1.0-rc1` |
| early February | experiments (five configurations, several repeats) done, raw results in `results/` |
| mid February | analysis, charts, `v1.0` |
| end of February | thesis text finished, corrections, defense materials |

Thesis chapters are written alongside the work, not at the end: each stage below has a "Thesis" line.

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

### 1.1 WAF tuning - `feat/waf-tuning` (done, `v0.2-waf-tuning`)
- [x] `make stop` / `make start`; `waf-log.sh` fails loudly when kubectl does not work
- [x] Rule exclusion for the `/socket.io/` false positive (custom rules file via ConfigMap)
- Demo: false positive gone, attacks still blocked.
- Thesis: WAF and OWASP CRS section.

### 1.2 Pinned images, attacker pod, rate limiting - `feat/rate-limit` (beta, week 3)
- [x] Verify which image env variables apply (checked against the image sources; `PROXY` does not
      exist for nginx, `PARANOIA` is deprecated in favour of `BLOCKING_PARANOIA` and `DETECTION_PARANOIA`)
- [ ] Pin images to digests (`make pin`) instead of `latest`
- [ ] Attacker pod in the cluster; `make attack` runs from it, so the WAF sees a real client IP
- [ ] nginx `limit_req` on the login endpoint (ConfigMap `waf-rate-limit`)
- [ ] Brute force case in `attack-demo.sh`: direct (not throttled) vs through the WAF (HTTP 429)
- Demo: brute force throttled, attacker pod IP visible in the WAF log.
- Thesis: rate limiting and the role of the client IP.
- Later, on AWS: `externalTrafficPolicy: Local` or PROXY protocol to keep the client IP behind a load balancer.

### 1.3 Observability - `feat/observability` (beta, week 4)
- [ ] Loki + Grafana (+ log collector) via Helm in a `monitoring` namespace, small resource limits
- [ ] WAF JSON audit log parsed into Loki with labels (rule id, client IP, status)
- [ ] Grafana dashboard: blocked requests over time, top rules, top IPs, 429 count
- Demo: run `make attack`, events appear on the dashboard. Tag `v0.4-observability`.
- Thesis: chapter 1 (introduction, goal, scope).

### 1.4 Own vulnerable API - `feat/vuln-api` (after the beta)
- [ ] Small FastAPI app with 2-3 deliberate vulnerabilities (SQLi, command injection, SSRF)
- [ ] Dockerfile (arm64), manifests, routed through the WAF; pytest for normal behaviour
- [ ] Extend `attack-demo.sh` with these attacks
- Demo: own app exploited directly, protected through the WAF.
- Thesis: threat model (OWASP Top 10 relevant to the lab).

### 1.5 Paranoia level comparison - `feat/paranoia` (after the beta)
- [ ] Compare paranoia levels 1 and 2 (3 optional): what each blocks, how many false positives
- Demo: table "attacks blocked / false positives" per paranoia level.
- Thesis: input for the experiments chapter.

## Phase 2. Runtime layer

Learn: eBPF basics, Falco rules, NetworkPolicy, CNI and Cilium, Kubernetes RBAC and service accounts.

### 2.2 NetworkPolicy - `feat/netpol` (beta, week 5)
- [ ] Default deny in `defense-lab`, explicit allows (attacker -> WAF, WAF -> app, monitoring)
- [ ] The app accepts traffic only from the WAF (closes the WAF bypass)
- [ ] Check that the k3s built-in network policy controller enforces the rules
- Demo: request from the attacker pod straight to `juiceshop:3000` is blocked, through the WAF it works.
- Thesis: IDS/IPS, WAF and runtime security theory.

### 2.1 Falco - `feat/falco` (beta, week 5)
- [ ] First: check if eBPF works in the local VM (one hour); if not, note it and move this to AWS
- [ ] Falco via Helm; default rules: shell in a container, reading sensitive files, unexpected network tools
- [ ] Falco events to Loki (Falcosidekick)
- Demo: `kubectl exec` into the app pod, Falco alert appears in Grafana. Tag `v0.5-runtime`.
- Thesis: Kubernetes architecture and container threats.

### 2.4 Cilium and Hubble - `feat/cilium` (after the beta)
- [ ] k3d cluster with Cilium as CNI (flannel disabled), Hubble UI
- [ ] The same NetworkPolicies on Cilium, flow visibility in Hubble
- Demo: blocked request visible in Hubble.

### 2.3 Cluster attack scenarios - `feat/k8s-attacks` (after the beta)
- [ ] Scenarios: service account token abuse, lateral movement between pods, kube-hunter scan
- [ ] Custom Falco rules for these scenarios
- [ ] kube-bench baseline, RBAC and `securityContext` hardening (non-root, read-only FS)
- Demo: each scenario detected by Falco or stopped by policy.
- Thesis: chapter 3 (review of existing solutions).

## Phase 3. Network layer and AWS

Learn: Suricata, Terraform, AWS VPC and security groups, Ansible roles, VPC Traffic Mirroring.

### 3.3a Suricata on k3d - `feat/suricata-local` (beta, week 6)
- [ ] Suricata as a DaemonSet on the node, ET Open rules, `eve.json` to Loki
- [ ] A few own rules for the lab scenarios (for example a scan from the attacker pod)
- [ ] Grafana dashboard with all layers on one screen
- Demo: scan and web attacks from the attacker pod seen by several layers. Tag `v0.6-network`.
- Thesis: chapter 4 (architecture and design).

### 3.1 AWS foundations - `feat/terraform-base` (after the beta)
- [ ] AWS Budgets alerts, IAM user for Terraform (no root keys)
- [ ] Terraform: VPC, public subnet, security groups (access only from my IP), EC2 Graviton nodes
- [ ] `lab-up.sh`, `lab-down.sh`, `cost-guard.sh`; `make aws-up` / `make aws-down`
- Demo: `terraform apply` and `destroy`, cost so far.

### 3.2 Ansible and k3s on EC2 - `feat/ansible-k3s` (after the beta)
- [ ] Ansible role: node hardening (SSH, sysctl, firewall, auditd)
- [ ] Ansible role: k3s server + agents, kubeconfig to the Mac
- [ ] Deploy the whole beta stack to AWS
- Demo: whole lab on AWS from two commands, `make attack` against it.
- Thesis: chapter 2 (theory) finished.

### 3.3b Suricata with Traffic Mirroring - `feat/suricata-aws` (after the beta)
- [ ] Check that the chosen instance types are supported as Traffic Mirroring sources
- [ ] Suricata sensor EC2, mirror session from the nodes, same rules and dashboard as locally
- Demo: nmap scan and web attacks seen by several layers on one dashboard. Tag `v1.0-rc1` when the responder is also on AWS.

## Phase 4. Automatic response

Learn: event-driven design, FastAPI background tasks, Kubernetes Python client, least-privilege RBAC.

### 4.1 Responder core and correlation - `feat/responder-core` (beta, week 7)
- [ ] FastAPI service, endpoints for WAF, Suricata and Falco events
- [ ] Common event model (source, time, IP, pod, severity, rule), pytest
- [ ] Correlation rules (N WAF hits from one IP in a window; scan followed by exploit; shell in pod)
- [ ] Alert-only mode, Telegram notifications (bot token in a Kubernetes Secret, never in git)
- Demo: an attack chain produces one high-priority Telegram alert.

### 4.2a Minimal response - `feat/responder-block` (beta, week 7)
- [ ] Block an IP on nginx (deny list via ConfigMap and reload, with expiry)
- [ ] Service account with minimal RBAC permissions for the responder
- Demo: the attacker pod is blocked automatically, alert sent. Tag `v0.9-beta` after the freeze.

### 4.2b Full response actions - `feat/responder-actions` (after the beta)
- [ ] Isolate a pod with a NetworkPolicy, label it for investigation
- [ ] Responder deployed on AWS, all layers connected
- Demo: attack blocked automatically, pod isolated, alert sent.
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
| 1.1 WAF tuning | `feat/waf-tuning` | | | `v0.2-waf-tuning` |
| 1.2 Pinned images, attacker pod, rate limiting | `feat/rate-limit` | | | `v0.3-layer1` |
| 1.3 Observability | `feat/observability` | | | `v0.4-observability` |
| 2.2 NetworkPolicy | `feat/netpol` | | | |
| 2.1 Falco | `feat/falco` | | | `v0.5-runtime` |
| 3.3a Suricata on k3d | `feat/suricata-local` | | | `v0.6-network` |
| 4.1 Responder core | `feat/responder-core` | | | |
| 4.2a Minimal response | `feat/responder-block` | | | `v0.9-beta` |
| 1.4 Own vulnerable API | `feat/vuln-api` | | | |
| 1.5 Paranoia comparison | `feat/paranoia` | | | |
| 2.4 Cilium and Hubble | `feat/cilium` | | | |
| 2.3 Cluster attack scenarios | `feat/k8s-attacks` | | | |
| 3.1 AWS foundations | `feat/terraform-base` | | | |
| 3.2 Ansible and k3s on EC2 | `feat/ansible-k3s` | | | |
| 3.3b Suricata with Traffic Mirroring | `feat/suricata-aws` | | | |
| 4.2b Full response actions | `feat/responder-actions` | | | `v1.0-rc1` |
| 5.1 Experiments | `feat/experiments` | | | |
| 5.2 Analysis | `feat/analysis` | | | `v1.0` |
| 6 Thesis and defense | `docs/...` | | | |