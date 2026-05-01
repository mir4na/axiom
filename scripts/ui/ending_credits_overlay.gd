extends Control

@export_multiline var credits_text: String = "CREDITS\n\nGame Designer\nmir4na\n\nProgrammer\nmir4na, Codex, Antigravity\n\nAssets\nCreators who published free models\n\nSound Effects and BGM\nCreators on YouTube\n\nAlso Thanks To\nGodot Engine\nGodot Community\nMixamo"
@export var thanks_text: String = "Again, Thanks for Playing this Game ^^."
@export var scroll_duration: float = 23.0
@export var end_hold_duration: float = 1.8
@export var scroll_bottom_padding: float = 110.0
@export var scroll_top_padding: float = 180.0
@export var credits_font_size: int = 68
@export var thanks_font_size: int = 56

@onready var _credits_label: Label = $CreditsLabel
@onready var _thanks_label: Label = $ThanksLabel

func _ready() -> void:
	if _credits_label != null:
		_credits_label.text = credits_text
		_credits_label.add_theme_font_size_override("font_size", credits_font_size)
	if _thanks_label != null:
		_thanks_label.text = thanks_text
		_thanks_label.add_theme_font_size_override("font_size", thanks_font_size)
		_thanks_label.modulate.a = 0.0

func play_roll(gameplay_font: Font = null) -> void:
	if _credits_label == null or _thanks_label == null:
		return
	if gameplay_font != null:
		_credits_label.add_theme_font_override("font", gameplay_font)
		_thanks_label.add_theme_font_override("font", gameplay_font)
	var viewport_size: Vector2 = get_viewport_rect().size
	var start_y: float = viewport_size.y + scroll_bottom_padding
	var credits_height: float = maxf(_credits_label.size.y, _credits_label.custom_minimum_size.y)
	var end_y: float = -credits_height - scroll_top_padding
	_credits_label.position.y = start_y
	var scroll_tween: Tween = create_tween()
	scroll_tween.tween_property(_credits_label, "position:y", end_y, maxf(0.01, scroll_duration)).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	await scroll_tween.finished
	var thanks_tween: Tween = create_tween()
	thanks_tween.tween_property(_thanks_label, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await thanks_tween.finished
	var tree: SceneTree = get_tree()
	if tree != null:
		await tree.create_timer(maxf(0.01, end_hold_duration)).timeout
