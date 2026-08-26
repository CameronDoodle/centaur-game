# Centaur Game

A security-gate game where the player inspects attendants and decides whether to let them into a horse racing/rodeo event.

## Language

**Subject**:
An attendant at the gate — one of human, horse, or centaur — represented by a 3D scene and a SubjectDef resource.
_Avoid_: Character, NPC, entity

**Appearance**:
The randomized visual look assigned to a Subject for an encounter. A Centaur’s Appearance combines a human look and a horse look.
_Avoid_: Skin, model

**Face**:
A marker on a subject scene that names where the attendant's face should be framed for camera views.
_Avoid_: Head bone, look target

**Gate**:
The main gameplay view from the security booth, showing the closed door and the full subject standing behind it.
_Avoid_: Main camera, world view

**Peephole**:
A close-up fisheye view through the door hole, using a separate stage and per-subject pose tuning.
_Avoid_: Zoom, close-up camera
