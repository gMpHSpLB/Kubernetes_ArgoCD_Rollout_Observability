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
K8S_CONTEXT_DEV     ?= minikube   # Dev app environment on local Minikube
K8S_CONTEXT_STAGING ?= minikube   # Staging app environment on local Minikube
K8S_CONTEXT_PROD    ?= minikube   # Prod app environment on local Minikube

# ---------- APP NAMESPACES PER ENV ----------
# These match infra/k8s/namespaces/myapp-namespaces.yaml.
K8S_APP_NAMESPACE_DEV     ?= myapp-dev      # Namespace for dev myapp workloads
K8S_APP_NAMESPACE_STAGING ?= myapp-staging  # Namespace for staging myapp workloads
K8S_APP_NAMESPACE_PROD    ?= myapp-prod     # Namespace for prod myapp workloads

# ---------- HELM RELEASE NAMES PER ENV ----------
# Keep releases separate so dev/staging/prod can be managed independently.
K8S_MYAPP_RELEASE_DEV     ?= myapp-dev      # Helm release name for dev myapp
K8S_MYAPP_RELEASE_STAGING ?= myapp-staging  # Helm release name for staging myapp
K8S_MYAPP_RELEASE_PROD    ?= myapp-prod     # Helm release name for prod myapp

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
	kubectl delete secret myapp-secret --ignore-not-found >/dev/null 2>&1 || true
	kubectl create secret generic myapp-secret \
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

.PHONY: k8s-port-forward-prometheus k8s-port-forward-grafana
# Port-forward helpers for Prometheus and Grafana
k8s-port-forward-prometheus:
	@echo "Port-forwarding Prometheus (kube-prometheus-stack) to http://localhost:9091 ..."
	kubectl port-forward -n $(K8S_MONITORING_NAMESPACE) svc/$(K8S_KPS_RELEASE)-kube-prometheus-stack-prometheus 9091:9090

k8s-port-forward-grafana:
	@echo "Port-forwarding Grafana (kube-prometheus-stack) to http://localhost:3001 ..."
	kubectl port-forward -n $(K8S_MONITORING_NAMESPACE) svc/$(K8S_KPS_RELEASE)-grafana 3001:80

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
	@echo "  make k8s-port-forward-prometheus"
	@echo "  make k8s-port-forward-grafana"

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
	MYAPP_IMAGE=$(MYAPP_IMAGE_DEV) \
	$(MAKE) k8-deploy-myapp

k8-deploy-myapp-staging:
	@echo "Deploying myapp to myapp-staging namespace..."
	CHART_NAME=myapp-staging \
	K8S_NAMESPACE=$(K8S_APP_NAMESPACE_STAGGING) \
	ENV_VALUES=$(K8S_ENV_DIR)/stagging/values-myapp.yaml \
	MYAPP_IMAGE=$(MYAPP_IMAGE_STAGING) \
	$(MAKE) k8-deploy-myapp

k8-deploy-myapp-prod:
	@echo "Deploying myapp to myapp-prod namespace..."
	CHART_NAME=myapp-prod \
	K8S_NAMESPACE=$(K8S_APP_NAMESPACE_PROD) \
	ENV_VALUES=$(K8S_ENV_DIR)/prod/values-myapp.yaml \
	MYAPP_IMAGE=$(MYAPP_IMAGE_PROD) \
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
define k8s_observability_check
	@echo "=== Observability check for $(1) ==="
	@kubectl --context "$(2)" get pods -n "$(3)" -o wide
	@kubectl --context "$(2)" get svc -n "$(3)"
	@kubectl --context "$(2)" get endpoints -n "$(3)" || true
	@kubectl --context "$(2)" top pods -n "$(3)" || true
	@kubectl --context "$(2)" logs -n "$(3)" deploy/"$(4)" --tail=50 || true
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

# export AWS_ACCESS_KEY_ID_STAGING=staging-key
# export AWS_SECRET_ACCESS_KEY_STAGING=staging-secret
k8s-logging-staging: helm-add-repos ensure-minikube k8s-logging-staging-secrets
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

# export key values before calling make k8s-logging-prod
# export AWS_ACCESS_KEY_ID=xxxx
# export AWS_SECRET_ACCESS_KEY=yyyy
# # Deploy prod Loki (S3-backed) into the current cluster
# make k8s-logging-prod
k8s-logging-prod: helm-add-repos ensure-minikube k8s-logging-prod-secrets
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
k8s-observability-check-dev:
	$(call check-k8s-context,$(K8S_CONTEXT_DEV))
	$(call check-k8s-namespace,$(K8S_APP_NAMESPACE_DEV))
	$(call k8s_observability_check,DEV,$(K8S_CONTEXT_DEV),$(K8S_APP_NAMESPACE_DEV),$(K8S_MYAPP_RELEASE_DEV))

# STAGING: run checks against the staging namespace in Minikube for now.
k8s-observability-check-staging:
	$(call check-k8s-context,$(K8S_CONTEXT_STAGING))
	$(call check-k8s-namespace,$(K8S_APP_NAMESPACE_STAGING))
	$(call k8s_observability_check,STAGING,$(K8S_CONTEXT_STAGING),$(K8S_APP_NAMESPACE_STAGING),$(K8S_MYAPP_RELEASE_STAGING))

# PROD: run checks against the prod namespace in Minikube for now.
k8s-observability-check-prod:
	$(call check-k8s-context,$(K8S_CONTEXT_PROD))
	$(call check-k8s-namespace,$(K8S_APP_NAMESPACE_PROD))
	$(call k8s_observability_check,PROD,$(K8S_CONTEXT_PROD),$(K8S_APP_NAMESPACE_PROD),$(K8S_MYAPP_RELEASE_PROD))

# ---------- APP OBSERVABILITY CHECKS (ALL ENVIRONMENTS) ----------
# Add an aggregate target
k8s-observability-check-all: k8s-observability-check-dev k8s-observability-check-staging k8s-observability-check-prod
	@echo "Observability checks completed for dev, staging, and prod."


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
k8s-observability-dev: k8s-namespaces-all k8s-monitoring-dev k8s-logging-dev k8s-alerts-dev k8s-grafana-dashboards-dev k8s-netpol-dev ## Deploy full observability stack to dev cluster (namespaces, monitoring, logging, alerts, dashboards, netpol)
	@echo "K8s observability stack (dev) deployed  (namespaces, monitoring, logging, rules, dashboards, netpol)."

k8s-observability-staging: k8s-namespaces-all k8s-monitoring-staging k8s-logging-staging k8s-alerts-staging k8s-grafana-dashboards-staging k8s-netpol-staging
	@echo "K8s observability stack (staging) deployed  (namespaces, monitoring, logging, rules, dashboards, netpol)."

k8s-observability-prod: k8s-monitoring-prod k8s-logging-prod k8s-alerts-prod k8s-grafana-dashboards-prod k8s-netpol-prod
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


# ---------- END-TO-END APP + OBSERVABILITY SMOKE PER ENV ----------
# Dev: deploy myapp to myapp-dev and then run observability checks.
# what each dependency does:
# 	k8-deploy-myapp-* → deploy app (GHCR image + Helm) into 
#						myapp-<env> namespace (you already have these).
# 	k8s-observability-* → install/upgrade observability stack 
#						(monitoring, logging, dashboards, alerts, netpol) for that env.
# 	k8s-observability-check-* → run runtime checks 
#						(pods, services, metrics, logs) in that env.
k8s-smoke-dev: ensure-minikube k8-deploy-myapp-dev k8s-observability-dev k8s-observability-check-dev ## Deploy + observability smoke for DEV
	@echo "End-to-end DEV smoke (app deploy + observability) completed."

# Staging: deploy myapp to myapp-staging and then run observability checks.
k8s-smoke-staging: ensure-minikube k8-deploy-myapp-staging k8s-observability-staging k8s-observability-check-staging ## Deploy + observability smoke for STAGING
	@echo "End-to-end STAGING smoke (app deploy + observability) completed."

# Prod: deploy myapp to myapp-prod and then run observability checks.
k8s-smoke-prod: ensure-minikube k8-deploy-myapp-prod k8s-observability-prod k8s-observability-check-prod ## Deploy + observability smoke for PROD
	@echo "End-to-end PROD smoke (app deploy + observability) completed."

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

.PHONY: k8s-nuke

k8s-nuke:
	@echo "!!! FULL NUKE: cleaning namespaces/PVCs and recreating Minikube cluster !!!"
	$(MAKE) k8s-clean-minikube
	$(MAKE) recreate-minikube