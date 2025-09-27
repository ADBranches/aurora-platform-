from feast import Entity

# Define core entities
product = Entity(
    name="product",
    description="A product in the inventory system",
    join_keys=["product_id"]
)

customer = Entity(
    name="customer", 
    description="A customer in the ERP system",
    join_keys=["customer_id"]
)

supplier = Entity(
    name="supplier",
    description="A supplier in the procurement system", 
    join_keys=["supplier_id"]
)
