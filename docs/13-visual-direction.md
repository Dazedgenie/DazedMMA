# Local fight night — visual sample

## Direction

The user selected concept B's gritty local event, lighting and camera with concept C's broader,
angular low-poly fighters. Desktop is the primary target; browser support is secondary. Explore a
lower, closer three-quarter camera, and include restrained blood, cuts and bruising. Existing visual
placeholders may be replaced. This refines D80 and the art pipeline in `04-tech-and-production.md` §3.

The generated concepts are art direction, not screenshots or finished game assets. The target is a
small community-hall event: bright worn canvas, dark cool surroundings, local banners, modest
spectator seating, corner equipment and visible ringside staff. Fighter identity comes from shape,
skin, hair and gear; red/blue identify equipment and corners rather than skin.

## First playable pass

- `game/local_venue.gd`: procedural octagon, matte canvas, painted branding, chain-link shader,
  padded posts, a small hall, seating, spectators, judges' table and corner equipment. Camera-facing
  panels are cut away above the ankle rail so cage action remains visible. Decoration uses its own
  seeded random generator, and repeated geometry is batched by mesh and material.
- `game/arena_view.gd`: 40° perspective camera lowered to about 28°; closer standing, clinch and ground
  framing. Standing zoom widens with fighter separation. The camera follows the exchange more
  closely. Simulation positions, collision boundaries and ground-position layouts are unchanged.
- `game/fight_mesh.gd`, `game/fighter_figure.gd`: faceted torso, head, limbs, hair, shorts and gloves,
  with articulated elbows on the existing move poses. Two temporary appearance presets are used
  for the red and blue corners. They are not yet persistent fighter customisation. Facial bruising
  and a small eyebrow cut become visible as existing head damage increases; these are cosmetic
  cues, not a new cut/injury mechanic. Hits have a small visual reaction.
- `ui/fight_theme.gd`, `ui/fight_hud.gd`: restrained broadcast panels, condensed button typography,
  a smaller damage display, and a shorter/narrower feed that leaves more of the cage visible.
  Existing calls, controls, damage readouts, ground diagram and explanations remain available.

The sample uses Godot's Compatibility renderer, shadowed key lighting and a few local lights. It
does not depend on desktop-only post-processing or new paid assets. Materials and meshes are
authored in the project; no subscription-generated models or external asset licences are required.

## Character refinement

The follow-up character pass keeps the low-poly direction and the existing fight poses. It replaces
the straight torso and head profiles with authored contours in `game/fighter_sculpt.gd`: chest and
sternum, tapered abdomen, shoulders, cheeks, jaw, ears, nose and a shaped hairline. The heavier
temporary appearance has a wider chest, thicker limbs, squarer jaw and fuller beard; the lighter
appearance has a narrower frame and swept hair. Both are still corner-based preview looks.

Gloves now have wrist tape, shaped padding, separate exposed finger ends and a thumb, and follow
the forearm's direction. Shorts have a fitted waistband, narrow side seams and hem trim. Hidden
upper-thigh skin is omitted to prevent it poking through the shorts when the legs move. Feet have
ankles, forefeet and individual toe forms. The neutral guard brings the hands closer to the face;
idle support feet lie flat on the canvas and release when lifted for a kick.

The clinch's drawn body centres now have 0.82 m of separation to fit the leaning torsos, and the
neutral grip bends the elbows toward the opponent's shoulders. At the fence, both drawn positions
shift inward together if necessary. The simulation's positions, reach and collision rules remain
unchanged. Strikes, collar ties and submissions retain their own poses.

## Movement refinement

`game/fighter_motion.gd` plans support-foot steps in world space and solves the thigh and shin
separately. The stance sits lower with bent knees. A foot stays planted until the stance moves far
enough to need a step; one foot swings at a time, with a small lift and a landing position ahead of
the moving body. The hips shift slightly toward the support leg. Kicks release their leg from the
step planner and replant on returning to guard. Kneeling poses retain their folded shins and feet,
and the bottom fighter bends the knees in guard. Stepping and breathing follow fight speed and
stop while the driver is paused or held.

Strikes extend through windup and return toward the guard over recovery, using the simulation's
existing phase durations. Jabs and crosses turn the hips and shoulders. These are procedural
presentation improvements, not new movement, reach, collision or strike-resolution rules. The
existing action poses still supply the direction and extent of each move; paired grappling
animations and an authored production rig remain future work.

## Strikes that connect (D281)

A strike that lands touches the man in front, and a clean hit, a blocked one, a slipped or checked one and a
miss each look different. All of it reads the sim's state and events; nothing here changes a fight.

- **Drawn spacing** (`ArenaView.standing_spots`, `drawn_gap`). The sim's ranges are wider than a person's reach,
  so standing the view draws the gap at human scale: up to `DRAWN_FROM` (0.9 m) as it is, each metre more out to
  `DRAWN_UNTIL` (3 m) as `DRAWN_SHARE` (0.45) of a metre, then a metre a metre. Mid range (1.5–2.2 m) draws at about
  1.15–1.45 m. Whoever has more room off the fence moves, so a man pinned on the fence stays on it.
- **Stepping in** (`ArenaView.lunge_for`, `strike_spots`). A striker steps in to his strike's contact gap
  (`FighterFigure.AIMS[...].contact`), 60% over the telegraph, the rest over the windup, holds it through the active
  part and steps back over the recovery; at most `LUNGE_MAX` (0.75 m). Out of range in the sim he steps `SHORT_BY`
  (0.3 m) less, so it falls short. Two men stepping in together stop at the shorter strike's contact gap and never
  closer than `LUNGE_CLOSEST` (0.85 m).
- **Aiming** (`FighterFigure.AIMS`, `aim_point`). Each punch and kick aims at a point on the man (`strike_point`: head,
  lower ribs, thigh above the lead knee, or calf), offset to the side by `across` for hooks and round kicks, and
  stops `STANDOFF` short of its centre. The elbow or knee bends by `bend`: down for straight punches, out for hooks,
  under for uppercuts, turned over for round kicks, up for the teep.
- **Fixed arms.** `UPPER_ARM` 0.31 m and `FOREARM` 0.32 m, solved with `FighterMotion.solve_bones` like the legs.
  An arm never stretches; a punch that needs more reach gets it from the step in and the shoulder turn.
- **Outcomes** (`ArenaView._show_strike`, `FighterFigure.show_outcome`). Landed: the glove or shin meets the point.
  Into the guard (`covered`): a head shot lands on his nearer glove, a body or leg shot on his elbow. Missed (rolled
  out or slipped): it goes `MISS_PAST` (0.35 m) past and `MISS_THROUGH` (0.12 m) through, over his shoulder. Out of
  range: short. Checked: it meets his raised shin.
- **Hit reactions** (`FighterFigure.show_hit`). A clean hit snaps the part hit, scaled by damage (full at
  `HIT_FULL_DAMAGE`, 18): the head back `HIT_HEAD_SNAP` (0.42 rad) and turned `HIT_HEAD_TURN` (0.35 rad) by hooks and
  round kicks, the body folded `HIT_BODY_FOLD` (0.35 rad), the legs dipped `HIT_LEG_DIP` (7 cm), and he's knocked
  back up to `HIT_KNOCK` (0.14 m). It's over in `HIT_FADE` (0.3 s of fight time, so slow motion shows it slowly and
  pause freezes it). A blocked shot knocks his gloves back into his face instead. No camera shake.
- **Defence poses.** The check lifts and turns out the lead knee, the slip drops the head off the line to the
  outside, the cover-up puts the gloves to the temples with the elbows in.
- **Feet.** The support feet turn on the ball of the foot (`FOOT_BALL`, 9 cm in front of the foot's origin) by
  `FOOT_PIVOT` (35% of the hip turn for the lead foot, 80% for the rear), and the rear heel lifts `HEEL_LIFT`
  (0.6 rad per radian of turn, at most 0.45). Round kicks turn the hips over further than before (body kick 1.0 rad,
  head kick 1.1, leg kick 0.7).
- **The near fence** (`LocalVenue.show_near_fence`). The camera-side panels stay cut down to a rail, but a panel fades
  in, see-through (`NEAR_FENCE_ALPHA` 0.7), while a fighter is within `NEAR_FENCE_WITHIN` (1.2 m) of it.
- **Labels.** The move label, call label, delay ring, stars and the tell's "!" sit `LABEL_ABOVE_HEAD` (0.5 m) over
  his head wherever it is, standing or down, and the two move labels lean apart on screen when both are up.

Not covered yet: clinch knees, elbows and dirty boxing keep their poses (they don't step in), ground strikes aim the
fist at the head but nothing else, and grappling is untouched (paired poses wait for the rig, D280).

Arranged clips of every covered strike and outcome, side on to the camera, at fight time (24 frames a fight second):

```sh
godot --path . --script res://tools/strike_preview.gd -- --out=res://build/strikes
ffmpeg -framerate 24 -i build/strikes/frame-%04d.png -c:v libx264 -pix_fmt yuv420p build/strikes.mp4
```

Tests: `tests/game/test_strike_contact.gd`.

## Review and verification

Open `project.godot` in Godot 4.7.2 and run the game normally. Start a fight and check striking,
clinch, ground transitions and fighting against each side of the fence. Compare at 1280×720 and
1920×1080, keeping both fighters and all coaching controls readable.

Reproducible arranged camera samples, using the real game scene and HUD:

```sh
godot --path . --script res://tools/visual_preview.gd -- --out=res://build/visual
```

Add `--720p` to check a 1280×720 window. This requires a graphics display. It writes standing,
arena-only, striking, kicking, clinch, full-guard, side-control, mount and near-fence PNGs. The
preview arranges its own temporary fighters and never saves a fight. Close model review from the
front, three-quarter and back uses the same real character meshes in a neutral presentation scene:

```sh
godot --path . --script res://tools/character_preview.gd -- --out=res://build/characters
```

The motion preview records a real seeded Boxer–Kicker fight at 1× fight speed, with the HUD hidden
and a fixed 24 frames per fight second. It does not arrange actions or write a saved fight:

```sh
godot --path . --script res://tools/motion_preview.gd -- --out=res://build/motion --seconds=12
ffmpeg -framerate 24 -i build/motion/frame-%04d.png -c:v libx264 -pix_fmt yuv420p build/motion.mp4
```

Run the existing GUT suite
and the main-scene smoke check as described in the root README. The presentation-only regression
test compares a watched fight with the same seed run without a view. The stance check verifies
both feet meet the mat, a body kick can lift the kicking foot, and returning to guard plants it again.
Another check keeps the clinch's drawn bodies inside the fence without moving the simulation.
Motion checks cover planted support, pause during a step, kick release, advancing and retreating,
fixed bone lengths (including degenerate solver inputs), and strike extension/recovery.

## Remaining art work

This is a foundation for iteration, not a match to the concept. The current procedural fighters
still use the prototype pose system. A shared production rig, authored foot pivots, paired grappling
animations, better faces, persistent body variations and authored clothing are the next major
character work. The wider menus and training spaces need their own visual pass. Tripo can help
provide starting meshes, but anatomy, topology and rigging must be checked before replacing these
working figures. Validate the first complete character and its striking/grappling poses before
producing a roster.
