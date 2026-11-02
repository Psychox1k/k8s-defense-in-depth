CLUSTER   ?= defense
NAMESPACE ?= defense-lab

.PHONY: help check up attack logs status pf down

help: ## show available targets
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | sed -E 's/:.*## /\t/'

check: ## verify local prerequisites
	@bash scripts/check-prereqs.sh

up: check ## create cluster, deploy app and WAF, open direct port-forward
	@k3d cluster list 2>/dev/null | grep -q "^$(CLUSTER) " || \
		k3d cluster create $(CLUSTER) --servers 1 --agents 1 \
			--k3s-arg "--disable=traefik@server:0" \
			--port "8080:80@loadbalancer" --wait
	kubectl apply -f k8s/base/
	kubectl apply -f k8s/waf/
	kubectl -n $(NAMESPACE) rollout status deploy/juiceshop --timeout=180s
	kubectl -n $(NAMESPACE) rollout status deploy/waf --timeout=120s
	@$(MAKE) --no-print-directory pf
	@echo "Ready. Through WAF: http://localhost:8080  Direct: http://localhost:8081"

pf: ## port-forward the app directly on :8081 (for the no-WAF comparison)
	@if [ -f .pf.pid ] && kill -0 $$(cat .pf.pid) 2>/dev/null; then \
		echo "port-forward already running"; \
	else \
		kubectl -n $(NAMESPACE) port-forward svc/juiceshop 8081:3000 >/dev/null 2>&1 & echo $$! > .pf.pid; \
		sleep 2; echo "port-forward started on :8081"; \
	fi

attack: ## run the demo attacks directly and through the WAF
	@bash scripts/attack-demo.sh

logs: ## show requests matched by the WAF with the CRS rules that fired
	@NAMESPACE=$(NAMESPACE) bash scripts/waf-log.sh

status: ## show pods and services
	kubectl -n $(NAMESPACE) get pods,svc

down: ## stop port-forward and delete the cluster
	@if [ -f .pf.pid ]; then kill $$(cat .pf.pid) 2>/dev/null || true; rm -f .pf.pid; fi
	k3d cluster delete $(CLUSTER)