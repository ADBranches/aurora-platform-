#!/bin/bash

# Infrastructure Deployment Script

set -e

echo "🏗️ Deploying Aurora infrastructure..."

# Check prerequisites
command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl is required but not installed. Aborting."; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "❌ helm is required but not installed. Aborting."; exit 1; }

# Create namespace if it doesn't exist
echo "📁 Creating namespace..."
kubectl create namespace aurora-dev --dry-run=client -o yaml | kubectl apply -f -

# Add Bitnami Helm repository for production-ready charts
echo "📦 Adding Bitnami Helm repository..."
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Deploy PostgreSQL using Bitnami chart (more production-ready)
echo "📊 Deploying PostgreSQL..."
helm upgrade --install postgresql bitnami/postgresql \
  --namespace aurora-dev \
  --set auth.postgresPassword=aurora123 \
  --set auth.database=aurora_core \
  --set primary.persistence.size=10Gi \
  --set resources.requests.memory=512Mi \
  --set resources.requests.cpu=250m

# Deploy Redis using Bitnami chart
echo "🔴 Deploying Redis..."
helm upgrade --install redis bitnami/redis \
  --namespace aurora-dev \
  --set auth.password=aurora-redis-123 \
  --set master.persistence.size=5Gi \
  --set resources.requests.memory=256Mi \
  --set resources.requests.cpu=100m

# Deploy Kafka (required for our microservices)
echo "📨 Deploying Kafka..."
helm upgrade --install kafka bitnami/kafka \
  --namespace aurora-dev \
  --set persistence.size=10Gi \
  --set resources.requests.memory=512Mi \
  --set resources.requests.cpu=250m

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgresql \
  --namespace aurora-dev --timeout=300s

kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=redis \
  --namespace aurora-dev --timeout=180s

kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kafka \
  --namespace aurora-dev --timeout=300s

# Create Aurora-specific databases and users
echo "🗃️ Initializing Aurora databases..."
kubectl run postgresql-client --rm -i --restart='Never' --namespace aurora-dev \
  --image docker.io/bitnami/postgresql:15.0.0 \
  --env="PGPASSWORD=aurora123" \
  --command -- psql -h postgresql -U postgres -d postgres -c "
CREATE DATABASE aurora_events;
CREATE DATABASE aurora_ml;
CREATE DATABASE aurora_users;
CREATE USER aurora_user WITH PASSWORD 'aurora123';
GRANT ALL PRIVILEGES ON DATABASE aurora_events TO aurora_user;
GRANT ALL PRIVILEGES ON DATABASE aurora_ml TO aurora_user;
GRANT ALL PRIVILEGES ON DATABASE aurora_users TO aurora_user;
"

# Display connection information
echo ""
echo "✅ Infrastructure deployment complete!"
echo ""
echo "📋 Connection Information:"
echo "   PostgreSQL Host: postgresql.aurora-dev.svc.cluster.local:5432"
echo "   Redis Host: redis-master.aurora-dev.svc.cluster.local:6379"
echo "   Kafka Bootstrap: kafka.aurora-dev.svc.cluster.local:9092"
echo ""
echo "🔧 Database Credentials:"
echo "   PostgreSQL User: aurora_user"
echo "   PostgreSQL Password: aurora123"
echo "   Redis Password: aurora-redis-123"
echo ""
echo "🔍 Check status with: kubectl get pods -n aurora-dev"
echo "📊 Check services with: kubectl get svc -n aurora-dev"
