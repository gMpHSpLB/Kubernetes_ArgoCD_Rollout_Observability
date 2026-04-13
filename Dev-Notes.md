Created on 05-04-2026
1. We have two very different types of projects:

🟦 myapp → Service (backend/API)
Needs full architecture (api, services, db, etc.)
Runs as a server
Has DB, CI/CD, Docker, etc.

🟨 mylearning → Library / Module
Pure Python logic (algorithms, exercises)
Has CI/CD, Docker, etc.

2. For myapp:
        Introduce a clear FastAPI-style structure (even if you don’t use FastAPI, follow the pattern):
        ARCHITECTURE FLOW (VERY IMPORTANT): Client → API → Service → DB

        myapp/src/myapp/
            api/ or routers/ – endpoints. (HTTP handling)
            services/ – business logic.
            models/ – Pydantic/ORM models. (Data structure)
            core/config.py – (Config Management-Central place for ALL environment variables) settings, env parsing. (Config + DB)
            core/db.py – DB session management.
            deps/ – dependency injection / wiring.

        myapp/src/myapp/
        │
        ├── api/                # FastAPI routers (HTTP layer)
        │   └── v1/
        │       └── routes.py
        │
        ├── services/           # Business logic
        │   └── user_service.py
        │
        ├── models/             # DB + Pydantic models
        │   ├── db_models.py
        │   └── schemas.py
        │
        ├── core/               # Core config + DB
        │   ├── config.py
        │   └── db.py
        │
        ├── deps/               # Dependency injection
        │   └── dependencies.py
        │
        └── main.py             # App entrypoint

3. For mylearning : A reusable Python package (library)
        mylearning/
        │
        ├── src/
        │   └── exercises/
        │       ├── fibonacci.py
        │       └── __init__.py
        │
        ├── tests/
        │   └── test_exercises.py
        │
        ├── pyproject.toml
        └── README.md
4. For better code quality,
        You will add:
                1. Linting → ruff
                2. Formatting → black
                3. Import sorting → isort
                4. Type checking → mypy
                5. Security scan → bandit
                6. Pre-commit hooks
                7. CI enforcement

        - Linting is the automated checking of source code for errors, bad patterns, and style issues before the code runs. It helps improve code quality by catching mistakes early, keeping code consistent, and making it easier to read and maintain.

                What it catches
                        Syntax mistakes.

                        Unused variables or imports.

                        Inconsistent formatting, like spacing or naming.

                        Possible bugs or risky code patterns.

                        Violations of team coding rules.

        MyPy
                MyPy checks whether your Python type hints match how your code is actually used. It helps catch mistakes like passing a string where an integer is expected, which improves reliability and makes refactoring safer.

        Bandit
                Bandit looks for common security problems in Python code, such as hard-coded passwords, insecure function use, shell injection risks, SQL injection patterns, and unsafe deserialization

        pre-commit hooks for instant local feedback (.pre-commit-config.yaml):
                Pre-commit hooks are small checks that run locally before a commit is created, so you get instant feedback on issues like formatting problems, lint errors, debug statements, or invalid code.

                What they do
                They stop or warn you before bad code gets committed, which saves time compared with finding the same issue later in CI or during code review. They are usually configured to run only on staged files, so they stay fast enough to feel immediate.

                Why they help
                        Catch mistakes early.

                        Keep code style consistent.

                        Prevent obvious problems from reaching the repository.

                        Reduce noisy CI failures by fixing simple issues locally first
5. -n auto option
        To run pytest -n auto you need pytest-xdist installed in the environment

        Each project runs its tests in parallel across CPU cores.

6. pytest-cov is a pytest plugin that measures test coverage while your tests run. It tells you which lines, branches, or files were exercised by the test suite, and it can generate reports such as terminal output, HTML, or XML.

        What it does
                - Runs your tests with coverage tracking enabled.

                - Reports how much of your code was executed.

                - Can show missing lines and branch coverage.

                - Supports combining coverage from multiple test runs and works well with pytest-xdist.

        Common command
        A typical command looks like this:

        bash
                pytest --cov=your_package
                That means “run pytest and collect coverage for your_package”.

        Why it is useful
                It helps you see untested parts of your code so you can improve confidence in your test suite. It is especially useful in CI pipelines because it can also produce machine-readable reports like XML for further processing.

        In short, pytest-cov is the tool that connects pytest with coverage measurement and reporting.
7. Codecov and Adding badge
        A Codecov badge is a small status image you add to a repository’s README to show code coverage, usually the percentage of your code exercised by tests. Codecov is the service that generates and updates that badge from your coverage data.

        Codecov: First‑class GitHub app, good monorepo + flag support, easy badges from their UI.

        What “adding a badge” means
                “Adding a badge” usually means pasting a Markdown image link into your README.md so the badge appears on your project page. For Codecov, the badge often shows your current coverage status and can be copied from the project’s badge/settings area.

        Why it is used
                It gives visitors a quick view of test coverage.

                It helps teams track whether coverage is improving or dropping.

                It makes the project look more complete and CI-aware.

        Example
                A typical README badge looks like a linked image, so clicking it takes you to the coverage dashboard. Codecov also supports badges for flags, components, and bundle size in some setups

        Github: You have to setup Codecov and set token as well.
8. volumes in docker-compose.yml file
        A volume (in your case, a bind mount) is how Docker makes a folder from your machine (or GitHub runner) visible inside the container, so tests and coverage files live in the same repo tree on both sides.

        1. How volumes link container ↔ repo
        When you use this in docker-compose.yml:

        services:
          myapp:
            working_dir: /app
            volumes:
              - ./myapp:/app
        it means:

        On the host (your machine or the GitHub Actions runner), . is your repo root directory.

        Inside the container, /app points to that same directory.

                - ./myapp:/app is a bind mount: host repo → /app inside each container.

                - working_dir makes your test command effectively run in /app/ or /app/, matching the repo layout.

        2. With the bind mount:

        - Code, tests, and coverage outputs are all the same directory tree from both Docker and GitHub’s point of view.

        - You edit files on the host, containers see them; containers write coverage, the host sees it.
9. Runner in Github
        In GitHub Actions, a runner is the machine or environment that actually executes your CI/CD jobs. GitHub triggers the workflow, then assigns each job to a runner, which runs the steps one by one inside that environment.

        How it works
                You push code or open a pull request.

                GitHub Actions detects the event and starts the workflow.

                A runner picks up the job.

                The runner executes each step, like installing dependencies, running tests, building the app, or deploying it.

        Types of runners
                GitHub-hosted runners: temporary virtual machines managed by GitHub.

                Self-hosted runners: machines you set up yourself, which can be customized for your needs

10. Safety (Dependency Check)
        OWASP Dependency-Check is a security tool that scans your project’s dependencies to find known, publicly disclosed vulnerabilities in third-party libraries.

        What it does
                It looks at your dependency files or build artifacts.

                It identifies the libraries and their versions.

                It matches them against vulnerability databases such as the National Vulnerability Database.

                It generates a report showing affected components and severity.

        Why it is used
                It helps you catch risky libraries early, before you ship them into production. This is useful in CI/CD because you can fail the build or warn the team whenever a vulnerable dependency is introduced.

        Important limitation
                - It can only detect vulnerabilities that are already known and published, so it will not catch brand-new or undisclosed issues. It can also produce some false positives if a dependency is matched incorrectly.

                - If you meant the Python package named safety, that is a similar dependency vulnerability checker for Python projects, also used to find known insecure packages.

11. Docker image lifecycle and best pratices:
        Docker images and containers are separate things, created at different times, and you normally reuse images and remove containers. You do not usually remove images on every make run.

        - When images and containers are created
                - Images are built once, reused many times.
                Created by:
                > docker build -t myapp:latest .
                > docker compose build
                > docker compose up --build (builds if needed, then runs)

                - Containers are runtime instances of an image.
                Created/run by:
                > docker run myapp:latest
                > docker compose up
                > docker compose run myapp ...

                - Stopped/removed with docker compose down or --rm.
        - So your flow is:

        1. Build (creates/updates images)
        2. Up/run (creates containers from those images)
        3. Down/stop (removes containers, but images stay unless you prune them)

        - How to check if images exist
        Use:
        > docker images | grep myapp
        > docker images | grep mylearning

        - You should see lines like:
        myapp        latest   <image-id>   ...
        mylearning   latest   <image-id>   ...

        - If you use Compose:
        > docker compose images
        This lists images used by services in docker-compose.yml.
12. Immutable release:
        Immutable releases are releases that cannot be changed after they are published. In GitHub’s implementation, that means the release assets and the associated Git tag are locked, which helps prevent supply-chain tampering and accidental changes.

        What that means
                The tag cannot be moved to a different commit or deleted.

                The attached files, like binaries or archives, cannot be modified or removed.

                Each immutable release gets an attestation, which helps verify that the release you download matches what was published.

        Why it matters
                Immutable releases improve trust and traceability. They make it much harder for an attacker to replace a safe release with a malicious one, and they also reduce the chance that a developer accidentally changes a release artifact after publication.

        Simple example
                If version 1.2.0 is published as an immutable release, then anyone who downloads it later can be confident they are getting the exact same tag and files that were originally published.
13. To temporarily disable pre-commit hook.
git commit --no-verify -m "...message" 
