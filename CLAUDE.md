# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Project

Engineering (BEng) thesis at WSEI Lublin, Computer Science, Cybersecurity and Network Technologies.

**Topic:** design and implementation of a multi-layer system for detecting and automatically
responding to attacks on web applications in a Kubernetes environment on AWS.

A web application runs in Kubernetes behind three independent protection layers. The lab is
attacked in a controlled way in five configurations, and the layers are compared by detection
rate, false positives, time to detect/respond and performance overhead. A custom Python service
correlates events from all layers and responds automatically.

Timeline: about 6 months, from October 2026 to April 2027. The supervisor expects visible
progress every week, so keep `docs/progress/week-NN.md` up to date.

## Architecture

1. **Application layer:** nginx + ModSecurity (or Coraza) + OWASP Core Rule Set, rate limiting, JSON logs.
2. **Network layer:** Suricata fed by AWS VPC Traffic Mirroring (AWS only).
3. **Runtime layer:** Falco (eBPF) and Cilium/Hubble with NetworkPolicy.
4. **Response:** Python FastAPI "responder" that correlates events by IP and time, blocks IPs on
   nginx, isolates pods via NetworkPolicy and sends Telegram alerts.
5. **Observability:** Loki + Grafana (Wazuh is an alternative).

Experiment configurations: (1) no protection, (2) WAF only, (3) WAF + Suricata,
(4) WAF + Suricata + Falco/Cilium, (5) everything + automatic response.

## Tech stack

- Kubernetes: k3s on AWS EC2 Graviton (ARM); k3d on OrbStack locally
- IaC: Terraform (AWS), Ansible (node configuration), Helm
- Security: ModSecurity/Coraza + OWASP CRS, Suricata, Falco, Cilium, kube-bench
- Code: Python 3.12+, FastAPI, Pandas, Matplotlib, pytest; Bash for lab automation
- Targets: OWASP Juice Shop, plus a deliberately vulnerable FastAPI app (planned)
- Attack tooling: Kali, sqlmap, nmap, nikto, hydra, gobuster, kube-hunter, k6/Locust

## Repository layout

```
k8s/base/      namespace and the vulnerable application (apply order is by filename prefix)
k8s/waf/       nginx + ModSecurity + CRS
scripts/       prerequisite check, attack demo, later: lab-up/down, experiments, cost guard
terraform/     AWS infrastructure (planned)
ansible/       node configuration (planned)
responder/     automatic response service (planned)
docs/          thesis notes and weekly progress
```

## Commands

```bash
make up        # k3d cluster + Juice Shop + WAF (+ port-forward on :8081)
make attack    # same attacks directly (:8081) and through the WAF (:8080)
make logs      # recent ModSecurity matches from the WAF logs
make status    # pods and services
make down      # delete the cluster
```

## Environment constraints

- Development machine: MacBook Pro M2 Pro, 16 GB RAM, Apple Silicon (arm64). Use arm64-compatible
  images and tools only. Cisco IOS images and anything that needs x86 virtualization do not work here.
- Local work runs on k3d/OrbStack. Heavy experiments (Suricata with Traffic Mirroring, full
  experiment runs) run on AWS and must be reproducible from Terraform + Ansible.
- Falco may not work in the local VM (eBPF/kernel support). If so, move that part to AWS instead of
  forcing a workaround.

## Conventions

- Everything is infrastructure as code. No manual console changes that are not reflected in the repo.
- Bash scripts: `#!/usr/bin/env bash`, `set -u` (or `set -euo pipefail` where it fits), pass ShellCheck.
- Python: type hints, small modules, tests with pytest, config via environment variables.
- Kubernetes manifests: one namespace (`defense-lab`), resource requests/limits on every container,
  pin image versions once a setup works.
- Every experiment must be repeatable from a script and write raw results (CSV/JSON) to `results/`,
  with timestamps for attack start and end.
- Commit messages: short imperative summary, one logical change per commit.
- Documentation and comments in English. Thesis text itself is in Polish and lives outside this repo
  or under `docs/`.

## Safety and cost rules

- This is a lab. Attack only the resources deployed from this repo, never anything else.
- Never commit credentials, AWS keys, `.tfstate`, `.tfvars`, kubeconfig or `.env` files.
- AWS cost control: no NAT Gateway, no EKS (use k3s on EC2), access only from the developer's IP
  via Security Groups, budget alerts enabled, `terraform destroy` after every session.
- Before any DoS or load test on AWS, check the current AWS Penetration Testing and Simulated
  Events policies. Keep flood tests local or moderate and inside the VPC.
- Do not run `terraform apply`, `terraform destroy` or other commands that create or delete cloud
  resources without asking first.

## Current status

- Done: repository structure, local k3d cluster, Juice Shop, Layer 1 (nginx + ModSecurity + CRS),
  demo attack script.
- Next: CRS tuning and false-positive measurement, rate limiting, JSON logs to Loki + Grafana,
  then Falco and Cilium, then Terraform/Ansible for AWS.

(Update this section at the end of every working session.)

## Working with Claude

- Verify before claiming something works: run the command or test and report the actual output.
- If a config or tool version is uncertain (for example container image environment variables),
  say so and point to where to check instead of guessing.
- Prefer small, reviewable changes and explain trade-offs briefly. This is a learning project, so
  explain new concepts (eBPF, Traffic Mirroring, CRS paranoia levels) when they first appear.