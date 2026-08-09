extends Node
class_name EventBusAnimal

## EventBusAnimal - 动物系统事件

signal animal_purchased(animal_type: String, animal_name: String, price: int)
signal animal_fed(animal_id: String, animal_name: String, food_item: String)
signal animal_product_ready(animal_id: String, product_id: String)
signal animal_product_collected(animal_id: String, product_id: String, quality: int)
signal animal_friendship_changed(animal_id: String, friendship: int, hearts: int)
signal animal_building_placed(building_type: String, building_name: String)
signal animal_building_upgraded(building_type: String, new_level: int)
