extends SceneTree

const HUD_SCENE := preload("res://scenes/hud.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	await _test_decision_row_visibility(failures)
	await _test_shift_end_fail(failures)
	await _test_shift_end_success_with_next(failures)
	await _test_verdict_label(failures)
	if failures.is_empty():
		print("HUD: all checks passed.")
		quit(0)
	else:
		for failure in failures:
			printerr(failure)
		print("HUD: %d check(s) failed." % failures.size())
		quit(1)


func _test_decision_row_visibility(failures: PackedStringArray) -> void:
	var hud := HUD_SCENE.instantiate() as HUD
	root.add_child(hud)
	await process_frame
	var decision_row := hud.get_node("%DecisionRow") as Control
	if decision_row.visible:
		failures.append("Decision row should start hidden.")
	hud.set_gate_actions_enabled(true)
	if not decision_row.visible:
		failures.append("Decision row should be visible when gate actions are enabled.")
	if hud.accept_button.disabled or hud.reject_button.disabled:
		failures.append("Accept/Reject should be enabled when gate actions are enabled.")
	hud.set_gate_actions_enabled(false)
	if decision_row.visible:
		failures.append("Decision row should hide when gate actions are disabled.")
	hud.free()


func _test_shift_end_fail(failures: PackedStringArray) -> void:
	var hud := HUD_SCENE.instantiate() as HUD
	root.add_child(hud)
	await process_frame
	hud.show_summary("Out of strikes.", true, false)
	if hud.summary_label.text != "Out of strikes.":
		failures.append("Fail Shift End headline should match the reason.")
	if not hud.replay_button.visible:
		failures.append("Fail Shift End should show Replay Shift.")
	if hud.next_button.visible:
		failures.append("Fail Shift End should hide Next Shift.")
	if hud.next_shift_facts.visible:
		failures.append("Fail Shift End should hide next-Shift facts.")
	hud.free()


func _test_shift_end_success_with_next(failures: PackedStringArray) -> void:
	var hud := HUD_SCENE.instantiate() as HUD
	root.add_child(hud)
	await process_frame
	var next_shift := ShiftDef.new()
	next_shift.subject_count = 4
	next_shift.strikes_allowed = 2
	next_shift.shift_timer_seconds = 90.0
	hud.show_summary("Shift complete.", false, true, next_shift)
	if hud.summary_label.text != "Shift complete.":
		failures.append("Success Shift End headline should match.")
	if hud.replay_button.visible:
		failures.append("Mid-roster success should hide Replay Shift.")
	if not hud.next_button.visible:
		failures.append("Mid-roster success should show Next Shift.")
	if not hud.next_shift_facts.visible:
		failures.append("Mid-roster success should show next-Shift facts.")
	if hud.next_shift_time_value.text != "01:30":
		failures.append(
			"Next-Shift time fact expected 01:30, got %s."
			% hud.next_shift_time_value.text
		)
	if hud.next_shift_subjects_value.text != "4":
		failures.append("Next-Shift subjects fact expected 4.")
	if hud.next_shift_strikes_value.text != "2":
		failures.append("Next-Shift strikes fact expected 2.")
	hud.free()


func _test_verdict_label(failures: PackedStringArray) -> void:
	var hud := HUD_SCENE.instantiate() as HUD
	root.add_child(hud)
	await process_frame
	var reveal_panel := hud.get_node("%RevealPanel") as PanelContainer
	var reveal_label := hud.get_node("%RevealLabel") as Label
	if not reveal_label.get_parent() is PanelContainer:
		failures.append("Verdict label should be inside RevealPanel.")
	hud.show_reveal("Correct.")
	if not reveal_panel.visible:
		failures.append("Reveal panel should be visible after show_reveal.")
	if reveal_label.text != "Correct.":
		failures.append("Verdict label should display the verdict text.")
	hud.hide_reveal()
	if reveal_panel.visible:
		failures.append("Reveal panel should hide after hide_reveal.")
	hud.free()
