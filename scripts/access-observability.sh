#!/bin/bash

echo "🔍 Observability Tools Access:"
echo ""
echo "1. Grafana (Dashboards): http://localhost:3000"
echo "   Username: admin"
echo "   Password: aurora123"
echo ""
echo "2. Prometheus (Metrics): http://localhost:9090"
echo ""
echo "3. Starting port forwarding..."
echo "   Press Ctrl+C to stop all services"

# Start port forwarding in background
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 &
GRAFANA_PID=$!

kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090 &
PROMETHEUS_PID=$!

# Wait for Ctrl+C
trap "kill $GRAFANA_PID $PROMETHEUS_PID; exit" INT
wait
