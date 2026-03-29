extends Node
class_name EventBusShop

## EventBusShop - 商店/经济系统事件

signal shop_opened(shop_id: String)
signal shop_closed
signal item_bought(item_id: String, price: int)
signal item_sold(item_id: String, price: int)
signal money_changed(amount: int, delta: int)
signal price_updated(item_id: String, new_price: int, base_price: int)
signal market_event_triggered(event_name: String, affected_items: Array)
signal prices_changed
