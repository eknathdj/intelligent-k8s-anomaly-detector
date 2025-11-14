"""Setup script for the project (legacy support)."""
from setuptools import setup, find_packages

# Read requirements
with open("src/requirements.txt") as f:
    requirements = [line.strip() for line in f if line.strip() and not line.startswith("#")]

# Read README
with open("README.md", encoding="utf-8") as f:
    long_description = f.read()

setup(
    name="intelligent-k8s-anomaly-detector",
    version="0.1.0",
    description="ML-powered predictive anomaly detection for Kubernetes workloads",
    long_description=long_description,
    long_description_content_type="text/markdown",
    author="eknathdj",
    author_email="maintainer@example.com",
    url="https://github.com/eknathdj/intelligent-k8s-anomaly-detector",
    packages=find_packages(where="src"),
    package_dir={"": "src"},
    python_requires=">=3.9",
    install_requires=requirements,
    extras_require={
        "dev": [
            "black>=23.12.0",
            "isort>=5.13.0",
            "flake8>=7.0.0",
            "mypy>=1.8.0",
            "pytest>=7.4.4",
            "pytest-cov>=4.1.0",
            "pytest-asyncio>=0.23.0",
        ]
    },
    classifiers=[
        "Development Status :: 3 - Alpha",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
    ],
)
