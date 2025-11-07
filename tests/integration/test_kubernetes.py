#!/usr/bin/env bats
# requires: brew install bats-core  (or apt install bats)

@test "namespace exists" {
  run kubectl get namespace k8s-anomaly-dev
  [ "$status" -eq 0 ]
}

@test "anomaly-detector pods ready" {
  kubectl wait --for=condition=Ready pod \
    -l app.kubernetes.io/name=anomaly-detector \
    -n k8s-anomaly-dev --timeout=300s
}

@test "service monitor created" {
  run kubectl get servicemonitor -n monitoring \
    -l app.kubernetes.io/name=anomaly-detector
  [ "$status" -eq 0 ]
}