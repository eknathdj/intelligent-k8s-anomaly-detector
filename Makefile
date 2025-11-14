# Makefile for Intelligent Kubernetes Anomaly Detector
# Compatible with Windows (using PowerShell), macOS, and Linux

.PHONY: help bootstrap install test lint format clean docker-build docker-push deploy-infra deploy-app k3d-up k3d-down open demo-cpu train dev-setup

# Detect OS
ifeq ($(OS),Windows_NT)
    DETECTED_OS := Windows
    SHELL := powershell.exe
    .SHELLFLAGS := -NoProfile -Command
else
    DETECTED_OS := $(shell uname -s)
endif

# Variables
PYTHON := python
PIP := pip
DOCKER := docker
KUBECTL := kubectl
HELM := helm
TERRAFORM := terraform

PROJECT_NAME := intelligent-k8s-anomaly-detector
REGISTRY := ghcr.io/eknathdj
IMAGE_TAG := latest
CLOUD ?= azure
ENV ?= dev
LOCATION ?= eastus
WINDOW ?= 12

# Colors for output (works in PowerShell and Unix)
ifeq ($(DETECTED_OS),Windows)
    INFO := Write-Host -ForegroundColor Cyan
    SUCCESS := Write-Host -ForegroundColor Green
    ERROR := Write-Host -ForegroundColor Red
else
    INFO := @echo "\033[0;36m"
    SUCCESS := @echo "\033[0;32m"
    ERROR := @echo "\033[0;31m"
endif

help: ## Show this help message
	@echo "Intelligent Kubernetes Anomaly Detector - Makefile Commands"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

bootstrap: ## Install all dependencies (Python, Docker, kubectl, Helm, Terraform)
	$(INFO) "Installing dependencies for $(DETECTED_OS)..."
	$(PYTHON) -m pip install --upgrade pip
	$(PIP) install -r ml-pipeline/requirements.txt
	$(PIP) install -r ml-pipeline/requirements-dev.txt
	$(PIP) install -e ml-pipeline/
	$(SUCCESS) "Bootstrap complete!"

install: ## Install Python dependencies only
	$(INFO) "Installing Python dependencies..."
	$(PIP) install -r ml-pipeline/requirements.txt
	$(PIP) install -e ml-pipeline/
	$(SUCCESS) "Installation complete!"

dev-setup: ## Setup development environment
	$(INFO) "Setting up development environment..."
	$(PIP) install -r ml-pipeline/requirements-dev.txt
	pre-commit install
	$(SUCCESS) "Development environment ready!"

test: ## Run all tests
	$(INFO) "Running tests..."
	tox

test-unit: ## Run unit tests only
	$(INFO) "Running unit tests..."
	pytest tests/unit/ -v --cov=src --cov=ml_pipeline

test-integration: ## Run integration tests
	$(INFO) "Running integration tests..."
	pytest tests/integration/ -v

lint: ## Run linting checks
	$(INFO) "Running linters..."
	flake8 src/ ml-pipeline/src/ tests/
	black --check src/ ml-pipeline/src/ tests/
	isort --check-only src/ ml-pipeline/src/ tests/
	mypy src/ ml-pipeline/src/

format: ## Format code with black and isort
	$(INFO) "Formatting code..."
	black src/ ml-pipeline/src/ tests/
	isort src/ ml-pipeline/src/ tests/
	$(SUCCESS) "Code formatted!"

clean: ## Clean build artifacts and cache
	$(INFO) "Cleaning build artifacts..."
ifeq ($(DETECTED_OS),Windows)
	if (Test-Path -Path "build") { Remove-Item -Recurse -Force build }
	if (Test-Path -Path "dist") { Remove-Item -Recurse -Force dist }
	if (Test-Path -Path "*.egg-info") { Remove-Item -Recurse -Force *.egg-info }
	Get-ChildItem -Recurse -Filter "__pycache__" | Remove-Item -Recurse -Force
	Get-ChildItem -Recurse -Filter "*.pyc" | Remove-Item -Force
	Get-ChildItem -Recurse -Filter ".pytest_cache" | Remove-Item -Recurse -Force
else
	rm -rf build/ dist/ *.egg-info
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
	find . -type d -name ".pytest_cache" -exec rm -rf {} +
endif
	$(SUCCESS) "Cleanup complete!"

docker-build: ## Build Docker images
	$(INFO) "Building Docker images..."
	$(DOCKER) build -t $(REGISTRY)/anomaly-api:$(IMAGE_TAG) -f docker/Dockerfile.api .
	$(DOCKER) build -t $(REGISTRY)/ml-pipeline:$(IMAGE_TAG) -f docker/Dockerfile.ml-pipeline ml-pipeline/
	$(SUCCESS) "Docker images built!"

docker-push: ## Push Docker images to registry
	$(INFO) "Pushing Docker images..."
	$(DOCKER) push $(REGISTRY)/anomaly-api:$(IMAGE_TAG)
	$(DOCKER) push $(REGISTRY)/ml-pipeline:$(IMAGE_TAG)
	$(SUCCESS) "Docker images pushed!"

docker-compose-up: ## Start local services with docker-compose
	$(INFO) "Starting local services..."
	cd docker && docker-compose up -d
	$(SUCCESS) "Services started! Access Grafana at http://localhost:3000"

docker-compose-down: ## Stop local services
	$(INFO) "Stopping local services..."
	cd docker && docker-compose down
	$(SUCCESS) "Services stopped!"

k3d-up: ## Create local k3d cluster
	$(INFO) "Creating k3d cluster..."
	k3d cluster create k8s-anomaly --agents 2 --port "8080:80@loadbalancer" --port "8443:443@loadbalancer"
	$(KUBECTL) cluster-info
	$(SUCCESS) "k3d cluster created!"

k3d-down: ## Delete local k3d cluster
	$(INFO) "Deleting k3d cluster..."
	k3d cluster delete k8s-anomaly
	$(SUCCESS) "k3d cluster deleted!"

deploy-infra: ## Deploy infrastructure with Terraform
	$(INFO) "Deploying infrastructure to $(CLOUD) in $(ENV) environment..."
	cd infrastructure/terraform && \
		$(TERRAFORM) init && \
		$(TERRAFORM) plan -var="cloud_provider=$(CLOUD)" -var="environment=$(ENV)" -var="location=$(LOCATION)" && \
		$(TERRAFORM) apply -var="cloud_provider=$(CLOUD)" -var="environment=$(ENV)" -var="location=$(LOCATION)" -auto-approve
	$(SUCCESS) "Infrastructure deployed!"

deploy-app: ## Deploy application with Helm
	$(INFO) "Deploying application to $(ENV) environment..."
	$(HELM) upgrade --install anomaly-detector \
		infrastructure/helm/anomaly-detector \
		--namespace anomaly-detection-$(ENV) \
		--create-namespace \
		--values infrastructure/helm/anomaly-detector/values.yaml \
		--values config/environments/$(ENV).yaml \
		--set global.environment=$(ENV)
	$(SUCCESS) "Application deployed!"

deploy-monitoring: ## Deploy monitoring stack
	$(INFO) "Deploying monitoring stack..."
	$(HELM) repo add prometheus-community https://prometheus-community.github.io/helm-charts
	$(HELM) repo add grafana https://grafana.github.io/helm-charts
	$(HELM) repo update
	$(HELM) upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
		--namespace monitoring \
		--create-namespace \
		--values infrastructure/helm/monitoring-stack/values.yaml
	$(SUCCESS) "Monitoring stack deployed!"

open: ## Open dashboards in browser
	$(INFO) "Opening dashboards..."
ifeq ($(DETECTED_OS),Windows)
	Start-Process "http://localhost:3000"
	Start-Process "http://localhost:8080"
	Start-Process "http://localhost:5000"
else
	@command -v xdg-open > /dev/null && xdg-open http://localhost:3000 || open http://localhost:3000
	@command -v xdg-open > /dev/null && xdg-open http://localhost:8080 || open http://localhost:8080
	@command -v xdg-open > /dev/null && xdg-open http://localhost:5000 || open http://localhost:5000
endif

demo-cpu: ## Trigger demo CPU anomaly
	$(INFO) "Triggering demo CPU anomaly..."
	$(KUBECTL) run stress-test --image=polinux/stress --restart=Never -- stress --cpu 4 --timeout 60s
	$(SUCCESS) "Demo anomaly triggered! Watch alerts in Grafana."

train: ## Train ML models locally
	$(INFO) "Training ML models with $(WINDOW)h window..."
	$(PYTHON) ml-pipeline/src/ml_pipeline/training/train.py --window $(WINDOW)
	$(SUCCESS) "Training complete!"

validate: ## Validate deployment
	$(INFO) "Validating deployment..."
	$(KUBECTL) get pods -n anomaly-detection-$(ENV)
	$(KUBECTL) get svc -n anomaly-detection-$(ENV)
	$(SUCCESS) "Validation complete!"

logs: ## Show application logs
	$(KUBECTL) logs -n anomaly-detection-$(ENV) -l app=anomaly-detector --tail=100 -f

port-forward: ## Port forward to API service
	$(INFO) "Port forwarding to API service..."
	$(KUBECTL) port-forward -n anomaly-detection-$(ENV) svc/anomaly-detector 8080:80

destroy-infra: ## Destroy infrastructure
	$(INFO) "Destroying infrastructure..."
	cd infrastructure/terraform && \
		$(TERRAFORM) destroy -var="cloud_provider=$(CLOUD)" -var="environment=$(ENV)" -auto-approve
	$(SUCCESS) "Infrastructure destroyed!"

security-scan: ## Run security scans
	$(INFO) "Running security scans..."
	bandit -r src/ ml-pipeline/src/ -f json -o bandit-report.json
	safety check --json --output safety-report.json
	$(SUCCESS) "Security scan complete!"

version: ## Show version information
	@echo "Project: $(PROJECT_NAME)"
	@echo "Python: $$($(PYTHON) --version)"
	@echo "Docker: $$($(DOCKER) --version)"
	@echo "kubectl: $$($(KUBECTL) version --client --short 2>/dev/null || echo 'Not installed')"
	@echo "Helm: $$($(HELM) version --short 2>/dev/null || echo 'Not installed')"
	@echo "Terraform: $$($(TERRAFORM) version -json 2>/dev/null | jq -r '.terraform_version' || echo 'Not installed')"
