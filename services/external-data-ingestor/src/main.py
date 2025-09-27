import asyncio
import aiohttp
import json
from kafka_producer import KafkaProducer
from config import settings
from structlog import get_logger

logger = get_logger()

class ExternalDataIngestor:
    def __init__(self):
        self.kafka_producer = KafkaProducer()
        self.services = {
            'weather': WeatherService(),
            'market_data': MarketDataService(),
            'exchange_rates': ExchangeRateService()
        }
    
    async def start(self):
        """Start all data ingestion services"""
        logger.info("Starting External Data Ingestion service")
        
        tasks = []
        for service_name, service in self.services.items():
            task = asyncio.create_task(self._run_service(service_name, service))
            tasks.append(task)
        
        await asyncio.gather(*tasks)
    
    async def _run_service(self, service_name: str, service):
        """Run a specific data ingestion service"""
        while True:
            try:
                data = await service.fetch_data()
                if data:
                    await self.kafka_producer.publish(
                        topic="external-data",
                        key=service_name,
                        value=data
                    )
                    logger.info("External data published", service=service_name)
                
                await asyncio.sleep(service.poll_interval)
            except Exception as e:
                logger.error("Service error", service=service_name, error=str(e))
                await asyncio.sleep(30)  # Backoff on error

class WeatherService:
    def __init__(self):
        self.poll_interval = 300  # 5 minutes
        self.api_key = settings.WEATHER_API_KEY
    
    async def fetch_data(self):
        # Simulate weather data fetching
        return {
            "service": "weather",
            "timestamp": "2024-01-15T10:30:00Z",
            "data": {
                "temperature": 22.5,
                "humidity": 65,
                "conditions": "clear",
                "location": "warehouse-01"
            }
        }

class MarketDataService:
    def __init__(self):
        self.poll_interval = 600  # 10 minutes
    
    async def fetch_data(self):
        # Simulate market data fetching
        return {
            "service": "market_data",
            "timestamp": "2024-01-15T10:30:00Z", 
            "data": {
                "commodity_prices": {
                    "steel": 850.00,
                    "copper": 9200.00
                }
            }
        }

async def main():
    ingestor = ExternalDataIngestor()
    await ingestor.start()

if __name__ == "__main__":
    asyncio.run(main())
    