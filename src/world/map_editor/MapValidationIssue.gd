@tool
extends RefCounted
class_name MapValidationIssue

enum Severity {
	INFO,
	WARNING,
	ERROR,
}

var code: StringName
var severity: Severity
var message: String
var node_path: NodePath


func _init(
	issue_code: StringName = &"unknown",
	issue_severity: Severity = Severity.ERROR,
	issue_message: String = "",
	issue_node_path: NodePath = NodePath()
) -> void:
	code = issue_code
	severity = issue_severity
	message = issue_message
	node_path = issue_node_path


func is_error() -> bool:
	return severity == Severity.ERROR


func to_dictionary() -> Dictionary:
	return {
		"code": str(code),
		"severity": Severity.keys()[severity].to_lower(),
		"message": message,
		"node_path": str(node_path),
	}
