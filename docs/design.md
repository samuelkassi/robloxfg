# Design reference

Repo copy of the design doc, kept for Claude Code. The full doc on claude.ai is the master. When a design decision changes, update it there, then refresh this file.

Values marked *(start)* are first-pass numbers to tune in playtesting. Keep them in data or named constants, never hard-coded inline.

## The game

A competitive 3D fighter on Roblox in the style of older Tekken. Launch target is March 2027, with 5 fighters, ranked 1v1, training and vs CPU. It earns money from cosmetics only, then runs as a live game with balance patches and new fighters.

Four pillars decide every trade-off:

- **Real fighting-game depth.** Motion inputs, high/mid/low mixups, throws, meter, honest frame data.
- **Plays everywhere.** The same inputs on keyboard, controller and touch, with no simplified scheme. PC and controller come first; mobile performance and 30 fps support follow.
- **Fair forever.** Every fighter is earnable by playing. Money only buys looks.
- **Built to grow.** Fighters are data plus animations, so adding one is content work, not engine work.

## Design direction

Older Tekken (3, Tag, 4, 5, and to a lesser extent 6, Tag 2, 7) sets the length and speed of interactions. The fight is built on poking, movement, punishing and fair frame data.

Rewards:

- Short, fast interactions: whiff punishing, spacing, reading movement.
- Strong execution, including just-frame enhanced moves (Electric Wind God Fist style).
- Game knowledge: frame data, punishes, matchup counterplay.

Avoids:

- Long blockstun and very plus-on-block moves, because they create easy forced 50/50s.
- Universal mechanics that make every character play the same (such as Tekken 8's Heat Smash).
- Gimmicky characters. Stances are very rare, with at most one stance fighter.
- Cutscene moves. Supers and throws play out in real time with no cinematic camera.
- Long juggles. No bound system; aerial combos are short, close to Tekken 5.

## Notation

- Buttons: **1** left punch, **2** right punch, **3** left kick, **4** right kick.
- Directions use numpad notation relative to the fighter's facing: 6 forward, 4 back, 2 down, 8 up, 3 down-forward, 1 down-back, 9 up-forward, 7 up-back, 5 neutral.
- `236` is quarter-circle forward, `214` quarter-circle back, `623` dragon punch, `41236` half-circle back. `1+2` means both buttons on the same frame. `1, 2, 4` is a string of presses chained on timing.

## Simulation (engine rules)

1. Each device turns raw input into **one bitmask per frame**: 4 direction bits plus buttons 1–4. Each input carries its frame number.
2. The simulation steps at a **fixed 60 Hz**, independent of render frame rate.
3. The motion parser reads input history and picks the matching move.
4. Each fighter is a **state machine**: idle, walk, dash, backdash, sidestep, sidewalk, crouch, jump, attack, hitstun, blockstun, thrown, knockdown, wakeup.
5. Hitboxes and hurtboxes are simple shapes checked in code each frame. Never Roblox physics, `Touched` events or `Humanoid` movement.
6. Rendering and animation follow the simulation and never drive it. A cancel cuts the animation instantly.

**Determinism:** no random values, no wall-clock reads, and no physics inside the simulation; fighters update in a fixed order. This keeps rollback netcode possible.

## Input handling

- Inputs are read once per simulation frame and stored as a short history.
- The motion parser allows slack between directions *(start: 8 frames)*, so motions work on a virtual stick and d-pad as well as a keyboard.
- An input buffer holds a button press *(start: 5 frames)* so a move comes out as soon as recovery ends.
- When several moves match, the most complex wins: super over special over normal.
- **Just-frame inputs:** the window varies per move, down to 1 frame for the biggest rewards. A missed just-frame always gives the regular version of the move. Training mode reports early, late or on the frame.

## Movement

- Walk forward and back. Dash = `6, 6`. Backdash = `4, 4`. Crouch = hold 2.
- **Sidestep:** tap 8 steps into the background, tap 2 steps out. Linear moves miss a sidestepping opponent; homing moves track them.
- **Sidewalk:** tap then hold 8 or 2 to keep circling. Slower than a sidestep, sustained, and can be stopped or cancelled at any point.
- **Jump:** hold 8 from neutral. Weak, mainly for evading lows. *Telling jump apart from sidestep and sidewalk is a parser detail to settle when building it.*
- **Movement cancelling:** dashes, backdashes, sidesteps and sidewalks can cancel into other movement before they finish.
  - Korean backdash: `4, 4, 1, 4, 4, 1…`, cancelling each backdash with down-back.
  - Sidestep cancelling: sidestep into backdash, crouch, another sidestep or sidewalk.
- Each movement state lists its cancel windows as data: from which frame it can switch into which states.
- Crouch dash and wavedash exist only for select fighters.
- The camera stays side-on and rotates to keep both fighters on screen after a sidestep.

## Defence

- Hold 4 blocks standing (highs and mids). Hold 1 blocks crouching (lows). Highs whiff over a crouching fighter.
- **Neutral guard** (no direction) blocks highs only. Unlike Tekken, you must hold back to block mids.
- Mids beat crouching block; lows beat standing block.
- **Low parry:** universal. Success knocks the opponent up for a small guaranteed follow-up.

## Throws

| Throw | Break |
| --- | --- |
| 1+3 | 1 |
| 2+4 | 2 |
| 1+2-break throw (input per fighter) | 1+2 |

- Break window *(start: 14 frames)*. Throws can't be blocked, only broken, ducked or stepped.
- Only grapplers get more throws, such as command throws.
- **Optional throw button:** performs a 1 or 2 throw. A throw done with the shortcut can be broken with either 1 or 2; a manual-input throw needs the matching break. The 1+2-break throw always needs 1+2. The defender can't tell which method was used.

## Hits, counters and juggles

- Hitting during the opponent's startup is a **counter hit**: extra damage and extra hitstun.
- Specific moves crumple or launch on counter hit (a per-move property).
- Juggles are short: heavy damage scaling plus gravity that increases with each hit. No bound system, no hard cap.
- **Walls:** a wall hit gives a short splat with 1 or 2 guaranteed hits, never an extended wall combo. Stages are a mix of infinite and walled, with no stage interactions.
- **Ground game:** the full old-Tekken knockdown game: tech rolls, back and side rolls, staying down, wakeup kicks, ground hits, tech traps.

## Punishers

- Standard punish speeds: 10, 12, 13 and 15 frames, plus a launch punisher. Every fighter has some or all of them, at different strengths.
- Fighters with weaker combo damage get better fast punishes.

## Super meter

3 bars, carried between rounds. Meter builds from landing hits, having attacks blocked, and taking damage. It is the only comeback mechanic.

| Level | Cost | Unscaled damage *(start)* | Input *(start)* |
| --- | --- | --- | --- |
| 1 | 1 bar | 20% | 236236 + 1+2 |
| 2 | 2 bars | 35% | 214214 + 1+2 |
| 3 | 3 bars | 50% | 236236 + 3+4 |

- Damage per bar falls as the level rises, so spending early is most efficient. Combo scaling applies to supers.
- Super values are per-fighter data.
- Open question: whether meter also buys enhanced specials.

## Move data

Every move is data, never code. Each move defines at least:

- Input (motion, buttons, and just-frame window if any)
- Startup, active and recovery frames
- Frame advantage on hit, on block and on counter hit
- Hit level: high, mid, low, or throw
- Damage, and whether it is linear or homing
- Hitbox shapes per active frame
- Cancel windows and string follow-ups
- Counter-hit properties: crumple, launch, extra stun

Fighters launch with about 30 moves and grow toward 50 in patches. Basic tools such as the standard jab and a generic low kick are shared or near-identical across fighters.

## Controls by platform

Every platform feeds the same input parser; only the device layer differs.

| Platform | Directions | Buttons 1 / 2 / 3 / 4 |
| --- | --- | --- |
| PC keyboard | WASD *(default)* | U / I / J / K *(default)* |
| Controller | Left stick or d-pad | Face buttons, Tekken layout |
| Mobile A | Virtual analogue stick | Four on-screen buttons |
| Mobile B | On-screen 8-way d-pad | Four on-screen buttons |

Keyboard and controller are fully rebindable. Every mobile button can be moved and resized, saved per player. Mobile gets full motion inputs with no shortcut button. Training mode has an input display.

## Modes and match structure

- Launch modes: ranked 1v1, training, vs CPU.
- A match is best of 5 rounds (first to 3) with a round timer *(start: 60 seconds)*. A timeout goes to the fighter with more health.
- Rounds should feel medium length, as in Tekken 5.
- Training: frame data on hit and block, input display, hitbox view, dummy settings (block, record and playback), position reset.

## Roster (internal only)

Inspirations never appear in game code, assets, names or marketing. Every fighter gets an original name and design; use neutral IDs (`fighter1`…`fighter5`) in code until names are chosen.

| Slot | Inspired by | Archetype | Access |
| --- | --- | --- | --- |
| 1 | Jin Kazama (Tekken 4–6 karate) | All-rounder | Starter |
| 2 | Ippo, with older Steve's bob, weave and peekaboo stances | Rushdown; the only stance fighter | Starter |
| 3 | Aizen | Zoner | Starter |
| 4 | Zangief | Grappler | Starter |
| 5 | Heihachi (Mishima style) | High risk/reward, execution-heavy: just-frames, crouch dash | Unlocked |

## Online and data

- **Matchmaking:** a queue in MemoryStoreService, matching by rating and region.
- **Matches:** each runs on its own reserved server, reached with TeleportService.
- **Netcode:** prototype server-authoritative with input delay over real servers in November, then decide between that and custom rollback by 30 November.
- **Player data:** rank, currency, unlocks and cosmetics, saved with ProfileStore on DataStores.
- **Ranked:** hidden MMR (such as Glicko-2) with visible tiers and placement matches.
- **Security:** the server owns match results, currency and unlocks. Clients send inputs only. Validate everything from the client.
- **Monetisation:** cosmetics only. Cosmetics never change a hurtbox or hit readability.

## Roadmap

| Month | Phase | Gate |
| --- | --- | --- |
| Nov 2026 | Foundation: fixed 60 Hz loop, input capture, two placeholder fighters, motion parser, first move data, netcode test over real servers | Netcode approach decided by 30 Nov |
| Dec 2026 | Core combat: hitboxes, high/mid/low blocking, sidestep, throws and breaks, super meter; move-data format locked; one greybox fighter playable end to end | Combat systems complete |
| Jan 2027 | Fighter 1 at launch quality; training mode; basic vs CPU; all three control layouts | Fighter 1 feels right with real players |
| Feb 2027 | Fighters 2–5; ranked with MMR and tiers; currency, challenges, unlocks, first cosmetics | Feature freeze 21 Feb |
| Mar 2027 | Closed beta, balance, exploit and load testing, then public launch | Ranked stable under beta load |

### November build order

Each step is small and testable on its own:

1. Fixed 60 Hz simulation loop with a frame counter.
2. Input capture into the per-frame bitmask (keyboard and controller).
3. Two grey-box fighters walking forward and back, facing each other, driven only by the simulation.
4. Input history and motion parser (236, 623, dashes and so on).
5. First move-data format with one jab that hits on the right frame.
6. Two-player netcode test: Studio multi-client, then real servers.
