# Quick Start Guide

## 🚀 Get Started in 5 Minutes

### Prerequisites
- Python 3.9+
- Docker (optional, for containerized deployment)
- kubectl (optional, for Kubernetes deployment)

### Step 1: Install Dependencies

```bash
# Install Python dependencies
pip install -r src/requirements.txt
pip install -r ml-pipeline/requirements.txt

# Or use make
make install
```

### Step 2: Create a Mock Model (for testing)

```bash
# Create models directory
mkdir -p models

# Create a simple mock model using Python
python -c "
import joblib
import numpy as np
from sklearn.ensemble import IsolationForest

# Create and train a simple model
model = IsolationForest(contamination=0.1, random_state=42)
X = np.random.randn(100, 10)
model.fit(X)

# Save model
joblib.dump(model, 'models/ensemble.joblib')

# Save version
with open('models/version.txt', 'w') as f:
    f.write('v0.1.0-mock')

print('✅ Mock model created successfully!')
"
```

### Step 3: Set Environment Variables

```bash
# Windows PowerShell
$env:MODEL_DIR="./models"
$env:LOG_LEVEL="INFO"
$env:PROMETHEUS_URL="http://localhost:9090"

# Linux/macOS
export MODEL_DIR="./models"
export LOG_LEVEL="INFO"
export PROMETHEUS_URL="http://localhost:9090"
```

### Step 4: Run the API

```bash
# From the project root
cd src
uvicorn api.main:app --host 0.0.0.0 --port 8080 --reload
```

### Step 5: Test the API

Open your browser to:
- **API Docs**: http://localhost:8080/docs
- **Health Check**: http://localhost:8080/health/live
- **API Info**: http://localhost:8080/

Or use curl:

```bash
# Health check
curl http://localhost:8080/health/live

# Readiness check
curl http://localhost:8080/health/ready

# Model info
curl http://localhost:8080/api/v1/predictions/model/info

# Make a prediction
curl -X POST http://localhost:8080/api/v1/predictions/predict \
  -H "Content-Type: application/json" \
  -d '{
    "metrics": {
      "cpu_usage": [
        {"timestamp": 1640000000, "value": 45.2},
        {"timestamp": 1640000060, "value": 48.1},
        {"timestamp": 1640000120, "value": 52.3}
      ],
      "memory_usage": [
        {"timestamp": 1640000000, "value": 1024000},
        {"timestamp": 1640000060, "value": 1048576},
        {"timestamp": 1640000120, "value": 1073741}
      ]
    }
  }'
```

## 🐳 Docker Quick Start

### Build and Run with Docker

```bash
# Build the image
docker build -t anomaly-detector:latest -f docker/Dockerfile.api .

# Run the container
docker run -p 8080:8080 \
  -e MODEL_DIR=/models \
  -v $(pwd)/models:/models \
  anomaly-detector:latest
```

### Using Docker Compose

```bash
# Start all services (Prometheus, Grafana, MLflow, API)
cd docker
docker-compose up -d

# Check logs
docker-compose logs -f anomaly-api

# Stop services
docker-compose down
```

Access services:
- **API**: http://localhost:8080
- **Grafana**: http://localhost:3000 (admin/admin)
- **Prometheus**: http://localhost:9090
- **MLflow**: http://localhost:5000

## ☸️ Kubernetes Quick Start

### Local k3d Cluster

```bash
# Create local cluster
make k3d-up

# Deploy the application
make deploy-app ENV=dev

# Check deployment
kubectl get pods -n anomaly-detection-dev

# Port forward to access API
kubectl port-forward -n anomaly-detection-dev svc/anomaly-detector 8080:80

# View logs
make logs ENV=dev
```

## 🧪 Running Tests

```bash
# Run all tests
make test

# Run unit tests only
make test-unit

# Run with coverage
pytest tests/unit/ -v --cov=src --cov-report=html

# View coverage report
open htmlcov/index.html  # macOS
start htmlcov/index.html  # Windows
```

## 🔧 Development Workflow

### 1. Setup Development Environment

```bash
# Install dev dependencies
make dev-setup

# Install pre-commit hooks
pre-commit install
```

### 2. Make Changes

```bash
# Edit code
code src/api/routes/predictions.py

# Format code
make format

# Lint code
make lint
```

### 3. Test Changes

```bash
# Run tests
make test

# Run specific test
pytest tests/unit/test_api.py::test_liveness -v
```

### 4. Build and Test Docker Image

```bash
# Build image
make docker-build

# Test image locally
docker run -p 8080:8080 \
  -e MODEL_DIR=/models \
  -v $(pwd)/models:/models \
  ghcr.io/eknathdj/anomaly-api:latest
```

## 📊 Monitoring

### View Metrics

```bash
# Prometheus metrics endpoint
curl http://localhost:8080/metrics

# Query Prometheus
curl "http://localhost:8080/api/v1/metrics/query?query=up"
```

### Grafana Dashboards

1. Open http://localhost:3000
2. Login with admin/admin
3. Import dashboard from `monitoring/grafana/dashboards/`

## 🐛 Troubleshooting

### API won't start

```bash
# Check if port is in use
netstat -an | grep 8080  # Linux/macOS
netstat -an | findstr 8080  # Windows

# Check logs
tail -f logs/api.log

# Verify Python version
python --version  # Should be 3.9+
```

### Model not loading

```bash
# Check model directory
ls -la models/

# Verify model file exists
test -f models/ensemble.joblib && echo "Model exists" || echo "Model missing"

# Check permissions
ls -l models/ensemble.joblib

# Try loading model manually
python -c "import joblib; model = joblib.load('models/ensemble.joblib'); print('✅ Model loaded')"
```

### Tests failing

```bash
# Install test dependencies
pip install -r ml-pipeline/requirements-dev.txt

# Clear pytest cache
rm -rf .pytest_cache

# Run with verbose output
pytest tests/unit/ -vv

# Run single test
pytest tests/unit/test_api.py::test_liveness -vv
```

### Docker build fails

```bash
# Check Docker is running
docker ps

# Clear Docker cache
docker system prune -a

# Build with no cache
docker build --no-cache -t anomaly-detector:latest -f docker/Dockerfile.api .

# Check Dockerfile syntax
docker build --check -f docker/Dockerfile.api .
```

## 📚 Next Steps

1. **Implement ML Pipeline**: Create actual training scripts in `ml-pipeline/`
2. **Add More Tests**: Increase test coverage to >80%
3. **Deploy to Cloud**: Use Terraform to deploy to Azure/AWS/GCP
4. **Setup CI/CD**: Configure GitHub Actions workflows
5. **Add Monitoring**: Create Grafana dashboards and alerts

## 🆘 Getting Help

- **Documentation**: See `docs/` directory
- **Issues**: Check `IMPROVEMENTS.md` for known issues
- **API Docs**: http://localhost:8080/docs
- **Logs**: Check application logs for detailed error messages

## ✅ Verification Checklist

- [ ] Python 3.9+ installed
- [ ] Dependencies installed (`make install`)
- [ ] Mock model created
- [ ] API starts successfully
- [ ] Health checks pass
- [ ] Tests pass (`make test`)
- [ ] Docker image builds
- [ ] Can make predictions via API

## 🎉 Success!

If you've completed all steps, you now have:
- ✅ Working API server
- ✅ Health monitoring
- ✅ Prediction endpoints
- ✅ Test suite
- ✅ Docker containerization
- ✅ Development environment

You're ready to start building the ML pipeline and deploying to production!
