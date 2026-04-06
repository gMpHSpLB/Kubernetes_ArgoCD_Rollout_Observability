# myapp/Dockerfile
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    POETRY_VIRTUALENVS_CREATE=false

WORKDIR /app

# System deps (build tools etc. if needed)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*
# Optional: control whether dev dependencies are installed
ARG INSTALL_DEV=false
# # Install Python deps via Poetry
# - always install main deps
# - optionally install dev deps if INSTALL_DEV=true
# Uses poetry install --only main for runtime; dev tools will be in your CI/WSL, not in the container
COPY pyproject.toml poetry.lock ./
RUN pip install --no-cache-dir poetry && \
    poetry --version && \
    poetry install --only main --no-interaction --no-ansi -vvv && \
    if [ "$INSTALL_DEV" = "true" ]; then \
      poetry install --with dev --no-interaction --no-ansi -vvv; \
    fi

# Copy source code only
# COPY src instead of COPY . → smaller image, 
# fewer cache busts, no pycache/test junk.
# Note:
# COPY src vs COPY . is about what files you put into the image and how often Docker has to rebuild layers.
# What COPY . does
# This copies everything in the myapp/ directory into the image:
#    - src/
#    - tests/
#    - __pycache__/
#    - .git, .github/, .vscode/ (if present)
#    - temporary files, local configs, etc.
# Problems:
# Bigger images: pycache, tests, git history are not needed at runtime.
# Worse caching: any change in any file (tests, notes, pycache) will invalidate this layer, forcing Docker to rebuild and reinstall more often.
# What COPY src does
# This copies only your application code into the image:
#    - No tests/.
#    - No __pycache__/.
#    - No .git or editor configs.
#Benefits:
#   - Smaller runtime image Only code that is actually needed to run the app is inside. That reduces size and potentially attack surface.
#   - Better build caching Docker builds layer by layer. It uses the cache if the contents for that step didn’t change.
#       When you change only tests or docs, the COPY src layer is unchanged → Docker reuses the existing image layers, so builds are faster.
#       With COPY . ., any change anywhere (even in tests) changes the context for that layer, so Docker has to rebuild from that point down (including reinstalling deps if you tie them to that layer).
#   - Cleaner separation of concerns
#       Runtime image: just the app and its dependencies.
#       CI: uses the repo (including tests) to build and test.

COPY src ./src
# Optional: if you want tests inside container, you can copy tests too
COPY tests ./tests

# Ensure src layout is importable
# PYTHONPATH=/app/src makes import myapp work with your src layout.
ENV PYTHONPATH=/app/src

# Run FastAPI with Uvicorn (good for dev/staging, later switch to Gunicorn for prod)
CMD ["poetry", "run", "uvicorn", "myapp.main:app", "--host", "0.0.0.0", "--port", "8000"]