class_name HUD
extends CanvasLayer

signal peephole_pressed
signal peephole_back_pressed
signal question_pressed(index: int)
signal accept_pressed
signal reject_pressed
signal summary_replay_pressed

@onready var timer_label: Label = %TimerLabel
@onready var score_label: Label = %ScoreLabel
@onready var strikes_label: Label = %StrikesLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var reveal_panel: PanelContainer = %RevealPanel
@onready var reveal_label: Label = %RevealLabel
@onready var summary_panel: PanelContainer = %SummaryPanel
@onready var summary_label: Label = %SummaryLabel
@onready var gate_actions: VBoxContainer = %GateActions
@onready var peephole_actions: VBoxContainer = %PeepholeActions
@onready var question_buttons: VBoxContainer = %QuestionButtons
@onready var peephole_button: Button = %PeepholeButton
@onready var accept_button: Button = %AcceptButton
@onready var reject_button: Button = %RejectButton
@onready var back_button: Button = %BackButton
@onready var replay_button: Button = %ReplayButton
@onready var fisheye_overlay: ColorRect = %FisheyeOverlay


func _ready() -> void:
	peephole_button.pressed.connect(func() -> void: peephole_pressed.emit())
	back_button.pressed.connect(func() -> void: peephole_back_pressed.emit())
	accept_button.pressed.connect(func() -> void: accept_pressed.emit())
	reject_button.pressed.connect(func() -> void: reject_pressed.emit())
	replay_button.pressed.connect(func() -> void: summary_replay_pressed.emit())
	hide_reveal()
	hide_summary()
	set_peephole_mode(false)
	set_gate_actions_enabled(false)


func set_timer_text(text: String) -> void:
	timer_label.text = text


func set_score(score: int) -> void:
	score_label.text = "Score: %d" % score


func set_strikes(strikes_used: int, strikes_allowed: int) -> void:
	strikes_label.text = "Strikes: %d / %d" % [strikes_used, strikes_allowed]


func set_subtitle(text: String) -> void:
	subtitle_label.text = text
	subtitle_label.visible = not text.is_empty()


func clear_subtitle() -> void:
	set_subtitle("")


func set_questions(questions: Array[QuestionDef]) -> void:
	for child in question_buttons.get_children():
		child.queue_free()
	for i in questions.size():
		var question := questions[i]
		var button := Button.new()
		button.text = question.button_label
		var index := i
		button.pressed.connect(func() -> void: question_pressed.emit(index))
		question_buttons.add_child(button)


func set_gate_actions_enabled(enabled: bool) -> void:
	peephole_button.disabled = not enabled
	accept_button.disabled = not enabled
	reject_button.disabled = not enabled
	for child in question_buttons.get_children():
		if child is Button:
			child.disabled = not enabled


func set_peephole_mode(active: bool) -> void:
	gate_actions.visible = not active
	peephole_actions.visible = active
	fisheye_overlay.visible = active


func show_reveal(text: String) -> void:
	reveal_label.text = text
	reveal_panel.visible = true


func hide_reveal() -> void:
	reveal_panel.visible = false


func show_summary(text: String) -> void:
	summary_label.text = text
	summary_panel.visible = true
	set_gate_actions_enabled(false)
	set_peephole_mode(false)


func hide_summary() -> void:
	summary_panel.visible = false
