extends Node
class_name EventBusShipping

## EventBusShipping - 出货箱系统事件

signal shipping_bin_opened
signal shipping_bin_closed
signal shipping_item_added(item_id: String, quantity: int)
signal shipping_item_removed(item_id: String, quantity: int)
signal shipment_processed(total_money: int, items_count: int)
