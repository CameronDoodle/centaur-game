extends SceneTree

const HORSE_SCENE := preload("res://scenes/subjects/horse.tscn")
const HUMAN_SCENE := preload("res://scenes/subjects/human.tscn")
const KENNEY_HORSE := preload("res://art/horse/Horse.glb")
const KENNEY_MAN := preload("res://art/human/Man.glb")
const QUATERNIUS_HORSE := preload("res://art/horse/Horse by Quaternius - qvTrSG9pZF.glb")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	_test_matcher(failures)
	await _test_walk_keeps_playing(KENNEY_HORSE, "Horse.glb", failures)
	await _test_walk_keeps_playing(QUATERNIUS_HORSE, "Quaternius Horse", failures)
	await _test_human_walk_keeps_playing(KENNEY_MAN, "Man.glb", failures)
	if failures.is_empty():
		print("AnimationHints: all checks passed.")
		quit(0)
	else:
		for failure in failures:
			printerr(failure)
		print("AnimationHints: %d check(s) failed." % failures.size())
		quit(1)


func _test_matcher(failures: PackedStringArray) -> void:
	_assert_match("Walk", "Walk", true, failures)
	_assert_match("Armature|Walk", "Walk", true, failures)
	_assert_match("Armature/Walk", "Walk", true, failures)
	_assert_match("HumanArmature|Man_Walk", "Walk", true, failures)
	_assert_match("HumanArmature|Man_Walk", "Man_Walk", true, failures)
	_assert_match("HumanArmature|Man_Idle", "Idle", true, failures)
	_assert_match("WalkSlow", "Walk", false, failures)
	_assert_match("Armature|WalkSlow", "Walk", false, failures)
	_assert_match("Armature/WalkSlow", "Walk", false, failures)
	_assert_match("CharacterArmature|Idle_Gun", "Idle", false, failures)


func _assert_match(clip_name: String, hint: String, expected: bool, failures: PackedStringArray) -> void:
	var actual := AnimationHints.matches(clip_name, hint)
	if actual != expected:
		failures.append(
			"matches(%s, %s) was %s, expected %s."
			% [clip_name, hint, actual, expected]
		)


func _advance_with_ticks(player: AnimationPlayer, total: float, step: float = 0.05) -> void:
	var elapsed := 0.0
	while elapsed < total:
		var delta := minf(step, total - elapsed)
		player.advance(delta)
		await process_frame
		elapsed += delta


func _test_walk_keeps_playing(
	horse_look: PackedScene,
	label: String,
	failures: PackedStringArray
) -> void:
	var horse := HORSE_SCENE.instantiate() as Node3D
	root.add_child(horse)
	horse.apply_appearance({ModelCatalog.HORSE_KEY: horse_look})
	horse.play_walk()
	await process_frame
	var player := _find_animation_player(horse)
	if player == null:
		failures.append("%s missing AnimationPlayer." % label)
		horse.free()
		return
	if not player.is_playing():
		failures.append("%s should play Walk after play_walk()." % label)
		horse.free()
		return
	var clip := player.current_animation
	if AnimationHints.clip_leaf(clip) != "Walk":
		failures.append("%s current clip leaf is '%s', expected Walk." % [label, clip])
		horse.free()
		return
	var animation := player.get_animation(clip)
	if animation == null:
		failures.append("%s missing animation resource for '%s'." % [label, clip])
		horse.free()
		return
	var skeleton := _find_skeleton(horse)
	var foot := -1
	if skeleton:
		foot = skeleton.find_bone("FrontFoot.L")
	if foot >= 0:
		await _advance_with_ticks(player, 1.5)
		skeleton.force_update_all_bone_transforms()
		var first_pose := skeleton.to_global(skeleton.get_bone_global_pose(foot).origin)
		await _advance_with_ticks(player, 0.25)
		skeleton.force_update_all_bone_transforms()
		var second_pose := skeleton.to_global(skeleton.get_bone_global_pose(foot).origin)
		if first_pose.distance_to(second_pose) < 0.05:
			failures.append(
				"%s feet are frozen after 1.5s (delta %.4f); Walk should still cycle."
				% [label, first_pose.distance_to(second_pose)]
			)
	else:
		await _advance_with_ticks(player, animation.length + 0.1)
	await process_frame
	if not player.is_playing():
		failures.append("%s stopped after clip length; Walk should still be playing." % label)
	elif AnimationHints.clip_leaf(player.current_animation) != "Walk":
		failures.append(
			"%s after clip length is '%s', expected Walk."
			% [label, player.current_animation]
		)
	horse.free()


func _test_human_walk_keeps_playing(
	human_look: PackedScene,
	label: String,
	failures: PackedStringArray
) -> void:
	var human := HUMAN_SCENE.instantiate() as Node3D
	root.add_child(human)
	human.apply_appearance({ModelCatalog.HUMAN_KEY: human_look})
	human.play_walk()
	await process_frame
	var player := _find_animation_player(human)
	if player == null:
		failures.append("%s missing AnimationPlayer." % label)
		human.free()
		return
	if not player.is_playing():
		failures.append("%s should play Man_Walk after play_walk()." % label)
		human.free()
		return
	var clip := player.current_animation
	var leaf := AnimationHints.clip_leaf(clip)
	if leaf != "Man_Walk":
		failures.append("%s current clip leaf is '%s', expected Man_Walk." % [label, leaf])
		human.free()
		return
	var skeleton := _find_skeleton(human)
	var foot := -1
	if skeleton:
		foot = skeleton.find_bone("Foot.L")
	if foot < 0:
		failures.append("%s missing Foot.L; Kenney Man walk should move that bone." % label)
	else:
		await _advance_with_ticks(player, 0.4)
		skeleton.force_update_all_bone_transforms()
		var first_pose := skeleton.to_global(skeleton.get_bone_global_pose(foot).origin)
		await _advance_with_ticks(player, 0.25)
		skeleton.force_update_all_bone_transforms()
		var second_pose := skeleton.to_global(skeleton.get_bone_global_pose(foot).origin)
		if first_pose.distance_to(second_pose) < 0.05:
			failures.append(
				"%s feet are frozen (delta %.4f); Man_Walk should cycle Foot.L."
				% [label, first_pose.distance_to(second_pose)]
			)
	await process_frame
	if not player.is_playing():
		failures.append("%s stopped after play_walk(); Man_Walk should still be playing." % label)
	elif AnimationHints.clip_leaf(player.current_animation) != "Man_Walk":
		failures.append(
			"%s after walk is '%s', expected Man_Walk."
			% [label, player.current_animation]
		)
	human.free()


func _find_skeleton(root_node: Node) -> Skeleton3D:
	if root_node == null:
		return null
	if root_node is Skeleton3D:
		return root_node
	for child in root_node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null


func _find_animation_player(root_node: Node) -> AnimationPlayer:
	var players: Array[AnimationPlayer] = []
	_collect_animation_players(root_node, players)
	for player in players:
		if player.is_playing():
			return player
	if players.is_empty():
		return null
	return players[0]


func _collect_animation_players(root_node: Node, players: Array[AnimationPlayer]) -> void:
	if root_node == null:
		return
	if root_node is AnimationPlayer:
		players.append(root_node)
	for child in root_node.get_children():
		_collect_animation_players(child, players)
