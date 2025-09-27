import asyncio
import json
import mlflow.pyfunc
from kafka_consumer import KafkaConsumer
from kafka_producer import KafkaProducer
from feature_store_client import FeatureStoreClient
from config import settings
from structlog import get_logger

logger = get_logger()

class PredictionService:
    def __init__(self):
        self.kafka_consumer = KafkaConsumer("erp-events")
        self.kafka_producer = KafkaProducer()
        self.feature_store = FeatureStoreClient()
        self.model = None
        self.is_running = False
    
    async def load_model(self):
        """Load the ML model from MLflow registry"""
        try:
            model_uri = f"models:/inventory-demand-forecaster/Production"
            self.model = mlflow.pyfunc.load_model(model_uri)
            logger.info("ML model loaded successfully")
        except Exception as e:
            logger.error("Failed to load ML model", error=str(e))
            # Fallback to local model
            self.model = mlflow.pyfunc.load_model('models/inventory_model.joblib')
    
    async def start(self):
        """Start the prediction service"""
        await self.load_model()
        self.is_running = True
        
        logger.info("Starting Prediction Service")
        
        async for message in self.kafka_consumer.consume():
            if self.is_running:
                await self.process_event(message)
    
    async def process_event(self, event):
        """Process an ERP event and generate predictions"""
        try:
            event_data = json.loads(event.value())
            
            # Extract entity information
            entity_type = self._extract_entity_type(event_data)
            entity_id = event_data['entity_id']
            
            if entity_type == 'product':
                # Get features from feature store
                features = await self.feature_store.get_features(
                    entity_type='product',
                    entity_id=entity_id,
                    feature_names=['historical_demand_7d', 'historical_demand_30d', 
                                  'price', 'day_of_week', 'month']
                )
                
                if features:
                    # Generate prediction
                    prediction = self.model.predict([features])[0]
                    
                    # Create prediction event
                    prediction_event = {
                        "prediction_id": f"pred_{entity_id}_{event_data['timestamp']}",
                        "entity_type": entity_type,
                        "entity_id": entity_id,
                        "prediction_type": "demand_forecast",
                        "prediction_value": float(prediction),
                        "confidence": 0.85,  # Simulated confidence
                        "timestamp": event_data['timestamp'],
                        "model_version": "1.0"
                    }
                    
                    # Publish prediction
                    await self.kafka_producer.publish(
                        topic="predictions-alerts",
                        key=entity_id,
                        value=prediction_event
                    )
                    
                    logger.info("Prediction generated", 
                               entity_id=entity_id, 
                               prediction=prediction)
            
        except Exception as e:
            logger.error("Prediction processing failed", error=str(e))
    
    def _extract_entity_type(self, event_data):
        """Extract entity type from event data"""
        event_type = event_data.get('event_type', '')
        if 'INVENTORY' in event_type:
            return 'product'
        elif 'SALE' in event_type:
            return 'order'
        return 'unknown'

async def main():
    service = PredictionService()
    await service.start()

if __name__ == "__main__":
    asyncio.run(main())
