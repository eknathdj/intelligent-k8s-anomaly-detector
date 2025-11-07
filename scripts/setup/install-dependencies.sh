#!/usr/bin/env bash
set -euo pipefail

# installs: terraform, kubectl, helm, k3d, pre-commit, azure-cli (optional)
# supports macOS (brew) and Debian/Ubuntu (apt)

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

echo "🧰  Installing dev dependencies for $OS/$ARCH"

install_terraform(){
  if ! command -v terraform &> /dev/null; then
    echo "📦  Terraform"
    curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add - || true
    sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main" || true
    sudo apt-get update && sudo apt-get install -y terraform
  else
    echo "✔   Terraform already installed"
  fi
}

install_kubectl(){
  if ! command -v kubectl &> /dev/null; then
    echo "📦  kubectl"
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/${OS}/amd64/kubectl"
    chmod +x kubectl && sudo mv kubectl /usr/local/bin/
  else
    echo "✔   kubectl already installed"
  fi
}

install_helm(){
  if ! command -v helm &> /dev/null; then
    echo "📦  Helm"
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  else
    echo "✔   Helm already installed"
  fi
}

install_k3d(){
  if ! command -v k3d &> /dev/null; then
    echo "📦  k3d"
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
  else
    echo "✔   k3d already installed"
  fi
}

install_precommit(){
  if ! command -v pre-commit &> /dev/null; then
    echo "📦  pre-commit"
    pip3 install --user pre-commit
  else
    echo "✔   pre-commit already installed"
  fi
}

install_azurecli(){
  if ! command -v az &> /dev/null; then
    echo "📦  Azure CLI"
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
  else
    echo "✔   Azure CLI already installed"
  fi
}

case "$OS" in
  darwin)
    which brew >/dev/null || { echo "❌  Homebrew not found"; exit 1; }
    brew install terraform kubectl helm k3d pre-commit azure-cli
    ;;
  linux)
    install_terraform
    install_kubectl
    install_helm
    install_k3d
    install_precommit
    install_azurecli
    ;;
  *)
    echo "❌  Unsupported OS: $OS"; exit 1
    ;;
esac

echo "✅  All dependencies installed"
pre-commit install