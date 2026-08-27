# Centaur Game

A security-gate game where the player inspects attendants and decides whether to let them into a horse racing/rodeo event.

## Language

**Subject**:
An attendant at the gate — one of Human, Horse, Centaur, Horse Centaur, or Human Centaur — represented by a 3D scene and a SubjectDef resource.
_Avoid_: Character, NPC, entity

**Centaur**:
A banned Subject: a horse body with a human torso and human head and neck, presenting as itself.
_Avoid_: Hybrid, chimera, True Centaur

**Human Centaur**:
A banned Subject: the same assembled look as a Centaur, but presenting as a Human through human footsteps, hand knock, and human-flavored speech.
_Avoid_: Centaur Human, disguise

**Horse Centaur**:
A banned Subject: the same horse-body and human-torso mix as a Centaur, but with a horse head and neck in place of the human head and neck.
_Avoid_: Disguise, masked centaur, Centaur Horse

**Appearance**:
The randomized visual look assigned to a Subject for an encounter. A Centaur, Human Centaur, or Horse Centaur Appearance combines a human look and a horse look; on a Horse Centaur the horse look is both the body and the grafted head.
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
