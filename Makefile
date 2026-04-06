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
test-docker:
	docker compose down -v --remove-orphans #remove any container created earlier those are orphan now
	docker compose up --build --abort-on-container-exit #--abort-on-container-exit = foreground mode (watch containers)
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