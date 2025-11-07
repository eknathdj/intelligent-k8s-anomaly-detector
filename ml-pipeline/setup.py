
--------------------------------------------------
ml-pipeline/setup.py  (modern, PEP-517 compatible)
------------------------------------------------```
from setuptools import setup, find_packages

with open("README.md", encoding="utf-8") as f:
    long_description = f.read()

with open("requirements.txt", encoding="utf-8") as f:
    requires = [line.strip() for line in f if line.strip() and not line.startswith("#")]

extras = {
    "azure": ["azure-storage-blob>=12.19.0", "azure-identity>=1.15.0"],
    "aws": ["boto3>=1.34.0", "botocore>=1.34.0"],
    "gcp": ["google-cloud-storage>=2.12.0", "google-cloud-secret-manager>=2.18.0"],
    "dev": open("requirements-dev.txt").read().splitlines()[1:],  # skip '-r req.txt'
}

setup(
    name="intelligent-k8s-anomaly-pipeline",
    version="0.1.0",
    description="ML pipeline for intelligent Kubernetes anomaly detection",
    long_description=long_description,
    long_description_content_type="text/markdown",
    author="eknathdj",
    python_requires=">=3.9",
    packages=find_packages(where="src"),
    package_dir={"": "src"},
    install_requires=requires,
    extras_require=extras,
    entry_points={
        "console_scripts": [
            "k8s-ml-train=ml_pipeline.training.train:main",
            "k8s-ml-infer=ml_pipeline.deployment.model_server:main",
        ],
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