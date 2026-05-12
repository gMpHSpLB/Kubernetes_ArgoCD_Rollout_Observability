SHELL := /bin/bash

# Default target
.DEFAULT_GOAL := help

# Self-documenting help: list targets with "##" comments
.PHONY: help
help:
	@echo "Available targets:"
	@grep -E '^[a-zA-Z0-9_-]+:.*##' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: lint format type security quality security-deps docker-security-deps docker-scan docker-scan-dev-image \
        coverage smoke-test test docker-build docker-db docker-test run check-api clean-coverage clean \
        dev-up dev-down hit-api-multiple \
		create-minikube-secrets \
		ensure-minikube recreate-minikube deploy-minikube-local-clean \
		test-minikube test-minikube-all check-minikube-api k8s-test \
		deploy-minikube-db test-minikube-db k8s-test-db \
		deploy-myapp-minikube-dev deploy-mylearning-minikube-dev \

SHELL := /bin/bash

# ---------- GLOBAL CONFIG ----------
APP_ENV ?= dev

# Control whether k8s-test re-creates Minikube or reuses existing cluster
K8S_TEST_RECREATE ?= true

# Local dev DB defaults
DEV_DB_HOST ?= db
DEV_DB_PORT ?= 5432
DEV_DB_NAME ?= mydb
DEV_DB_USER ?= myuser
DEV_DB_PASSWORD ?= mypassword

LOG_LEVEL ?= info

# OTEL / Uptrace defaults (dev-only)
OTEL_ENABLED ?= true
OTEL_SERVICE_NAME ?= myapp-dev
OTEL_EXPORTER_OTLP_ENDPOINT ?= api.uptrace.dev:4317
UPTRACE_TOKEN ?= WLfJDCI9dKwaoXgI-Z-jFg
UPTRACE_DSN ?= "https://WLfJDCI9dKwaoXgI-Z-jFg@api.uptrace.dev?grpc=4317"
OTEL_TRACES_SAMPLER ?= always_on
DISABLE_CUSTOM_MIDDLEWARE ?= false

# Kubernetes directories
K8S_ENV_DIR				?= environments
K8S_NAMESPACE_DIR       ?= infra/k8s/namespaces
K8S_MONITORING_DIR      ?= infra/k8s/monitoring
K8S_NETWORKPOLICY_DIR   ?= $(K8S_MONITORING_DIR)/networkpolicies
K8S_RULES_DIR           ?= infra/k8s/rules

# ---------- KUBECONFIG / CONTEXTS PER ENV ----------
# Use the same local Minikube context for all environments for now.
# When you later add real staging/prod clusters, change only STAGING/PROD values.
# Dev app environment on local Minikube
K8S_CONTEXT_DEV     ?= minikube
# Staging app environment on local Minikube
K8S_CONTEXT_STAGING ?= minikube
# Prod app environment on local Minikube
K8S_CONTEXT_PROD    ?= minikube

# ---------- Docker Image Name For local test for dev/staging/prod----------------------#
# Local dev image name (used when no CI image is provided)
LOCAL_MYAPP_IMAGE_DEV ?= myapp:dev-local
LOCAL_MYAPP_IMAGE_STAGING ?= myapp:staging-local
LOCAL_MYAPP_IMAGE_PROD ?= myapp:prod-local

# ---------- APP NAMESPACES PER ENV ----------
# These match infra/k8s/namespaces/myapp-namespaces.yaml.
# Namespace for dev myapp workloads
K8S_APP_NAMESPACE_DEV     ?= myapp-dev
# Namespace for staging myapp workloads
K8S_APP_NAMESPACE_STAGING ?= myapp-staging
# Namespace for prod myapp workloads
K8S_APP_NAMESPACE_PROD    ?= myapp-prod

# ---------- HELM RELEASE NAMES PER ENV ----------
# Keep releases separate so dev/staging/prod can be managed independently.
# Helm release name for dev myapp
K8S_MYAPP_RELEASE_DEV     ?= myapp-dev-myapp# Release name is derived; Helm release= CHART_NAME(myapp-dev) + chart myapp
# Helm release name for staging myapp
K8S_MYAPP_RELEASE_STAGING ?= myapp-staging-myapp# Release name is derived; Helm release= CHART_NAME(myapp-staging) + chart myapp
# Helm release name for prod myapp
K8S_MYAPP_RELEASE_PROD    ?= myapp-prod-myapp# Release name is derived; Helm release= CHART_NAME(myapp-prod) + chart myapp

# --------------- Deployment name ----------------------------#
K8S_MYAPP_DEPLOY_DEV 		?= myapp-dev-myapp
K8S_MYAPP_DEPLOY_STAGING 	?= myapp-staging-myapp
K8S_MYAPP_DEPLOY_PROD    	?= myapp-prod-myapp


# Monitoring / logging namespaces
K8S_MONITORING_NAMESPACE ?= monitoring
K8S_LOGGING_NAMESPACE    ?= logging

# kube-prometheus-stack / Loki releases & values
K8S_KPS_RELEASE      ?= kps
K8S_LOKI_RELEASE     ?= loki
K8S_PROM_CRDS_RELEASE ?= prometheus-operator-crds
K8S_PROM_CRDS_CHART   ?= prometheus-community/prometheus-operator-crds
K8S_KPS_VALUES_DEV   ?= infra/k8s/monitoring/kube-prometheus-stack-values-dev.yaml
K8S_KPS_VALUES_STAGING ?= infra/k8s/monitoring/kube-prometheus-stack-values-staging.yaml
K8S_KPS_VALUES_PROD  ?= infra/k8s/monitoring/kube-prometheus-stack-values-prod.yaml
K8S_LOKI_VALUES_DEV  ?= infra/k8s/logging/loki-stack-values-dev.yaml
K8S_LOKI_VALUES_STAGING ?= infra/k8s/logging/loki-stack-values-staging.yaml
K8S_LOKI_VALUES_PROD ?= infra/k8s/logging/loki-stack-values-prod.yaml

# Alerting chart
K8S_ALERTS_CHART_DIR ?= infra/k8s/rules/myapp-alerts
K8S_ALERTS_RELEASE   ?= myapp-alerts
K8S_ALERTS_NAMESPACE ?= monitoring

# Grafana dashboards
K8S_GRAFANA_DASHBOARD_DIR ?=  $(K8S_MONITORING_DIR)/grafana/dashboards
K8S_GRAFANA_DASHBOARD_CM_DIR ?= $(K8S_MONITORING_DIR)/grafana/configmaps

# AWS 
REQUIRE_AWS_LOGGING ?= 0

# ---- ArgoCD bootstrap ----
GITOPS_DIR ?= gitops

ARGOCD_NAMESPACE ?= argocd
ARGOCD_MANIFEST_URL ?= https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# ArgoCD CLI
ARGOCD_CLI_BIN ?= bin/argocd
ARGOCD_CLI_URL ?= https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
# ArgoCD CLI login (local Minikube)
ARGOCD_SERVER ?= localhost:8080
ARGOCD_USERNAME ?= admin
# For local dev, we often disable TLS verification for the CLI.
ARGOCD_INSECURE ?= true

# Path to local, untracked HTTPS repo secret for ArgoCD
REPO_HTTPS_SECRET_FILE ?= infra/secrets-local/argocd-repo-pythonworkspace-https.yaml

###############Code Quality ###############################
.PHONY: lint format type security quality coverage smoke-test test test-docker clean-coverage clean

lint: ## Run ruff lint on myapp and mylearning
	( cd myapp && poetry run ruff check . ) & \
	P1=$$!; \
	( cd mylearning && poetry run ruff check . ) & \
	P2=$$!; \
	wait $$P1 || exit 1; \
	wait $$P2 || exit 1

format:
	( cd myapp && poetry run black . ) & \
	( cd myapp && poetry run isort . ) & \
	( cd mylearning && poetry run black . ) & \
	( cd mylearning && poetry run isort . ) & \
	( cd myapp && poetry run ruff format . ) & \
	P1=$$!; \
	( cd mylearning && poetry run ruff format . ) & \
	P2=$$!; \
	wait $$P1 || exit 1; \
	wait $$P2 || exit 1

type:
	( cd myapp && poetry run mypy . ) & \
	( cd mylearning && poetry run mypy . )

security: #Check in python code for security vulnerability
	( cd myapp && poetry run bandit -r . -c bandit.yml ) & \
	( cd mylearning && poetry run bandit -r . -c bandit.yml )

quality:
	@echo "Running code quality checks..."
	@$(MAKE) lint
	@$(MAKE) format
	@$(MAKE) type
	@$(MAKE) security

###############Security -- Dependencies ##########################
# safety check scans for known CVEs; you can tune failure behavior with --fail-on flags depending on how strict you want CI to be.
# Use this if you want to run make security-deps on your machine (outside Docker).
# You have to manually run "poetry install --with dev" command under each project.
#export SAFETY_API_KEY= .. before running below command.
security-deps:
	@test -n "$(SAFETY_API_KEY)" || { echo "SAFETY_API_KEY not set"; exit 1; }
	@echo "Running Safety dependency scan for myapp..."
	cd myapp && SAFETY_API_KEY=$(SAFETY_API_KEY) poetry run safety scan --full-report --ignore 88512

	@echo "Running Safety dependency scan for mylearning..."
	cd mylearning && SAFETY_API_KEY=$(SAFETY_API_KEY) poetry run safety scan --full-report --ignore 88512

# In CI, use only the Docker variant, which already uses INSTALL_DEV=true:
#export SAFETY_API_KEY= .. before running below command.
docker-security-deps:
	@test -n "$(SAFETY_API_KEY)" || { echo "SAFETY_API_KEY not set"; exit 1; }
	@echo "Running Safety scan for myapp inside Docker..."
	docker compose run --rm myapp sh -lc "\
		SAFETY_API_KEY=$(SAFETY_API_KEY) poetry run safety scan --full-report --ignore 88512 \
	"

	@echo "Running Safety scan for mylearning inside Docker..."
	docker compose run --rm mylearning sh -lc "\
		SAFETY_API_KEY=$(SAFETY_API_KEY) poetry run safety scan --full-report --ignore 88512 \
	"
# ---------- DOCKER IMAGE SECURITY (Docker Scout) ----------
# curl ... | sh installs the docker scout CLI in the runner/container.
# docker scout cves myapp:latest and ... mylearning:latest use the images your compose build already creates (image: myapp, image: mylearning).
# --only-severity high,critical focuses on serious issues; remove it for full detail.
# If you want the scan to not fail CI even when vulns exist, add || true to each scout line
# Note: run make docker-build before running this.
docker-scan:
	@echo "Installing Docker Scout CLI..."
	@curl -fsSL https://raw.githubusercontent.com/docker/scout-cli/main/install.sh -o install-scout.sh
	@sh install-scout.sh
	#The leading @ is a Makefile feature: it tells make not to echo the command itself before running it.
	#	- Without @, make would print the whole line (docker scout cves ...) and then the command’s output.
	#	- With @, you only see the output of docker scout, which keeps logs cleaner.
	@echo "Scanning myapp image for high/critical CVEs (multi-stage)..."
	#Docker Scout vulnerability scan command.
	#	- docker scout cves analyzes the myapp:latest image and reports known CVEs affecting packages inside it.
	#	- --only-severity high,critical filters the findings so you only see vulnerabilities with severity high or critical, hiding medium/low ones.
	#Rightnow we donot want CI to fail on findings, we have wraped each docker scout call with || true
	# Since your images are multi‑stage, you can explicitly ask Scout to show multi‑stage package info
	#   --multi-stage is recommended by Scout docs to get a full view of packages across stages in multi‑stage builds.
	@docker scout cves myapp:latest \
		--multi-stage \
		--only-severity high,critical || true

	@echo "Scanning mylearning image for high/critical CVEs (multi-stage)..."
	@docker scout cves mylearning:latest \
		--multi-stage \
		--only-severity high,critical || true

	# Optional: sometimes it’s useful to see only base‑image 
	# issues (to decide when to bump python:3.11-slim)
	@echo "Base image-only issues for myapp..."
	@docker scout cves myapp:latest \
        --only-base \
        --only-severity high,critical || true

	@echo "Base image-only issues for mylearning..."
	@docker scout cves mylearning:latest \
        --only-base \
        --only-severity high,critical || true

docker-scan-dev-image:
	@echo "Installing Docker Scout CLI..."
	@curl -fsSL https://raw.githubusercontent.com/docker/scout-cli/main/install.sh -o install-scout.sh
	@sh install-scout.sh
	#The leading @ is a Makefile feature: it tells make not to echo the command itself before running it.
	#	- Without @, make would print the whole line (docker scout cves ...) and then the command’s output.
	#	- With @, you only see the output of docker scout, which keeps logs cleaner.
	@echo "Scanning $(IMAGE) image for high/critical CVEs (multi-stage)..."
	#Docker Scout vulnerability scan command.
	#	- docker scout cves analyzes the $(IMAGE) image and reports known CVEs affecting packages inside it.
	#	- --only-severity high,critical filters the findings so you only see vulnerabilities with severity high or critical, hiding medium/low ones.
	#Rightnow we donot want CI to fail on findings, we have wraped each docker scout call with || true
	docker scout cves $(IMAGE) \
		--multi-stage \
		--only-severity high,critical || true

	@echo "Scanning $(IMAGE) image for high/critical CVEs (multi-stage)..."
	docker scout cves $(IMAGE) \
		--multi-stage \
		--only-severity high,critical || true



# This is combined coverage for both projects.
# We have added this but not using it in our project
#   as we want to have seperate report.
coverage:
	@echo "Running combined coverage for myapp + mylearning..."
	# Use myapp's venv but extend PYTHONPATH so both packages are importable
	cd myapp && \
	PYTHONPATH=../myapp/src:../mylearning/src \
	poetry run pytest \
		../myapp/tests ../mylearning/tests \
		--cov=myapp --cov=mylearning \
		--cov-report=term-missing \
		--cov-report=xml:../coverage-combined.xml \
		--cov-fail-under=20

# ---------- LOCAL/CI TESTS ----------
# ---------- SMOKE TESTS ----------
# Fast gate: health endpoints + minimal DB wiring.
smoke-test:
	@echo "Running smoke tests ..."
	( cd myapp && USE_TESTCONTAINERS=true poetry run pytest -m smoke \
		--log-cli-level=INFO \
  		--log-cli-format="%(asctime)s %(levelname)s [%(name)s] %(message)s") && \
	( cd mylearning && poetry run pytest -m smoke \
		--log-cli-level=INFO \
  		--log-cli-format="%(asctime)s %(levelname)s [%(name)s] %(message)s")

#Use wait -n trick, to detect failure correctly
# Runs both tests in parallel
# Tracks each process
# Fails if ANY fails
# Note: remove -n auto to see logs from logging module
# 	-vv is pytest’s “very verbose” mode.
# 		-v shows each test name and its result.
#		-vv shows even more detail: full node IDs 
#		(module, class, function), useful when you 
#		have many similarly named tests or use parametrization
test: ## Run full pytest suite (both projects, parallel, with coverage)
	@echo "Running tests in parallel..."
	( cd myapp && USE_TESTCONTAINERS=true poetry run pytest -vv -n auto \
		--log-cli-level=INFO \
  		--log-cli-format="%(asctime)s %(levelname)s [%(name)s] %(message)s" \
		--cov=myapp --cov-report=term-missing \
		--cov-report=xml:coverage-myapp.xml --cov-fail-under=20) & \
	P1=$$!; \
	( cd mylearning && poetry run pytest -vv -n auto \
		--log-cli-level=INFO \
  		--log-cli-format="%(asctime)s %(levelname)s [%(name)s] %(message)s" \
		--cov=exercises --cov-report=term-missing \
		--cov-report=xml:coverage-mylearning.xml --cov-fail-under=20) & \
	P2=$$!; \
	wait $$P1 || exit 1; \
	wait $$P2 || exit 1;

# ---------- DOCKER BUILD ----------
#Make sure you're building images before tagging/pushing
#make sure app images are rebuilt when you change Dockerfiles or deps:
#Docker builds images with tags:
#	myapp:latest
#	mylearning:latest
#  dev deps in these local dev images, pass INSTALL_DEV=true
docker-build:
	docker compose build --build-arg INSTALL_DEV=true #build image with dev dependency.

# ---------- DOCKER DB ----------
docker-db:
	docker compose up -d db

# ---------- DOCKER TEST ----------
#Parallel Docker Tests (Advanced)
#Note:
#      1. docker compose run SERVICE COMMAND starts a one-time container
#      for a specific service and runs the command you give it.
#      For example, docker compose run web bash starts the web service and opens a shell in it.
#      It reads settings from compose.yml, so you reuse the service config instead of rewriting ports, env vars, and volumes manually.
#      The command you pass overrides the service’s default command.
#      2. docker compose up --build → forces a build step first, then starts containers, ensuring you’re running with the latest code/Dockerfile changes.
#         it reads docker-compose.yml file
#      3. --remove-orphans
#				remove any container created earlier those are orphan now
#      4. --abort-on-container-exit
#				--abort-on-container-exit = foreground mode (watch containers). if any container (e.g. pytest inside myapp) exits, Compose stops the whole stack.
#				Note: - As soon as any container in the stack exits (for any reason), Docker Compose stops all other containers and the up command returns.
#                     - If mylearning’s container exits quickly (e.g. runs tests then exits, or crashes), myapp (uvicorn) is stopped too, and the up command ends.
#	   5. docker compose run --rm myapp poetry run pytest
#				overrides CMD with poetry run pytest and ignores the Dockerfile CMD.
#	   6. docker compose up --build --abort-on-container-exit
#               Starts services as defined in docker-compose.yml. whatever command the service has will run.
#               If they have no command: in docker-compose.yml,	then it will run CMD [] command from corresponding Dockefile
#      7. docker compose run --rm myapp poetry run pytest
#				Here, myapp is service name from docker-compose.yml file instead of image name.
#	   8. If you want machine-readable reports for CI for code coverage, add XML:coverage.xml
#				- This writes coverage.xml inside the container;
#	    		- Add a threshold in your pytest command using --cov-fail-under.
#					If coverage drops below the threshold, pytest exits non‑zero and CI fails.
#				- Your code lives at mylearning/src/exercises/..., and the Python package name is exercises
#				- --cov must point to the importable package/module,
#				- --cov-report=term-missing, which prints a table into the CI log.

test-docker:
	docker compose down -v --remove-orphans
	#docker compose up --build --abort-on-container-exit
	docker compose up --build -d db  # only DB, run tests in one-off containers. only builds (and starts) the db service, not myapp or mylearning.
	sleep 10
	@echo "Running Docker tests in parallel..."
	(docker compose run --rm myapp pytest -vv \
		--log-cli-level=INFO \
  		--log-cli-format="%(asctime)s %(levelname)s [%(name)s] %(message)s" \
		--cov=myapp --cov-report=term-missing \
		--cov-report=xml:coverage-myapp.xml --cov-fail-under=20) & \
	P1=$$!; \
	(docker compose run --rm mylearning pytest -vv  \
		--log-cli-level=INFO \
  		--log-cli-format="%(asctime)s %(levelname)s [%(name)s] %(message)s" \
		--cov=exercises --cov-report=term-missing \
		--cov-report=xml:coverage-mylearning.xml --cov-fail-under=20) & \
	P2=$$!; \
	wait $$P1 || exit 1; \
	wait $$P2 || exit 1;
	docker compose down -v

# ---------- FULL RUN ----------
run:
	docker compose down -v --remove-orphans # CI runners are reused sometimes → leftover containers can break builds, down -v ensures clean start
	docker compose up --build -d #Run DB in background, tests separately. -d = detached mode (run in background)

# ---------- API CHECK ----------
check-api:
	@echo "Waiting for API to be ready on http://localhost:8000/docs ..."
	@for i in 1 2 3 4 5; do \
		sleep 5; \
		if curl -sf http://localhost:8000/docs > /dev/null; then \
			echo "API is up!"; \
			exit 0; \
		else \
			echo "API not ready yet (attempt $$i)..."; \
		fi; \
	done; \
	echo "API did not become ready in time"; \
	exit 1

# ---------- CLEAN COVERAGE ----------
clean-coverage:
	rm -f myapp/.coverage myapp/coverage*.xml /tmp/coverage*.xml
	rm -f mylearning/.coverage mylearning/coverage*.xml /tmp/coverage*.xml

# ---------- CLEAN ----------
clean:
	docker compose down -v #--remove-orphans
	docker system prune -f #remove unused images and layers
	@$(MAKE) clean-coverage

# ---------- LOCAL DEV STACK WITH OBSERVABILITY ----------
# Builds local dev images (myapp:latest, mylearning:latest)
# Run full dev stack: db + myapp + mylearning + prometheus + grafana
# Run full dev stack: db + myapp + mylearning + prometheus + grafana
dev-up: docker-build  ## Start local dev stack (db + myapp + mylearning + Prometheus + Grafana)
	APP_ENV=${APP_ENV} \
	IMAGE_MYAPP=myapp:latest \
	IMAGE_MYLEARNING=mylearning:latest \
	DB_HOST=$(DEV_DB_HOST) \
	DB_PORT=$(DEV_DB_PORT) \
	DB_NAME=$(DEV_DB_NAME) \
	DB_USER=$(DEV_DB_USER) \
	DB_PASSWORD=$(DEV_DB_PASSWORD) \
	LOG_LEVEL=${LOG_LEVEL} \
	OTEL_ENABLED=${OTEL_ENABLED} \
	OTEL_SERVICE_NAME=${OTEL_SERVICE_NAME} \
	OTEL_EXPORTER_OTLP_ENDPOINT=${OTEL_EXPORTER_OTLP_ENDPOINT} \
	UPTRACE_TOKEN=${UPTRACE_TOKEN} \
	UPTRACE_DSN=${UPTRACE_DSN} \
	OTEL_TRACES_SAMPLER=${OTEL_TRACES_SAMPLER} \
	DISABLE_CUSTOM_MIDDLEWARE=${DISABLE_CUSTOM_MIDDLEWARE} \
	docker compose -f docker-compose.base.yml -f docker-compose.dev.yml up -d

# Tear down dev stack
dev-down:
	APP_ENV=${APP_ENV} \
	IMAGE_MYAPP=myapp:latest \
	IMAGE_MYLEARNING=mylearning:latest \
	DB_HOST=$(DEV_DB_HOST) \
	DB_PORT=$(DEV_DB_PORT) \
	DB_NAME=$(DEV_DB_NAME) \
	DB_USER=$(DEV_DB_USER) \
	DB_PASSWORD=$(DEV_DB_PASSWORD) \
	LOG_LEVEL=${LOG_LEVEL} \
	OTEL_ENABLED=${OTEL_ENABLED} \
	OTEL_SERVICE_NAME=${OTEL_SERVICE_NAME} \
	OTEL_EXPORTER_OTLP_ENDPOINT=${OTEL_EXPORTER_OTLP_ENDPOINT} \
	UPTRACE_TOKEN=${UPTRACE_TOKEN} \
	UPTRACE_DSN=${UPTRACE_DSN} \
	OTEL_TRACES_SAMPLER=${OTEL_TRACES_SAMPLER} \
	DISABLE_CUSTOM_MIDDLEWARE=${DISABLE_CUSTOM_MIDDLEWARE} \
	docker compose -f docker-compose.base.yml -f docker-compose.dev.yml down -v --remove-orphans

hit-api-multiple:
	for i in {1..20}; do curl -s -o /dev/null http://localhost:8000/docs; done


check-metrics-myapp:
	@echo "Waiting for myapp metrics on http://localhost:8000/metrics ..."
	@for i in 1 2 3 4 5; do \
		sleep 5; \
		if curl -sf http://localhost:8000/metrics > /dev/null; then \
			echo "/metrics is up for myapp!"; \
			exit 0; \
		else \
			echo "/metrics not ready yet for myapp (attempt $$i)..."; \
		fi; \
	done; \
	echo "/metrics did not become ready in time for myapp"; \
	exit 1

check-metrics:
	@echo "Checking /metrics for myapp on localhost..."
	@$(MAKE) check-metrics-myapp


######Deployment using Kubernetes K8S CLUSTER / NAMESPACES (MINIKUBE)########################
.PHONY: ensure-minikube recreate-minikube install-prometheus-operator-crds k8s-namespaces-all k8s-namespace-monitoring k8s-namespaces-myapp

# Create or update K8s Secrets needed for dev/staging/prod
# Leading - before kubectl delete tells make: ignore error if the secret doesn’t exist.
# This keeps dev simple: each run ensures you have a clean myapp-secret with known values.
create-secrets:
	@echo "Creating/updating myapp-secret ..."
	# Try to create; if it exists, delete and recreate (simple dev behavior)
	kubectl -n $(K8S_NAMESPACE) delete secret myapp-secret --ignore-not-found >/dev/null 2>&1 || true
	kubectl -n $(K8S_NAMESPACE) create secret generic myapp-secret \
	  --from-literal=DB_HOST=$(K8_DB_HOST) \
	  --from-literal=DB_PORT=$(K8_DB_PORT) \
	  --from-literal=DB_NAME=$(K8_DB_NAME) \
	  --from-literal=DB_USER=$(K8_DB_USER) \
	  --from-literal=DB_PASSWORD=$(K8_DB_PASSWORD) \
	  --from-literal=UPTRACE_TOKEN=$(K8_UPTRACE_TOKEN) \
	  --from-literal=UPTRACE_DSN=$(K8_UPTRACE_DSN)

# start cluster if needed.
ensure-minikube:
	@echo "Checking minikube status..."
	@if ! minikube status >/dev/null 2>&1; then \
	  echo "Minikube not running, starting..."; \
	  minikube start --memory=3072 --cpus=2 ; \
	fi

# hard reset when things are really broken.
recreate-minikube:
	@echo "Recreating Minikube cluster..."
	minikube stop || true
	minikube delete --all=true --purge=true || true
	minikube start --memory=3072 --cpus=2

# Why we used monitoring namespace for CRDs
# CRDs themselves are cluster-scoped, 
# so helm install ... --namespace monitoring doesn't actually 
# put the CRD in the monitoring namespace—it installs it cluster-wide. 
# But we used your existing K8S_MONITORING_NAMESPACE variable for 
# consistency with your monitoring setup.
#
# The real reason was pattern matching: your Makefile already 
# has K8S_MONITORING_NAMESPACE ?= monitoring for kube-prometheus-stack, 
# so using the same variable keeps your monitoring infra organized.
install-prometheus-operator-crds: ## Install Prometheus Operator CRDs for Minikube
	@echo "Adding Prometheus Community repo and installing CRDs..."
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
	helm repo update
	helm upgrade --install $(K8S_PROM_CRDS_RELEASE) $(K8S_PROM_CRDS_CHART) \
		--namespace $(K8S_MONITORING_NAMESPACE) --create-namespace

# targets to apply namespaces
# 	- monitoring exists (with PSA and name=monitoring label used by NetworkPolicy).
#	- myapp-dev, myapp-staging, myapp-prod exist before you deploy.

.PHONY: k8s-namespace-monitoring k8s-namespace-myapp-local k8s-namespaces-myapp k8s-namespaces-all

k8s-namespace-monitoring:
	@echo "Applying monitoring namespace..."
	kubectl apply -f $(K8S_NAMESPACE_DIR)/monitoring.yaml

k8s-namespace-myapp-local:
	@echo "Applying myapp-local namespace..."
	kubectl apply -f $(K8S_NAMESPACE_DIR)/myapp-local.yaml

# Keep your namespace application target, but make it explicit
k8s-namespaces-myapp:
	@echo "Applying myapp dev/staging/prod namespaces with PSA labels..."
	kubectl apply -f $(K8S_NAMESPACE_DIR)/myapp-namespaces.yaml

k8s-namespaces-all: k8s-namespace-monitoring k8s-namespaces-myapp k8s-namespace-myapp-local
	@echo "Core namespaces (monitoring + myapp envs + local) applied."

# Appliy Network Policy
.PHONY: k8s-netpol-dev k8s-netpol-staging k8s-netpol-prod k8s-netpol-all

k8s-netpol-dev:
	@echo "Applying NetworkPolicies for myapp-dev metrics..."
	kubectl apply -f $(K8S_NETWORKPOLICY_DIR)/networkpolicy-myapp-metrics-dev.yaml

k8s-netpol-staging:
	@echo "Applying NetworkPolicies for myapp-staging metrics..."
	kubectl apply -f $(K8S_NETWORKPOLICY_DIR)/networkpolicy-myapp-metrics-staging.yaml

k8s-netpol-prod:
	@echo "Applying NetworkPolicies for myapp-prod metrics..."
	kubectl apply -f $(K8S_NETWORKPOLICY_DIR)/networkpolicy-myapp-metrics-prod.yaml

k8s-netpol-all: k8s-netpol-dev k8s-netpol-staging k8s-netpol-prod
	@echo "NetworkPolicies for myapp metrics applied for dev, staging, and prod."


# ---------- K8S APP DEPLOY (HELM) ----------
# This uses helm upgrade --install as recommended for idempotent deploys and 
# overlays environment-specific values via -f values-local.yaml
#		- Ensure Minikube is running/using local Docker (optional).
#		- Install/upgrade both charts with a values-local.yaml per app.
# Build images into Minikube Docker and deploy via Helm
# Note:
#	let Helm own the secret and remove the separate kubectl create 
#   secret step. That avoids split ownership, prevents release 
#   collisions, and matches Helm’s resource ownership model 
#   more cleanly.
# Why this is the better design
#	Helm tracks ownership with labels and annotations, and 
#   it expects the objects in a release to be created and managed 
#   by that release. When you create the same secret manually and 
#   also define it in the chart, you create two controllers of 
#   the same resource, which is exactly what caused your error
#   Builds images into minikube's Docker, then deploys. Restores host Docker env afterwards.
#   depend on CRDs and enable ServiceMonitor
deploy-minikube-local: ensure-minikube k8s-namespace-myapp-local install-prometheus-operator-crds ## Deploy myapp/mylearning to Minikube (builds images + Helm)
	@echo "Using Minikube Docker daemon..."
	eval "$$(minikube docker-env)" && \
	docker build -t myapp:mklatest -f myapp/Dockerfile . && \
	docker build -t mylearning:mklatest -f mylearning/Dockerfile . --build-arg INSTALL_DEV=true && \
	eval "$$(minikube docker-env -u)"
	@echo "Deploying myapp to Minikube (myapp-local namespace) with Helm..."
	helm upgrade --install myapp-mklatest charts/myapp \
	  -n myapp-local --create-namespace \
	  -f charts/myapp/values-local.yaml \
	  --set image.fullName="myapp:mklatest" \
	  --set serviceMonitor.enabled=true
	@echo "Deploying mylearning to Minikube with Helm (with test jobs enabled)..."
	helm upgrade --install mylearning-mklatest charts/mylearning \
	  -f charts/mylearning/values.yaml \
	  --set image.fullName="mylearning:mklatest" \
	  --set tests.enabled=true \
	  --set tests.smoke.enabled=true \
	  --set tests.full.enabled=true
	@echo "Waiting for mylearning smoke Job to complete..."
	@if kubectl wait --for=condition=complete --timeout=900s job/mylearning-mklatest-mylearning-smoke; then \
	  echo "mylearning smoke Job completed successfully. Showing logs..."; \
	  kubectl logs job/mylearning-mklatest-mylearning-smoke; \
	else \
	  echo "mylearning smoke Job did not complete successfully or timed out."; \
	  echo "Job description:"; \
	  kubectl describe job mylearning-mklatest-mylearning-smoke || true; \
	  echo "Job pod logs (if any):"; \
	  kubectl logs job/mylearning-mklatest-mylearning-smoke || true; \
	  exit 1; \
	fi
	@echo "Waiting for mylearning full test Job to complete..."
	@if kubectl wait --for=condition=complete --timeout=1800s job/mylearning-mklatest-mylearning-tests; then \
	  echo "mylearning full test Job completed successfully. Showing logs..."; \
	  kubectl logs job/mylearning-mklatest-mylearning-tests; \
	else \
	  echo "mylearning full test Job did not complete successfully or timed out."; \
	  echo "Job description:"; \
	  kubectl describe job mylearning-mklatest-mylearning-tests || true; \
	  echo "Job pod logs (if any):"; \
	  kubectl logs job/mylearning-mklatest-mylearning-tests || true; \
	  exit 1; \
	fi

# “nuke cluster and redeploy” when regular deploy fails.
# Add a “clean” deploy for when the cluster is flaky
# Sometimes Minikube profiles get into a weird state and only delete+start fixes them. To encode that pattern
deploy-minikube-local-clean: recreate-minikube deploy-minikube-local

# 1) Run pytest against Minikube deployment
# Assuming:
# 	- deploy-minikube-local has already deployed myapp-mklatest.
# 	- Your charts/myapp exposes the service as ClusterIP named myapp-mklatest on port 8000 (the typical Helm naming).
# Add a new target that:
# 	- Port‑forwards svc/myapp-mklatest to localhost:8000.
# 	- Runs pytest in your local env (just like smoke-test / test).
# 	- Cleans up the port‑forward.
#USE_TESTCONTAINERS=true
test-minikube: #deploy-minikube-local
	@echo "Starting port-forward from Minikube service to localhost:8000..."
	@kubectl port-forward -n myapp-local svc/myapp-mklatest-myapp 8000:8000 >/tmp/kube-pf-myapp.log 2>&1 & \
	PF_PID=$$!; \
	sleep 5; \
	echo "Running smoke tests against Minikube app myapp..."; \
	( cd myapp && APP_ENV=dev USE_TESTCONTAINERS=true poetry run pytest -m smoke \
		--log-cli-level=INFO \
		--log-cli-format="%(asctime)s %(levelname)s [%(name)s] %(message)s" ); \
	echo "Stopping port-forward..."; \
	kill $$PF_PID || true; \
	echo "Running smoke tests for mylearning locally..."; \
	( cd mylearning && APP_ENV=dev poetry run pytest -m smoke \
		--log-cli-level=INFO \
		--log-cli-format="%(asctime)s %(levelname)s [%(name)s] %(message)s" )

# USE_TESTCONTAINERS=true
test-minikube-all: #deploy-minikube-local
	@echo "Starting port-forward from Minikube service to localhost:8000..."
	@kubectl port-forward -n myapp-local svc/myapp-mklatest-myapp 8000:8000 >/tmp/kube-pf-myapp.log 2>&1 & \
	PF_PID=$$!; \
	sleep 5; \
	echo "Running all tests against Minikube app myapp..."; \
	( cd myapp && APP_ENV=dev USE_TESTCONTAINERS=true poetry run pytest -vv \
		--log-cli-level=INFO \
		--log-cli-format="%(asctime)s %(levelname)s [%(name)s] %(message)s" \
		--cov=myapp --cov-report=term-missing \
		--cov-report=xml:coverage-myapp.xml --cov-fail-under=20 ); \
	echo "Stopping port-forward..."; \
	kill $$PF_PID || true; \
	echo "Running all tests for mylearning locally..."; \
	( cd mylearning && APP_ENV=dev poetry run pytest -vv \
		--log-cli-level=INFO \
		--log-cli-format="%(asctime)s %(levelname)s [%(name)s] %(message)s" \
		--cov=exercises --cov-report=term-missing \
		--cov-report=xml:coverage-mylearning.xml --cov-fail-under=20 )

# URL access / health check for Minikube (like check-api)
check-minikube-api: #deploy-minikube-local
	@echo "Port-forwarding myapp-mklatest-myapp service to localhost:8000 for health check..."
	@kubectl port-forward -n myapp-local svc/myapp-mklatest-myapp 8000:8000 >/tmp/kube-pf-myapp.log 2>&1 & \
	PF_PID=$$!; \
	for i in 1 2 3 4 5; do \
	  sleep 5; \
	  if curl -sf http://localhost:8000/docs > /dev/null; then \
	    echo "Minikube API is up!"; \
	    #kill $$PF_PID || true; \
	    exit 0; \
	  else \
	    echo "Minikube API not ready yet (attempt $$i)..."; \
	  fi; \
	done; \
	echo "Minikube API did not become ready in time"; \
	kill $$PF_PID || true; \
	exit 1

# want a single “Kubernetes quick loop” target
# 	- Build images into Minikube.
# 	- Deploy via Helm.
# 	- Run smoke tests against the live Minikube app.
# 	- Confirm /docs is reachable via port‑forward.
.PHONY: k8s-test k8s-test-no-recreate

#Fresh run (wipe cluster): make k8s-test (default).
k8s-test:
ifeq ($(K8S_TEST_RECREATE),true)
	@echo "Running k8s-test with full Minikube recreate..."
	$(MAKE) deploy-minikube-local-clean
else
	@echo "Running k8s-test without recreating Minikube (reusing existing cluster)..."
	$(MAKE) deploy-minikube-local
endif
	$(MAKE) test-minikube
	$(MAKE) test-minikube-all
	$(MAKE) check-minikube-api
	@echo "Minikube deploy + pytest smoke + API health check completed."

# Reuse existing cluster for quicker metrics iteration:
# Convenience alias to always skip recreate
k8s-test-no-recreate:
	@echo "Running k8s-test with K8S_TEST_RECREATE=false..."
	K8S_TEST_RECREATE=false $(MAKE) k8s-test

# That will create:
# 	Deployment: mydb-postgres
# 	Service: mydb-postgres (ClusterIP, port 5432)
deploy-minikube-db: ensure-minikube
	@echo "Deploying Postgres to Minikube..."
	helm upgrade --install mydb charts/postgres

# We’ll:
# 	- Ensure Minikube + Postgres chart are up.
# 	- Port‑forward mydb-postgres to localhost:5433.
# 	- Run pytest with USE_TESTCONTAINERS=false and DB_* envs pointing at this forwarded DB.
test-minikube-db: deploy-minikube-db deploy-minikube-local
	@echo "Port-forwarding Minikube Postgres service to localhost:5433..."
	@kubectl port-forward svc/mydb-postgres 5433:5432 >/tmp/kube-pf-db.log 2>&1 & \
	PF_DB_PID=$$!; \
	sleep 10; \
	echo "Running smoke tests against Minikube app + DB..."; \
	( cd myapp && \
	  USE_TESTCONTAINERS=false \
	  DB_HOST=127.0.0.1 \
	  DB_PORT=5433 \
	  DB_NAME=mydb \
	  DB_USER=myuser \
	  DB_PASSWORD=mypassword \
	  poetry run pytest -m smoke \
	    --log-cli-level=INFO \
	    --log-cli-format="%(asctime)s %(levelname)s [%(name)s] %(message)s" ) ; \
	echo "Stopping DB port-forward..."; \
	kill $$PF_DB_PID || true

# Want to hit the app via HTTP, extend this with an app port‑forward
k8s-test-db: deploy-minikube-db deploy-minikube-local
	@echo "Port-forwarding myapp and Postgres from Minikube..."
	@kubectl port-forward -n myapp-local svc/myapp-mklatest-myapp 8000:8000 >/tmp/kube-pf-app.log 2>&1 & \
	PF_APP_PID=$$!; \
	kubectl port-forward svc/mydb-postgres 5433:5432 >/tmp/kube-pf-db.log 2>&1 & \
	PF_DB_PID=$$!; \
	sleep 10; \
	echo "Running All tests against Minikube app + DB..."; \
	( cd myapp && \
	  USE_TESTCONTAINERS=false \
	  DB_HOST=127.0.0.1 \
	  DB_PORT=5433 \
	  DB_NAME=mydb \
	  DB_USER=myuser \
	  DB_PASSWORD=mypassword \
	  poetry run pytest -vv \
	    --log-cli-level=INFO \
	    --log-cli-format="%(asctime)s %(levelname)s [%(name)s] %(message)s" ) ; \
	echo "Checking /docs on Minikube app..."; \
	if curl -sf http://localhost:8000/docs >/dev/null; then \
	  echo "Minikube API is up!"; \
	else \
	  echo "Minikube API not responding on /docs"; \
	fi; \
	echo "Stopping port-forwards..."; \
	kill $$PF_APP_PID $$PF_DB_PID || true

.PHONY: k8s-port-forward-prometheus-dev k8s-port-forward-prometheus-staging
k8s-port-forward-prometheus-dev:
	@echo "Port-forwarding DEV Prometheus (kube-prometheus-stack) to http://localhost:9091 ..."
	kubectl -n $(K8S_MONITORING_NAMESPACE) port-forward svc/$(K8S_KPS_RELEASE)-kube-prometheus-stack-prometheus 9091:9090

k8s-port-forward-prometheus-staging:
	@echo "Port-forwarding STAGING Prometheus (kube-prometheus-stack) to http://localhost:9092 ..."
	kubectl -n $(K8S_MONITORING_NAMESPACE) port-forward svc/$(K8S_KPS_RELEASE)-staging-kube-prometheu-prometheus 9092:9090

k8s-port-forward-prometheus-prod:
	@echo "Port-forwarding PROD Prometheus (kube-prometheus-stack) to http://localhost:9093 ..."
	kubectl -n $(K8S_MONITORING_NAMESPACE) port-forward svc/$(K8S_KPS_RELEASE)-prod-kube-prometheus-s-prometheus 9093:9090

.PHONY: k8s-port-forward-grafana-dev k8s-port-forward-grafana-staging k8s-port-forward-grafana-prod
k8s-port-forward-grafana-dev:
	@echo "Port-forwarding DEV Grafana (kube-prometheus-stack) to http://localhost:3001 ..."
	kubectl -n $(K8S_MONITORING_NAMESPACE) port-forward svc/$(K8S_KPS_RELEASE)-grafana 3001:80

k8s-port-forward-grafana-staging:
	@echo "Port-forwarding STAGING Grafana (kube-prometheus-stack) to http://localhost:3002 ..."
	kubectl -n $(K8S_MONITORING_NAMESPACE) port-forward svc/$(K8S_KPS_RELEASE)-staging-grafana 3002:80

k8s-port-forward-grafana-prod:
	@echo "Port-forwarding PROD Grafana (kube-prometheus-stack) to http://localhost:3003 ..."
	kubectl -n $(K8S_MONITORING_NAMESPACE) port-forward svc/$(K8S_KPS_RELEASE)-prod-grafana 3003:80

.PHONY: k8s-test-observability
# Add k8s-test-observability target
# This will:
# 	Run k8s-test (deploy + tests).
# 	Install monitoring/logging.
# 	Apply dev dashboards and alerts.
# 	Print port-forward commands for Prometheus and Grafana.
k8s-test-observability:
	@echo "=== Step 1: Running k8s-test (Minikube deploy + tests) ==="
	$(MAKE) k8s-test
	@echo "=== Step 2: Installing monitoring (kube-prometheus-stack) in Minikube ==="
	$(MAKE) k8s-monitoring-dev
	@echo "=== Step 3: Installing logging (Loki stack) in Minikube ==="
	$(MAKE) k8s-logging-dev
	@echo "=== Step 4: Applying dev Grafana dashboards and alert rules ==="
	$(MAKE) k8s-grafana-dashboards-dev
	$(MAKE) k8s-alerts-dev
	@echo "=== Step 5: Running infra observability health checks (Prometheus/Grafana/Loki) ==="
	$(MAKE) k8s-observability-infra-check
	@echo "=== Done. You can also run k8s-observability-check-dev for app-level signals. ==="
	@echo "=== Done. Now on different terminal you can port-forward Prometheus and Grafana using: ==="
	@echo "  make k8s-port-forward-prometheus-dev"
	@echo "  make k8s-port-forward-grafana-dev"

# Your deploy-minikube-dev target pulls prebuilt images from GHCR and doesn’t touch Docker env
# Usage:
# 
#   MYAPP_IMAGE=ghcr.io/<owner>/<repo>/myapp:dev \
#   MYLEARNING_IMAGE=ghcr.io/<owner>/<repo>/mylearning:dev
#   images from GHCR (no local build)
k8-deploy-myapp:
	@echo "Deploying myapp with Helm (pulling from GHCR)..."
	helm upgrade --install $(CHART_NAME) charts/myapp \
	  -n $(K8S_NAMESPACE) \
	  --create-namespace \
	  -f $(ENV_VALUES) \
	  --set image.fullName="$(MYAPP_IMAGE)"

.PHONY: k8-deploy-myapp-dev k8-deploy-myapp-staging k8-deploy-myapp-prod

k8-deploy-myapp-dev:
	@echo "Deploying myapp to myapp-dev namespace..."
	CHART_NAME=myapp-dev \
	K8S_NAMESPACE=$(K8S_APP_NAMESPACE_DEV) \
	ENV_VALUES=$(K8S_ENV_DIR)/dev/values-myapp.yaml \
	MYAPP_IMAGE=$(LOCAL_MYAPP_IMAGE_DEV) \
	$(MAKE) k8-deploy-myapp

k8-deploy-myapp-staging:
	@echo "Deploying myapp to myapp-staging namespace..."
	CHART_NAME=myapp-staging \
	K8S_NAMESPACE=$(K8S_APP_NAMESPACE_STAGGING) \
	ENV_VALUES=$(K8S_ENV_DIR)/stagging/values-myapp.yaml \
	MYAPP_IMAGE=$(LOCAL_MYAPP_IMAGE_STAGING) \
	$(MAKE) k8-deploy-myapp

k8-deploy-myapp-prod:
	@echo "Deploying myapp to myapp-prod namespace..."
	CHART_NAME=myapp-prod \
	K8S_NAMESPACE=$(K8S_APP_NAMESPACE_PROD) \
	ENV_VALUES=$(K8S_ENV_DIR)/prod/values-myapp.yaml \
	MYAPP_IMAGE=$(LOCAL_MYAPP_IMAGE_PROD) \
	$(MAKE) k8-deploy-myapp

# mylearning app
k8-deploy-mylearning:
	@echo "Deploying mylearning image (pulling from GHCR)..."
	helm upgrade --install $(CHART_NAME) charts/mylearning \
	  -f $(ENV_VALUES) \
	  --set image.fullName="$(MYLEARNING_IMAGE)" \
	  --set tests.enabled=false \ # no dev dependency, so cannot test it.
	  --set tests.smoke.enabled=false \
	  --set tests.full.enabled=false

# ---------- K8S OBSERVABILITY STACK ----------

# Adding Helm chart repositories so Helm can find and 
# install charts from Prometheus and Grafana later. 
# In practice, it’s a one-time setup step on each machine, 
# and it’s commonly used when you want to deploy monitoring 
# tools into Kubernetes with Helm.
#
# What Helm repos are
# A Helm repository is just a catalog of packaged Kubernetes 
# applications called charts. When you add a repo, Helm stores 
# its name and URL locally so you can reference charts from 
# it using short names like prometheus-community/... 
# or grafana/... instead of downloading them manually.
#
# For your example, these repositories are the official sources 
# for commonly used monitoring charts:
#
# prometheus-community: charts for Prometheus-related components.
# grafana: charts for Grafana and related tooling.
#
# Why this is useful
# This is useful because Prometheus and Grafana are often 
# installed through Helm in Kubernetes environments. Once 
# the repos are added, you can deploy monitoring stacks quickly, 
# keep chart versions manageable, and update them more easily 
# than hand-writing all Kubernetes manifests.
#
# For someone building observability for a cluster, this is 
# typically the first setup step before running helm install 
# for Prometheus or Grafana charts.
#
# Line by line
# helm-add-repos:
# This is not a Helm command itself.
# helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
# This tells Helm:
# repository name: prometheus-community
# repository URL: https://prometheus-community.github.io/helm-charts
#
# After this, you can install charts from that repo using the 
# short repo name. 
# For example, a Prometheus chart might be 
# installed from that source without typing the full URL every time.
#
# helm repo add grafana https://grafana.github.io/helm-charts
# This adds Grafana’s chart repository to Helm with the local 
# name grafana. That lets you install Grafana charts such as 
# grafana/grafana using Helm’s normal chart naming convention.
#
# helm repo update
# This refreshes Helm’s local cache of chart metadata from all 
# added repositories. It makes Helm aware of the latest chart 
# versions and fixes the common issue where Helm can’t “see” 
# new versions until you update the repo index.
#
# Typical use case
	# A very common workflow is:
	# Add the Prometheus and Grafana repositories.
	# Update repo metadata.
	# Install charts into a Kubernetes cluster.
	# Customize values for storage, namespace, persistence, dashboards, and alerts
# Which repo for what
#	- kube-prometheus-stack → prometheus-community Helm repo.
#	- loki-stack (Loki + Promtail) → grafana Helm repo.
#
# You can verify it from the Helm client, not by looking inside 
# your git repository. The usual check is helm repo list, and 
# for these specific repos you can also run helm search repo 
# prometheus-community and helm search repo grafana to confirm 
# Helm can see charts from them
helm-add-repos:
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo add grafana https://grafana.github.io/helm-charts
	helm repo update

# ---------- REUSABLE OBSERVABILITY HELPERS ----------
# These helpers keep the Makefile DRY and make the checks 
# consistent across environments
#
# Fail fast if a context does not exist in the local kubeconfig.
define check-k8s-context
	@kubectl config get-contexts -o name | grep -qx "$(1)" || \
		{ echo "Missing kubectl context: $(1)"; exit 1; }
endef

# Fail fast if a namespace is not present.
define check-k8s-namespace
	@kubectl get namespace "$(1)" >/dev/null 2>&1 || \
		{ echo "Missing namespace: $(1)"; exit 1; }
endef

# Generic observability health check for one environment.
# This checks pods, services, endpoints, metrics, and recent logs.
# Let each env-specific k8s-observability-check-* decide what image it cares about (dev-local vs ghcr.io tag vs prod tag).
#
#Assuming:
#
# $(1) = label (DEV/STAGING/PROD)
# $(3) = namespace
# $(4) = deployment name (if you still use it elsewhere)
# We’ll add $(5) = expected image (optional; can be empty)
define k8s_observability_check
	@echo "=== Observability check for $(1) ==="
	@echo "Namespace: $(3)"
	@kubectl get pods -n "$(3)" -o wide
	@kubectl get svc -n "$(3)"
	@kubectl get endpoints -n "$(3)" || true
	@kubectl top pods -n "$(3)" || echo "WARNING: Metrics API not available; skipping resource usage for namespace $(3)."
	@POD=""; \
	IMAGE_FILTER="$(5)"; \
	if [ -n "$$IMAGE_FILTER" ]; then \
		echo "Looking for pod with image $$IMAGE_FILTER..."; \
		POD=$$(kubectl get pods -n "$(3)" -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.containers[0].image}{"\n"}{end}' \
			| awk '$$2 == "'$$IMAGE_FILTER'" {print $$1; exit}'); \
	fi; \
	if [ -z "$$POD" ]; then \
		echo "No matching image or no filter; falling back to first pod in namespace $(3)"; \
		POD=$$(kubectl get pods -n "$(3)" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo ""); \
	fi; \
	if [ -n "$$POD" ]; then \
		echo "Found pod $$POD, showing logs..."; \
		kubectl logs -n "$(3)" $$POD --tail=50 || true; \
	else \
		echo "No pod found in namespace $(3)"; \
	fi
endef

# An HTTP smoke helper
# 	Use kubectl port-forward from your machine to the dev Service.
# 	curl /healthz and /readyz locally.
# 	Fail the Make target if these return non‑200.
# port‑forwards the Service to the same local port, waits a bit
# curl -sf will error out if non‑200, causing the Make step to fail.
define k8s_http_smoke_check
	@echo "=== HTTP smoke check for $(1) ==="
	@NAMESPACE="$(2)"; \
	SVC="$(3)"; \
	PORT="$(4)"; \
	echo "Port-forwarding service/$$SVC in namespace $$NAMESPACE to localhost:$$PORT..."; \
	kubectl -n "$$NAMESPACE" port-forward "service/$$SVC" $$PORT:$$PORT > /tmp/k8s-smoke-$$SVC.log 2>&1 & \
	PF_PID=$$!; \
	sleep 3; \
	set -e; \
	echo "GET http://localhost:$$PORT/healthz"; \
	if curl -fsS http://localhost:$$PORT/healthz; then \
		echo "OK"; \
	else \
		echo "HTTP smoke check failed (healthz)"; \
		kill $$PF_PID 2>/dev/null || true; \
		wait $$PF_PID 2>/dev/null || true; \
		exit 7; \
	fi; \
	echo "GET http://localhost:$$PORT/readyz"; \
	if curl -fsS http://localhost:$$PORT/readyz; then \
		echo "OK"; \
	else \
		echo "HTTP smoke check failed (readyz)"; \
		kill $$PF_PID 2>/dev/null || true; \
		wait $$PF_PID 2>/dev/null || true; \
		exit 7; \
	fi; \
	echo "GET http://localhost:$$PORT/metrics"; \
	if curl -fsS http://localhost:$$PORT/metrics; then \
		echo "OK"; \
	else \
		echo "HTTP smoke check failed (metrics)"; \
		kill $$PF_PID 2>/dev/null || true; \
		wait $$PF_PID 2>/dev/null || true; \
		exit 7; \
	fi; \
	echo "HTTP smoke checks passed for $$SVC on port $$PORT"; \
	kill $$PF_PID 2>/dev/null || true; \
	wait $$PF_PID 2>/dev/null || true
endef

# Generic in-cluster curl helper
# An in‑cluster service test answers:
# “If I am a pod inside the cluster, can I reach myapp via its Kubernetes Service?”
# Concretely:
# 	- You create a temporary pod (here: curlimages/curl) inside the same namespace as your app.
# 	- That pod does an HTTP request to the service DNS name (myapp-dev-myapp, myapp-staging-myapp, etc.) on the app port (8000).
# 	- You assert 200 OK from /healthz using curl -sf (which fails if the status code is not 2xx).
# So the test validates:
# 	- Cluster DNS (service name resolves).
# 	- Service object (selector, port) is correct.
# 	- Pods behind the Service are alive and answering HTTP.
# 	- No network policies are blocking traffic inside the namespace for that path.
#
# How we’re doing it with this command
# Example dev run after the refactor:
# bash
# 	kubectl -n myapp-dev run curlpod --rm -it \
#   	--image=curlimages/curl --restart=Never -- \
#   	curl -sf http://myapp-dev-myapp:8000/healthz
# Step‑by‑step:
# 	kubectl -n myapp-dev run curlpod ...
# 	- Creates a short‑lived pod named curlpod in namespace myapp-dev using image curlimages/curl.
# 	- --rm cleans it up afterwards.
# Inside that pod, we run:
# bash
# 	curl -sf http://myapp-dev-myapp:8000/healthz
# 		- myapp-dev-myapp is your Service name.
# 		- Kubernetes DNS resolves it to the ClusterIP (e.g. 10.103.83.137).
#		- curl -sf sends a GET to /healthz and exits non‑zero if the status is not 2xx or the connection fails.
# If anything is miswired (DNS, Service, pods, Netpol), the command fails and so does the Make target.
# The in‑cluster test is complementary because it:
# 	- Simulates real service‑to‑service traffic as other workloads in the cluster would see it.
# 	- Catches DNS/service wiring or network policy issues that a port‑forward might bypass.
# Think of it as:
# 	- In‑cluster smoke: “Kubernetes plumbing and app are healthy from another pod’s point of view.”
# 	- Host‑side smoke: “I, as an operator/CI job on the host, can talk to the app via its Service.”
# $(1) = namespace
# $(2) = service DNS name
define k8s_incluster_smoke_check
	@echo "=== In-cluster service smoke for namespace $(1), service $(2) ==="
	kubectl -n "$(1)" run curlpod --rm -it \
	  --image=curlimages/curl --restart=Never -- \
	  curl -sf "http://$(2):8000/healthz"
endef

# -------- In-cluster Grafana smokes (staging/prod) --------
# - Creates a short‑lived pod in monitoring named grafana-curlpod, 
#   using curlimages/curl.
# - Inside that pod, runs curl -sf http://kps-staging-grafana/login.
# 	  - Kubernetes DNS resolves kps-staging-grafana to the Grafana ClusterIP service.
# 	  - Traffic is routed via that service to the Grafana pod(s) on port 80.
# 	  - /login should return 200 (or a 3xx redirect), which curl -sf treats as success.
#
# If DNS is broken, service name is wrong, Grafana pods are down, or 
# Netpol blocks traffic, the command fails and so does the Make target.
# The in‑cluster test is complementary:
# 	- Port‑forward check: “From my laptop/CI host, I can tunnel to 
#     Grafana and get /login.”
# 	- In‑cluster test: “From another pod in the monitoring namespace, 
#     Kubernetes Service + DNS + Grafana are working.”
# Generic helper
# $(1) = namespace (monitoring)
# $(2) = service name (e.g. kps-staging-grafana)
define k8s_incluster_grafana_smoke
	@echo "=== In-cluster Grafana smoke for service $(2) in namespace $(1) ==="
	kubectl -n "$(1)" run grafana-curlpod --rm -it \
	  --image=curlimages/curl --restart=Never -- \
	  curl -sf "http://$(2)/login"
endef

# A Helm-based installation target for deploying the kube-prometheus-stack 
# chart into a Kubernetes cluster, usually for a development or local 
# environment. It is a convenient wrapper around helm upgrade --install, 
# so the same command works whether the release already exists or not.
#
#What it does
# kube-prometheus-stack is a popular Helm chart that bundles the 
# Prometheus Operator stack, Prometheus, Alertmanager, Grafana, 
# and the Kubernetes monitoring rules and dashboards needed for 
# observability.
#
# The goal is to install or update that stack in a namespace 
# defined by variables, using a dev-specific values file so 
# the deployment fits a local or lower-environment cluster.
# helm upgrade --install $(K8S_KPS_RELEASE) prometheus-community/kube-prometheus-stack \
# This is the main Helm action. helm upgrade --install means:
# upgrade the release if it already exists,
# otherwise install it fresh.
# $(K8S_KPS_RELEASE) is a Make variable holding the release name, and prometheus-community/kube-prometheus-stack tells Helm which chart to use from the repo you added earlier.
# -n $(K8S_MONITORING_NAMESPACE) --create-namespace \
# -n sets the Kubernetes namespace where the chart will be installed. --create-namespace tells Helm to create that namespace first if it does not already exist, so the install does not fail just because the namespace is missing.
# -f $(K8S_KPS_VALUES_DEV)
# This points Helm to a custom values file for the dev environment. That file usually overrides defaults such as storage settings, resource limits, ingress, scraping behavior, retention, or Grafana settings to match your local cluster and development needs
# Practical use case
#	A typical use case is:
#		- you spin up a local Kubernetes cluster,
# 		- add the Prometheus and Grafana chart repositories,
# 		- then run this target to deploy observability components,
#		- and finally open Grafana to inspect cluster metrics and dashboards.
# Install/upgrade kube-prometheus-stack in dev (current kube-context)
k8s-monitoring-dev: helm-add-repos ensure-minikube
	@echo "Installing/Upgrading kube-prometheus-stack (dev) in namespace $(K8S_MONITORING_NAMESPACE)..."
	helm upgrade --install $(K8S_KPS_RELEASE) prometheus-community/kube-prometheus-stack \
	  -n $(K8S_MONITORING_NAMESPACE) --create-namespace \
	  -f $(K8S_KPS_VALUES_DEV)

k8s-monitoring-staging: helm-add-repos ensure-minikube
	@echo "Installing/Upgrading kube-prometheus-stack (staging)..."
	helm upgrade --install $(K8S_KPS_RELEASE)-staging prometheus-community/kube-prometheus-stack \
	  -n $(K8S_MONITORING_NAMESPACE) --create-namespace \
	  -f $(K8S_KPS_VALUES_STAGING)

k8s-monitoring-prod: helm-add-repos ensure-minikube
	@echo "Installing/Upgrading kube-prometheus-stack (prod)..."
	helm upgrade --install $(K8S_KPS_RELEASE)-prod prometheus-community/kube-prometheus-stack \
	  -n $(K8S_MONITORING_NAMESPACE) --create-namespace \
	  -f $(K8S_KPS_VALUES_PROD)

#apply Grafana dashboards per env
.PHONY: k8s-grafana-dashboards-dev k8s-grafana-dashboards-staging k8s-grafana-dashboards-prod k8s-grafana-dashboards-all

# k8s-grafana-dashboards-dev:
# 	@echo "Applying Grafana dashboards ConfigMaps for DEV..."
# 	kubectl apply -n $(K8S_MONITORING_NAMESPACE) \
# 	  -f $(K8S_GRAFANA_DASHBOARD_CM_DIR)/grafana-dashboards-infra-dev.yaml \
# 	  -f $(K8S_GRAFANA_DASHBOARD_CM_DIR)/grafana-dashboards-myapp-dev.yaml

k8s-grafana-dashboards-dev:
	@echo "Generating and applying Grafana dashboards ConfigMaps for DEV..."
	# Generate myapp dashboards ConfigMap
	kubectl create configmap grafana-dashboards-myapp-dev \
	  --from-file=$(K8S_GRAFANA_DASHBOARD_DIR)/dev/myapp/ \
	  -n $(K8S_MONITORING_NAMESPACE) \
	  --dry-run=client -o yaml | \
	  kubectl label --local -f - grafana_dashboard=1 --dry-run=client -o yaml | \
	  kubectl apply -f -
	# Generate infra dashboards ConfigMap
	kubectl create configmap grafana-dashboards-infra-dev \
	  --from-file=$(K8S_GRAFANA_DASHBOARD_DIR)/dev/infra/ \
	  -n $(K8S_MONITORING_NAMESPACE) \
	  --dry-run=client -o yaml | \
	  kubectl label --local -f - grafana_dashboard=1 --dry-run=client -o yaml | \
	  kubectl apply -f -

# k8s-grafana-dashboards-staging:
# 	@echo "Applying Grafana dashboards ConfigMaps for STAGING..."
# 	kubectl apply -n $(K8S_MONITORING_NAMESPACE) \
# 	  -f $(K8S_GRAFANA_DASHBOARD_CM_DIR)/grafana-dashboards-infra-staging.yaml \
# 	  -f $(K8S_GRAFANA_DASHBOARD_CM_DIR)/grafana-dashboards-myapp-staging.yaml

.PHONY: k8s-grafana-admin-secret-staging
k8s-grafana-admin-secret-staging:
	@echo "Applying Grafana admin secret for STAGING..."
	kubectl apply -f $(K8S_MONITORING_DIR)/grafana-admin-secret-staging.yaml

k8s-grafana-dashboards-staging:
	@echo "Generating and applying Grafana dashboards ConfigMaps for STAGING..."
	# Generate myapp dashboards ConfigMap
	kubectl create configmap grafana-dashboards-myapp-staging \
	  --from-file=$(K8S_GRAFANA_DASHBOARD_DIR)/staging/myapp/ \
	  -n $(K8S_MONITORING_NAMESPACE) \
	  --dry-run=client -o yaml | \
	  kubectl label --local -f - grafana_dashboard=1 --dry-run=client -o yaml | \
	  kubectl apply -f -
	# Generate infra dashboards ConfigMap
	kubectl create configmap grafana-dashboards-infra-staging \
	  --from-file=$(K8S_GRAFANA_DASHBOARD_DIR)/staging/infra/ \
	  -n $(K8S_MONITORING_NAMESPACE) \
	  --dry-run=client -o yaml | \
	  kubectl label --local -f - grafana_dashboard=1 --dry-run=client -o yaml | \
	  kubectl apply -f -	

# k8s-grafana-dashboards-prod:
# 	@echo "Applying Grafana dashboards ConfigMaps for PROD..."
# 	kubectl apply -n $(K8S_MONITORING_NAMESPACE) \
# 	  -f $(K8S_GRAFANA_DASHBOARD_CM_DIR)/grafana-dashboards-infra.yaml \
# 	  -f $(K8S_GRAFANA_DASHBOARD_CM_DIR)/grafana-dashboards-myapp.yaml

.PHONY: k8s-grafana-admin-secret-prod
k8s-grafana-admin-secret-prod:
	@echo "Applying Grafana admin secret for PROD..."
	kubectl apply -f $(K8S_MONITORING_DIR)/grafana-admin-secret-prod.yaml

k8s-grafana-dashboards-prod:
	@echo "Generating and applying Grafana dashboards ConfigMaps for PROD..."
	# Generate myapp dashboards ConfigMap
	kubectl create configmap grafana-dashboards-myapp-prod \
	  --from-file=$(K8S_GRAFANA_DASHBOARD_DIR)/prod/myapp/ \
	  -n $(K8S_MONITORING_NAMESPACE) \
	  --dry-run=client -o yaml | \
	  kubectl label --local -f - grafana_dashboard=1 --dry-run=client -o yaml | \
	  kubectl apply -f -
	# Generate infra dashboards ConfigMap
	kubectl create configmap grafana-dashboards-infra-prod \
	  --from-file=$(K8S_GRAFANA_DASHBOARD_DIR)/prod/infra/ \
	  -n $(K8S_MONITORING_NAMESPACE) \
	  --dry-run=client -o yaml | \
	  kubectl label --local -f - grafana_dashboard=1 --dry-run=client -o yaml | \
	  kubectl apply -f -

k8s-grafana-dashboards-all: k8s-grafana-dashboards-dev k8s-grafana-dashboards-staging k8s-grafana-dashboards-prod
	@echo "Grafana dashboard ConfigMaps applied for dev, staging, and prod."

# Apply Prometheus rules (base + SLOs)
# Because kubectl apply -f dir/ recursively applies all YAML 
# in that directory, this will pick up new rules automatically 
# as you add them
# Render and apply PrometheusRule for dev
k8s-alerts-dev:
	@echo "Applying myapp PrometheusRule alerts for DEV..."
	helm template $(K8S_ALERTS_RELEASE)-dev $(K8S_ALERTS_CHART_DIR) \
	  -f $(K8S_ALERTS_CHART_DIR)/values.yaml \
	  -f $(K8S_ALERTS_CHART_DIR)/values-dev.yaml \
	  --namespace $(K8S_ALERTS_NAMESPACE) \
	| kubectl apply -n $(K8S_ALERTS_NAMESPACE) -f -

# Render and apply PrometheusRule for staging, base + SLO for staging
k8s-alerts-staging:
	@echo "Applying myapp PrometheusRule alerts for STAGING..."
	helm template $(K8S_ALERTS_RELEASE)-staging $(K8S_ALERTS_CHART_DIR) \
	  -f $(K8S_ALERTS_CHART_DIR)/values.yaml \
	  -f $(K8S_ALERTS_CHART_DIR)/values-staging.yaml \
	  --namespace $(K8S_ALERTS_NAMESPACE) \
	| kubectl apply -n $(K8S_ALERTS_NAMESPACE) -f -

# Render and apply PrometheusRule for prod, base + SLO 
k8s-alerts-prod:
	@echo "Applying myapp PrometheusRule alerts for PROD..."
	helm template $(K8S_ALERTS_RELEASE)-prod $(K8S_ALERTS_CHART_DIR) \
	  -f $(K8S_ALERTS_CHART_DIR)/values.yaml \
	  -f $(K8S_ALERTS_CHART_DIR)/values-prod.yaml \
	  --namespace $(K8S_ALERTS_NAMESPACE) \
	| kubectl apply -n $(K8S_ALERTS_NAMESPACE) -f -

# Convenience target to apply all env rules (if you share a cluster), base + SLO 
k8s-alerts-all: k8s-alerts-dev k8s-alerts-staging k8s-alerts-prod
	@echo "myapp PrometheusRule alerts applied for dev, staging, and prod."

# You can add k8s-alerts-diff-* targets right next to the existing k8s-alerts-* targets, reusing the same variables. They will run helm template and pipe the result into kubectl diff -f - so you see what would change without applying it
# Show what would change for DEV alerts, without applying
# shows diff including SLO rules
k8s-alerts-diff-dev:
	@echo "Diffing myapp PrometheusRule alerts for DEV (no changes applied)..."
	helm template $(K8S_ALERTS_RELEASE)-dev $(K8S_ALERTS_CHART_DIR) \
	  -f $(K8S_ALERTS_CHART_DIR)/values.yaml \
	  -f $(K8S_ALERTS_CHART_DIR)/values-dev.yaml \
	  --namespace $(K8S_ALERTS_NAMESPACE) \
	| kubectl diff -n $(K8S_ALERTS_NAMESPACE) -f -

# Show what would change for STAGING alerts, without applying
# shows diff including SLO rules
k8s-alerts-diff-staging:
	@echo "Diffing myapp PrometheusRule alerts for STAGING (no changes applied)..."
	helm template $(K8S_ALERTS_RELEASE)-staging $(K8S_ALERTS_CHART_DIR) \
	  -f $(K8S_ALERTS_CHART_DIR)/values.yaml \
	  -f $(K8S_ALERTS_CHART_DIR)/values-staging.yaml \
	  --namespace $(K8S_ALERTS_NAMESPACE) \
	| kubectl diff -n $(K8S_ALERTS_NAMESPACE) -f -

# Show what would change for PROD alerts, without applying
# shows diff including SLO rules
k8s-alerts-diff-prod:
	@echo "Diffing myapp PrometheusRule alerts for PROD (no changes applied)..."
	helm template $(K8S_ALERTS_RELEASE)-prod $(K8S_ALERTS_CHART_DIR) \
	  -f $(K8S_ALERTS_CHART_DIR)/values.yaml \
	  -f $(K8S_ALERTS_CHART_DIR)/values-prod.yaml \
	  --namespace $(K8S_ALERTS_NAMESPACE) \
	| kubectl diff -n $(K8S_ALERTS_NAMESPACE) -f -

# Convenience: run diffs for all envs
# shows diff including SLO rules
k8s-alerts-diff-all: k8s-alerts-diff-dev k8s-alerts-diff-staging k8s-alerts-diff-prod
	@echo "Diff for myapp PrometheusRule alerts completed for dev, staging, and prod."


#  - kubectl diff -f file.yaml compares the cluster’s current 
#    object with what would be applied from that file and prints 
#    a YAML diff.
#  - I’ve added || true to avoid failing the Make target if 
#    kubectl diff exits with a non‑zero code (diff found). 
#    That way it behaves like a “preview” step. If you want 
#    CI to fail on any difference, remove || true
.PHONY: k8s-grafana-dashboards-diff-dev k8s-grafana-dashboards-diff-staging k8s-grafana-dashboards-diff-prod k8s-grafana-dashboards-diff-all

# Preview changes to DEV Grafana dashboard ConfigMaps (no apply)
k8s-grafana-dashboards-diff-dev:
	@echo "Diffing Grafana dashboards ConfigMaps for DEV (no changes applied)..."
	kubectl diff -n $(K8S_MONITORING_NAMESPACE) \
	  -f $(K8S_GRAFANA_DASHBOARD_CM_DIR)/grafana-dashboards-infra-dev.yaml \
	  -f $(K8S_GRAFANA_DASHBOARD_CM_DIR)/grafana-dashboards-myapp-dev.yaml || true

# Preview changes to STAGING Grafana dashboard ConfigMaps (no apply)
k8s-grafana-dashboards-diff-staging:
	@echo "Diffing Grafana dashboards ConfigMaps for STAGING (no changes applied)..."
	kubectl diff -n $(K8S_MONITORING_NAMESPACE) \
	  -f $(K8S_GRAFANA_DASHBOARD_CM_DIR)/grafana-dashboards-infra-staging.yaml \
	  -f $(K8S_GRAFANA_DASHBOARD_CM_DIR)/grafana-dashboards-myapp-staging.yaml || true

# Preview changes to PROD Grafana dashboard ConfigMaps (no apply)
k8s-grafana-dashboards-diff-prod:
	@echo "Diffing Grafana dashboards ConfigMaps for PROD (no changes applied)..."
	kubectl diff -n $(K8S_MONITORING_NAMESPACE) \
	  -f $(K8S_GRAFANA_DASHBOARD_CM_DIR)/grafana-dashboards-infra.yaml \
	  -f $(K8S_GRAFANA_DASHBOARD_CM_DIR)/grafana-dashboards-myapp.yaml || true

# Convenience: diff for all envs
k8s-grafana-dashboards-diff-all: k8s-grafana-dashboards-diff-dev k8s-grafana-dashboards-diff-staging k8s-grafana-dashboards-diff-prod
	@echo "Grafana dashboard ConfigMaps diffs completed for dev, staging, and prod."


# Install/upgrade Loki stack (Loki + Promtail) in dev
k8s-logging-dev: helm-add-repos ensure-minikube
	@echo "Installing/Upgrading Loki stack (dev) in namespace $(K8S_LOGGING_NAMESPACE)..."
	helm upgrade --install $(K8S_LOKI_RELEASE) grafana/loki-stack \
	  -n $(K8S_LOGGING_NAMESPACE) --create-namespace \
	  -f $(K8S_LOKI_VALUES_DEV)

#STAGING
# AWS creds for Loki S3 must be provided via environment:
# AWS_ACCESS_KEY_ID_STAGING=... AWS_SECRET_ACCESS_KEY_STAGING=... make k8s-logging-prod
k8s-logging-staging-secrets:
	@test -n "$(AWS_ACCESS_KEY_ID_STAGING)" || { echo "AWS_ACCESS_KEY_ID_STAGING not set"; exit 1; }
	@test -n "$(AWS_SECRET_ACCESS_KEY_STAGING)" || { echo "AWS_SECRET_ACCESS_KEY_STAGING not set"; exit 1; }
	@echo "Creating/updating loki-s3-credentials-staging secret in namespace $(K8S_LOGGING_NAMESPACE)..."
	kubectl delete secret loki-s3-credentials-staging \
	  -n $(K8S_LOGGING_NAMESPACE) --ignore-not-found >/dev/null 2>&1 || true
	kubectl create secret generic loki-s3-credentials-staging \
	  -n $(K8S_LOGGING_NAMESPACE) \
	  --from-literal=AWS_ACCESS_KEY_ID="$(AWS_ACCESS_KEY_ID_STAGING)" \
	  --from-literal=AWS_SECRET_ACCESS_KEY="$(AWS_SECRET_ACCESS_KEY_STAGING)"

# Add a “soft” wrapper for local smoke
# 	For local staging smoke, you want:
#		- If AWS env vars are set → run the strict target and get 
#         full S3‑backed Loki.
# 		- If they are not set → skip S3 secret setup but still proceed 
#         with the rest of the smoke.
.PHONY: k8s-logging-staging-secrets-soft
k8s-logging-staging-secrets-soft:
	@if [ -z "$(AWS_ACCESS_KEY_ID_STAGING)" ] || [ -z "$(AWS_SECRET_ACCESS_KEY_STAGING)" ]; then \
		echo "WARNING: AWS_ACCESS_KEY_ID_STAGING / AWS_SECRET_ACCESS_KEY_STAGING not set;"; \
		echo "skipping k8s-logging-staging-secrets (Loki S3 creds) in this environment."; \
	else \
		$(MAKE) k8s-logging-staging-secrets; \
	fi

# export AWS_ACCESS_KEY_ID_STAGING=staging-key
# export AWS_SECRET_ACCESS_KEY_STAGING=staging-secret
k8s-logging-staging: helm-add-repos ensure-minikube k8s-logging-staging-secrets-soft
	@echo "Installing/Upgrading Loki stack (staging) in namespace $(K8S_LOGGING_NAMESPACE)..."
	helm upgrade --install $(K8S_LOKI_RELEASE)-staging grafana/loki-stack \
	  -n $(K8S_LOGGING_NAMESPACE) --create-namespace \
	  -f $(K8S_LOKI_VALUES_STAGING)

#PROD
k8s-logging-prod-secrets:
	@test -n "$(AWS_ACCESS_KEY_ID)" || { echo "AWS_ACCESS_KEY_ID not set"; exit 1; }
	@test -n "$(AWS_SECRET_ACCESS_KEY)" || { echo "AWS_SECRET_ACCESS_KEY not set"; exit 1; }
	@echo "Creating/updating loki-s3-credentials-prod secret in namespace $(K8S_LOGGING_NAMESPACE)..."
	kubectl delete secret loki-s3-credentials-prod \
	  -n $(K8S_LOGGING_NAMESPACE) --ignore-not-found >/dev/null 2>&1 || true
	kubectl create secret generic loki-s3-credentials-prod \
	  -n $(K8S_LOGGING_NAMESPACE) \
	  --from-literal=AWS_ACCESS_KEY_ID="$(AWS_ACCESS_KEY_ID)" \
	  --from-literal=AWS_SECRET_ACCESS_KEY="$(AWS_SECRET_ACCESS_KEY)"

.PHONY: k8s-logging-prod-secrets-soft
k8s-logging-prod-secrets-soft:
	@if [ -z "$(AWS_ACCESS_KEY_ID_PROD)" ] || [ -z "$(AWS_SECRET_ACCESS_KEY_PROD)" ]; then \
		echo "WARNING: AWS_ACCESS_KEY_ID_PROD / AWS_SECRET_ACCESS_KEY_PROD not set; skipping k8s-logging-prod-secrets."; \
	else \
		$(MAKE) k8s-logging-prod-secrets; \
	fi
# export key values before calling make k8s-logging-prod
# export AWS_ACCESS_KEY_ID=xxxx
# export AWS_SECRET_ACCESS_KEY=yyyy
# # Deploy prod Loki (S3-backed) into the current cluster
# make k8s-logging-prod
k8s-logging-prod: helm-add-repos ensure-minikube k8s-logging-prod-secrets-soft
	@echo "Installing/Upgrading Loki stack (prod) in namespace $(K8S_LOGGING_NAMESPACE)..."
	helm upgrade --install $(K8S_LOKI_RELEASE)-prod grafana/loki-stack \
	  -n $(K8S_LOGGING_NAMESPACE) --create-namespace \
	  -f $(K8S_LOKI_VALUES_PROD)

# Deploy Loki logging stack for all envs (dev + staging + prod) in current cluster.
# Requires:
#   - dev: uses K8S_LOKI_VALUES_DEV (typically filesystem or simple storage)
#   - staging: AWS_ACCESS_KEY_ID_STAGING / AWS_SECRET_ACCESS_KEY_STAGING
#   - prod: AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY
# export AWS_ACCESS_KEY_ID_STAGING=staging-key
# export AWS_SECRET_ACCESS_KEY_STAGING=staging-secret
# export AWS_ACCESS_KEY_ID=prod-key
# export AWS_SECRET_ACCESS_KEY=prod-secret
k8s-logging-all: k8s-logging-dev k8s-logging-staging k8s-logging-prod
	@echo "Loki logging stacks deployed for dev, staging, and prod."

# ---------- APP OBSERVABILITY CHECKS PER ENV ----------
# Add env-specific deploy/observability targets
# verify workload readiness and inspect runtime signals in each namespace.
# DEV: run checks against the dev namespace in Minikube.
# Dev: prefer the dev-local image when running k8s-smoke-dev locally.
# In CI, you can override EXPECTED_IMAGE_DEV via environment if you want.
EXPECTED_IMAGE_DEV ?= $(LOCAL_MYAPP_IMAGE_DEV)
k8s-observability-check-dev:
	$(call check-k8s-context,$(K8S_CONTEXT_DEV))
	$(call check-k8s-namespace,$(K8S_APP_NAMESPACE_DEV))
	$(call k8s_observability_check,DEV,$(K8S_CONTEXT_DEV),$(K8S_APP_NAMESPACE_DEV),$(K8S_MYAPP_DEPLOY_DEV),$(EXPECTED_IMAGE_DEV))

# STAGING: run checks against the staging namespace in Minikube for now.
# Staging: usually use the staging tag from registry; you can override EXPECTED_IMAGE_STAGING in CI.
EXPECTED_IMAGE_STAGING ?= $(LOCAL_MYAPP_IMAGE_STAGING)
k8s-observability-check-staging:
	$(call check-k8s-context,$(K8S_CONTEXT_STAGING))
	$(call check-k8s-namespace,$(K8S_APP_NAMESPACE_STAGING))
	$(call k8s_observability_check,STAGING,$(K8S_CONTEXT_STAGING),$(K8S_APP_NAMESPACE_STAGING),$(K8S_MYAPP_DEPLOY_STAGING),$(EXPECTED_IMAGE_STAGING))

# PROD: run checks against the prod namespace in Minikube for now.
# Prod: same pattern.
EXPECTED_IMAGE_PROD ?= $(LOCAL_MYAPP_IMAGE_PROD)
k8s-observability-check-prod:
	$(call check-k8s-context,$(K8S_CONTEXT_PROD))
	$(call check-k8s-namespace,$(K8S_APP_NAMESPACE_PROD))
	$(call k8s_observability_check,PROD,$(K8S_CONTEXT_PROD),$(K8S_APP_NAMESPACE_PROD),$(K8S_MYAPP_DEPLOY_PROD),$(EXPECTED_IMAGE_PROD))

.PHONY: k8s-http-smoke-dev
k8s-http-smoke-dev: ## HTTP-level smoke for myapp-dev via Service
	$(call k8s_http_smoke_check,DEV,$(K8S_APP_NAMESPACE_DEV),$(K8S_MYAPP_DEPLOY_DEV),8000)

.PHONY: k8s-http-smoke-staging
k8s-http-smoke-staging: ## HTTP-level smoke for myapp-staging via Service
	$(call k8s_http_smoke_check,STAGING,$(K8S_APP_NAMESPACE_STAGING),$(K8S_MYAPP_DEPLOY_STAGING),8000)

.PHONY: k8s-http-smoke-prod
k8s-http-smoke-prod: ## HTTP-level smoke for myapp-prod via Service
	$(call k8s_http_smoke_check,PROD,$(K8S_APP_NAMESPACE_PROD),$(K8S_MYAPP_DEPLOY_PROD),8000)

# ---------- APP OBSERVABILITY CHECKS (ALL ENVIRONMENTS) ----------
# Add an aggregate target
k8s-observability-check-all: k8s-observability-check-dev k8s-http-smoke-dev k8s-observability-check-staging k8s-http-smoke-staging k8s-observability-check-prod k8s-http-smoke-prod
	@echo "Observability + HTTP checks completed for dev, staging, and prod."

# --------- in‑cluster service smoke ------------------------------
# An in‑cluster service test answers:
# 	- “If I am a pod inside the cluster, can I reach myapp via its Kubernetes Service?

.PHONY: k8s-incluster-smoke-myapp-dev
k8s-incluster-smoke-myapp-dev:
	$(call k8s_incluster_smoke_check,$(K8S_APP_NAMESPACE_DEV),$(K8S_MYAPP_DEPLOY_DEV))

.PHONY: k8s-incluster-smoke-myapp-staging
k8s-incluster-smoke-myapp-staging:
	$(call k8s_incluster_smoke_check,$(K8S_APP_NAMESPACE_STAGING),$(K8S_MYAPP_DEPLOY_STAGING))

.PHONY: k8s-incluster-smoke-myapp-prod
k8s-incluster-smoke-myapp-prod:
	$(call k8s_incluster_smoke_check,$(K8S_APP_NAMESPACE_PROD),$(K8S_MYAPP_DEPLOY_PROD))

# The in‑cluster Grafana smoke answers:
# 	- “If I am another pod inside the cluster (in monitoring), 
#	   can I reach the Grafana Service and get a valid HTTP response?”
.PHONY: k8s-incluster-grafana-smoke-staging
k8s-incluster-grafana-smoke-staging:
	$(call k8s_incluster_grafana_smoke,$(K8S_MONITORING_NAMESPACE),$(K8S_KPS_RELEASE)-staging-grafana)

.PHONY: k8s-incluster-grafana-smoke-prod
k8s-incluster-grafana-smoke-prod:
	$(call k8s_incluster_grafana_smoke,$(K8S_MONITORING_NAMESPACE),$(K8S_KPS_RELEASE)-prod-grafana)

# ---------- INFRA OBSERVABILITY CHECKS (Prometheus / Grafana / Loki) ----------
#Right now, all three envs (dev/staging/prod) are on the same Minikube cluster, sharing:
#	- monitoring namespace
#	- logging namespace
# 	- same Prometheus/Grafana/Loki releases, just with -staging / -prod suffixes for some Helm releases, but same namespace.
# Infra-level observability checks (Prometheus/Grafana/Loki)
# This encapsulates the kubectl get/wait/port-forward + curl checks you had in ci.yml.
k8s-observability-infra-check: ## Verify monitoring/logging stack health in Minikube
	@echo "Checking observability components in Minikube..."

	# Check pods in monitoring and logging namespaces.
	kubectl -n $(K8S_MONITORING_NAMESPACE) get pods
	kubectl -n $(K8S_LOGGING_NAMESPACE) get pods

	@echo "Checking if Grafana is already Available..."
	# Fast-path: if Grafana is already Available, skip long waits.
	if kubectl -n $(K8S_MONITORING_NAMESPACE) get deploy -l app.kubernetes.io/name=grafana \
		-o jsonpath='{.items[0].status.conditions[?(@.type=="Available")].status}' 2>/dev/null | grep -q True; then \
		echo "Grafana already Available – skipping full wait."; \
	else \
		echo "Waiting for Grafana to become Available..."; \
		kubectl -n $(K8S_MONITORING_NAMESPACE) wait --for=condition=available --timeout=120s deploy -l app.kubernetes.io/name=grafana; \
	fi

	# Check Loki pods.
	kubectl -n $(K8S_LOGGING_NAMESPACE) get pods -l app.kubernetes.io/name=loki

	# Check that PrometheusRules and ServiceMonitors exist.
	kubectl -n $(K8S_MONITORING_NAMESPACE) get prometheusrules
	kubectl -n $(K8S_MONITORING_NAMESPACE) get servicemonitors

	# Quick HTTP checks to Prometheus and Grafana via port-forward.
	@echo "Port-forwarding Prometheus on 9091..."
	kubectl -n $(K8S_MONITORING_NAMESPACE) port-forward svc/$(K8S_KPS_RELEASE)-kube-prometheus-stack-prometheus 9091:9090 >/tmp/pf-prom.log 2>&1 & \
	PF_PROM=$$!; \
	sleep 5; \
	curl -sf http://127.0.0.1:9091/-/ready; \
	kill $$PF_PROM || true

	@echo "Port-forwarding Grafana on 3001..."
	kubectl -n $(K8S_MONITORING_NAMESPACE) port-forward svc/$(K8S_KPS_RELEASE)-grafana 3001:80 >/tmp/pf-graf.log 2>&1 & \
	PF_GRAF=$$!; \
	sleep 5; \
	curl -sf http://127.0.0.1:3001/login; \
	kill $$PF_GRAF || true

	@echo "Minikube observability stack looks healthy."

# Finally, define a single target to bring up the entire observability 
# stack in whatever cluster your current kube‑context points at:
# Full observability stack for DEV in current cluster:
# - creates namespaces (monitoring + myapp envs),
# - kube-prometheus-stack (Prometheus, Alertmanager, Grafana)
# - Loki + Promtail
# - PrometheusRule files (base + SLOs) + Dashboard
# - applies NetworkPolicies.
k8s-observability-dev: \
	k8s-namespaces-all \
	k8s-monitoring-dev \
	k8s-logging-dev \
	k8s-alerts-dev \
	k8s-grafana-dashboards-dev \
	k8s-netpol-dev ## Deploy full observability stack to dev cluster (namespaces, monitoring, logging, alerts, dashboards, netpol)
	@echo "K8s observability stack (dev) deployed  (namespaces, monitoring, logging, rules, dashboards, netpol)."

k8s-observability-staging: \
	k8s-namespaces-all \
	k8s-monitoring-staging \
	k8s-logging-staging \
	k8s-grafana-admin-secret-staging \
	k8s-alerts-staging \
	k8s-grafana-dashboards-staging \
	k8s-netpol-staging
	@echo "K8s observability stack (staging) deployed  (namespaces, monitoring, logging, rules, dashboards, netpol)."

k8s-observability-prod: \
	k8s-namespaces-all \
	k8s-monitoring-prod \
	k8s-logging-prod \
	k8s-grafana-admin-secret-prod \
	k8s-alerts-prod \
	k8s-grafana-dashboards-prod \
	k8s-netpol-prod
	@echo "K8s observability stack (prod) deployed  (namespaces, monitoring, logging, rules, dashboards, netpol)."

# Full observability stack (monitoring + logging) for all envs:
# - kube-prometheus-stack: dev, staging, prod
# - Loki + Promtail: dev, staging, prod
#
# Requires:
#   AWS_ACCESS_KEY_ID_STAGING / AWS_SECRET_ACCESS_KEY_STAGING for staging Loki
#   AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY for prod Loki
k8s-observability-all: k8s-observability-dev k8s-observability-staging k8s-observability-prod
	@echo "K8s observability stack deployed for dev, staging, and prod."

.PHONY: build-myapp-dev-local build-myapp-satging-local build-myapp-prod-local 
build-myapp-dev-local: ## Build local dev image for myapp (used by k8s-smoke-dev)
	@echo "Building local dev image $(LOCAL_MYAPP_IMAGE_DEV)..."
	@echo "Using Minikube Docker daemon..."
	eval "$$(minikube docker-env)" && \
	docker build -t $(LOCAL_MYAPP_IMAGE_DEV) -f myapp/Dockerfile . && \
	eval "$$(minikube docker-env -u)"
	@echo "Local dev image built: $(LOCAL_MYAPP_IMAGE_DEV)"

build-myapp-staging-local: ## Build local staging image for myapp (used by k8s-smoke-staging)
	@echo "Building local staging image $(LOCAL_MYAPP_IMAGE_STAGING)..."
	@echo "Using Minikube Docker daemon..."
	eval "$$(minikube docker-env)" && \
	docker build -t $(LOCAL_MYAPP_IMAGE_STAGING) -f myapp/Dockerfile . && \
	eval "$$(minikube docker-env -u)"
	@echo "Local staging image built: $(LOCAL_MYAPP_IMAGE_STAGING)"

build-myapp-prod-local: ## Build local dev image for myapp (used by k8s-smoke-prod)
	@echo "Building local prod image $(LOCAL_MYAPP_IMAGE_PROD)..."
	@echo "Using Minikube Docker daemon..."
	eval "$$(minikube docker-env)" && \
	docker build -t $(LOCAL_MYAPP_IMAGE_PROD) -f myapp/Dockerfile . && \
	eval "$$(minikube docker-env -u)"
	@echo "Local prod image built: $(LOCAL_MYAPP_IMAGE_PROD)"


# ---------- END-TO-END APP + OBSERVABILITY SMOKE PER ENV ----------
# Dev: deploy myapp to myapp-dev and then run observability checks.
# what each dependency does:
# 	k8-deploy-myapp-* → deploy app (GHCR image + Helm) into 
#						myapp-<env> namespace (you already have these).
# 	k8s-observability-* → install/upgrade observability stack 
#						(monitoring, logging, dashboards, alerts, netpol) for that env.
# 	k8s-observability-check-* → run runtime checks 
#						(pods, services, metrics, logs) in that env.


# k8s-smoke-dev: ensure-minikube k8-deploy-myapp-dev k8s-observability-dev k8s-observability-check-dev ## Deploy + observability smoke for DEV
# 	@echo "End-to-end DEV smoke (app deploy + observability) completed."

# Key points:
#
# First local run: you just type make k8s-smoke-dev-local.
# It will build myapp:dev-local then deploy it and run 
# observability checks.
#
# Subsequent local runs: it will reuse the same local image; 
# no rebuild unless you change the target to always build or 
# add --pull in the Dockerfile step.

# CI / promotion use: in GitHub Actions you already have MYAPP_IMAGE=${{ needs.ci.outputs.image_myapp_dev }}; when you call make k8s-smoke-dev there, it will skip the local build and use the CI image.
k8s-smoke-dev-local: k8s-namespaces-myapp ## Full DEV smoke (local) – build image + secret + deploy + observability
	@echo "Checking minikube status..."
	$(MAKE) ensure-minikube

	@echo "Creating myapp-secret for dev..."
	$(MAKE) create-secrets \
		K8S_NAMESPACE=myapp-dev \
		K8_DB_HOST=localhost \
		K8_DB_PORT=5432 \
		K8_DB_NAME=mydb \
		K8_DB_USER=myuser \
		K8_DB_PASSWORD=mypassword \
		K8_UPTRACE_TOKEN=$(UPTRACE_TOKEN) \
		K8_UPTRACE_DSN=$(UPTRACE_DSN)

	@echo "Resolving image for local DEV..."
	@if [ -n "$$MYAPP_IMAGE" ]; then \
		IMAGE="$$MYAPP_IMAGE"; \
		echo "Using provided MYAPP_IMAGE=$$IMAGE"; \
	else \
		echo "MYAPP_IMAGE not set, building and using local dev image $(LOCAL_MYAPP_IMAGE_DEV)"; \
		$(MAKE) build-myapp-dev-local; \
		IMAGE="$(LOCAL_MYAPP_IMAGE_DEV)"; \
	fi; \
	echo "Deploying myapp to myapp-dev namespace with image $$IMAGE..."; \
	$(MAKE) k8-deploy-myapp \
		CHART_NAME="myapp-dev" \
		K8S_NAMESPACE="myapp-dev" \
		ENV_VALUES="environments/dev/values-myapp.yaml" \
		MYAPP_IMAGE="$$IMAGE"

	@echo "Cleaning up old myapp-dev pods not using $(LOCAL_MYAPP_IMAGE_DEV)..."
	@kubectl -n myapp-dev get pods -l app.kubernetes.io/name=myapp -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.containers[0].image}{"\n"}{end}' \
	 | awk '$$2 != "$(LOCAL_MYAPP_IMAGE_DEV)" {print $$1}' \
	 | xargs -r kubectl -n myapp-dev delete pod

	$(MAKE) k8s-smoke-dev
	@echo "End-to-end DEV smoke (app deploy + observability) completed."

k8s-smoke-staging-local: k8s-namespaces-myapp ## Full STAGING smoke (local) – build image + secret + deploy + observability + HTTP
	@echo "Checking minikube status..."
	$(MAKE) ensure-minikube

	@echo "Creating myapp-secret for staging..."
	$(MAKE) create-secrets \
		K8S_NAMESPACE=myapp-staging \
		K8_DB_HOST=localhost \
		K8_DB_PORT=5432 \
		K8_DB_NAME=mydb \
		K8_DB_USER=myuser \
		K8_DB_PASSWORD=mypassword \
		K8_UPTRACE_TOKEN=$(UPTRACE_TOKEN) \
		K8_UPTRACE_DSN=$(UPTRACE_DSN)

	@echo "Resolving image for local STAGING..."
	@if [ -n "$$MYAPP_IMAGE" ]; then \
		IMAGE="$$MYAPP_IMAGE"; \
		echo "Using provided MYAPP_IMAGE=$$IMAGE"; \
	else \
		echo "MYAPP_IMAGE not set, building and using local staging image $(LOCAL_MYAPP_IMAGE_STAGING)"; \
		$(MAKE) build-myapp-staging-local; \
		IMAGE="$(LOCAL_MYAPP_IMAGE_STAGING)"; \
	fi; \
	echo "Deploying myapp to myapp-staging namespace with image $$IMAGE..."; \
	$(MAKE) k8-deploy-myapp \
		CHART_NAME="myapp-staging" \
		K8S_NAMESPACE="myapp-staging" \
		ENV_VALUES="environments/staging/values-myapp.yaml" \
		MYAPP_IMAGE="$$IMAGE"

	@echo "Cleaning up old myapp-staging pods not using $(LOCAL_MYAPP_IMAGE_STAGING)..."
	@kubectl -n myapp-staging get pods -l app.kubernetes.io/name=myapp -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.containers[0].image}{"\n"}{end}' \
	 | awk '$$2 != "$(LOCAL_MYAPP_IMAGE_STAGING)" {print $$1}' \
	 | xargs -r kubectl -n myapp-staging delete pod

	$(MAKE) k8s-smoke-staging
	@echo "End-to-end STAGING smoke (app deploy + observability + HTTP) completed."

k8s-smoke-prod-local: k8s-namespaces-myapp ## Full PROD smoke (local) – build image + secret + deploy + observability + HTTP
	@echo "Checking minikube status..."
	$(MAKE) ensure-minikube

	@echo "Creating myapp-secret for prod..."
	$(MAKE) create-secrets \
		K8S_NAMESPACE=myapp-prod \
		K8_DB_HOST=localhost \
		K8_DB_PORT=5432 \
		K8_DB_NAME=mydb \
		K8_DB_USER=myuser \
		K8_DB_PASSWORD=mypassword \
		K8_UPTRACE_TOKEN=$(UPTRACE_TOKEN) \
		K8_UPTRACE_DSN=$(UPTRACE_DSN)

	@echo "Resolving image for local PROD..."
	@if [ -n "$$MYAPP_IMAGE" ]; then \
		IMAGE="$$MYAPP_IMAGE"; \
		echo "Using provided MYAPP_IMAGE=$$IMAGE"; \
	else \
		echo "MYAPP_IMAGE not set, building and using local prod image $(LOCAL_MYAPP_IMAGE_PROD)"; \
		$(MAKE) build-myapp-prod-local; \
		IMAGE="$(LOCAL_MYAPP_IMAGE_PROD)"; \
	fi; \
	echo "Deploying myapp to myapp-prod namespace with image $$IMAGE..."; \
	$(MAKE) k8-deploy-myapp \
		CHART_NAME="myapp-prod" \
		K8S_NAMESPACE="myapp-prod" \
		ENV_VALUES="environments/prod/values-myapp.yaml" \
		MYAPP_IMAGE="$$IMAGE"

	@echo "Cleaning up old myapp-prod pods not using $(LOCAL_MYAPP_IMAGE_PROD)..."
	@kubectl -n myapp-prod get pods -l app.kubernetes.io/name=myapp -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.containers[0].image}{"\n"}{end}' \
	 | awk '$$2 != "$(LOCAL_MYAPP_IMAGE_PROD)" {print $$1}' \
	 | xargs -r kubectl -n myapp-prod delete pod

	$(MAKE) k8s-smoke-prod
	@echo "End-to-end PROD smoke (app deploy + observability + HTTP) completed."

.PHONY: k8s-smoke-dev
# CI/CD jobs: create secret + deploy app (as you have).
# k8s-smoke-dev: assume app is deployed, only do observability 
# 				 wiring + checks.
k8s-smoke-dev: ## Observability smoke for DEV (assumes dev app already deployed)
	@echo "Running DEV observability smoke (stack + app checks)..."
	$(MAKE) k8s-observability-dev         # namespaces + monitoring + logging + rules + dashboards + netpol
	$(MAKE) k8s-observability-infra-check # Prom/Grafana/Loki in monitoring/logging
	$(MAKE) k8s-observability-check-dev   # Pod-level health (probes + logs), app-level checks in myapp-dev
	$(MAKE) k8s-incluster-smoke-myapp-dev
	$(MAKE) k8s-http-smoke-dev			  # Service-level behavior, 
	@echo "End-to-end DEV smoke (observability + HTTP) completed."

k8s-smoke-staging: ## Observability smoke for STAGING (assumes staging app already deployed)
	@echo "Running STAGING observability smoke (stack + app checks)..."
	$(MAKE) k8s-logging-staging-secrets-soft
	$(MAKE) k8s-observability-staging         # namespaces + monitoring + logging + rules + dashboards + netpol
	$(MAKE) k8s-observability-infra-check # Prom/Grafana/Loki in monitoring/logging
	$(MAKE) k8s-incluster-grafana-smoke-staging
	$(MAKE) k8s-observability-check-staging   # app-level checks in myapp-staging
	$(MAKE) k8s-incluster-smoke-myapp-staging
	$(MAKE) k8s-http-smoke-staging			  # Service-level behavior,
	@echo "End-to-end STAGING smoke (observability + HTTP) completed."

k8s-smoke-prod: ## Observability smoke for PROD (assumes prod app already deployed)
	@echo "Running PROD observability smoke (stack + app checks)..."
	$(MAKE) k8s-logging-prod-secrets-soft
	$(MAKE) k8s-observability-prod         # namespaces + monitoring + logging + rules + dashboards + netpol
	$(MAKE) k8s-observability-infra-check # Prom/Grafana/Loki in monitoring/logging
	$(MAKE) k8s-incluster-grafana-smoke-prod
	$(MAKE) k8s-observability-check-prod   # app-level checks in myapp-prod
	$(MAKE) k8s-incluster-smoke-myapp-prod
	$(MAKE) k8s-http-smoke-prod			  # Service-level behavior,
	@echo "End-to-end PROD smoke (observability + HTTP) completed."

# # Staging: deploy myapp to myapp-staging and then run observability checks.
# k8s-smoke-staging: ensure-minikube k8-deploy-myapp-staging k8s-observability-staging k8s-observability-check-staging ## Deploy + observability smoke for STAGING
# 	@echo "End-to-end STAGING smoke (app deploy + observability) completed."

# # Prod: deploy myapp to myapp-prod and then run observability checks.
# k8s-smoke-prod: ensure-minikube k8-deploy-myapp-prod k8s-observability-prod k8s-observability-check-prod ## Deploy + observability smoke for PROD
# 	@echo "End-to-end PROD smoke (app deploy + observability) completed."

# Convenience target to run dev/staging/prod smokes in sequence (local minikube).
k8s-smoke-all: k8s-smoke-dev k8s-smoke-staging k8s-smoke-prod ## Deploy + observability smoke for all envs
	@echo "End-to-end smoke completed for dev, staging, and prod."


.PHONY: k8s-clean-minikube k8s-clean-namespaces k8s-clean-pvcs

# Delete key app/infra namespaces but keep Minikube VM + images
k8s-clean-minikube:
	@echo "=== Cleaning Minikube workloads (namespaces + PVCs) without deleting cluster... ==="
	$(MAKE) k8s-clean-namespaces
	$(MAKE) k8s-clean-pvcs
	@echo "=== Minikube workloads cleaned. Cluster and image cache are still intact. ==="

# Delete namespaces you own
k8s-clean-namespaces:
	@echo "Deleting application and infra namespaces (if they exist)..."
	# app env namespaces
	kubectl delete namespace myapp-dev --ignore-not-found
	kubectl delete namespace myapp-staging --ignore-not-found
	kubectl delete namespace myapp-prod --ignore-not-found
	# local namespace
	kubectl delete namespace myapp-local --ignore-not-found
	# monitoring/logging
	kubectl delete namespace $(K8S_MONITORING_NAMESPACE) --ignore-not-found
	kubectl delete namespace $(K8S_LOGGING_NAMESPACE) --ignore-not-found

# Optionally clean PVCs cluster-wide (dev-only)
# The PVC wipe is dev‑only; if you ever mount hostPath or external volumes, this won’t touch them, only Kubernetes PVC objects
k8s-clean-pvcs:
	@echo "Deleting all PersistentVolumeClaims in the cluster (dev-only)..."
	kubectl delete pvc --all --all-namespaces || true

#	- docker ps -a --filter "ancestor=myapp:dev-local" -q lists containers created from that image.
# 	- xargs -r docker rm -f removes them forcefully if any exist.
#	- Then the docker image rm myapp:dev-local will succeed because no 
#	  containers reference it anymore.
#	- docker image prune -f cleans up dangling images.
.PHONY: clean-local-dev-images
clean-local-dev-images: ## Remove local dev containers/images to free space
	@echo "Stopping and removing containers using $(LOCAL_MYAPP_IMAGE_DEV) (if any)..."
	@docker ps -a --filter "ancestor=$(LOCAL_MYAPP_IMAGE_DEV)" -q | xargs -r docker rm -f
	@echo "Removing image $(LOCAL_MYAPP_IMAGE_DEV) (if present)..."
	@docker image rm $(LOCAL_MYAPP_IMAGE_DEV) || true
	@echo "Pruning dangling images..."
	@docker image prune -f

.PHONY: clean-local-staging-images
clean-local-staging-images: ## Remove local staging images to free space
	@echo "Stopping and removing containers using $(LOCAL_MYAPP_IMAGE_STAGING) (if any)..."
	@docker ps -a --filter "ancestor=$(LOCAL_MYAPP_IMAGE_STAGING)" -q | xargs -r docker rm -f	
	@echo "Removing image $(LOCAL_MYAPP_IMAGE_STAGING) (if present)..."	
	@docker image rm $(LOCAL_MYAPP_IMAGE_STAGING) || true
	@echo "Pruning dangling images..."	
	@docker image prune -f

.PHONY: clean-local-prod-images
clean-local-prod-images: ## Remove local prod containers/images to free space
	@echo "Stopping and removing containers using $(LOCAL_MYAPP_IMAGE_PROD) (if any)..."
	@docker ps -a --filter "ancestor=$(LOCAL_MYAPP_IMAGE_PROD)" -q | xargs -r docker rm -f
	@echo "Removing image $(LOCAL_MYAPP_IMAGE_PROD) (if present)..."
	@docker image rm $(LOCAL_MYAPP_IMAGE_PROD) || true
	@echo "Pruning dangling images..."
	@docker image prune -f

.PHONY: clean-local-images
clean-local-images:
	$(MAKE) clean-local-dev-images
	$(MAKE) clean-local-staging-images
	$(MAKE) clean-local-prod-images

.PHONY: k8s-nuke
k8s-nuke:
	$(MAKE) clean-local-images
	@echo "!!! FULL NUKE: cleaning namespaces/PVCs and recreating Minikube cluster !!!"
	$(MAKE) k8s-clean-minikube
	$(MAKE) recreate-minikube

# -------------------------- ArgoCD --------------------------------------------------------

# -------------------------- ArgoCD bootstrap ----------------------------------------------
.PHONY: argocd-install
argocd-install:
# 1) Create namespace
	kubectl create namespace $(ARGOCD_NAMESPACE) || true
# 2) Install ArgoCD (stable manifests include ApplicationSet controller)
	kubectl apply -n $(ARGOCD_NAMESPACE) --server-side --force-conflicts -f $(ARGOCD_MANIFEST_URL)
# 3) Wait for all ArgoCD pods to be ready:
	kubectl wait --for=condition=Ready pods --all -n $(ARGOCD_NAMESPACE) --timeout=300s
# You should see pods like:
# 	argocd-server
# 	argocd-repo-server
# 	argocd-application-controller
# 	argocd-applicationset-controller
	kubectl get pods -n $(ARGOCD_NAMESPACE)

# Access ArgoCD UI
# Port‑forward the UI, You can now see each Application, their sync status, health, and logs
.PHONY: argocd-port-forward
argocd-port-forward:
	kubectl port-forward svc/argocd-server -n $(ARGOCD_NAMESPACE) 8080:443

# Password
.PHONY: argocd-admin-password
argocd-admin-password:
	kubectl -n $(ARGOCD_NAMESPACE) get secret argocd-initial-admin-secret \
	  -o jsonpath="{.data.password}" | base64 -d && echo

# ---- ArgoCD ApplicationSets for myapp ----

# Apply the ApplicationSet in your ArgoCD bootstrap
# installing kube‑prometheus‑stack + CRDs
.PHONY: argocd-apply-cluster-monitoring-appset
argocd-apply-cluster-monitoring-appset:
	kubectl apply -f gitops/argocd-appset-cluster-monitoring.yaml

# Apply ApplicationSets
# After this, The ApplicationSet controller will then generate Application objects automatically.
.PHONY: argocd-apply-appsets
argocd-apply-appsets:
	kubectl apply -f $(GITOPS_DIR)/argocd-appset-monitoring.yaml
	kubectl apply -f $(GITOPS_DIR)/argocd-appset-logging.yaml
	kubectl apply -f $(GITOPS_DIR)/argocd-appset-myapp.yaml

# Check Application objects
# You should see something like:
# 	myapp-monitoring-dev|staging|prod
# 	myapp-logging-dev|staging|prod
# 	myapp-dev|staging|prod
# They’ll initially be OutOfSync until they sync the first time.
.PHONY: argocd-list-apps
argocd-list-apps:
	kubectl get applications.argoproj.io -n $(ARGOCD_NAMESPACE)

.PHONY: argocd-repo-https-secret
argocd-repo-https-secret:
	@if [ ! -f "$(REPO_HTTPS_SECRET_FILE)" ]; then \
	  echo "ERROR: $(REPO_HTTPS_SECRET_FILE) not found."; \
	  echo "Create it with your HTTPS repo credentials (GitHub PAT) before bootstrapping."; \
	  exit 1; \
	fi
	kubectl apply -f $(REPO_HTTPS_SECRET_FILE)

# Keep argocd-rbac-cm.yaml under gitops/argocd/ (without secrets).
.PHONY: argocd-rbac
argocd-rbac:
	kubectl apply -f gitops/argocd/argocd-rbac-cm.yaml
	kubectl rollout restart deployment argocd-server -n $(ARGOCD_NAMESPACE)
	# In the standard Argo CD install, the application controller runs 
	# as a StatefulSet, not a Deployment
	kubectl rollout restart statefulset argocd-application-controller -n $(ARGOCD_NAMESPACE)

# Full bootstrap from scratch, 
# From a clean Minikube: make k8s-bootstrap-argocd
.PHONY: k8s-bootstrap-argocd
k8s-bootstrap-argocd:
	$(MAKE) argocd-install
	$(MAKE) argocd-rbac
	$(MAKE) argocd-repo-https-secret
	$(MAKE) argocd-apply-appsets
	$(MAKE) argocd-apply-cluster-monitoring-appset
	$(MAKE) argocd-list-apps

# ---- ArgoCD CLI install ---------------------------------------------
# CLI install (Linux / WSL)
# This mirrors the official install snippet 
#   (download latest Linux binary, mark executable).
# Download the argocd binary to $(ARGOCD_CLI_BIN) (which in your Makefile appears to 
#   be argocd in the current directory).
# Mark it executable.
# Run ./argocd version --client to verify.
.PHONY: argocd-cli-install
argocd-cli-install:
	mkdir -p bin
	curl -sSL -o $(ARGOCD_CLI_BIN) "$(ARGOCD_CLI_URL)"
	chmod +x $(ARGOCD_CLI_BIN)
	# Put it in PATH if needed; on WSL you can keep it in repo and call ./argocd
	$(ARGOCD_CLI_BIN) version --client

# ---- ArgoCD CLI login (local Minikube) --------------------------------------
# Make targets to sync via ArgoCD (not Helm)
# We’ll assume you’re using the ApplicationSets we discussed, which generate these Applications:
# 	- Monitoring: myapp-monitoring-dev|staging|prod
# 	- Logging: myapp-logging-dev|staging|prod
# 	- App: myapp-dev|staging|prod
# We’ll create:
# 	- argocd-login-local – log in the CLI to the ArgoCD server.
# 	- argocd-sync-dev|staging|prod – sync apps for each env and wait for them to become Healthy.
# Env smokes can call these instead of helm upgrade.
# Duplicate, see above
# .PHONY: argocd-port-forward
# argocd-port-forward:
# 	kubectl port-forward svc/argocd-server -n $(ARGOCD_NAMESPACE) 8080:443

# Duplicate, see above
# .PHONY: argocd-admin-password
# argocd-admin-password:
# 	kubectl -n $(ARGOCD_NAMESPACE) get secret argocd-initial-admin-secret \
# 	  -o jsonpath="{.data.password}" | base64 -d && echo

# This logs in using the initial admin password and grpc-web via the 
# port‑forwarded endpoint.
# For a “real” cluster, you’d use the LoadBalancer URL and proper TLS; 
# but design is the same.
.PHONY: argocd-login-local
argocd-login-local:
	@if [ ! -x "$(ARGOCD_CLI_BIN)" ]; then \
	  echo "ERROR: $(ARGOCD_CLI_BIN) not found or not executable. Run 'make argocd-cli-install' first."; \
	  exit 1; \
	fi
	@echo "Starting port-forward to ArgoCD server on localhost:8080..."
	-kubectl port-forward svc/argocd-server -n $(ARGOCD_NAMESPACE) 8080:443 >/tmp/argocd-pf.log 2>&1 &
	@echo "Waiting for ArgoCD server port-forward to be ready..."
	@for i in $$(seq 1 20); do \
	  if nc -z localhost 8080 2>/dev/null; then \
	    echo "ArgoCD server is reachable on localhost:8080"; \
	    break; \
	  fi; \
	  sleep 1; \
	  if [ $$i -eq 20 ]; then \
	    echo "ERROR: ArgoCD server not reachable on localhost:8080 after 20s"; \
	    exit 1; \
	  fi; \
	done
	@echo "Logging into ArgoCD at $(ARGOCD_SERVER) as $(ARGOCD_USERNAME)..."
	$(ARGOCD_CLI_BIN) login $(ARGOCD_SERVER) \
	  --username $(ARGOCD_USERNAME) \
	  --password "$$(kubectl -n $(ARGOCD_NAMESPACE) get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)" \
	  --grpc-web \
	  $(if $(ARGOCD_INSECURE),--insecure,)

# ---- ArgoCD app sync targets ----
# Sync targets per environment
# This uses the standard argocd app sync and argocd app wait commands 
# to sync and ensure all three apps per env are Healthy.
# Check Guide-ArgoCD-Resync-dev_staging_prod.md for more details, when should we call this?
.PHONY: argocd-sync-dev
argocd-sync-dev: argocd-login-local
	$(ARGOCD_CLI_BIN) app sync myapp-monitoring-dev
	$(ARGOCD_CLI_BIN) app sync myapp-logging-dev
	$(ARGOCD_CLI_BIN) app sync myapp-dev
	$(ARGOCD_CLI_BIN) app wait myapp-monitoring-dev myapp-logging-dev myapp-dev \
	  --health --timeout 300

.PHONY: argocd-sync-staging
argocd-sync-staging: argocd-login-local
	$(ARGOCD_CLI_BIN) app sync myapp-monitoring-staging
	$(ARGOCD_CLI_BIN) app sync myapp-logging-staging
	$(ARGOCD_CLI_BIN) app sync myapp-staging
	$(ARGOCD_CLI_BIN) app wait myapp-monitoring-staging myapp-logging-staging myapp-staging \
	  --health --timeout 300

.PHONY: argocd-sync-prod
argocd-sync-prod: argocd-login-local
	$(ARGOCD_CLI_BIN) app sync myapp-monitoring-prod
	$(ARGOCD_CLI_BIN) app sync myapp-logging-prod
	$(ARGOCD_CLI_BIN) app sync myapp-prod
	$(ARGOCD_CLI_BIN) app wait myapp-monitoring-prod myapp-logging-prod myapp-prod \
	  --health --timeout 600

# Sync per env using the generated Application names
# cluster-monitoring-infra is synced,
.PHONY: argocd-sync-cluster-monitoring-dev
argocd-sync-cluster-monitoring-dev: argocd-login-local
	$(ARGOCD_CLI_BIN) app sync cluster-monitoring-infra-dev
	$(ARGOCD_CLI_BIN) app wait cluster-monitoring-infra-dev --health --timeout 600

.PHONY: argocd-sync-cluster-monitoring-staging
argocd-sync-cluster-monitoring-staging: argocd-login-local
	$(ARGOCD_CLI_BIN) app sync cluster-monitoring-infra-staging
	$(ARGOCD_CLI_BIN) app wait cluster-monitoring-infra-staging --health --timeout 600

.PHONY: argocd-sync-cluster-monitoring-prod
argocd-sync-cluster-monitoring-prod: argocd-login-local
	$(ARGOCD_CLI_BIN) app sync cluster-monitoring-infra-prod
	$(ARGOCD_CLI_BIN) app wait cluster-monitoring-infra-prod --health --timeout 600

# ArgoCD smoke targets (separate from Helm)
# You already added:
# 	argocd-cli-install
# 	argocd-login-local
# 	argocd-sync-dev|staging|prod
# 	k8s-bootstrap-argocd
#
# We’ll now add parallel smoke targets that:
# 	- Assume ArgoCD is managing deployments for that env.
# 	- Call argocd-sync-* to reconcile Git → cluster.
# 	- Then reuse your existing observability + app smokes.

# Dev: ArgoCD‑driven smoke
# Notes:
# - We do not call k8s-observability-dev here, because ArgoCD is now 
#   responsible for deploying monitoring/logging (via the ApplicationSets).
# - k8s-observability-infra-check and k8s-observability-check-dev remain 
#   valid; they just verify what ArgoCD deployed.
.PHONY: k8s-smoke-dev-argocd
k8s-smoke-dev-argocd: ## Full DEV smoke using ArgoCD (no Helm deploys)
	@echo "Running DEV ArgoCD-based smoke (sync + observability + app checks)..."
	$(MAKE) argocd-sync-dev
	$(MAKE) k8s-observability-infra-check
	$(MAKE) k8s-observability-check-dev
	$(MAKE) k8s-incluster-smoke-myapp-dev
	$(MAKE) k8s-http-smoke-dev
	@echo "End-to-end DEV ArgoCD smoke completed."

# Staging: ArgoCD‑driven smoke
# 	- k8s-logging-staging-secrets-soft is still fine; it just ensures 
#     staging Loki secrets exist before/after ArgoCD sync.
# 	- We intentionally do not call k8s-observability-staging 
#     (Helm deploy), keeping ArgoCD as the sole deployer.
.PHONY: k8s-smoke-staging-argocd
k8s-smoke-staging-argocd: ## Full STAGING smoke using ArgoCD (no Helm deploys)
	@echo "Running STAGING ArgoCD-based smoke (sync + observability + app checks)..."
	$(MAKE) argocd-sync-staging
	$(MAKE) k8s-logging-staging-secrets-soft
	$(MAKE) k8s-observability-infra-check
	$(MAKE) k8s-incluster-grafana-smoke-staging
	$(MAKE) k8s-observability-check-staging
	$(MAKE) k8s-incluster-smoke-myapp-staging
	$(MAKE) k8s-http-smoke-staging
	@echo "End-to-end STAGING ArgoCD smoke completed."

# Prod: ArgoCD‑driven smoke
# Again, no Helm deploy here; ArgoCD manages prod monitoring/logging/app based on Git.
.PHONY: k8s-smoke-prod-argocd
k8s-smoke-prod-argocd: ## Full PROD smoke using ArgoCD (no Helm deploys)
	@echo "Running PROD ArgoCD-based smoke (sync + observability + app checks)..."
	$(MAKE) argocd-sync-prod
	$(MAKE) k8s-logging-prod-secrets-soft
	$(MAKE) k8s-observability-infra-check
	$(MAKE) k8s-incluster-grafana-smoke-prod
	$(MAKE) k8s-observability-check-prod
	$(MAKE) k8s-incluster-smoke-myapp-prod
	$(MAKE) k8s-http-smoke-prod
	@echo "End-to-end PROD ArgoCD smoke completed."

# Convenience: run ArgoCD smokes for all envs
.PHONY: k8s-smoke-all-argocd
k8s-smoke-all-argocd: ## ArgoCD-based smokes for dev, staging, prod
	$(MAKE) k8s-smoke-dev-argocd
	$(MAKE) k8s-smoke-staging-argocd
	$(MAKE) k8s-smoke-prod-argocd
	@echo "End-to-end ArgoCD-based smoke completed for dev, staging, and prod."

# add one more top-level target for your own convenience, instead of wiring bootstrap into each smoke:
#  - From clean cluster: make k8s-from-scratch-dev-argocd
#  - Day-to-day: just make k8s-smoke-dev-argocd (no reinstall/rebootstrapping).
.PHONY: k8s-from-scratch-dev-argocd
k8s-from-scratch-dev-argocd:
	$(MAKE) argocd-cli-install
	$(MAKE) k8s-bootstrap-argocd
	$(MAKE) argocd-sync-cluster-monitoring-dev
	$(MAKE) k8s-smoke-dev-argocd

.PHONY: k8s-from-scratch-staging-argocd
k8s-from-scratch-staging-argocd:
	$(MAKE) argocd-cli-install
	$(MAKE) k8s-bootstrap-argocd
	$(MAKE) argocd-sync-cluster-monitoring-staging
	$(MAKE) k8s-smoke-staging-argocd

.PHONY: k8s-from-scratch-prod-argocd
k8s-from-scratch-prod-argocd:
	$(MAKE) argocd-cli-install
	$(MAKE) k8s-bootstrap-argocd
	$(MAKE) argocd-sync-cluster-monitoring-prod
	$(MAKE) k8s-smoke-prod-argocd