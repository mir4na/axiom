extends Control

@onready var _line_1: Label = get_node_or_null("BoardAnchor/Line1") as Label
@onready var _line_2: Label = get_node_or_null("BoardAnchor/Line2") as Label
@onready var _line_3: Label = get_node_or_null("BoardAnchor/Line3") as Label
@onready var _footer: Label = get_node_or_null("BoardAnchor/Footer") as Label

var _line_1_text: String = ""
var _line_2_text: String = ""
var _line_3_text: String = ""
var _footer_text: String = ""

func _ready() -> void:
	visible = false
	_reset_labels()

func set_content(line_1: String, line_2: String, line_3: String, footer: String) -> void:
	_line_1_text = line_1
	_line_2_text = line_2
	_line_3_text = line_3
	_footer_text = footer
	_reset_labels()

func reset_content() -> void:
	_reset_labels()

func play_typewriter(char_interval: float, line_pause: float, footer_pause: float) -> void:
	if not is_inside_tree():
		return
	visible = true
	await _type_into_label(_line_1, _line_1_text, char_interval)
	if not is_inside_tree():
		return
	await get_tree().create_timer(line_pause).timeout
	await _type_into_label(_line_2, _line_2_text, char_interval)
	if not is_inside_tree():
		return
	await get_tree().create_timer(line_pause).timeout
	await _type_into_label(_line_3, _line_3_text, char_interval)
	if not is_inside_tree():
		return
	await get_tree().create_timer(footer_pause).timeout
	if not is_inside_tree():
		return
	if _footer != null:
		_footer.text = _footer_text
		_footer.visible = true

func _reset_labels() -> void:
	if _line_1 != null:
		_line_1.text = ""
	if _line_2 != null:
		_line_2.text = ""
	if _line_3 != null:
		_line_3.text = ""
	if _footer != null:
		_footer.text = ""
		_footer.visible = false

func _type_into_label(label: Label, text: String, char_interval: float) -> void:
	if label == null:
		return
	if not is_inside_tree():
		return
	label.text = ""
	for index in range(text.length()):
		if not is_inside_tree():
			return
		label.text = text.substr(0, index + 1)
		await get_tree().create_timer(char_interval).timeout
