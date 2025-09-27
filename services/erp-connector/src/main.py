import asyncio
import logging
import json
from typing import Dict, Any
from aiokafka import AIOKafkaProducer

class KafkaProducer:
    def __init__(self):
        self.producer = AIOKafkaProducer(bootstrap_servers=settings.KAFKA_BOOTSTRAP_SERVERS)
    
    async def publish(self, topic: str, key: str, value: dict):
        await self.producer.start()
        try:
            await self.producer.send_and_wait(topic, key=key.encode('utf-8'), value=json.dumps(value).encode('utf-8'))
        finally:
            await self.producer.stop()
try:
    try:
        from erp_client import ERPClient  # Adjusted import path
    except ImportError:
        raise ImportError("The module 'erp_client' could not be found. Ensure it exists and is in the correct path.")
except ImportError:
    raise ImportError("The module 'erp_client' could not be found. Ensure it exists and is in the Python path.")
try:
    from config import settings
except ImportError:
    raise ImportError("The 'settings' module could not be imported. Ensure it exists in the 'config' package and is correctly implemented.")
import prometheus_client as prom
from structlog import get_logger

logger = get_logger()

# Metrics
events_processed = prom.Counter('erp_connector_events_processed', 'Number of ERP events processed', ['event_type'])
processing_errors = prom.Counter('erp_connector_processing_errors', 'Number of processing errors')

class ERPConnector:
    def __init__(self):
        self.erp_client = ERPClient()
        self.kafka_producer = KafkaProducer()
        self.is_running = False
    
    async def start(self):
        """Start the ERP connector service"""
        self.is_running = True
        logger.info("Starting ERP Connector service")
        
        # Start metrics server
        prom.start_http_server(8000)
        
        while self.is_running:
            try:
                await self._poll_erp_events()
                await asyncio.sleep(settings.POLL_INTERVAL_SECONDS)
            except Exception as e:
                logger.error("Error in ERP polling cycle", error=str(e))
                processing_errors.inc()
                await asyncio.sleep(10)  # Backoff on error
    
    async def _poll_erp_events(self):
        """Poll ERP system for new events"""
        try:
            # Simulate fetching events from ERP (replace with actual ERP API calls)
            events = await self.erp_client.get_recent_events()
            
            for event in events:
                # Transform ERP event to standard format
                kafka_event = self._transform_event(event)
                
                # Publish to Kafka
                await self.kafka_producer.publish(
                    topic="erp-events",
                    key=event["entity_id"],
                    value=kafka_event
                )
                
                events_processed.labels(event_type=event["event_type"]).inc()
                logger.info("ERP event published to Kafka", event_type=event["event_type"], entity_id=event["entity_id"])
                
        except Exception as e:
            logger.error("Failed to poll ERP events", error=str(e))
            raise
    
    def _transform_event(self, erp_event: Dict[str, Any]) -> Dict[str, Any]:
        """Transform ERP-specific event to standard Aurora event format"""
        return {
            "event_id": erp_event.get("id"),
            "event_type": erp_event.get("type"),
            "entity_id": erp_event.get("entity_id"),
            "timestamp": erp_event.get("timestamp"),
            "payload": erp_event.get("data", {}),
            "source_system": "jde_erp",
            "version": "1.0"
        }

async def main():
    connector = ERPConnector()
    await connector.start()

if __name__ == "__main__":
    asyncio.run(main())
    