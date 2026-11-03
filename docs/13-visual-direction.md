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
fist at the head (D282 adds the hammerfist, body punch and bomb), and grappling was untouched here (D282 below poses it).

Arranged clips of every covered strike and outcome, side on to the camera, at fight time (24 frames a fight second):

```sh
godot --path . --script res://tools/strike_preview.gd -- --out=res://build/strikes
ffmpeg -framerate 24 -i build/strikes/frame-%04d.png -c:v libx264 -pix_fmt yuv420p build/strikes.mp4
```

Tests: `tests/game/test_strike_contact.gd`.

## A pose for every grappling move (D282)

Every move in `data/actions/` now moves the figure when it's thrown; before this, 32 grappling moves showed only the
position's resting pose. These are quick poses on the current rigid figure (Kyle, 2026-10-31: "Yes, quick poses for all
now"), so every move reads in a playtest; the rig prototype (D280's order of work) can replace them later. Presentation
only: nothing here changes a fight.

- **Clinch grips you can see** (`FighterFigure._read_grips`, `grip_point`, `GRIP_HANDS`). The sim's two clinch sides
  (D261) are drawn on the hands: red's lead arm is on side 0 and meets the blue arm across from it (`grip_arm`). On a
  side where he has the inside, his hand is an **underhook**, under the other man's arm on his shoulder blade; where
  the other man has it, his arm is the **overhook**, over the top clamping the triceps, elbow high; with both he has
  the **body lock**, hands locked at the small of the back; with neither it's **hand fighting**, hands on the arms in
  front. Holding the collar tie puts both hands behind the head. A gripping hand eases to a new grip (`GRIP_EASE`)
  rather than jumping. A strike thrown from the clinch takes only its own arm off the grip, so a knee keeps the body
  lock and a short uppercut lets the rear hand go.
- **Chest to chest.** `ArenaView.CLINCH_BODY_GAP` came in from 0.82 m to 0.68 m so an underhook reaches round his back.
- **Grip moves.** The pummel swims the hand down under his arm and up inside to the underhook (`PUMMEL_DIP`, 14 cm);
  the strip goes to his elbow and shoves it out (`STRIP_PUSH`, 10 cm); the collar tie takes both hands up behind his
  head. Each dips the shoulder in with it. Driving to the fence puts the head in his chest and the hips low off the back
  foot; turning him and spinning off turn the hips the corner one way or the other.
- **Ground and pound.** The hammerfist cocks the rear fist up by the ear and drops it; the body punch leans down low
  into the ribs; the posture-up bomb kneels up tall out of the guard (`POSTURE_HIP`) with the hand cocked high, then
  drops it all. All three aim at the man underneath like the other strikes (`AIMS`). Underneath, covering up puts the
  forearms over the face (the cover-up now works lying down), and turning away rolls him onto his front about his
  spine (a new `roll` pose number, also used by the bridge, sweep and getting back to guard).
- **Submissions.** Each choke and arm lock has a pose for both men, used while going for it and while it's held: the
  guillotine's arm under the chin; the triangle's legs high round the head and arm; the armbar lying back with both
  legs across, his arm pulled straight; the rear-naked choke's arms round the neck with him fighting the hands; the
  arm-triangle's chest driving down with his arm pinned up. The leg locks sit back onto the leg as they go for it.
- **Everything else.** The bridge throws the hips up; escaping the back turns in; getting back to guard comes up on a
  hip with a knee in; the sweep kicks a leg up under him and rolls; the pass lifts the hips and cuts across; taking
  mount slides a knee over; taking the back swings round; the scramble turns the hips; following him down drops onto
  the knees; the foot sweep, hip throw, outside trip and guard pull each have their own shape.

Not covered: the two men still don't hold each other in the ground positions and submissions (each figure is posed on
its own), so legs and arms point the right way without wrapping; that's the rig's job.

Arranged clips of every grip, grappling move and submission, side on to the camera, at fight time:

```sh
godot --path . --script res://tools/grapple_preview.gd -- --out=res://build/grapples [--only=pummel,armbar]
ffmpeg -framerate 24 -i build/grapples/frame-%04d.png -c:v libx264 -pix_fmt yuv420p build/grapples.mp4
```

Tests: `tests/game/test_grapple_poses.gd` (the grips sit where they should, and every move in the library moves the
figure).

## The rig prototype (D283)

Today's figures pose each man on his own, so on the ground and in the clinch their limbs pass through each other.
The rig prototype is the step before paired grappling: a skeleton that can be posed against a second one.

**The skeleton** (`game/rig/fighter_rig.gd`, `FighterRig`) is built in code in today's faceted look. The pelvis
carries a waist joint 0.29 m up where the torso is cut (`FighterSculpt.torso(stocky, from, to)` keeps the rings
between two heights), so the chest bends forward, twists and side-bends over the hips. The neck and head nod and
turn. Arms (0.31 + 0.32 m) and legs (0.46 + 0.45 m) are two-bone chains solved like the fighters' legs
(`FighterMotion.solve_bones`): fixed lengths, the elbow or knee bent toward a pole, a target out of reach stopping
at full stretch.

**Points on a body.** Hands and feet go to named points on either man: `chest`, `sternum`, `back`, `blade_l/r`
(shoulder blades), `belly`, `lower_back`, `waist_l/r`, `hip_l/r`, `seat`, `neck`, `nape`, `head`,
`back_of_head`, `chin`, `shoulder_l/r`, `armpit_l/r`, a limb's middle (`thigh_l`, `shin_r`, `upper_l`, `fore_r`)
or a joint (`elbow_l`, `knee_r`, `wrist_l`, `ankle_r`). Each is a bone and an offset in that bone's frame
(`FighterRig.POINTS`), so the hand stays on his back when his back moves.

**Paired poses** (`game/rig/rig_pairs.gd`, `RigPairs`) are data in one frame for both men: the origin on the
canvas between them, red on the +Z side facing -Z, blue facing him (turn 180). A body is `root` (the pelvis),
`turn`, `lean` (forward +, -90 on his back), `roll`, `bend` [forward, twist, side] at the waist and `head` [nod,
turn], in degrees and metres. Each hand and foot is `{"to": "b.back", "off": [x, y, z]}` (a point on blue;
`a.` is red), `{"at": [x, y, z]}` (a place in the frame) or nothing (hands up, feet under the hips),
with an optional `pole` (where the elbow or knee points, in his pelvis frame) and `flat` (1 lays the foot on
the canvas). The prototype's set:

| Pose | Red | Blue |
| --- | --- | --- |
| Clinch (body lock) | arms under blue's, hands round his shoulder blades, head on his shoulder, hips back | overhooks on red's shoulder blades, head on the other side |
| Double leg | level changed, rear knee down, head on blue's ribs to the outside, hands behind his knees | tall, hands on red's back |
| Full guard | kneeling between his legs, hands on his belly | on his back, legs round red's waist with the ankles crossed behind his lower back, a hand on the back of red's neck and one on his arm |
| Sprawl | down on his knees, arms short at blue's hips | hips dropped on red's head, legs kicked back, chest over his back, one arm over his back and one under his arm |
| Getting up | sitting back on a hand posted behind, the other framing, one foot planted and the other leg out at blue | waiting a step away |

`FighterRig.pose_pair(a, b, pose, frame, to, t)` places both bodies, then solves the limbs twice (so a hand on his
arm finds the arm where it ended up). With `to` and `t` it blends: the body numbers are mixed, and each hand and
foot target is mixed in the world, so a hand on him stays on him through the move. The clips: standing to the
clinch, shooting the double leg and finishing it into the guard, shooting into a sprawl, and getting up.

**A skinned body later.** A single mesh that bends at the joints (for example an auto-rigged Tripo or Mixamo
body) will look better than separate faceted pieces. The rig is the part that body still needs: what moves the
bones so two men fit together. `FighterRig.HUMANOID` maps each joint to the bone names of Godot's standard
humanoid skeleton (`Hips`, `Chest`, `Neck`, `Head`, `LeftUpperArm`, `LeftLowerArm`, `LeftHand`, `LeftUpperLeg`,
`LeftLowerLeg`, `LeftFoot` and the right side's), and `bone_transforms()` gives each one's place and turn, so the
same poses can drive an imported body's skeleton.

**Not yet:** the rig isn't in the fight screen; poses are hand-placed with no physics; no grip, ground or
submission position past these five; the hands are mitts with no fingers. Next: drive a skinned humanoid body
with the same poses, then replace the fight view's grappling positions one at a time.

Preview, side on in the real venue (the clinch and the full guard are first shown as today's figures draw them);
`--stills` writes one picture per pose, `--angle=80` turns the camera round the pair:

```sh
godot --path . --script res://tools/rig_preview.gd -- --out=res://build/rig [--stills] [--angle=80]
ffmpeg -framerate 24 -i build/rig/frame-%04d.png -c:v libx264 -pix_fmt yuv420p build/rig.mp4
```

Tests: `tests/game/test_fighter_rig.gd` (bones keep their length in every pose and blend, every hand and foot gets
within 3 cm of its point, the bodies touch without passing through each other's core, the guard's ankles cross
behind his back, nothing goes through the canvas and standing feet stay on it, and every joint has a humanoid
bone name).

## A skinned body on the rig (D284)

The rig's faceted pieces can be swapped for a skinned, auto-rigged body: one mesh that bends at the joints. Kyle
made the first one in Tripo (image to model, Humanoid auto-rig with the Mixamo skeleton preset, just under 12,000
faces, exported as GLB); it lives at `game/bodies/tripo_fighter.glb` (until D285 it was kept in `tools/bodies/`,
out of the exported game). Tripo's colour texture came at 8192 × 8192 (7.4 MB, 256 MB
of video memory a body once loaded); it was scaled to 2048 × 2048 (1.6 MB file), which looks the same at fight
distance.

**How it follows the rig** (`game/rig/skinned_body.gd`, `SkinnedBody`):

- `load_body(path)` reads the glTF at run time and finds the Mixamo bones (`mixamorig_Hips`, `Spine`, `Spine1`,
  `Spine2`, `Neck`, `Head`, the shoulders, arms, forearms, hands, up legs, legs and feet). A Mixamo body faces
  +Z, so it is turned round, and it is scaled so its hip joints stand at the rig's pelvis height (0.92 m).
- `measure()` gives the body's sizes in metres (waist and neck heights, the head, the shoulder joints, the hip
  width, the four limb lengths, the ankle height) and `FighterRig.fit(sizes)` gives the rig those sizes, so the
  pose's contacts are worked out for this body. The torso's points stretch with it: across and front to back
  by the shoulders, up by the trunk. Feet placed on the canvas are lifted by the difference in ankle height.
- `follow(rig)` poses the body: the hips, the spine (Spine 35% and Spine1 70% of the way from the pelvis's turn
  to the chest's), Spine2, the neck and the head copy the rig's turns; the shoulders ride with Spine2. Each arm
  and leg is solved again in the body's own bone lengths (`FighterMotion.solve_bones`) toward the rig's wrist
  or ankle, bending the way the rig's elbow or knee bends. The hands carry on along the forearms; the feet copy
  the rig's feet.
- `set_colour(colour)` tints the light-grey shorts the corner's colour with a small shader: light, colourless
  texels take the tint, while skin, gloves, hair and the dark panels keep the texture's colours.

**Points on red and blue.** In a paired pose `a.` is always red and `b.` always blue, whichever man the spec is
for (until D284 a hand spec read `a.` as himself, which sent blue's hands round his own back).

**Limits:** the body's arms (0.27 + 0.25 m) are shorter than the faceted rig's (0.31 + 0.32 m, with the glove),
so in the clinch and the double leg a hand can stop up to 5 cm short, on his skin; the hands are open (the
Mixamo fingers aren't curled into fists yet); the body is smooth-shaded, not faceted like the venue; one body
and one face for both corners. The fight screen still uses today's figures.

Preview with the body on the rigs (`--body`, or `--body=<file.glb>` for another Mixamo-rigged body):

```sh
godot --path . --script res://tools/rig_preview.gd -- --out=res://build/body --body [--stills] [--angle=80]
```

Tests: `tests/game/test_skinned_body.gd` (the body stands at the rig's height and measures like a man, its hands
and feet are where the rig's are in every pose, the fitted rig still reaches every contact within 5 cm, the
body's bones keep their length, the shorts take the corner's colour).

The preview tools start a throwaway fight from the title screen (D302); a fight now hides every menu screen when
it starts, so the arranged clips show the fight, not the title.

## The fight screen draws the skinned body (D285)

Both fighters in the fight are now drawn with the Tripo body (`game/bodies/tripo_fighter.glb`, imported with the
game and exported with it). The first step copies today's figures: the faceted pieces still pose every frame
exactly as before (strikes aim and land, hit reactions, grips, ground positions, the scouted tell), but they
aren't drawn; the body follows their joints. Every strike, move and position already in the game shows on the
body at once. The rig's paired poses (D283) take over the clinch and ground positions one at a time later.

**How** (`FighterFigure.use_body`, `FighterFigure.body_pose`, `SkinnedBody.follow_joints`):

- `ArenaView.BODY` names the body the fight draws (`""` draws the faceted pieces as before). Each figure loads
  it, tints its shorts the corner's colour and hides its pieces from every camera and light (render layers 0),
  except the scouted tell's glow.
- The pieces are taller in the trunk than the body (shoulders 1.52 m against 1.39 m when both stand with hips
  at 0.92 m), so the body is scaled by **shoulder height** to match. Each frame its hips then move along with
  the pieces' hips so its shoulders sit where the pieces' shoulders are; its longer legs take up the gap.
- The arms and legs are solved in the body's own lengths toward the pieces' gloves and ankles, bending where
  the pieces' elbows and knees bend. The feet are lifted by the difference in ankle height (`BODY_ANKLE_UP`
  0.097 m for the pieces, against the body's own), so the soles stay on the canvas.
- **A long punch throws the shoulder.** The body's arms are a little shorter than the pieces'. A bent arm keeps
  the pieces' bend (the hand goes the same share of the arm's length toward the glove); from 85% straight
  (`STRAIGHT_FROM`) the hand starts reaching for the glove itself and from 96% (`STRAIGHT_AT`) goes all the way.
  When the glove is then out of reach the shoulder blade turns toward it (up to `SHOULDER_REACH`, 0.5 rad) to
  make up the gap, as a man does when he extends a punch; a landed jab touches the face.
- **Each bone starts from its parent** (`SkinnedBody._anchored`, D379). The trunk's bones, the shoulder blades and
  the start of each arm and leg are placed at their rest spot on their parent bone as it's posed now, never read
  back from where they were last frame. Reading them back let a stale position carry a bone a little further each
  frame: by the end of a long fight an arm could hang metres from its shoulder, drawn as a long tube across the
  cage, and the hips were dragged half way after it (found filming D375 in Dirty boxer v Muay Thai, seed 35001).
- **Fists.** The fingers curl into a gloved fist when the body loads (`FIST_CURL` 1.35 rad a joint, the thumb
  about half as far). Mixamo's left-hand finger bones are mirrored, so they bend the other way round; each
  thumb folds about its own axis (`THUMB_AXIS`, found by search).

**To change:** `ArenaView.BODY` (another Mixamo-rigged GLB under `game/`, or `""` for the pieces);
`SkinnedBody.FIST_CURL`, `THUMB_AXIS`, `SHOULDER_REACH`, `STRAIGHT_FROM`, `STRAIGHT_AT`;
`FighterFigure.BODY_ANKLE_UP`.

**Limits:** the ground positions, clinch and grips are still today's piece layouts, so where the pieces
touched (a hand on a head, legs round a waist) the body can sit a few centimetres off or into the other man
until the paired poses replace them. Today's clinch holds the gloves out wide beside the other man's back, which
the slimmer body shows more plainly; the rig's body lock (D283) is the first position to replace. One body and
one face for both corners; smooth-shaded, not faceted.

Tests: `tests/game/test_fight_body.gd` (the fight draws the body and hides the pieces but not the tell, the
shoulders sit where the pieces' do, the hands go where the gloves do in guard, the jab, the hook and the clinch
within 4 cm, standing feet are under the pieces' feet with the toes on the mat, an arm knocked off its shoulder
put back on the next pose without dragging the hips).

## The clinch from the rig, a pose for each grip (D286)

The second step of Kyle's route (D285: copy today's figures first, then the rig position by position): the
standing clinch is posed by the rig (D283) from what the fight says each man holds, and the Tripo bodies follow
it. Kyle picked a pose for each grip (2026-10-31) over one body lock for every clinch.

**The poses** (`game/rig/clinch_pair.gd`, `ClinchPair`). `ClinchPair.build(grips, red_sides, collar, held)`
reads the sim's grips (who has the inside on each side, D261), the collar tie (D129) and who is held on the
fence (D220) and returns a pair pose like `RigPairs`:

- **Body** by the kind of clinch: *tied up* (chest to chest, heads on each other's shoulder, hips back), *body
  lock* (the man with both underhooks a little lower, hips in, the other taller over him), *collar tie* (the
  holder stands tall, the other is bent over with his head pulled down) and *held on the fence* (the held man
  upright with his back to it, the other driving in low with his head in his chest). The collar tie comes
  first, then the fence, then the body lock. Heads go to the side of the driving man's underhook; the pose is
  mirrored for the other side.
- **Hands** by each man's grip on each side: *under* round his back to the shoulder blade, *over* clamping his
  arm above the elbow, *lock* both hands locked at the small of his back, *collar* behind his head, *frame* (the
  man in the collar tie) on the holder's chest, and with no grip on that side *hand fighting* on his biceps.
- The pose is written for the man driving it (collar holder, the man holding him on the fence, the body lock,
  else red); when that is blue, the men's roles are swapped and the frame turned half round (`ClinchPair.swap`,
  `ClinchPair.pose`).

**In the fight** (`ArenaView._pose_clinch`). With bodies, the view keeps two hidden rigs fitted to them. In the
clinch (not in a submission hold) while each man is holding or fighting for grips (`CLINCH_POSE_MOVES`: no move,
the pummel, the strip, the collar tie) or striking from it (`CLINCH_STRIKES`: the knee, the short hook and
uppercut, the elbow), the pair is posed from the grips in a frame between the two men, its +Z toward red, and
the bodies follow the rigs. A strike moves only the striking arm or leg, from today's figure; the rest holds the
grip. Any other move (driving him to the fence, turning him, spinning off, breaking away, a takedown or throw) is
drawn from today's figures as in D285. Going into or out of the rig's clinch, a new grip, or a strike starting
or ending eases over `CLINCH_EASE` (0.25 s) instead of jumping (`SkinnedBody.ease_over` and `settle`: each bone
part way from last frame's pose to the new one). In five fights each of the Wrestler against the Boxer and the
Muay Thai fighter against the Boxer, the rig poses 63% and 78% of the clinch; the rest is takedowns, fence
drives and breaks.

**To change:** the poses in `ClinchPair.body` and `ClinchPair.hand` (root, lean, bend, head and feet as in
`RigPairs`; hand points and offsets as `FighterRig.POINTS`); which moves keep the pose in
`ArenaView.CLINCH_POSE_MOVES` and `CLINCH_STRIKES`; the easing in `ArenaView.CLINCH_EASE`.

**Limits:** the drive to the fence, turning him, spinning off and the clinch takedowns still use today's figures,
so their arms go wide again for a moment; the man at the fence is posed from where today's figures stand, not
pressed flat on the mesh; the overhooks and underhooks don't move while a pummel is under way (the pose changes,
easing, when the grip changes hands).

Preview: `tools/rig_preview.gd --clinch --body` (one picture per example in `ClinchPair.examples`); a real clinch
fight: `tools/motion_preview.gd --red=muay_thai --blue=wrestler --seed=35013`.

Tests: `tests/game/test_clinch_pair.gd` (every hand and foot reaches its place within 5 cm on rigs fitted to the
body, the bodies press together without passing through, each grip's hands are where it holds, the man on the
fence has his back to it with the other lower, the pose is the same whichever corner drives it, mirroring twice
changes nothing) and `tests/game/test_clinch_view.gd` (a body lock in the fight is drawn from the rig with the
hands round his back, each grip changes the pose, a knee keeps the hold and lifts only the knee, a takedown goes
back to today's figures and eases out, standing and on the ground the rig doesn't pose them).

## The fence from the rig (D287)

The third step of Kyle's route: the moves on the fence come off today's figures and onto the rig. Kyle picked
the fence next (2026-11-01, over the clinch takedowns or the ground positions), the held man *flat, fighting
when he moves* (over always flat or always fighting) and the fence that *gives and rattles* (over a rattle only
or neither).

**Held on the fence** (`ClinchPair.body("fence")`, `ArenaView.fence_frame`). While one man is held on the fence
(D220) the pair frame is squared to the fence panel behind him, so he is pressed flat on it: back, hips and back
of the head on the wire (`ClinchPair.FENCE_Z`, 0.5 m behind the frame's middle), feet a little out, the other
man in low with his head under his chin. The fence bows `ArenaView.PRESS_DEPTH` (3 cm) under him and he sinks
in with it.

**Fighting off it** (`ClinchPair._work`, `WORK_MOVES`). While the held man tries a spin-off, a turn or a clinch
break his hips come out (`WORK_HIPS_OUT`, the other man giving a little ground), he turns toward his way out
(`WORK_TURN`: to his underhook's side turning him, his overhook's side spinning off), looks that way and posts
the other hand on the wire (`POST_OUT`, `POST_UP`); breaking, both hands frame on the other man instead.

**The drive** (`ClinchPair.body("drive")`, `_step`). Setting up a drive (its windup) and while the fight drives
him back (`FightSim.drive`), the driver changes levels with his head in the other's chest and the other man is
upright, leaning back, giving ground. Both men step: each foot is planted and slides back as far as the pair
goes, then lifts (`STEP_LIFT`) and swings forward, the feet taking turns every `DRIVE_STRIDE` metres.

**The slam and the rattle.** When a drive ends with him pinned, or a turn puts the other man on the fence, the
fence bows further (up to `SLAM_DEPTH`, 9 cm, times how hard) and springs back (`SLAM_HZ`, `SLAM_DAMPING`) to his
weight on it, and `ArenaView.fence_slammed` plays the rattle (`StrikeSounds.play_rattle`): his back thudding into
the wire, the chain link clattering and dying away, a faint ring of the posts, made in code like the strike
sounds (`render_rattle`, three versions). A drive is as hard as how far it went (`DRIVE_SLAM_MIN` to full after
`SLAM_FULL_AFTER` metres); a turn is `TURN_SLAM`. The wire is a grid fine enough to bend (`LocalVenue.BOW_GRID`)
and the bow is drawn in the chain-link shaders (`bow_at`, `bow_depth`), held flat at the posts and rails.

**The turn** (`ClinchPair.turning`, `ArenaView.TURN_SECONDS`). When a turn or a spin-off works the fight swaps the
men's places at once; the view takes them round each other over 0.45 s, from the pose before to the one after
(after a spin-off, standing apart, `ClinchPair.apart`), then a spin-off eases back to today's figures.

**A clinch break** away from the fence: the man breaking frames on the other with both hands and pushes his hips
back (`BREAK_HIPS_BACK`) until they come apart.

**To change:** the poses in `ClinchPair.body` ("fence", "drive"), `_work`, `_break`, `apart` and the constants at
the top of `game/rig/clinch_pair.gd`; the turn, bow and slam numbers at the top of `game/arena_view.gd`; the
rattle in `StrikeSounds` (`RATTLE_*`, `RING_*`); `tools/strike_sounds.gd` writes it to
`build/strike_sounds/fence_rattle.wav`.

**Limits:** the clinch takedowns and throws still use today's figures (since D288 they don't); the drive's steps slide a little when the
fight's pace changes; the fence bows at one place at a time; only the drive and the turn rattle it (knees into a
man on the fence don't yet).

Preview: `tools/rig_preview.gd --clinch --body` (the new examples: the drive, the drive mid step, spinning off,
turning him, breaking off the fence, a break in the open); a real fence fight:
`tools/motion_preview.gd --red=dirty_boxer --blue=wrestler --seed=35024`.

Tests: `tests/game/test_clinch_pair.gd` (every example, the new ones too: hands and feet in place, bodies not
passing through) and `tests/game/test_fence_view.gd` (held on the fence he is flat on it and it bows, working off
it his hips come out and a hand posts on the wire, a drive steps them across and slams him in, a slam bows the
fence further then it springs back, a turn takes them round each other onto the fence, only the panel he is
against bows); `tests/game/test_strike_sounds.gd` (the rattle is the same every time, muting silences it).

## Clinch takedowns from the rig (D288)

The fourth step of Kyle's route: the takedowns in the clinch come off today's figures and onto the rig. Kyle
picked them after the fence (2026-11-01, before the ground positions), the fall *during the attempt*, a *thud,
bigger for the throws* and a *big hip throw, feet over the top*.

**A path of poses** (`game/rig/takedown_pair.gd`, `TakedownPair`). Each takedown is a path of paired poses from
the clinch pose it started in to the canvas, written like the clinch's with the man taking it down as "a":

| Move | Its keys after the clinch | Lands in |
|---|---|---|
| Double leg | the shot (level change, arms round the knees: `RigPairs.double_leg`), the drive through (blue tipping back, feet leaving the canvas) | his guard |
| Outside trip | the hook (red's leg round behind blue's), the tip (the leg reaped up, blue going back over it, a hand reaching for the canvas) | his guard |
| Hip throw | the load (turned in, hips under his, an arm round the waist and the other pulling his arm across), over the hip (blue lying across red's back), over the top (blue upside down beside him, feet in the air) | side control |
| Guard pull | the sit (red sits under blue, a foot on his hip, pulling his head down) | red's own guard, red underneath |

**When it falls** (`ArenaView.attempt_x`). Through the move's telegraph and wind-up the pair goes into the entry;
through its active part, while the fight has not decided yet, he is taken `fall` of the way toward the canvas
(`TakedownPair.TIMING`: half the way for a shot or a trip, a third for the hip throw, more for the guard pull).
When it works he goes the rest of the way in `land` seconds, quicker as he comes down. When it is stopped
(defended, a knee into the shot, pressed on the fence) the bodies ease back to the clinch over `STUFF_EASE`
(0.3 s), and the clinch is drawn from the rig while the shooter gets over it. When he is sprawled on he goes
down onto his knees under the sprawl (`RigPairs.sprawl`, `SPRAWL_SECONDS`) and stays there until his move is
over. A takedown that only half works lands them both on their knees, face to face (`TakedownPair.scramble`).

**Where it lands.** The landing is turned the way today's figures lay out the ground position it ends in
(`ArenaView.lay_out`, the man underneath across the screen), so when the takedown is done the bodies ease into
today's figures (`LAND_EASE`, 0.45 s) without turning round. It lands where the move puts him (`TIMING.at`: a
double leg or trip drives him back, the hip throw puts him on the far side of the man throwing him), and today's
figures carry on there (`_ground_shift`) until they are back on their feet. Near the fence each pose along the
way is moved in so neither man's head, back or hips goes through it (`_keep_off_fence`, `FENCE_GAP`): a double
leg off the fence lands him along it.

**The thud.** The landing plays `ArenaView.takedown_landed` → `StrikeSounds.play_thud`: a low thump of a body on
the mat (`THUD_HZ` falling to `THUD_LOW_HZ`, a smaller bounce after it) under the slap of the canvas, made in
code like the strike sounds (`render_thud`, three versions). How hard: the hip throw 1, the trip 0.8, the double
leg 0.7, a scramble 0.4, the guard pull 0.35 (`TIMING.thud`, `SCRAMBLE_THUD`); harder is louder and deeper.

Along the way `ClinchPair.half_turn` now turns a man whose pose doesn't say which way he faces (it left him facing
the wrong way round); no fight or clinch pose changes.

**To change:** the keys and `TIMING` in `game/rig/takedown_pair.gd`; the takedown numbers at the top of
`game/arena_view.gd` (`TAKEDOWN_EASE`, `STUFF_EASE`, `SPRAWL_SECONDS`, `LAND_EASE`, `FENCE_GAP`); the thud in
`StrikeSounds` (`THUD_*`); `tools/strike_sounds.gd` writes it to `build/strike_sounds/takedown_thud.wav`.

**Limits:** takedowns from standing (a double leg shot from range, the foot sweep, the catch-kick single) and the
ground positions themselves still used today's figures (they are posed from the rig since D289, and a takedown's
landing goes straight into the ground pose); the defender doesn't fight the attempt (a whizzer, a hand on the head) beyond the
sprawl.

Preview: `tools/rig_preview.gd --takedowns --body` (every key from the clinch to the landing, halves between for
the double leg and the hip throw, the scramble and the sprawl); real fights:
`tools/motion_preview.gd --red=judoka --blue=wrestler --seed=35000 --from=11.5` (a hip throw stuffed, then one
landing) and `--seed=35002 --from=9` (double legs landing and sprawled on). `--from=` is new: it plays the fight
up to there without saving frames.

Tests: `tests/game/test_takedown_pair.gd` (every key: hands and feet in place, bodies not passing through each
other, no one under the canvas) and `tests/game/test_takedown_view.gd` (a double leg starts falling during the
attempt and lands in his guard with a thud; the landing lines up with today's figures; a stuffed shot goes back to
the clinch; a sprawl puts the shooter on his knees until his move is over; the hip throw goes feet over the top
and lands him beyond the thrower; a half-worked takedown lands both on their knees; the guard pull puts the puller
underneath; turns go the short way round; off the fence he lands inside the cage);
`tests/game/test_strike_sounds.gd` (the thud is the same every time, low, and muting silences it).

## The ground positions from the rig (D289)

The fifth step of Kyle's route: the ground positions come off today's figures and onto the rig. Kyle said "We can
start the ground rig" (2026-11-01) and picked *all six positions held* in this step, *a pose for each grip*, *ease,
sweeps and bridges roll* between positions, and ground and pound with *the arm only, the bomb sits up*.

**A pose for each position** (`game/rig/ground_pair.gd`, `GroundPair`), written like the clinch's with the man on top
as "a" and the man underneath as "b", in a ground frame with its origin under the bottom man's hips and its +Z toward
his feet:

| Position | The man on top | The man underneath |
|---|---|---|
| Full guard | kneeling between his legs, hands on his belly (`RigPairs.full_guard`) | on his back, legs locked round the waist, hands on the forearms |
| Half guard | chest down on him, one leg trapped between his, the other posted out | on his back, legs locked round the trapped shin, a hand on the shoulder and one at the neck |
| Side control | across him on his side, an arm round the head, the other at the far hip (the hip throw lands here) | flat, a hand pushing the hip |
| Mount | sat on his hips, knees down by his ribs, hands on his chest | flat, hands on the hips, feet planted to bridge |
| The back | sat behind him, heels hooked inside his thighs, arms in a seat belt | sat up in front, hands on the top arm |
| Crucifix | across him from the head side, his near arm trapped between the legs | flat, the trapped arm pinned |

**Where it is drawn** (`ArenaView.ground_frame`). The frame is laid out the way today's figures lay the position out
(`lay_out`, D210): the bottom man across the screen where the sim has him (moved by `_ground_shift` after a takedown
that landed elsewhere, D288), the man on top on the side away from the camera in half guard, side control and the
crucifix (`GroundPair.build`'s `far` mirrors the pose). The frame is kept while the position lasts, so the pose doesn't
swing round when the sim nudges their spots. Landing from a clinch takedown goes straight into it.

**The grips** (`ArenaView.ground_grips_now` from the sim's ground grips, D263, D264). In the guard and half guard: his
wrists held (one or both of the bottom man's hands on them), the collar tie (both hands behind his head, his posture
broken: `COLLAR_LEAN`, `COLLAR_SINK`, `COLLAR_FORWARD`), and in half guard the underhook (the bottom man turned toward
him, `UNDERHOOK_ROLL`, an arm under his round his back) or the crossface (the top man's forearm across the face, the
head turned away). Under side control or mount: the frame (a forearm on his neck, or a hand on his chest in mount).
With the back taken: two hands on the choking arm. Covering up (`ground_cover`): both gloves in front of his face.
Posturing up (the move, or the bomb's wind-up) sits the top man up (`POSTURE_LEAN`, `POSTURE_RISE`) with his hands up
and tears the bottom man's grips off. A new position eases in over `GROUND_EASE` (0.4 s), a grip over `CLINCH_EASE`.

**Rolling over** (`GroundPair.roll_path`, `ArenaView._pose_roll`). A sweep, a bridge or getting out from under the
back (`GroundPair.ROLLS`) that works plays a roll over `ROLL_SECONDS` (0.6 s): from the pose before it, the man going
over tipped onto his side (`ROLL_SIDE`) as the other comes up, to the new position the other way round. A pass, a
mount, taking the back and the other moves ease from one pose to the next.

**Ground and pound** (`GroundPair.STRIKES`, `ArenaView.strike_blend`). The ground punch, hammerfist, elbow, body punch
and the bomb move only the striking arm in the rig: cocked by his ear (`COCKED`) over the first `COCK_SHARE` (65%) of
the telegraph and wind-up, down onto the man underneath (the head, or the belly for the body punch) through the rest
and its active part, leaning `STRIKE_LEAN` (14°) into it, and back over the recovery. The bomb sits him up first (his
posture through the wind-up), then comes down.

**What isn't posed as the position:** standing up and getting up (`GROUND_UNPOSED`) and the scramble were today's
figures until D368 posed them as moves of their own (§Scrambles, getting up and shots from range); a submission once
it is locked in and the leg locks were until D366.

**To change:** the poses, grips, `STRIKES`, `COCKED`, `STRIKE_LEAN` and the roll in `game/rig/ground_pair.gd`;
`GROUND_EASE`, `ROLL_SECONDS`, `COCK_SHARE` and `GROUND_UNPOSED` at the top of `game/arena_view.gd`.

**Limits:** passes, taking
the mount and the back ease between poses rather than stepping round; the knee on the ground (PRIDE) and the
up-kick keep the pose; the poses are tuned on the Tripo body and are hand-placed, with no physics.

Preview: `tools/rig_preview.gd --ground --body` (every position and grip, then a sweep in steps); a real fight:
`tools/motion_preview.gd --red=bjj --blue=wrestler --seed=35005 --from=5 --seconds=30` (a guard pull, ground and pound
in the guard, side control and frames, a sweep and a scramble, the BJJ fighter on top).

Tests: `tests/game/test_ground_pair.gd` (every hand and foot in place, bodies not passing through each other, no one
under the canvas, the man underneath down and the top man over him, the far side mirrored, the grips where they hold,
each strike landing from cocked by his ear, a sweep rolling them over) and `tests/game/test_ground_view.gd` (every
position posed where today's figures lay it out, the top man on the far side, the frame kept while the position lasts,
the grips on the bodies, a punch landing and the bomb sitting up first, a sweep rolling them over with the sweeper on
top, standing up and the scramble not posed as a ground position).

## Stand-up striking polish (D360–D362)

Kyle picked stand-up striking polish after the ground positions (D289): most of a fight is on the feet. A
20-second Boxer–Kicker fight on the skinned body showed four things: strikes snapped out (nothing for half a
second, then the limb fully out in two or three frames, kicks with no chamber), the camera ended up behind one
man so his back hid the other's strikes, everyone stood the same, and the uppercut read as a straight punch.

**Wind-ups that read (D360).** Standing, a strike's telegraph shows a tell, `FighterFigure.TELLS`: the shoulder
loads (the rear one back for the cross and overhand, the lead dipping for the jab, turning away for the hook),
the hand drops and the knees dip for the uppercut, the hips open and the hand drops for a kick. The tell's size
is the telegraph the sim gave him over the move's own (`TELL_SIZE_MIN` 0.35 to `TELL_SIZE_MAX` 1.25), so a quick
man, a good kicker and the second shot of a combination show less; it is gone by the middle of the wind-up. The
wind-up then carries the strike out over its whole length (`FighterFigure.strike_shape`). A kick chambers first
(`KICK_CHAMBER`: the knee up, the shin folded) over the first `KICK_LIFT_SHARE` of the wind-up, goes out from
`KICK_CHAMBER_SHARE`, and comes back through `KICK_RECHAMBER` of the chamber in the recovery; the kicking side's
arm swings down (`KICK_ARM_SWING`). The uppercut aims under the chin (`AIMS.uppercut.drop`, contact 0.72 m) and
drives up off the legs, and one man stepping in alone gets as close as his strike's contact (the uppercut and
the body hook get inside `ArenaView.LUNGE_CLOSEST`).

**The camera sees them side-on (D361).** Standing, when the two are lined up with the view (side-on-ness, the
sine of the angle between the view and the line between them, under `ArenaView.CAMERA_SIDE_ON_BELOW` 0.65) the
camera eases round the cage at `CAMERA_TURN_SPEED` to square them up, at most `CAMERA_SWING_MAX` (0.7 rad, 40°)
either way of `CAMERA_FROM`, so it stays on the side whose fence is cut down to a rail. Where that leaves them
short of `CAMERA_RISE_BELOW` side-on it climbs, up to `CAMERA_RISE_MAX` (0.35 rad, 20°) at `CAMERA_RISE_FULL`.
Off their feet it eases back to `CAMERA_FROM`, which the clinch and ground layouts are drawn for.

**Stances by style (D362).** Standing, `FighterFigure.stance_for` builds each man's stance from his leanings and
what he throws, so a generated opponent stands like his style too. Each `STANCE_PULLS` line is what all the way
along it adds: "grappler" (Base +100: low, leaning in, hands lower and a little out, wider), "boxer" (Boxing 30
or more over Kicking: bladed, tight high guard, knees bent, narrower), "kicker" (Kicking 30 or more over Boxing:
square, upright, weight back, the lead hand out), "outside" (Range −100: a longer stance leaning back) and
"aggressive" (Pace +100: leaning in). `width` and `length` move the feet from `STANCE_WIDTH` and
`STANCE_LENGTH`. Strikes now turn from his own stance rather than from square, and a fighter who bit on a feint
puts his hands up from his own guard.

**To change:** the tells, chambers and stances at the top of `game/fighter_figure.gd` (`TELLS`, `TELL_SIZE_*`,
`KICK_*`, `STANCE_*`, `AIMS.uppercut`); the camera's `CAMERA_SIDE_ON_BELOW`, `CAMERA_SWING_MAX`,
`CAMERA_TURN_SPEED` and `CAMERA_RISE_*` at the top of `game/arena_view.gd`.

**Limits:** the clinch and ground keep their own poses (no stance or tell there); the camera can't swing past
40° because the fence is only cut down on one side; follow-through and weight transfer came next (D363); the faceted pieces carry the same changes but aren't drawn.

Preview: `tools/strike_preview.gd` (each strike thrown and landing, blocked, missed or checked, with its tell
and chamber) and a real fight, `tools/motion_preview.gd --seconds=20` (the Boxer against the Kicker, seed 35003).

Tests: `tests/game/test_strike_tells.gd` (every standing strike's tell, the second shot of a combination
showing less, punches travelling out over the wind-up, kicks chambering and coming back through it, the arm
swing, the uppercut under the chin, nothing in the clinch), `tests/game/test_fight_camera.gd` (staying put
side-on, turning to see them side-on but no further than its limit, climbing where it can't, back to
`CAMERA_FROM` off their feet, easing rather than cutting) and `tests/game/test_stances.gd` (the Boxer bladed and
the Kicker square, a wrestler low with his hands lower, every fighter's stance in bounds, none in the clinch).

## Strike follow-through (D363)

Kyle picked strike follow-through as the slice after the striking polish, and on the cards: a miss carries him
"By the shot", a missed round kick will "Turn through, back to stance", and a landed punch finishes "By power".
Before, a strike went out and came straight back the same way whatever happened: a miss looked like a hit, and
nobody's weight moved over his feet.

**Weight through the feet.** Standing, as a strike goes out his hips move forward over his front foot (`SHIFT`, in
metres at full extension: 7 cm behind a cross, 9 behind an overhand, 3 behind a jab or hook; the teep pushes him
3 cm back off the man) and come back over the recovery, whatever becomes of it. A rear-leg kick's standing foot
turns out on its ball with the hips (`KICK_PIVOT` of the hip turn, not the 35% a stepping foot turns) and its heel
comes up (`KICK_HEEL`).

**Misses, by the shot.** Each strike has a commitment (`CARRY`, 0 to 1): the jab 0.15, the teep 0.3, the calf
kick 0.4, the uppercut 0.5, the cross, body hook and leg kick 0.6, the hook and body kick 0.8, the overhand and
head kick 1. A miss carries him by it: his hips carry on round `MISS_TURN` (80%) of the strike's own turn again,
a punch leans `MISS_LEAN` further in, goes `MISS_SHIFT` (10 cm) further over his front foot and reaches on
`MISS_REACH` (15 cm) past the side of the head. The carry builds through the active part, peaks a third of the
way into the recovery and is gone by its end, so he is back in his stance when the sim lets him act again.

**A missed round kick turns through.** A round kick's hips are already most of the way round, so a miss carries
them `KICK_MISS_TURN` (110%) of its turn again, and the leg sweeps `MISS_SWEEP` (45 cm) further across in front of
him, then he turns back into his stance. It never spins him all the way round: the fight gives nothing for a
missed kick's back, so the view doesn't show one.

**Landed shots, by power.** A man's drive is his Power over his Speed (`drive_for`: half, plus the difference over
`DRIVE_SPREAD` 40 points; the Brawler 1, the Boxer 0.75, the Kicker 0.38, the Karate man 0). A heavy hitter's
landed shot carries on `LAND_CARRY` (40%) of the way a miss would, and the glove or shin goes on `DRIVE_THROUGH`
(7 cm, at full drive) through the target. A quick man's punch that lands or hits the guard snaps back to guard in
`SNAP_RETURN` (55%) of the recovery instead of all of it. Kicks come back through their chamber either way.

**What to edit:** the constants above, at the top of `game/fighter_figure.gd` with the D363 comment;
`strike_shape` (the `carry` curve and the `snap` share), `_follow_through` and `_snap`.

**Limits:** the clinch and ground strikes have no follow-through (they keep their own poses); he doesn't take a
step to catch a miss (his feet stay where the sim has them, so the carry is in his hips, shoulders and the
striking limb); a missed kick's leg doesn't land in front of him.

Preview: `tools/strike_preview.gd` now also throws the cross, hook and overhand being slipped and the body and
head kick missing; `--only=` keeps some cases (`cross`, or `head_kick:missed`) and `--red=` picks the man throwing
them (`--red=brawler` against `--red=karate` for driving through and snapping back). Before and after sheets and
clips: `/mnt/project-files/screenshots/followthrough-d363/`.

Tests: `tests/game/test_follow_through.gd` (the weight over the front foot and back, a miss carrying further round
and in than a landed shot, a missed jab hardly at all and an overhand well past, a missed round kick turning
through and back, drive from Power over Speed, a heavy hitter driving through and a quick man snapping back, a
rear kick's standing foot turning out, nothing in the clinch).

## Fighters who look different (D364, D365)

Kyle picked fighters who look different as the slice after strike follow-through. Before, both men were the same
body at the same size, and only the shorts changed colour. On the cards he picked: "You pick for your own
fighter" (the look of the career's own man is chosen on the new-career screen; everyone else's comes from where
he's from), "Corner colours, as now" for the shorts, "True to the numbers" for size, and "Colours, shaved and
beards" for how far hair and faces go.

**A look** (`FighterLook`, `sim/world/fighter_look.gd`) is `{skin, hair, hair_style, beard}`: one of seven skin
tones, light to dark (`SKIN_TONES`); a hair colour (`HAIR_COLOURS`: black, dark brown, brown, light brown, blonde,
red, grey); `short` (the body's own hair), `buzzed` or `shaved` (`HAIR_STYLES`, 45%, 30%, 25%); and `none`,
`stubble` or `beard` (`BEARDS`, 45%, 35%, 20%). Everyone but the career's own man has his look rolled for where he's
from: each country file says how often each tone and hair colour turns up there (`docs/09` names@1 `looks`), so a man
from Lagos is nearly always dark-skinned and a Japanese man mostly has black hair, but any country has a mix. A man
`DARK_HAIR_FROM` (tone 5 of 7) or darker has black or dark brown hair. The dice are his id and name, so the same man
looks the same in every fight. The world's men carry their country into the fight (`home`); the test fighters have one
each in their files (the BJJ man from Brazil, the Judoka from Japan, the Muay Thai man from Thailand, and so on).

**Your fighter's look** (D365): the new-career screen has a row of skin-tone swatches and three drop-downs (hair colour,
hair, beard) under Stance. *Roll everything* rolls them for his hometown's country, last, so the rest of a roll is as it
was. The pick is saved with the career (`docs/09` career@1 `about.look`) and he's drawn with it in every fight; a career
saved before has none and gets one rolled for where he's from.

**The body's regions.** The body has one painted texture, so `tools/body_regions.py` finds which texels are which from
where they sit on the body and what colour they are, and bakes `game/bodies/tripo_fighter_regions.png`: red the hair on
his head, green where a beard grows (the jaw, chin and upper lip, not the lips), blue his eyebrows, alpha his shorts.
The body's shader (`SkinnedBody.set_look`) then gives skin his tone, each texel shaded as the body's own skin is there,
keeping `SKIN_DETAIL` (65%) of the texture's own colour (its lips, blush and shadows); dyes the hair and eyebrows his
hair colour; for a buzzed head keeps `BUZZED_HAIR` (55%) of the hair over a scalp the colour of his skin, and sinks the
hair's shell in toward the scalp (`HAIR_SINK`: 1.4 cm buzzed, 2.2 cm shaved, so a shaved head isn't a hairstyle in
skin colour); and darkens the beard's zone toward his hair colour (`FighterLook.BEARD_SHADE`: stubble 40%, a beard
95%). The shorts' light grey still takes the corner's red or blue (now only on the shorts, so eye whites no longer
pick it up); gloves, eyes and the shorts' dark panels stay as they are.

**His size, true to the numbers** (`FighterLook.sizes`, from fighter@1 `frame`):
- *Height:* the whole figure (the posing pieces and the body on them) is scaled by his height over
  `DRAWN_HEIGHT_CM` (180 cm), so a 190 cm man stands 190 cm next to a 172 cm one. The clinch and ground poses are fitted
  to each man's own body, so two men of different sizes still hold each other.
- *Build:* his trunk is thickened across (not lengthened) by his body-mass index, from what he walks around at this age
  and his height: `GIRTH_PER_BMI` (3.5%) a point over or under `DRAWN_BMI` (25), between `GIRTH_RANGE` (88% to 125%;
  a stocky man about 105%, a lean one about 95%, a heavyweight as thick as it goes, a 16-year-old not yet filled out).
  His arms and legs take `LIMB_GIRTH_SHARE` (80%) of it, his neck `SkinnedBody.NECK_GIRTH_SHARE` (70%).
- *Reach:* each arm is longer by half his reach over his height, on an arm `ARM_SHARE_OF_HEIGHT` (33%) of his height
  long (a 180 cm man with a 192 cm reach has arms 10% longer). The rig the clinch and ground poses use is fitted to the
  longer arms too.

**What to edit:** the tones, colours and shares at the top of `sim/world/fighter_look.gd`; a country's mix in its
`data/names/` file (`looks`); the shading in `SkinnedBody._tint_shader` and the D364 constants above it; the regions'
limits in `tools/body_regions.py` (run it again if the body file changes: `python3 tools/body_regions.py`, which needs
numpy and Pillow).

**Limits:** one body and one face for everyone (a face's shape, a nose or ears that differ are for the faces and
damage slice); no new hair shapes (Kyle kept hairstyles out of this slice); a shaved head keeps the hair's outline, a
little sunk; the 16-year-old's height is his grown height (the frame has no growing height); the strikes' reach in the
fight is the sim's, so a long-armed man's arm only looks longer.

Preview: `tools/look_preview.gd` draws the test fighters five to a picture, each with his height, reach, build and look
written over him (`--men=` picks them, `--plain` draws them all as before); `tools/visual_preview.gd` now takes
`--red=` and `--blue=`. Pictures: `/mnt/project-files/screenshots/looks-d364/`.

Tests: `tests/sim/world/test_fighter_look.gd` (the same man the same look, a man mostly looking like where he's from, dark
skin with dark hair, a given look kept, size from height, reach and weight, your fighter's look kept through a save and an
old save getting one, the world's men carrying their country), `tests/game/test_fighter_looks.gd` (a taller man taller,
long arms long and the rig fitted to them, a stocky man thicker, the body coloured as his look with the corner's shorts,
no profile drawn as before), the new-career screen's look in `tests/ui/test_career_screens.gd`, and the data checks on
`home`, `look` and each country's `looks`.

## Submissions from the rig (D366, D367)

Kyle picked submissions and scrambles on the rig as the slice after fighters who look different, and said "You can
start". It comes in two PRs: the holds first (this section), then the scramble, standing up and the shots from range.
On the cards he picked "Submissions first", "Tightens with the danger", "Tap shown, escape eases out" and
"Standing, sits back if deep".

**A pose for each hold** (`game/rig/submission_pair.gd`, `SubmissionPair`), written like the ground's with the man
attacking as "a" and the man in it as "b". Each hold has a loose pose (the danger meter near empty: he's nearly out)
and a tight one (near full: about to tap):

| Hold | The man attacking | The man in it | Tight |
|---|---|---|---|
| Guillotine, standing | upright, his arm round the neck, hands clasped under the chin | bent over in front of him, hands on the arm | he arches back and pulls up |
| Guillotine, pulled to guard | on his back, the neck in his arm, legs round the waist | on his knees in the guard, head trapped | hips up, the head pulled in |
| Triangle | on his back, legs locked round the head and one arm, a hand pulling the head down | on his knees, bent over into it | hips up, the head pulled down |
| Armbar from the guard | on his back turned across, a leg over the face, both hands on the wrist | on his knees over him, the arm caught | hips up into the elbow, the arm straight |
| Armbar from mount | swung off beside the head, legs across the chest and face | flat, the arm held up | falls back to the canvas |
| Rear-naked choke | behind him, hooks in, an arm round the throat, a hand behind the head | sat in front, hands on the forearm | leans back and pulls, the chin up |
| Arm-triangle, side control | low across him, arms round the head and near arm | flat, the near arm pinned across his face | drives in, the hips down, the head turned away |
| Arm-triangle, mount | chest down on him, arms round the head and arm | flat under him | sprawls the hips down |
| Ankle lock | sat facing him, the foot under his armpit, a foot on his hip | propped back on his hands | falls back arching, the leg straight |
| Kneebar | on his back along the leg, the heel on his chest, legs round the thigh | propped back on his hands | arches the hips into the knee |
| Heel hook | on his back, the leg between his, the heel in his elbow | on his back turning away | turns the heel, rolling onto his side |

**Tightens with the danger** (`SubmissionPair.at_danger`): the pose blends loose to tight as the danger meter fills (eased
at the ends), and the danger shown slides toward the sim's at `DANGER_SPEED` (3× the gap a second), so a struggle
beat's jump eases rather than snapping.

**Where it is drawn** (`ArenaView._start_hold`). A hold locked from a ground position is drawn in that position's frame
(`ground_frame`, D289): where the bottom man was, the man on top on the far side from the camera in side control
(the arm-triangle mirrored). A standing guillotine is drawn between the two (`hold_frame`); a leg lock side-on to the
camera, since it is fought sat down face to face. The frame is kept while the hold lasts.

**Easing in and out.** A new hold eases in over `HOLD_EASE` (0.35 s) from whatever was drawn; an escape eases out to
where the sim puts them (back in the position, or the scramble, posed from the rig since D368) as the clinch and ground do.

**The guillotine standing, sitting back if deep.** A guillotine from standing or the clinch starts standing, the man
caught bent over in front. Once the danger shown reaches `SubmissionPair.GUARD_PULL_AT` (70) he sits back and pulls
him into the guard over `PULL_EASE` (0.6 s), and stays down even if it loosens.

**The tap** (D367, `SubmissionPair.tapping`, `TAPS`). A fight won by a hold drawn from the rig holds the tight pose with
the man in it tapping with his free hand, on the attacker or the canvas (`TAP_HZ`, 3 a second, `TAP_LIFT` 9 cm up), for
`ArenaView.TAP_SECONDS` (1.4 s); the view says `tapped` and only then does the result screen come up
(`game/main.gd` `_on_fight_over`; not in a headless run).

**What to edit:** the poses, `TAPS`, `TAP_HZ`, `TAP_LIFT` and `GUARD_PULL_AT` in `game/rig/submission_pair.gd`;
`HOLD_EASE`, `PULL_EASE`, `DANGER_SPEED` and `TAP_SECONDS` at the top of `game/arena_view.gd`.

**Limits:** the hold is one pose blended, with no hands fighting the grip or rolling with it, and an escape eases out rather
than being shown; the poses are hand-placed on the Tripo body, with no physics, and the hold's frame doesn't follow the
sim nudging their spots.

Preview: `tools/rig_preview.gd --subs --body` (each hold loose and tight, and the tap); a real fight from its first hold:
`tools/motion_preview.gd --red=bjj --blue=boxer --seed=35002 --hold=1 --seconds=8` (a triangle to the tap; `--hold=n` starts
recording at the nth hold). Pictures: `/mnt/project-files/screenshots/subs-d366/`.

Tests: `tests/game/test_submission_pair.gd` (each hold loose, tight and a tap, every hand and foot in place, no one under
the canvas, the danger taking it loose to tight, tight tighter than loose, the free hand tapping, the standing guillotine
standing and pulled to guard, the side holds mirrored) and `tests/game/test_submission_view.gd` (a hold drawn where it
was locked from, the danger sliding, the guillotine sitting back once deep and staying down, a leg lock side-on, an
escape letting go, the tap before the result).

## Scrambles, getting up and shots from range (D368, D369)

The second PR of submissions and scrambles on the rig (D366): what was left on today's figures off the feet comes
onto the rig. On Kyle's four cards for it (2026-11-02 03:37) he picked the
recommended answers: the scramble as "Both on knees, fighting for it", getting up as "Technical stand-up, fence walk",
the shot from range as "Level change and blast in" and following him down as "Dives on top".

**How they play.** Each move is a list of paired poses (`game/rig/scramble_pair.gd`, `ScramblePair`, and
`game/rig/shot_pair.gd`, `ShotPair`) played along from the pose the two were in, the way the clinch takedowns play
(D288): the move's first keys over its telegraph and wind-up (`TIMING.entry`), `fall` of the way on to its end during
the active part while the sim is still deciding, and the rest over `land` seconds once it works, with a thud of
`thud` if it lands on the canvas. A move stopped eases back to where the sim leaves them (`STUFF_EASE`); ending on
their feet, the bodies ease back to today's standing figures over `LAND_EASE` (0.45 s).

| Move | Its keys | Ends |
|---|---|---|
| The scramble (position) | both up on their knees face to face, hands on each other's waist and shoulders | held while it lasts |
| Scramble for the top | he comes up on a foot and drives through, head by the ribs, arms round the waist; the other knocked onto his seat | in his guard, thud 0.3 |
| Getting up out of it | up onto a foot, hands framing on his shoulders to push off | both in their stance |
| Getting up (technical stand-up) | sitting out on a hand posted behind, a foot on the top man's hip; hips up, a leg swung back under him | both in their stance, a step apart |
| Getting up, back on the fence | sat against it, knees up, hands on his shoulders; half way up, back flat on it, pinned by the head in his chest; standing on it | off it, both in their stance |
| Standing up from the top (D330) | into a base, a foot up, hands on his knees; standing over him bent at his shins, his feet up; a step back out of reach | the man underneath left down |
| Double leg from range | the level change (hips down `LEVEL_DROP`, 30 cm, the lead foot stepped in deep); in on the legs (the clinch double leg's pose); driving through | his guard, thud 0.7 |
| Catch-kick single | the kick caught under the arm on its side, his hand on the knee, hopping on the other leg; reaping the standing leg out | his guard, thud 0.75 |
| Following him down (D142) | a man down flat, feet toward him; the dive in low over his legs, hands for the waist | half guard (his guard when it half works), thud 0.5 |

**The scramble** (`ArenaView._pose_scramble`). In the scramble position both are posed on their knees in a frame kept
while it lasts: where a takedown or a get-up that half worked left them (it carries on from there), or between the two.
A takedown from the clinch that half works now lands in it too, rather than going back to today's figures.

**Getting up, which way** (`ArenaView._move_for`). The man underneath gets up by the technical stand-up in the ground
position's frame; when the sim has him pinned against the fence (`cage_proximity` pinned, the same thing that gives
him the get-up's fence bonus) he walks up it instead, posed in a frame squared to the panel behind him with its
origin `ScramblePair.FENCE_BACK` (40 cm) in from it (`wall_frame`). Standing up from the top keeps the position's frame.

**The shots** (`ShotPair`). A shot from range is posed in a frame on the canvas `BEHIND_FEET` (26 cm) in front of the
man being shot on, so his stance is where it was drawn and the shot's later poses are the clinch takedown's
(`RigPairs.double_leg`, `TakedownPair._dl_drive`); how far he steps in depends on how far apart they were drawn. The
catch-kick single is mirrored when the kick came with the left leg (`ArenaView._kicking_leg`). Following him down is
posed from the downed man's hips (where his fall laid him, D370). Each lands laid out the way today's figures lay out the position (as D288's do) and
today's figures carry on where it landed.

**What to edit:** the poses, `TIMING` and `FENCE_BACK` in `game/rig/scramble_pair.gd`; the poses, `TIMING`,
`BEHIND_FEET`, `LEVEL_DROP` and `LEVEL_STEP` in `game/rig/shot_pair.gd`; `OPEN_SHOTS` and the eases at the top of
`game/arena_view.gd`.

**Limits:** the up-kick and diving back on him after standing up (D333, D334), the leg grab and the knee on the ground
keep the pose they're in; a stuffed shot from range eases back to today's standing figures; the scramble is one pose held (no hand fighting on the knees); the poses
are hand-placed on the Tripo body, with no physics.

Preview: `tools/rig_preview.gd --moves --body` (each move key by key and half way between, the fence walk against the
fence); a real fight from a move: `tools/motion_preview.gd --red=wrestler --blue=bjj --seed=35003 --move=double_leg
--seconds=3` (`--move=<move>[:n]` starts recording the nth time that move is posed: `scramble`, `scramble_up`,
`get_up`, `get_up_fence`, `stand_up`, `double_leg`, `catch_kick_single`, `follow_down`). Pictures:
`/mnt/project-files/screenshots/scrambles-d368/`.

Tests: `tests/game/test_scramble_pair.gd` (every move's keys, every hand and foot in place, bodies not passing through
each other, no one under the canvas, the fence walk leaning on the fence but not through it, the ways up ending on their
feet and standing up leaving him down, the level change out at range) and `tests/game/test_scramble_view.gd` (the
scramble on their knees, a half-worked shot carrying on into it, the scramble for the top landing in the guard, getting
up out of it, the technical stand-up, the fence walk, a stopped get-up back in the guard, standing up leaving him down, the double leg
from range, a sprawl on it, the catch-kick holding the leg he kicked with, following him down into half guard).

## Knockdowns from the rig (D370–D372)

The first PR of knockdowns and finishes (Kyle picked the slice on 2026-11-02 at 04:14; the visual slices now use
D370–D379). A man knocked down used to snap flat in a third of a second, lie there stiff and snap back up; now he falls,
lies and gets up on the rig. On Kyle's five cards (04:50–04:51) he picked the recommended answers: the fall "By the
shot that dropped him", getting up "To a knee, then up on wobbly legs", rocked "Wobbly legs, low hands, stars kept",
a referee in the cage who jumps in to stop it and a few seconds on the finish before the result (the second PR).

**Which way down** (`ArenaView._lay_out_knockdown`, from the KNOCKDOWN event):

| Dropped by | The fall (`KnockdownPose`) | Down for (FightSim) |
|---|---|---|
| A flash knockdown (D145) | "stiff": tipping back straight, arms up in front, flat on his back (0.45 s) | 2 s |
| Anything else standing | "crumple": his knees go, he sits down hard and falls back (0.7 s) | 2 s |
| A liver shot (D143) | "liver": folding onto both knees, curled over it with his forehead near the canvas (0.8 s) | 3 s |
| A leg giving out (D144) | "leg": down onto that knee, his hands on the other (0.3 s; mirrored for the right leg) | 1 s |
| No room behind him | "fence": sliding down the fence to sit against it, hands on his thighs (0.6 s) | 2 s |

The fall is posed in his own frame (`knockdown_frame`): origin where his feet were, +Z behind him, away from the other
man. A hook or a round kick that dropped him (the way it turned his head, `_last_hit_turn`) turns a stiff fall 55°
and a crumple 35° toward that side. A stiff or crumpled fall needs `LYING_LENGTH` (1.75 m) behind him clear of the fence
by `FENCE_ROOM` (15 cm); without it the fall turns `KNOCKDOWN_ROOM_TURNS` (±0.6 rad) to find room, and with none
there either he goes down the fence, posed in the fence's frame (`wall_frame` turned half round). A southpaw's poses
are mirrored. The fall quickens as he goes (`fall_x`). Dropped on the ground, he's shown already down.

**Getting up** (D371, `KnockdownPose.rises`). The last `rise` seconds of his time down: from his back he sits up
propped on his hands, comes up on one knee pushing off the other with both hands, and stands bent over, knees bent and
hands low (0.9 s); from the liver shot a hand goes to the canvas first (1 s); from the leg he pushes straight up
(0.45 s); against the fence he walks up it (0.9 s). Getting up turns him back to face the other man. Once the sim has
him up he eases back to today's figure over `DOWN_EASE_OUT` (0.3 s). A knockout (or the third knockdown) ends the fight
with him down, and the fall plays on to the canvas.

**Following him down** (D369) dives on him from where his fall laid him (the rig's hips), not from his feet.

**Rocked** (D372, `FighterFigure.rocked_pose`). On his feet and rocked, his hands drop `ROCKED_HANDS` (0.55 rad) from
his guard, his hips sink `ROCKED_DIP` (4 cm) with his knees giving up to `ROCKED_BUCKLE` (10 cm) more now and then, and
he sways side to side up to `ROCKED_SWAY` (0.16 rad), slower than before; all of it full when just rocked, fading to
`ROCKED_LEAST` (40%) over his last `ROCKED_FADE_TICKS` (3 s) of being rocked. The stars stay. A cover-up or a strike
still takes his arms.

**What to edit:** the poses, `TIMING` (fall, rise, twist), `LYING_LENGTH` and `FENCE_ROOM` in
`game/rig/knockdown_pose.gd`; `DOWN_EASE_IN`, `DOWN_EASE_OUT` and `KNOCKDOWN_ROOM_TURNS` at the top of
`game/arena_view.gd`; the `ROCKED_*` numbers in `game/fighter_figure.gd`.

**Limits:** the other man is today's figure meanwhile; a man rocked or knocked down in the clinch or on the ground has
no fall of his own (the sim breaks them apart standing and he's shown down); the poses are hand-placed, with no physics.
The referee and the hold on the finish came in the second PR (D373, D374, below).

Preview: `tools/rig_preview.gd --knockdowns --body` (each way down and up key by key and half way between); a real
knockdown: `tools/motion_preview.gd --red=brawler --blue=boxer --seed=35004 --knockdown=1 --seconds=5`
(`--knockdown=n` starts a second before the nth knockdown). Pictures: `/mnt/project-files/screenshots/knockdowns-d370/`
(`now-*.png` how it looked before).

Tests: `tests/game/test_knockdown_pose.gd` (every way down's keys and timing, the fall and getting up inside his time
down, every hand and foot in place, no one under the canvas, lying behind where he stood inside the room it needs, down
the fence not through it, every way up ending on his feet) and `tests/game/test_knockdown_view.gd` (a flash knockdown
on his back away from the man who dropped him, a hook turning a crumple, down the fence with no room, the liver fold,
the leg giving out on either side, getting up through a knee and back to his figure, a knockout leaving him down,
following him down from where he lies, the rocked wobble).

## The referee and the finish (D373, D374)

The second PR of knockdowns and finishes. Kyle's cards: "Yes, he jumps in to stop it" and "A few seconds on the
finish" (04:51), then "Striped shirt, shadows the action" (13:23), each the recommended option. Presentation only: the
fight doesn't know he's there, so fights are unchanged.

**Him** (`game/rig/referee.gd`, `Referee`). The fighters' skinned body sized to a `SHOULDER_HEIGHT` of 1.5 m, posed by a
hidden rig of his own. His face, skin and hair are rolled from the fight's seed (`LOOK_SEED`), so a fight's seed is
always the same man. `SkinnedBody.set_referee` dresses him: a black-and-white striped shirt, grey
trousers and black shoes (`SHIRT_WHITE`, `SHIRT_BLACK`, `TROUSERS`, `SHOES`), read from a second baked mask,
`game/bodies/tripo_fighter_clothes.png` (`tools/body_regions.py`: R the shirt, G its stripes and the bare hands, B the
trousers, A the shoes; the stripes run upright round his body and round his sleeves).

**Where he stands** (`ArenaView._move_referee`, every frame):

| What's happening | Where (`Referee.watch_spot` / `stop_spot`) | How he holds himself (`pose_spec`) |
|---|---|---|
| On their feet apart | `STANDING_OFF` (2.3 m) from the middle of them | "watch": upright, hands loose in front |
| Tied up in the clinch | `CLINCH_OFF` (1.8 m) | "watch" |
| On the ground | `GROUND_OFF` (1.6 m) | "ground": crouched, hands on his knees |
| A man knocked down on his feet | `DOWN_OFF` (1.4 m) from the downed man | "down": bent over him, a hand out |
| A stoppage, them apart | between them, 0.6 m from the beaten man toward the winner | "stop": both hands crossing over his head |
| A stoppage, them closer than `CLEAR_OF_MEN` | beside them across the camera's view (`SIDE_ON`, 0.95 m) on the beaten man's side | "stop": a hand on the beaten man (on the ground on the winner, bent down to pull him off), the other waving |

Watching, he tries `SPOT_TRIES` (16) spots round them and takes the one furthest round to the far side from the camera,
less `STAY_WEIGHT` (0.6) for each step-length it moves him (so he doesn't dance about as they move), never within
`CLEAR_OF_MEN` (1.2 m) of either man or `CLEAR_OF_FENCE` (0.55 m) of the fence. He walks there at `WALK_SPEED`
(1.5 m/s) turning `TURN_SPEED` (5 rad/s) to face them, one foot stepping at a time once it's `STEP_FROM` (12 cm) out
of place; at a stoppage he rushes in at `RUSH_SPEED` (4 m/s) with quicker steps. He waves `WAVE_RATE` (1.6) times a
second.

**The finish** (D374). A knockout, a stoppage (TKO) or a submission (`ArenaView.FINISHES`) is held on the cage for
`FINISH_HOLD` (3 s) before the result comes up: the referee waving it off, a knocked-out man still falling, and after a
submission the tap first (D367). `ArenaView.finish_shown` fires once when it's done and `main._on_fight_over` waits
for it. A decision goes straight to the cards. Without the body there's no referee, and only a submission waits (for
the tap, as before).

**What to edit:** the numbers at the top of `game/rig/referee.gd`; his poses in `Referee.pose_spec`; the clothes'
colours at the top of `game/rig/skinned_body.gd`; where the shirt ends (`WAIST`, `COLLAR`, `SLEEVE_END`), the stripes'
width (`STRIPE`) and the trousers' hem (`HEM`) in `tools/body_regions.py` (then run it again); `FINISH_HOLD` in
`game/arena_view.gd`.

**Limits:** he walks through the fighters' arms and legs if they swing through his spot (he only keeps his hips clear
of theirs); he doesn't step in to break up the clinch or a stalled fight, count, or check on a man between rounds; he
isn't drawn in the camp or on the setup screens; the same body as the fighters with the shirt painted on it.

Preview: `tools/motion_preview.gd --finish` starts saving `FINISH_LEAD` (1.5 s) before the fight ends:
`--red=brawler --blue=boxer --seed=35004 --finish --seconds=5` is a stoppage on their feet, `--seed=35006` a knockout,
`--red=gnp_wrestler --blue=kicker --seed=35003` a stoppage in the guard and `--red=bjj --blue=boxer --seed=35002` a
triangle. Pictures: `/mnt/project-files/screenshots/referee-d373/`.

Tests: `tests/game/test_referee.gd` (clear of both men and the fence on the far side from the camera, inside the cage
with them against the fence, not dancing about, between them by the beaten man, beside them where the camera sees him
when they're close, the waving hands and the one on the man, a referee in every fight dressed, the same man for the
same seed, crouched on the ground, over a knocked-down man, the stoppage bringing him in and the result waiting 3 s).

## Damage on the body (D375–D378)

The visual slice after knockdowns and finishes. Kyle picked "Damage on the body" (2026-11-02 14:39) and then, each the
recommended option (14:40): cuts "By what hit him", blood "A trickle that grows", bruising "Swelling and marks where
hit", sweat "Yes, with how tired he is" and "Looks only, for now". Presentation only: the fight never hears of a cut,
so fights are unchanged (golden fights not re-pinned) and the doctor doesn't stop a fight on one yet.

**What it remembers** (`game/rig/body_marks.gd`, `BodyMarks`, one a man, made by `ArenaView.watch` from the fight's
seed). Every landed strike goes to `ArenaView._mark_hit`, which works out the side of his face it landed on from the
limb that threw it and the thrower's stance (a left hand lands on the right side; `BodyMarks.side_hit`) and hands it
to `BodyMarks.landed`. Each frame `ArenaView._show_marks` brings the marks up to date with the fight
(`BodyMarks.update`) and draws them (`SkinnedBody.set_damage`).

| Mark | What brings it on | Numbers (`BodyMarks`) |
|---|---|---|
| A cut over an eye (D375) | A clean head strike once his head is `CUT_FROM_HURT` (12%) hurt, on the side it landed, at the strike's chance scaled by how hard it landed (`CUT_FULL_DAMAGE`, within `CUT_SCALE_LIMITS`) and by `0.5 + how hurt his head is`; one a side | `CUT_CHANCE`: elbows 11%, knees, head kicks, soccer kicks and stomps 3%, overhand and posture-up bomb 1.6%, hooks and hammerfists 1.3%, cross 1.1%, ground punch 1%, uppercuts 0.8%, jab 0.4% |
| The trickle (D376) | Starts at `BLEED_START` (25% of its length), each shot on it adds `BLEED_PER_HIT` (12%), runs on its own `BLEED_RATE` a second up to `BLEED_DRIFT_TO` (35% fresh to 80% hurt); the cutman leaves `BLEED_AFTER_CORNER` (30%) between rounds | the trickle runs from the cut down past the outer corner of his eye to his cheekbone |
| Blood on the gloves (D376) | A clean shot on a bleeding cut puts `GLOVE_BLOOD_PER_HIT` (18%) on the hitter's gloves, smeared | `ArenaView._drop_blood` also spots 1–2 drops under his head (`BLOOD_SPOT_SIZE`, `BLOOD_SPOT_SCATTER`, at most `BLOOD_SPOTS_MAX` (40) a fight) |
| A swollen eye (D377) | His head hurt, times how much of the damage landed on that side (`STRAIGHT_SHARE`: a straight shot puts 65% on the side it landed) | from `SWELL_FROM` (12%) to `SWELL_FULL` (60%); the eye puffs out (`SkinnedBody.SWELL_SIZE`, 8 mm) and goes purple underneath |
| Bruised ribs and legs (D377) | His body damage and each leg's own damage | `BODY_MARK`, `LEG_MARK` (from 6%, full at 60%): red and blotchy, purple as they build |
| Sweat and the flush (D378) | Work (`SWEAT_PER_MINUTE` up to `SWEAT_WORK_MAX`) and strain (his tank below `STRAIN_FROM`, half) | strain follows over `STRAIN_RISE_SECONDS` (20) and `STRAIN_FALL_SECONDS` (45); sweat adds `SWEAT_TIRED` (0.65) of it, coming on over `SWEAT_RISE_SECONDS` (20) and drying over `SWEAT_DRY_SECONDS` (180); the flush from `FLUSH` (15% to 75% strain) |

How often (8 pairings × 40 seeds, the AI corner): about a quarter of fights see a cut, nearly half of them from elbows
(on their feet and on the ground). Two men who only punch: about one in eight; a dirty boxer against a Muay Thai
fighter: one in two.

**How it's drawn** (the body's shader in `game/rig/skinned_body.gd`). Two more baked masks from
`tools/body_regions.py`: `game/bodies/tripo_fighter_damage.png` (R and G each eye's swelling zone, under the brow and
round the eye; B the ribs and stomach; A the flush on the face, neck and upper chest) and
`game/bodies/tripo_fighter_marks.png` (R and G the cut on each brow, at 1, and its trickle, 0.95 at the cut falling
along it, so the shader shows as much of it as the bleed says; B and A each leg's bruising, the outside and front of
the thigh and the calf). The cut and the trickle are drawn on the front of the face only (`CUT`, `TRICKLE`,
`front_of_face`), the swelling stops below the brow (`EYE_TOP`) so the brow doesn't lift off. The bruises mix
`bruise_fresh` to `bruise_old` as they build, broken up by noise; the blood is `blood`; the flush multiplies by
`flushed`; sweat lowers the skin's roughness (0.85 to 0.4) and raises its shine. Blood on the gloves is painted where
the clothes mask marks the hands. Spots on the canvas are flat discs (no decals: the web build's renderer has none).

**What to edit:** the numbers at the top of `game/rig/body_marks.gd`; the colours (`bruise_fresh`, `bruise_old`,
`blood`, `flushed`) and `SWELL_SIZE` in `game/rig/skinned_body.gd`; where the cut, trickle, eyes, ribs and flush are
(`CUT`, `TRICKLE`, `EYE`, `EYE_REACH`, `EYE_TOP`, `RIBS`, `FLUSH_FROM`) in `tools/body_regions.py` (then run it
again, and `godot --headless --import`); the blood spots at the top of `game/arena_view.gd`.

**Limits:** at the fight camera's distance a cut and a swollen eye are small (the gloves and the canvas show most);
cuts don't stop fights, and the doctor doesn't look at them; there are no cuts on the nose, cheek or back of the head,
no broken noses or black eyes from the same hit twice; the marks don't carry from fight to fight or show in the camp,
the fight night card or the result screen; the referee is never marked; blood on the canvas doesn't smear when they
roll through it; sweat doesn't make him slippery.

Preview: `tools/damage_preview.gd` (fresh, a round in, cut, a war; `--man=`) and in a fight
`tools/motion_preview.gd --red=dirty_boxer --blue=muay_thai --seed=35001 --from=880` (a cut, bloody gloves and a
swollen eye by the end). Pictures: `/mnt/project-files/screenshots/damage-d375/`.

Tests: `tests/game/test_body_marks.gd` (no cut or swelling from body and leg shots, no cut before his head is hurt,
elbows cutting far more than punches and jabs least, a shot on his gloves opening nothing, the same seed opening the
same cuts, a left hand landing on the right side, hooks on one side and straights spread, the trickle growing and the
cutman, bloody gloves, an eye swelling on the side he's hit, the ribs and each leg marked by their own damage, sweat
and the flush coming on over seconds, a watched fight drawing the marks on both men and capping the spots, a clean
shot on a bleeding cut bloodying the hitter and the canvas).

## Before, between and after the fight (D390–D394)

The visual slice after damage on the body. Kyle picked "Before, between and after" (2026-11-02 17:14) and then, each
the recommended option (17:15): before the bell "Called to the centre, touch gloves", between rounds "Stools, coach
and cutman", a decision "Referee raises his hand", after a finish "Celebrate, then hand raised", skipping "Both".
Presentation only: the fight is held while a moment plays, so fights are unchanged (golden fights not re-pinned).

**Walking** (`game/rig/walker.gd`, `Walker`). The referee's walking (D373) is now its own class: a body on a hidden
rig that walks to a spot at a speed, turns to look at a point, steps one foot at a time and poses everything above its
feet from a rig spec in its own frame, with hands able to reach a point in the world (another man's wrist or face).
The referee is a Walker; so are the corner team; and for a moment each fighter's own body and rig are lent to one.

**The moments** (`game/rig/ceremony.gd`, `Ceremony`, made by `ArenaView.watch` when the bodies and the referee are
drawn). `ArenaView.play_moment` starts one; while one is on, `ArenaView._play_moment` hands the frame to it (the
fight's own drawing waits, the overhead labels and the range tag hide, the camera looks where `Ceremony.view` says).
Each moment is a list of beats; walks end when everyone has arrived (or after `WALK_MAX`, 5 s, when they're put
there).

| Moment | What happens | Numbers (`Ceremony`) |
|---|---|---|
| Before the bell (D390, `INTRO`) | Both men start by their stools, the referee in the middle; they walk to the centre, touch gloves (both hands, glove to glove), and back off to their marks (`FightSim.START_POSITIONS`); the referee steps out to his spot | `TOUCH_GAP` 1.05 m apart, `TOUCH_SECONDS` 1, `READY_SECONDS` 0.4 on the marks, `WALK` 1.4 m/s; about six seconds |
| Between rounds (D391, `CORNERS`, then `OUT`) | Each walks to his stool (`stool_spot`: in from his corner post, red's far from the camera, blue's across), turns and sits; his coach crouches in front with a hand on his knee, talking with the other; the cutman leans in at his side, his hands on the cut (or the back of the neck); the referee waits by a neutral corner. They breathe harder the more tired they are (`BodyMarks.strain`). On Start round they stand, the team go out by the post and they walk to their marks | `STOOL_IN` 0.8 m from the post, `SEAT_HEIGHT` 0.5 m, `COACH_AT`, `CUTMAN_AT`, `TEAM_WALK` 1.8 m/s, `SIT_SECONDS` 0.6, `STAND_SECONDS` 0.5, `CUTMAN_SECONDS` 1.5 before the cut is closed, `BREATHE_HZ`, `BREATHE_DEG`, hands on his hips past `HANDS_ON_HIPS` (60% strain) |
| A decision (D392, `VERDICT`) | Both walk to the centre and stand either side of the referee facing the camera, a wrist in each of his hands; he raises the winner's (both for a draw) | `RAISE_GAP` 0.78 m, `HOLD_SECONDS` 0.8, the arm going up over `RAISE_UP_SECONDS` 0.45 and held `RAISE_SECONDS` 1.8 |
| A finish (D393, `VERDICT` with `finished`) | After the three-second hold (D374) the winner strolls a few steps toward his corner with his arms up, fists pumping, while the beaten man, if he's down, sits up on the canvas leaning back on his hands with the referee crouched over him, then gets up; then the hand raised as above | `CELEBRATE_SECONDS` 2.5, `STROLL` 0.7 m/s, `GET_UP_SECONDS` 1.2 |

The camera: before the bell and walking out as in a fight (the men side-on, closing in to `CLOSE_ZOOM` at the touch);
between rounds on the player's own corner from the middle of the cage (`CORNER_ZOOM`, raised by `CORNER_RISE`, looking
`CORNER_SHIFT` to the right of the stool so it sits left of the round panel); the hand raised straight on
(`VERDICT_ZOOM`).

**The corner team** are two bodies a corner made at the first break (`Ceremony._make_team`), dressed by
`SkinnedBody.set_cornerman`: the referee's clothes mask with a plain shirt in the corner's colour and dark trousers
(`SkinnedBody.set_clothes` does both; `CORNER_TROUSERS`), their looks rolled from the fight's seed. The stools are
three cylinders (`_build_stool`, `STOOL_COLOUR`).

**The fight screen** (`game/main.gd`). With the setup's **Walk-out and corners** option on (the `moments` setting, on
by default; career fights take it from the setup) and the bodies drawn: `Main._first_bell` plays the intro with the
fight held (the state is `MOMENT`, so no calls go in); the round break plays the corners and shows its panel down the
right (`FightHud.show_dialog(…, side)`, `SIDE_DIALOG_WIDTH` 600 px); Start round plays the walk out and then starts
the round; the end plays the verdict after the finish hold and then shows the result. Any key or click while a moment
is moving skips it to its end (`Main._skips_moment`, D394; not F3). A cut is closed by the cutman on the stool
(`ArenaView.close_cuts`, once a break); with the option off, at the bell as before. Headless the moments don't play
(`Main.moments_in_headless` for a test).

**What to edit:** the numbers at the top of `game/rig/ceremony.gd` (and its poses: `stand_pose`, `sit_pose`,
`celebrate_pose`, `sit_up_pose`, `_pose_team`); the walking at the top of `game/rig/walker.gd`; the corner team's
clothes (`set_cornerman`, `CORNER_TROUSERS`) in `game/rig/skinned_body.gd`; the side panel at `SIDE_DIALOG_WIDTH` in
`ui/fight_hud.gd`.

**Limits:** no walkout from a tunnel, no announcer or cage door; the corner team appear by the post and leave the same
way and say nothing on screen (the round panel is the coach's word); the cutman's hands are on the face but there's no
swab or vaseline; the coach doesn't change what he says by how it went; the beaten man gets up on his own (the referee
crouches by him) and a stretcher never comes; the winner never climbs the fence; nobody touches gloves again before
the last round; the other corner is seen from behind; a man in the clinch or on the ground at the bell eases out of
it as he starts walking.

Preview: `tools/moment_preview.gd` with Godot's movie maker (`--moment=intro`, `break` or `end`, `--skip`; see
`tools/README.md`). Pictures: `/mnt/project-files/screenshots/moments-d390/`.

Tests: `tests/game/test_ceremony.gd` (the stools in each corner inside the cage, across from each other; a watched
fight able to play them; walking from the corners to touch gloves and back to the marks with the fight waiting; sitting
on the stools with the coach and cutman and walking out to the marks; the cutman closing a cut once he's had a moment,
once a break, and at the bell without the moments; the hand raised after a decision with the referee in the middle; a
draw raising both; the winner's arms up after a finish; a beaten man down sitting up and getting up first; a key or
click skipping each one; a whole fight played with them unchanged; the setup's option; the round panel down the side).
`tests/game/test_referee.gd` checks the referee still walks the same on `Walker`.

## Limbs that stay put (D395–D397)

Kyle asked for an hour on the animations (2026-11-02 19:10: "limbs sometimes go all over the place") and picked
"Stand-up striking" as where he sees it most. Presentation only: fights are unchanged (golden fights not re-pinned).

**Finding them** (`tools/limb_check.gd`). Plays real seeded fights through the fight screen without drawing them and
checks both skinned bodies every frame (24 a second) while they're on their feet and drawn from the pieces (not the
clinch, a takedown or a man down): an elbow or knee whose bend turns more than 75° round the limb in one frame, a joint
moving more than 45 cm in a frame against his hips, a knee bent backwards, a leg locked straight with its foot on the
canvas, a foot more than 4 cm from where the pieces put it, anything through the canvas. It prints each by what the
fighter was doing and the worst frames with the seconds to film them from (`tools/motion_preview.gd --from=`).

**What it found** (four striking fights, about 30 minutes of standing, both men). The body is moved so its shoulders
are where the pieces' are (D285), and its trunk is shorter, so its hips were lifted: in 17.6% of frames a leg was locked
straight and in 6.5% a foot couldn't reach the canvas, hanging or sliding as he stepped. Knees swinging round, elbows
flipping and joints jumping were rare (kicks snapping out from the chamber the most, 0.3% of frames).

**The fix** (`SkinnedBody._sink_to_feet`). After the trunk is placed, his hips come down until each foot lower than
20 cm off the canvas is within 98.5% of his leg's length, by at most 20 cm; a kicking foot doesn't pull him down, and a
foot too far out to the side for any height is left. A bent arm comes down with him (a punch still reaches for the
glove), so his guard stays where it is on him. A nearly straight leg barely says which way its knee bends, and sinking
bends his legs more than the pieces', so the knee now leans 8 cm toward his front: knees bend forward unless the pieces'
knee clearly points somewhere else (a round kick). After: legs locked straight 0.03% of frames, feet that can't reach
2.0% (mostly easing out of the clinch and the first frames of a round), knee flips unchanged at 2 in 85,000.

Numbers: `PLANTED_BELOW` 0.2 m, `LEG_REACH` 0.985, `SINK_MAX` 0.2 m, `KNEE_FORWARD` 0.08 m, all at the top of
`game/rig/skinned_body.gd`. The checker's limits are at the top of `tools/limb_check.gd`.

Pictures: `/mnt/project-files/screenshots/limbs-d395/` (the same moments before and after, side by side).

**The rest of the animations (D396).** Kyle then asked for the same for everything else (2026-11-02 20:08). With
`--all` the checker counts every frame, says what drew it (the feet, the clinch, a move such as a takedown or getting
up, the ground, a man down), and also counts a hand, foot, elbow, knee or head inside the other man (within 9 cm of the
line from his hips to his chest). Four grappling fights (Wrestler v BJJ, Judoka v Sambo, Muay Thai v Dirty boxer, GnP
wrestler v Boxer; about 48 minutes, both men):

- *Knees through the canvas*: 4.5% of frames, nearly all in mount and the crucifix (the top man's knees bent down
  into it with his shins flat behind him) and the man underneath. `FighterRig.above_canvas` now turns a knee or elbow
  round the line from hip to ankle (shoulder to wrist) the least way that lifts it to 5 cm (`JOINT_FLOOR`), keeping
  the bones' lengths. After: 0.01%.
- *Joints snapping between moves*: a joint jumping more than 45 cm in a frame against his hips, 0.4% of frames, worst
  where one move hands over to another (a sprawl starting, a guard pull meeting a double leg so the pair turns round,
  a scramble, getting up). `SkinnedBody.settle` now eases in any new pose that would move a hand, foot, elbow, knee or
  the head faster than 20 m/s against his hips (`POP_SPEED`; the quickest kicks are about 15), at 5 m/s
  (`EASE_SPEED`, at most 0.4 s), and lengthens an ease that was too short for how far the pose moves. After (with the flips eased
  too): elbows 153 frames to 10, wrists 170 to 18, knees 155 to 59, ankles 85 to 5, the head 18 to none; strikes on
  the feet unchanged.
- *Feet and hands through the canvas*: once the knees were out, a foot or wrist still went under it (0.3% of
  frames): a foot hooked on a man lying there, a hand posted on the mat, and while easing between two poses (out of a
  hold into a scramble). The rig now puts no wrist lower than 4 cm (`HAND_FLOOR`) and no ankle lower than 70% of its
  height standing (`FOOT_FLOOR`), and while the body is easing, if any joint dips under 3 cm (`CANVAS_FLOOR` in
  `skinned_body.gd`) the whole body is lifted until it doesn't. After: none in 48 minutes.
- *Elbows flipping*: an elbow or knee whose bend swings right round in a frame, 0.45% of frames, mostly ground
  punches from back control and the guard, clinch uppercuts and scrambles: a strike's phases (or one hold handing
  over to the next) turning the arm from one way of bending to another in a frame. The skinned body now eases in,
  over 0.12 s (`FLIP_EASE`), any pose that would turn a bent elbow or knee (at least 6 cm off straight, `FLIP_BENT`)
  more than 60° round its limb in a frame (`FLIP_TURN`). On the feet, a bent arm drawn from the pieces also leans its
  elbow 4 cm down and out (`ELBOW_DOWN`). After: elbows 2 frames (from 312), knees none (from 17).
- *Inside the other man*: 3.9% at first, but most of it was the checker counting a hand on his neck. Measured to his
  chest instead, 0.7% of frames, spread thinly (back control's seat belt, the full guard, double legs): left for the
  final grappling pass Kyle has planned (done next, D397).

Pictures: `ground-knees-before-left-after-right.png`, `guard-pull-before-after-half-speed.mp4` and
`sprawl-before-after-half-speed.mp4` in the same folder.

**Out of the other man (D397).** Kyle asked for that grappling pass next (2026-11-02 23:01). A joint inside the other
man (within 9 cm of the line from his hips to his chest) was 1,027 joint-frames in the four grappling fights: the bottom
man's hands and knees in the full guard, his legs getting up from under a man, the back taker's knees and elbows, the
shooter's knee in a double leg, and bodies passing through each other while easing from one position to the next (a
sweep turning them over). Two layers now keep a hand, foot, elbow or knee at least 12 cm (`TRUNK_RADIUS` in
`fighter_rig.gd`) from that line:

- *The rig* (`FighterRig.set_limbs`): a hand or foot placed inside the other man is put on him the shortest way out
  (`out_of`), and a knee or elbow inside him is turned round its limb the least way that gets it out while keeping it
  above the canvas (`clear_of`), its bones' lengths kept.
- *The body* (`SkinnedBody._keep_out`, after easing): `ArenaView._settle_bodies` hands each body the other's trunk
  (`avoid`, his `Hips` to `Spine2`), and any limb still in it is posed again the same way. The first body is checked again
  once the second has settled, so neither ends up in where the other moved to. This is what catches the easing.

After: 47 joint-frames (from 1,027), 25 of them a head on his chest in the full guard. Elbow flips rose from 2 to 22
frames as limbs are turned out of him. Pictures: `inside-guard.mp4`, `inside-back.mp4`, `inside-sweep.mp4` in the same
folder (half speed, before on the left).

Tests: `tests/game/test_limbs.gd` (lifted hips sinking until both feet on the canvas reach; feet off the canvas not
pulling him down; a nearly straight leg's knee bending forward; a knee bent into the canvas turning up out of it with
its bones' lengths kept; a pose that jumps eased in; a quick strike not slowed; an elbow turned right round its arm in a
frame eased round; a hand inside the other man put on him; a knee inside him turned out keeping its bones' lengths; the
body keeping its hands out of him).

## Round-kick arm clearance (D420)

The rear glove used to sweep down through the raised thigh, especially while a head kick rechambered.
The kicking-side hand now counterbalances outward and behind its shoulder through both extension and
rechamber, then returns to guard. The lead hand still guards the head. `KICK_HAND_OUT`, `KICK_HAND_DOWN`
and `KICK_HAND_BACK` in `fighter_figure.gd` describe that hand path in metres relative to the chest.
This applies to body, head, leg and calf round kicks in either stance; it does not change the sim.

`tests/game/test_kick_clearance.gd` samples every phase at 60 Hz and measures the visible body's
forearm against its thigh, rather than only the hidden driver joints. The old path failed five of
eight stance/action combinations (head-kick clearance fell to 11 cm); the new path clears the 18 cm
regression threshold in all eight. Rendered body and head kicks were also compared through chamber,
contact and recovery. This check covers the kicking arm against its own thigh, not every possible
opponent contact.

## Short-strike contact (D421)

Standing elbows now lead with the elbow, and knees lead with the knee. Previously the elbow used the
punch solver's hand target and the knee had no opponent target or step-in distance. The elbow also
turned the rear shoulder away from the opponent, crowding the striker's own head when brought close.
Its torso now turns the rear shoulder forward. Contact gaps are 0.65 m for an elbow and 0.67 m for a knee.

The `joint` flag in `FighterFigure.AIMS` selects middle-joint contact. `FighterMotion.strike_joint`
blends limb directions with fixed bone lengths, folding the hand/foot back along `ELBOW_FOLD` or
`KNEE_FOLD`. `body_pose` carries that intent to `SkinnedBody.follow_joints`, which solves it again
using the visible body's actual lengths. The existing outcome target still chooses landed, covered,
missed or short contact; no fight rules or timing change.

`tests/game/test_short_strike_contact.gd` checks visible elbow/knee contact in both stances, the distal
limb behind the striking joint, the elbow forearm outside its own head, and fixed bone lengths through
extension and recovery. `tools/strike_preview.gd -- --only=elbow,knee` renders the standing strikes.
Clinch and ground combinations remain separate review cases; this does not certify every grip or
transition around a short strike.

## Keeping the whole body inside the cage (D422)

Sprawl paths bypassed the fence adjustment, and that adjustment checked only trunk/head points.
The final body's toes could extend more than 80 cm outside the wire. Sprawl paths now receive the
same adjustment as other takedowns, and authored path checks include the rig's limb joints.

After both visible bodies settle, the view also checks `FENCE_BONES` with surface allowances against
every octagon panel. One shared translation brings the pair inside, preserving their relative contact
and every bone length. This catches limbs swinging outside between path keys and the visible body's
different proportions. `SkinnedBody.translate_pose` remembers the corrected pose for the next frame.
This is presentation only; the simulation positions remain unchanged.

`tests/game/test_cage_clearance.gd` samples the visible body during sprawls and takedowns beside all
eight panels and corners. Existing fence, takedown, clinch and submission-view checks also pass.
`tools/cage_preview.gd` supplies reproducible before/after fence samples in the real game scene.
The final constraint is a safety bound; authored paths should still avoid large corrective slides.

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
animations, better faces and authored clothing are the next major
character work. The wider menus and training spaces need their own visual pass. Tripo can help
provide starting meshes, but anatomy, topology and rigging must be checked before replacing these
working figures. Validate the first complete character and its striking/grappling poses before
producing a roster.
