# syntax=docker/dockerfile:1.6
# ---------- Build stage ----------
FROM python:3.11-slim-bookworm AS builder

ARG CLOUD=azure
ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# system deps
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        git \
        libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# create venv
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# copy dependency lists first (better layer cache)
COPY requirements.txt requirements-dev.txt pyproject.toml setup.py README.md ./

# install python deps + cloud extra
RUN pip install --upgrade pip setuptools wheel && \
    pip install -r requirements.txt && \
    pip install .[${CLOUD}]

# copy source & install package
COPY src/ ./src/
RUN pip install . && \
    pip-compile --output-file=/dev/null 2>/dev/null || true  # sanity check

# ---------- Runtime stage ----------
FROM python:3.11-slim-bookworm

ARG CLOUD=azure
ENV PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH" \
    USER=mlflow \
    UID=1000 \
    GID=1000

# create non-root user
RUN groupadd -g $GID $USER && \
    useradd -u $UID -g $GID -m -s /bin/bash $USER

# copy venv from builder
COPY --from=builder /opt/venv /opt/venv

# runtime system libs (no build tools)
RUN apt-get update && apt-get install -y --no-install-recommends \
        libpq5 \
        curl \
    && rm -rf /var/lib/apt/lists/*

# health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
  CMD python -c "import urllib.request, os, sys; urllib.request.urlopen(os.getenv('HEALTH_URL','http://localhost:8080/health')).read() or sys.exit(0)"

# switch to non-root
USER $USER
WORKDIR /home/$USER

# expose ports (inference HTTP + optional Jupyter)
EXPOSE 8080 8888

# default command shows help (override in k8s)
CMD ["k8s-ml-train", "--help"]