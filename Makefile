SHELL := /bin/bash

.PHONY: lint format type security quality security-deps docker-security-deps docker-scan docker-scan-dev-image \
        coverage test docker-build docker-db docker-test run check-api clean-coverage clean \
        dev-up dev-down hit-api-multiple

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

# ---------- LOCAL TESTS ----------
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
	(docker compose run --rm myapp poetry run pytest -vv \
		--log-cli-level=INFO \
  		--log-cli-format="%(asctime)s %(levelname)s [%(name)s] %(message)s" \
		--cov=myapp --cov-report=term-missing \
		--cov-report=xml:coverage-myapp.xml --cov-fail-under=20) & \
	P1=$$!; \
	(docker compose run --rm mylearning poetry run pytest -vv  \
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
	rm -f myapp/.coverage myapp/coverage*.xml
	rm -f mylearning/.coverage mylearning/coverage*.xml
# ---------- CLEAN ----------
clean:
	docker compose down -v --remove-orphans
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