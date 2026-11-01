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
within 4 cm, standing feet are under the pieces' feet with the toes on the mat).

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
