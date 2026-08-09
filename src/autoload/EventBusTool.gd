extends Node
class_name EventBusTool

## EventBusTool - 工具升级系统事件

signal tool_upgraded(tool_type: int, old_tier: int, new_tier: int)
signal upgrade_started(tool_type: int)
signal upgrade_failed(tool_type: int, reason: String)
