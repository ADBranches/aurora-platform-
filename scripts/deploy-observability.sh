#!/bin/bash

# Observability Stack Deployment Script

set -e

echo "📊 Deploying Observability Stack..."

# Add Prometheus community repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Create monitoring namespace
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Deploy Prometheus Stack (includes Grafana)
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values infrastructure/helm-charts/monitoring/values.yaml \
  --set grafana.adminPassword=aurora123

# Deploy Jaeger
helm upgrade --install jaeger jaegertracing/jaeger \
  --namespace monitoring \
  --values infrastructure/helm-charts/jaeger/values.yaml

# Wait for services to be ready
echo "⏳ Waiting for observability services..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana \
  --namespace monitoring --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus \
  --namespace monitoring --timeout=300s

# Get Grafana admin password
GRAFANA_PASSWORD=$(kubectl get secret prometheus-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 --decode)

echo "✅ Observability stack deployed!"
echo ""
echo "📈 Monitoring URLs:"
echo "   Grafana: http://localhost:3000 (port-forward: kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80)"
echo "   Grafana Admin Password: $GRAFANA_PASSWORD"
echo "   Prometheus: http://localhost:9090 (port-forward: kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090)"
echo "   Jaeger: http://localhost:16686 (port-forward: kubectl port-forward -n monitoring svc/jaeger-query 16686:16686)"
