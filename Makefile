lint:
	(cd myapp && poetry run ruff check . ) && \
	(cd mylearning && poetry run ruff check . )

format:
	(cd myapp && poetry run black . ) && \
	(cd myapp && poetry run isort . ) && \
	(cd mylearning && poetry run black . ) && \
	(cd mylearning && poetry run isort . ) && \
	( cd myapp && poetry run ruff format . ) && \
	( cd mylearning && poetry run ruff format . )
type:
	(cd myapp && poetry run mypy . ) && \
	(cd mylearning && poetry run mypy . )

security:
	(cd myapp && poetry run bandit -r . -c bandit.yml ) && \
	(cd mylearning && poetry run bandit -r . -c bandit.yml )

quality:
	@echo "Running code quality checks..."
	make lint
	make format
	make type
	make security

# ---------- LOCAL TESTS ----------
#Use wait -n trick, to detect failure correctly
# Runs both tests in parallel
# Tracks each process
# Fails if ANY fails
test:
	@echo "Running tests in parallel..."
	( cd myapp && USE_TESTCONTAINERS=true poetry run pytest ) & \
	P1=$$!; \
	( cd mylearning && poetry run pytest ) & \
	P2=$$!; \
	wait $$P1 || exit 1; \
	wait $$P2 || exit 1;

# ---------- DOCKER BUILD ----------
#Make sure you're building images before tagging/pushing
docker-build:
	docker compose build #build image with dev dependency.

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
test-docker:
	docker compose down -v --remove-orphans
	#docker compose up --build --abort-on-container-exit
	docker compose up --build -d db  # only DB, run tests in one-off containers
	sleep 10
	@echo "Running Docker tests in parallel..."
	(docker compose run --rm myapp poetry run pytest) & \
	P1=$$!; \
	(docker compose run --rm mylearning poetry run pytest) & \
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
	sleep 10
	curl -f http://localhost:8000/docs || exit 1

# ---------- CLEAN ----------
clean:
	docker compose down -v --remove-orphans
	docker system prune -f