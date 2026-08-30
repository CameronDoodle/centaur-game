extends SceneTree

const HUD_SCENE := preload("res://scenes/hud.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	await _test_unique_nodes(failures)
	await _test_session_chrome(failures)
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


func _test_unique_nodes(failures: PackedStringArray) -> void:
	var hud := HUD_SCENE.instantiate() as HUD
	root.add_child(hud)
	await process_frame
	var unique_names := [
		"TopBar", "ShiftLabel", "TimerLabel", "RightCluster",
		"RevealPanel", "RevealLabel", "SummaryPanel", "SummaryStack",
		"SummaryLabel", "NextShiftFacts", "TimeValue", "SubjectsValue",
		"StrikesValue", "WinLabel", "GateActions", "PeepholeActions",
		"DecisionRow", "AcceptButton", "RejectButton",
		"BackButton", "ReplayButton", "NextButton", "FisheyeOverlay",
		"FadeRect", "DoorOverlay", "PeepholeHotspot", "KnockHotspot",
		"ApproachHotspot", "PeepholeIcon", "KnockIcon", "KnockPlaybackFill",
		"ApproachIcon", "ApproachPlaybackFill",
	]
	for unique_name in unique_names:
		if hud.get_node_or_null("%" + unique_name) == null:
			failures.append("Missing unique HUD node %%%s." % unique_name)
	var margin := hud.get_node_or_null("Margin") as Control
	if margin == null:
		failures.append("HUD should still have a Margin root for session chrome.")
	else:
		for child in margin.get_children():
			var control := child as Control
			if control and control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
				failures.append(
					"Margin child %s should ignore mouse so stacked overlays do not block the world."
					% control.name
				)
	hud.free()


func _test_session_chrome(failures: PackedStringArray) -> void:
	var hud := HUD_SCENE.instantiate() as HUD
	root.add_child(hud)
	await process_frame
	hud.hide_session_chrome()
	if hud.top_bar.visible or hud.shift_label.visible or hud.timer_label.visible:
		failures.append("hide_session_chrome should hide TopBar, ShiftLabel, and TimerLabel.")
	hud.show_session_chrome()
	if not hud.top_bar.visible or not hud.shift_label.visible or not hud.timer_label.visible:
		failures.append("show_session_chrome should show TopBar, ShiftLabel, and TimerLabel.")
	hud.free()


func _test_decision_row_visibility(failures: PackedStringArray) -> void:
	var hud := HUD_SCENE.instantiate() as HUD
	root.add_child(hud)
	await process_frame
	var decision_row := hud.get_node("%DecisionRow") as Control
	if decision_row.visible:
		failures.append("Decision row should start hidden.")
	hud.set_decision_row_visible(true)
	hud.set_gate_actions_enabled(false)
	if not decision_row.visible:
		failures.append("Decision row should stay visible while gate actions are disabled.")
	if not hud.accept_button.disabled or not hud.reject_button.disabled:
		failures.append("Accept/Reject should be disabled during approach and knock.")
	hud.set_gate_actions_enabled(true)
	if hud.accept_button.disabled or hud.reject_button.disabled:
		failures.append("Accept/Reject should be enabled when gate actions are enabled.")
	hud.set_decision_row_visible(false)
	if decision_row.visible:
		failures.append("Decision row should hide when explicitly hidden.")
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
