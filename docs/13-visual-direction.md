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
