What your stack is
Right now, your stack for this monorepo is:

    db: Postgres 15 with mydb / myuser / mypassword.

    myapp: FastAPI service in myapp/src/myapp, talking to the DB.

    mylearning: Python exercises service in mylearning/src/exercises.

They run together via Docker Compose, with environment variables for config:

    APP_ENV (ci, dev, staging, production).

    DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD.

With the base+override approach, the shape of the stack is:

    text
    # docker-compose.base.yml (conceptually)
    services:
    db:          # Postgres
    myapp:       # your main API
    mylearning:  # learning app
Then each environment adds small tweaks:

    docker-compose.dev.yml: local dev overrides (bind mounts, APP_ENV=dev, dev DB defaults).

    docker-compose.staging.yml: staging overrides, using staging DB secrets.

    docker-compose.prod.yml: production overrides, using prod DB secrets, no bind mounts, restart: always.

So “stack” = db + myapp + mylearning + env vars, always the same structure, only configuration changes per env.

What your promotion model is
Your promotion model is how Docker images flow through environments:

1. CI (dev stage) – build & test In ci job:

    Build local CI images for tests with docker-compose.yml (with build: and INSTALL_DEV=true).

    Run tests, quality checks, Safety, Docker Scout on those.

    Compute registry tags:

        image_myapp_dev = ghcr.io/<repo-lower>/myapp:dev

        image_mylearning_dev = ghcr.io/<repo-lower>/mylearning:dev

        image_myapp_staging = ...:staging, image_mylearning_staging = ...:staging

        image_myapp_prod = ...:vX.X.X or latest, image_mylearning_prod = ....

2. deploy-dev – rebuild and push dev images In deploy-dev:

    Rebuild images from ./myapp and ./mylearning and tag them as:

        ${{ needs.ci.outputs.image_myapp_dev }} (e.g. ghcr.io/.../myapp:dev)

        ${{ needs.ci.outputs.image_mylearning_dev }}.

    Push these to GHCR.

    Run the dev stack using those images:

        text
        IMAGE_MYAPP = image_myapp_dev
        IMAGE_MYLEARNING = image_mylearning_dev
        APP_ENV = dev
        DB_* = dev defaults
        docker compose -f docker-compose.base.yml -f docker-compose.dev.yml up -d

    Optionally run Docker Scout on the dev images (you added docker-scan-dev-image).

This gives you a prod-like dev environment on the CI runner using the same images you just pushed.

3. deploy-staging – promote dev → staging In deploy-staging:

    No rebuild. You promote images by retagging:

        bash
        docker pull image_myapp_dev
        docker tag  image_myapp_dev image_myapp_staging
        docker push image_myapp_staging

        docker pull image_mylearning_dev
        docker tag  image_mylearning_dev image_mylearning_staging
        docker push image_mylearning_staging

    Run the staging stack:

        text
        IMAGE_MYAPP = image_myapp_staging
        IMAGE_MYLEARNING = image_mylearning_staging
        APP_ENV = staging
        DB_* = STAGING_DB_* secrets
        docker compose -f docker-compose.base.yml -f docker-compose.staging.yml up -d

    Run API checks against http://localhost:8000/docs.

Here, “promotion” means: same dev image bits, new tag :staging, and new DB config.

4. deploy-prod – promote staging → prod In deploy-prod (for tags v*):

    Again no rebuild. You promote staging images to prod tags:

        bash
        docker pull image_myapp_staging
        docker tag  image_myapp_staging image_myapp_prod
        docker push image_myapp_prod

        docker pull image_mylearning_staging
        docker tag  image_mylearning_staging image_mylearning_prod
        docker push image_mylearning_prod

    In a real prod server, you’d then run:

        bash
        IMAGE_MYAPP=image_myapp_prod
        IMAGE_MYLEARNING=image_mylearning_prod
        APP_ENV=production
        DB_* = PROD_DB_* secrets

        docker compose -f docker-compose.base.yml -f docker-compose.prod.yml up -d
That’s the final promotion: staging → prod, changing only tags and configuration, not the build.

Putting it together in one sentence each
    Stack: the fixed set of services (db, myapp, mylearning) and how they connect, defined once in docker-compose.base.yml plus env-specific overrides.

    Promotion model: how a built image (myapp/mylearning) gets tagged and pushed as :dev, then re-tagged to :staging, then to :prod without rebuilding, and how each environment composes those tags into a running stack using compose and env vars.


How to run in prod environment:
You use that block on the machine where you actually want to run prod (for now: a single Docker host, e.g. an EC2 VM), not inside GitHub Actions.

1) What needs to exist on the prod host
On the prod server (your “real deployment” box):

    Docker and Docker Compose plugin installed.

    Your repo’s compose files copied there:

        docker-compose.base.yml

        docker-compose.prod.yml

    Network access from that host to:

        GHCR (to pull ghcr.io/... images).

        Your production Postgres (if it’s external).

You can either:

    Git clone the repo onto the server, or

    Copy just the compose files and .env yourself.

2) How the variables map to your promotion model
From your CI/CD:

    image_myapp_prod = ghcr.io/<repo-lower>/myapp:v1.0.0

    image_mylearning_prod = ghcr.io/<repo-lower>/mylearning:v1.0.0

On the prod host, you set:

    bash
    export IMAGE_MYAPP=ghcr.io/<repo-lower>/myapp:v1.0.0
    export IMAGE_MYLEARNING=ghcr.io/<repo-lower>/mylearning:v1.0.0
    export APP_ENV=production
    export DB_HOST=<your-prod-db-host>
    export DB_PORT=5432
    export DB_NAME=mydb
    export DB_USER=myuser
    export DB_PASSWORD=<your-prod-db-password>
Those env vars are what docker-compose.base.yml + docker-compose.prod.yml read:

    IMAGE_MYAPP / IMAGE_MYLEARNING → which images to run.

    APP_ENV, DB_* → how the app connects to the DB in prod.

3) Running the stack on the prod host
Still on that prod box:

    bash
    docker compose -f docker-compose.base.yml -f docker-compose.prod.yml pull
    docker compose -f docker-compose.base.yml -f docker-compose.prod.yml up -d

    pull fetches the tagged images from GHCR (myapp:v1.0.0, mylearning:v1.0.0).

    up -d starts db, myapp, mylearning with the prod env vars.

To update to a new version (e.g. v1.1.0):

    bash
    export IMAGE_MYAPP=ghcr.io/<repo-lower>/myapp:v1.1.0
    export IMAGE_MYLEARNING=ghcr.io/<repo-lower>/mylearning:v1.1.0
    docker compose -f docker-compose.base.yml -f docker-compose.prod.yml pull
    docker compose -f docker-compose.base.yml -f docker-compose.prod.yml up -d
Compose will pull the new tags and recreate the containers.

4) How to implement this end‑to‑end (minimal version)
    1. Provision a server (e.g. AWS EC2 t3.small) and install Docker + Compose.

    2. Copy compose files to /opt/myapp on that server:

        docker-compose.base.yml

        docker-compose.prod.yml

    3. Create a small deploy script on the server, e.g. /opt/myapp/deploy.sh:

    bash
    #!/usr/bin/env bash
    set -euo pipefail

    VERSION="$1"  # e.g. v1.0.0

    export IMAGE_MYAPP="ghcr.io/<repo-lower>/myapp:${VERSION}"
    export IMAGE_MYLEARNING="ghcr.io/<repo-lower>/mylearning:${VERSION}"
    export APP_ENV=production
    export DB_HOST="<prod-db-host>"
    export DB_PORT=5432
    export DB_NAME="mydb"
    export DB_USER="myuser"
    export DB_PASSWORD="<prod-password>"

    docker compose -f docker-compose.base.yml -f docker-compose.prod.yml pull
    docker compose -f docker-compose.base.yml -f docker-compose.prod.yml up -d

From your laptop, after CI has produced v1.0.0 images, SSH into the server and run:

    bash
    ssh ubuntu@your-ec2 "cd /opt/myapp && ./deploy.sh v1.0.0"

That’s your first “real deployment”: the stack defined in compose, using the :v1.0.0 images that your CI pipeline already built and promoted.
