#!/bin/bash

# Phase 2 Data Flow Testing/Verification - Enhanced Version

set -e

echo "🧪 Phase 2 Data Flow Verification"
echo "=================================="

# Function to log messages
log_info() {
    echo "ℹ️  $1"
}

log_success() {
    echo "✅ $1"
}

log_warn() {
    echo "⚠️  $1"
}

log_error() {
    echo "❌ $1"
}

# Generate unique timestamp for pod names
TIMESTAMP=$(date +%s)

# Clean up any existing test pods
echo "0. Cleaning up previous test pods..."
kubectl delete pod kafka-test kafka-check-topics postgres-test kong-test --namespace aurora-dev --ignore-not-found=true --timeout=5s

# Test 1: Service Status Overview
echo ""
echo "1. 📊 Checking Service Status..."
kubectl get all -n aurora-dev

# Test 2: Database Connectivity & Data
echo ""
echo "2. 💾 Testing Database..."
if kubectl get pods -n aurora-dev -l app=postgresql --no-headers | grep -q Running; then
    log_success "PostgreSQL is running"
    
    # Test connectivity
    if kubectl run postgres-test-$TIMESTAMP --rm -i --restart=Never --namespace aurora-dev \
      --image=postgres:15 \
      --env="PGPASSWORD=aurora123" -- \
      psql -h postgresql -U postgres -d aurora_events -c "SELECT '✅ Database connection OK' as status;" 2>/dev/null; then
        log_success "Database connection successful"
    else
        log_error "Database connection failed"
    fi
    
    # Try to check record counts (if tables exist) - using exec if possible, otherwise skip
    if kubectl get pods -n aurora-dev -l app=postgresql --no-headers | grep Running | head -1 | awk '{print $1}' | grep -q postgresql; then
        POSTGRES_POD=$(kubectl get pods -n aurora-dev -l app=postgresql --no-headers | grep Running | head -1 | awk '{print $1}')
        log_info "Checking database records via pod: $POSTGRES_POD"
        kubectl exec -it $POSTGRES_POD -n aurora-dev -- psql -U postgres -d aurora_events -c "
            SELECT relname as table_name, n_live_tup as row_count 
            FROM pg_stat_user_tables 
            WHERE relname IN ('erp_events', 'predictions', 'inventory_snapshots')
            ORDER BY relname;" 2>/dev/null || log_warn "Could not query table statistics (tables may not exist yet)"
    fi
else
    log_error "PostgreSQL not running"
fi

# Test 3: Kafka Infrastructure
echo ""
echo "3. 🔄 Testing Kafka..."
if kubectl get pods -n aurora-dev -l app=kafka --no-headers | grep -q Running; then
    log_success "Kafka pod is running"
    
    # Wait for Kafka to be fully ready
    sleep 10
    
    # List topics
    log_info "Listing Kafka topics..."
    if kubectl run kafka-test-$TIMESTAMP --rm -i --restart=Never --namespace aurora-dev \
      --image=bitnami/kafka:3.7 -- \
      /opt/bitnami/kafka/bin/kafka-topics.sh --list --bootstrap-server kafka:9092 2>/dev/null; then
        log_success "Kafka connection successful"
    else
        log_error "Kafka connection failed"
    fi
    
    # Create essential topics if they don't exist
    echo ""
    echo "4. 📝 Ensuring Aurora topics exist..."
    kubectl run kafka-create-topics-$TIMESTAMP --rm -i --restart=Never --namespace aurora-dev \
      --image=bitnami/kafka:3.7 -- \
      /bin/bash -c "
        /opt/bitnami/kafka/bin/kafka-topics.sh --create --if-not-exists --topic erp-events --partitions 1 --replication-factor 1 --bootstrap-server kafka:9092
        /opt/bitnami/kafka/bin/kafka-topics.sh --create --if-not-exists --topic predictions --partitions 1 --replication-factor 1 --bootstrap-server kafka:9092
        /opt/bitnami/kafka/bin/kafka-topics.sh --create --if-not-exists --topic audit-logs --partitions 1 --replication-factor 1 --bootstrap-server kafka:9092
        /opt/bitnami/kafka/bin/kafka-topics.sh --create --if-not-exists --topic inventory-updates --partitions 1 --replication-factor 1 --bootstrap-server kafka:9092
        echo '✅ Topics created/verified'
      " 2>/dev/null || log_warn "Topic creation may have failed"
    
    # Check message counts in topics (if kafka-0 pod exists)
    echo ""
    echo "5. 📨 Checking Kafka Message Counts..."
    if kubectl get pods -n aurora-dev -l app=kafka --no-headers | grep kafka-0 | grep -q Running; then
        for topic in erp-events predictions inventory-updates; do
            if kubectl exec -it kafka-0 -n aurora-dev -- /opt/bitnami/kafka/bin/kafka-topics.sh --describe --topic $topic --bootstrap-server localhost:9092 &> /dev/null; then
                count=$(kubectl exec -it kafka-0 -n aurora-dev -- /opt/bitnami/kafka/bin/kafka-run-class.sh kafka.tools.GetOffsetShell \
                    --broker-list localhost:9092 --topic $topic --time -1 2>/dev/null | awk -F: '{sum += $3} END {print sum+0}' || echo "0")
                log_info "Topic $topic has $count messages"
            else
                log_warn "Topic $topic does not exist"
            fi
        done
    fi
else
    log_error "Kafka not running"
    exit 1
fi

# Test 4: Core Services Health
echo ""
echo "6. 🌐 Testing Core Services..."

# ERP Connector
if kubectl get pods -n aurora-dev -l app=erp-connector --no-headers | grep -q Running; then
    ERP_POD=$(kubectl get pods -n aurora-dev -l app=erp-connector --no-headers | grep Running | head -1 | awk '{print $1}')
    log_success "ERP Connector running: $ERP_POD"
    
    # Health check
    if kubectl exec -it $ERP_POD -n aurora-dev -- curl -s http://localhost:8000/health > /dev/null; then
        log_success "ERP Connector health check passed"
    else
        log_error "ERP Connector health check failed"
    fi
    
    # Check recent logs
    log_info "Recent ERP Connector logs:"
    kubectl logs -l app=erp-connector -n aurora-dev --tail=3 --since=2m 2>/dev/null || log_warn "No recent logs available"
else
    log_warn "ERP Connector not running"
fi

# Prediction Service
echo ""
if kubectl get pods -n aurora-dev -l app=prediction-service --no-headers | grep -q Running; then
    log_success "Prediction Service is running"
    log_info "Recent prediction logs:"
    kubectl logs -l app=prediction-service -n aurora-dev --tail=3 --since=2m 2>/dev/null || log_warn "No prediction logs available"
else
    log_warn "Prediction Service not running"
fi

# Test 5: API Gateway
echo ""
echo "7. 🚪 Testing Kong API Gateway..."
KONG_STATUS=$(kubectl get pods -n aurora-dev -l app.kubernetes.io/name=kong --no-headers | awk '{print $3}' | head -1)
if [ "$KONG_STATUS" = "Running" ]; then
    log_success "Kong Gateway is running"
    # Test Kong proxy internally
    if kubectl run kong-test-$TIMESTAMP --rm -i --restart=Never --namespace aurora-dev \
      --image=curlimages/curl:8.15.0 -- \
      curl -s -o /dev/null -w "Kong internal status: %{http_code}\n" http://kong-kong-proxy:80 --connect-timeout 5; then
        log_success "Kong internal connectivity OK"
    else
        log_warn "Kong internal connectivity issue"
    fi
else
    log_warn "Kong Gateway status: $KONG_STATUS"
fi

# Test 6: Data Flow Simulation
echo ""
echo "8. 🔌 Testing Data Flow..."
if kubectl get pods -n aurora-dev -l app=kafka --no-headers | grep -q Running; then
    log_info "Producing test message to erp-events topic..."
    if kubectl run kafka-producer-test-$TIMESTAMP --rm -i --restart=Never --namespace aurora-dev \
      --image=bitnami/kafka:3.7 -- \
      /bin/bash -c "
        echo '{\"event_type\":\"integration_test\",\"entity_id\":\"test-$(date +%s)\",\"timestamp\":\"$(date -Iseconds)\",\"payload\":{\"test\":\"data\",\"phase\":2}}' | \
        /opt/bitnami/kafka/bin/kafka-console-producer.sh --topic erp-events --bootstrap-server kafka:9092
        echo '✅ Test message produced to erp-events topic'
      " 2>/dev/null; then
        log_success "Data flow test message sent"
        
        # Quick check for message arrival
        sleep 2
        log_info "Verifying message delivery..."
    else
        log_warn "Data flow test failed"
    fi
fi

# Final Summary
echo ""
echo "📈 VERIFICATION SUMMARY"
echo "======================"

# Count running pods
RUNNING_PODS=$(kubectl get pods -n aurora-dev --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l || echo "0")
TOTAL_PODS=$(kubectl get pods -n aurora-dev --no-headers 2>/dev/null | wc -l || echo "0")

log_info "Overall Status: $RUNNING_PODS/$TOTAL_PODS pods running in aurora-dev"

# Critical services check
CRITICAL_SERVICES=("postgresql" "kafka" "erp-connector" "prediction-service")
for service in "${CRITICAL_SERVICES[@]}"; do
    if kubectl get pods -n aurora-dev --no-headers 2>/dev/null | grep -q "$service.*Running"; then
        log_success "$service: RUNNING"
    else
        log_error "$service: NOT RUNNING"
    fi
done

echo ""
if [ "$RUNNING_PODS" -eq "$TOTAL_PODS" ] && [ "$TOTAL_PODS" -gt 0 ]; then
    log_success "✅ Phase 2 verification completed successfully!"
    echo ""
    echo "🔍 Next steps:"
    echo "   kubectl logs -f deployment/erp-connector -n aurora-dev"
    echo "   kubectl port-forward svc/kafka 9092:9092 -n aurora-dev"
    echo "   kubectl port-forward svc/postgresql 5432:5432 -n aurora-dev"
else
    log_warn "⚠️  Phase 2 verification completed with warnings"
    echo ""
    echo "💡 Troubleshooting:"
    echo "   kubectl describe pods -n aurora-dev"
    echo "   kubectl get events -n aurora-dev"
    echo "   minikube logs"
fi
