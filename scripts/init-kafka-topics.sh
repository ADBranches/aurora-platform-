# #!/bin/bash

# # Initialize Kafka Topics for Aurora

# set -e

# echo "📤 Initializing Kafka topics..."

# # Load environment variables
# if [ -f .env ]; then
#   export $(cat .env | grep -v '^#' | xargs)
# fi

# # Wait for Kafka to be ready
# until docker-compose exec -T kafka kafka-topics.sh --list --bootstrap-server ${KAFKA_BOOTSTRAP_SERVERS:-kafka:9092} >/dev/null 2>&1; do
#   echo "Waiting for Kafka..."
#   sleep 2
# done

# # Create topics with production-ready configurations
# TOPICS=(
#   "erp.events:3:1:604800000"  # 3 partitions, 1 replica, 7-day retention
#   "predictions.alerts:3:1:604800000"
# )

# for topic_config in "${TOPICS[@]}"; do
#   IFS=':' read -r topic partitions replicas retention_ms <<< "$topic_config"
#   echo "Creating topic: $topic"
#   docker-compose exec -T kafka kafka-topics.sh \
#     --create \
#     --topic "$topic" \
#     --bootstrap-server ${KAFKA_BOOTSTRAP_SERVERS:-kafka:9092} \
#     --partitions "$partitions" \
#     --replication-factor "$replicas" \
#     --config retention.ms="$retention_ms" || true
# done

# echo "✅ Kafka topics initialized!"

#!/bin/bash

# Initialize Kafka Topics for Aurora

set -e

echo "📤 Initializing Kafka topics..."

# Load environment variables
if [ -f .env ]; then
  export $(cat .env | grep -v '^#' | xargs)
fi

# Wait for Kafka to be ready using port check (more reliable)
echo "⏳ Waiting for Kafka..."
until nc -z localhost 9092; do
  echo "Waiting for Kafka..."
  sleep 2
done

# Additional wait for Kafka to fully initialize
echo "Kafka port open, waiting for service to stabilize..."
sleep 10

# Create topics with production-ready configurations using positional parameters
set -- "erp-events:3:1:604800000"  # 3 partitions, 1 replica, 7-day retention
set -- "$@" "predictions-alerts:3:1:604800000"

for topic_config in "$@"; do
  IFS=':' read -r topic partitions replicas retention_ms <<< "$topic_config"
  echo "Creating topic: $topic"
  docker compose exec -T kafka kafka-topics \
    --create \
    --topic "$topic" \
    --bootstrap-server ${KAFKA_BOOTSTRAP_SERVERS:-kafka:9092} \
    --partitions "$partitions" \
    --replication-factor "$replicas" \
    --config retention.ms="$retention_ms" || true
done

echo "✅ Kafka topics initialized!"

