# Peephole shows the presented face, not the true body

The peephole is a separate clone in `PeepholeStage`, not a zoom of the gate subject. If it reused the encounter scene, Centaur kinds would leak silhouette through the hole (horse body scale, Horse Centaur mask rotation) even when the player should only see a Human or Horse face.

We map each encounter to a Human or Horse stand-in scene via `SubjectDef.presented_face_type`: Horse and Horse Centaur use the Horse stand-in; Human, Centaur, and Human Centaur use the Human stand-in. The same rolled `Appearance` dict is passed through so the Punk face on a Centaur matches at the gate and in the hole. Peephole pose tuning reads and saves the stand-in SubjectDef (`human_01` / `horse_01`), not the encounter's Centaur def, so framing does not betray the true type.
