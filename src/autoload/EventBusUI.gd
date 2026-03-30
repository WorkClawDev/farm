extends Node
class_name EventBusUI

## EventBusUI - UI系统事件

signal ui_opened(ui_name: String)
signal ui_closed(ui_name: String)
signal notification_shown(message: String, type: int)
