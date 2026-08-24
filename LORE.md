# LORE.md

## Premise

You are security at a horse racing/rodeo event where centaurs are strictly banned.

Attendants arrive one at a time at a security gate. Every attendant is one of three types:

- **Human** — allowed
- **Horse** — allowed
- **Centaur** — banned

Centaurs are actively trying to disguise themselves and sneak into the event.

The player's job is to determine what is on the other side of the gate and decide whether to let them in.

## Core Interaction

Each attendant approaches the gate and gives the player several pieces of information.

### 1. Approach Sounds

Before the attendant reaches the gate, the player hears how they are moving.

Possible clues include:

- Human footsteps
- Horse hoofsteps

This is the player's first hint.

### 2. The Knock

The attendant knocks on the gate.

Possible knocks include:

- Human hand knock
- Horse hoof knock

This is the second hint.

### 3. Investigation

Before making a decision, the player can gather additional information using a small set of actions.

Examples:

- **Peephole** — the gate camera zooms to the door hole, then a fisheye close-up frames the attendant's face from the **full figure** standing behind the door (legs are off-screen from lens placement, not a separate head mesh).
- **Ask questions** — each subject has authored question buttons; subtitles always show, with optional voice lines when audio exists.

The exact available actions and information can expand as the game develops.

### 4. Decision

After the knock, the player chooses **Accept** or **Reject**. They never label the attendant Human, Horse, or Centaur directly.

- **Accept** — let them in (correct for Human or Horse).
- **Reject** — turn them away (correct for Centaur).

Score +1 for a correct Accept or Reject. A strike is Accepting a Centaur or Rejecting a Human/Horse.

Each shift runs on **one timer** for the whole list of attendants; it does not reset between subjects.

## Disguises

Centaurs can disguise themselves as the allowed types.

Examples:

### Centaur pretending to be Human

A centaur may:

- Wear pants to hide their horse body.
- Wear shoes to conceal hoof sounds.
- Knock with a hand.
- Present a human-looking head.
- Give a human name.
- Attempt to behave like a human.

### Centaur pretending to be Horse

A centaur may:

- Wear a horse mask.
- Make neighing sounds.
- Knock with a hoof.
- Attempt to behave like a horse.

## Tone

The game should be lighthearted and absurd.

The central joke is that centaurs are trying increasingly ridiculous ways to pass as horses or humans, while the player is taking the security job completely seriously.

The world does not need extensive lore. The important fact is simply:

**Centaurs are banned from horse racing/rodeo events, and they want in.**

## Visual Direction

Use a simple, low-poly 3D presentation.

The security gate should be the primary gameplay space. The player should have a clear view of the gate/attendant and a small number of readable interaction elements.

Visual information should be immediately understandable:

- Human
- Horse
- Centaur
- Clothing/disguises
- Head/face
- Relevant props

## Gameplay Goal

The player should process information quickly and accurately.

The game should create tension through:

- Increasingly deceptive centaur disguises
- Limited time / pressure to process attendants
- Multiple imperfect clues
- The need to decide when enough evidence has been gathered

The player should never need to memorize a large amount of lore. The challenge comes from noticing and interpreting the clues presented during each interaction.
