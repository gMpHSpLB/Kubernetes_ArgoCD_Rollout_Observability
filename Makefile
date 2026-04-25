SHELL := /bin/bash

.PHONY: lint format type security quality security-deps docker-security-deps docker-scan docker-scan-dev-image \
        coverage smoke-test test docker-build docker-db docker-test run check-api clean-coverage clean \
        dev-up dev-down hit-api-multiple \
		create-minikube-secrets \
		ensure-minikube recreate-minikube deploy-minikube-local-clean \
		test-minikube test-minikube-all check-minikube-api k8s-test \
		deploy-minikube-db test-minikube-db k8s-test-db \
		deploy-myapp-minikube-dev deploy-mylearning-minikube-dev \

###############Code Quality ###############################
lint:
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

quality:
	@echo "Running code quality checks..."
	@$(MAKE) lint
	@$(MAKE) format
	@$(MAKE) type
	@$(MAKE) security

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
test:
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
APP_ENV ?=dev
DEV_DB_HOST ?= db
DEV_DB_PORT ?= 5432
DEV_DB_NAME ?= mydb
DEV_DB_USER ?= myuser
DEV_DB_PASSWORD ?= mypassword
LOG_LEVEL ?= info
DISABLE_CUSTOM_MIDDLEWARE 	?=false
OTEL_ENABLED ?= true
OTEL_SERVICE_NAME ?= myapp-dev
OTEL_EXPORTER_OTLP_ENDPOINT ?= api.uptrace.dev:4317
UPTRACE_TOKEN ?= WLfJDCI9dKwaoXgI-Z-jFg
UPTRACE_DSN ?="https://WLfJDCI9dKwaoXgI-Z-jFg@api.uptrace.dev?grpc=4317"
OTEL_TRACES_SAMPLER ?= always_on
# Builds local dev images (myapp:latest, mylearning:latest)
# Run full dev stack: db + myapp + mylearning + prometheus + grafana
# Run full dev stack: db + myapp + mylearning + prometheus + grafana
dev-up: docker-build
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


#######################Deployment using Kubernetes ########################

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
deploy-minikube-local: ensure-minikube
	@echo "Using Minikube Docker daemon..."
	eval "$$(minikube docker-env)" && \
	docker build -t myapp:mklatest -f myapp/Dockerfile . && \
	docker build -t mylearning:mklatest -f mylearning/Dockerfile . --build-arg INSTALL_DEV=true && \
	eval "$$(minikube docker-env -u)"
	@echo "Deploying myapp to Minikube with Helm..."
	helm upgrade --install myapp-mklatest charts/myapp \
	  -f charts/myapp/values-local.yaml \
	  --set image.fullName="myapp:mklatest"
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
test-minikube: deploy-minikube-local
	@echo "Starting port-forward from Minikube service to localhost:8000..."
	@kubectl port-forward svc/myapp-mklatest-myapp 8000:8000 >/tmp/kube-pf-myapp.log 2>&1 & \
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
test-minikube-all: deploy-minikube-local
	@echo "Starting port-forward from Minikube service to localhost:8000..."
	@kubectl port-forward svc/myapp-mklatest-myapp 8000:8000 >/tmp/kube-pf-myapp.log 2>&1 & \
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
check-minikube-api: deploy-minikube-local
	@echo "Port-forwarding myapp-mklatest-myapp service to localhost:8000 for health check..."
	@kubectl port-forward svc/myapp-mklatest-myapp 8000:8000 >/tmp/kube-pf-myapp.log 2>&1 & \
	PF_PID=$$!; \
	for i in 1 2 3 4 5; do \
	  sleep 5; \
	  if curl -sf http://localhost:8000/docs > /dev/null; then \
	    echo "Minikube API is up!"; \
	    kill $$PF_PID || true; \
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
k8s-test: deploy-minikube-local-clean test-minikube test-minikube-all check-minikube-api
	@echo "Minikube deploy + pytest smoke + API health check completed."

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
	@kubectl port-forward svc/myapp-mklatest-myapp 8000:8000 >/tmp/kube-pf-app.log 2>&1 & \
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

# Your deploy-minikube-dev target pulls prebuilt images from GHCR and doesn’t touch Docker env
# Usage:
# 
#   MYAPP_IMAGE=ghcr.io/<owner>/<repo>/myapp:dev \
#   MYLEARNING_IMAGE=ghcr.io/<owner>/<repo>/mylearning:dev
#   images from GHCR (no local build)
k8-deploy-myapp:
	@echo "Deploying myapp with Helm (pulling from GHCR)..."
	helm upgrade --install $(CHART_NAME) charts/myapp \
	  -f $(ENV_VALUES) \
	  --set image.fullName="$(MYAPP_IMAGE)"

k8-deploy-mylearning:
	@echo "Deploying mylearning image (pulling from GHCR)..."
	helm upgrade --install $(CHART_NAME) charts/mylearning \
	  -f $(ENV_VALUES) \
	  --set image.fullName="$(MYLEARNING_IMAGE)" \
	  --set tests.enabled=false \ # no dev dependency, so cannot test it.
	  --set tests.smoke.enabled=false \
	  --set tests.full.enabled=false

# ---------- K8S OBSERVABILITY STACK ----------
K8S_MONITORING_NAMESPACE ?= monitoring
K8S_LOGGING_NAMESPACE ?= logging

K8S_KPS_RELEASE ?= kps
K8S_LOKI_RELEASE ?= loki

K8S_KPS_VALUES_DEV ?= infra/k8s/monitoring/kube-prometheus-stack-values-dev.yaml
K8S_KPS_VALUES_STAGING ?= infra/k8s/monitoring/kube-prometheus-stack-values-staging.yaml
K8S_KPS_VALUES_PROD ?= infra/k8s/monitoring/kube-prometheus-stack-values-prod.yaml

K8S_LOKI_VALUES_DEV ?= infra/k8s/logging/loki-stack-values-dev.yaml
K8S_LOKI_VALUES_STAGING ?= infra/k8s/logging/loki-stack-values-staging.yaml
K8S_LOKI_VALUES_PROD    ?= infra/k8s/logging/loki-stack-values-prod.yaml

K8S_RULES_DIR ?= infra/k8s/rules
K8S_ALERTS_CHART_DIR ?= infra/k8s/rules/myapp-alerts
K8S_ALERTS_RELEASE   ?= myapp-alerts
K8S_ALERTS_NAMESPACE ?= monitoring

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

# Finally, define a single target to bring up the entire observability 
# stack in whatever cluster your current kube‑context points at:
# Full observability stack for DEV in current cluster:
# - kube-prometheus-stack (Prometheus, Alertmanager, Grafana)
# - Loki + Promtail
# - PrometheusRule files (base + SLOs)
k8s-observability-dev: k8s-monitoring-dev k8s-logging-dev k8s-alerts-dev
	@echo "K8s observability stack (dev) deployed."

k8s-observability-staging: k8s-monitoring-staging k8s-logging-staging k8s-alerts-staging
	@echo "K8s observability stack (staging) deployed."

k8s-observability-prod: k8s-monitoring-prod k8s-logging-prod k8s-alerts-prod
	@echo "K8s observability stack (prod) deployed."

# Full observability stack (monitoring + logging) for all envs:
# - kube-prometheus-stack: dev, staging, prod
# - Loki + Promtail: dev, staging, prod
#
# Requires:
#   AWS_ACCESS_KEY_ID_STAGING / AWS_SECRET_ACCESS_KEY_STAGING for staging Loki
#   AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY for prod Loki
k8s-observability-all: k8s-observability-dev k8s-observability-staging k8s-observability-prod
	@echo "K8s observability stack deployed for dev, staging, and prod."