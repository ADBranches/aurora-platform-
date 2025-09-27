# infrastructure/feast/entities.py
from feast import Entity
from feast.value_type import ValueType

# Define core entities with value_type to fix deprecation warnings
product = Entity(
    name="product",
    description="A product in the inventory system",
    join_keys=["product_id"],
    value_type=ValueType.STRING  # Add value_type
)

customer = Entity(
    name="customer", 
    description="A customer in the ERP system",
    join_keys=["customer_id"],
    value_type=ValueType.STRING  # Add value_type
)

supplier = Entity(
    name="supplier",
    description="A supplier in the procurement system", 
    join_keys=["supplier_id"],
    value_type=ValueType.STRING  # Add value_type
)
