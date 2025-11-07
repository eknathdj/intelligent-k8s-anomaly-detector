
--------------------------------------------------
docs/development/setup.md
--------------------------------------------------
```markdown
# Development Setup

## Tools
| Tool | Version | Install |
|------|---------|---------|
| Python | 3.9+ | pyenv |
| Terraform | ≥ 1.9 | tfenv |
| Kubectl | ≥ 1.28 | brew/apt |
| Helm | ≥ 3.13 | brew/apt |
| K3d | ≥ 5.6 | brew/apt |
| Tox | latest | pip |

## Clone & Virtual-Env
```bash
git clone https://github.com/eknathdj/intelligent-k8s-anomaly-detector.git
cd intelligent-k8s-anomaly-detector
python -m venv .venv
source .venv/bin/activate
pip install -e ml-pipeline/[dev,azure]  # or aws/gcp
pre-commit install