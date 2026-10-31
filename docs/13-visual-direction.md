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

## Review and verification

Open `project.godot` in Godot 4.7.2 and run the game normally. Start a fight and check striking,
clinch, ground transitions and fighting against each side of the fence. Compare at 1280×720 and
1920×1080, keeping both fighters and all coaching controls readable.

Reproducible arranged camera samples, using the real game scene and HUD:

```sh
godot --path . --script res://tools/visual_preview.gd -- --out=res://build/visual
```

Add `--720p` to check a 1280×720 window. This requires a graphics display. It writes standing, arena-only, striking, ground and near-fence PNGs. The
preview arranges its own temporary fighters and never saves a fight. Run the existing GUT suite
and the main-scene smoke check as described in the root README. The presentation-only regression
test compares a watched fight with the same seed run without a view.

## Remaining art work

This is a foundation for iteration, not a match to the concept. The current procedural fighters
still use the prototype pose system. A shared production rig, foot planting, paired grappling
animations, better faces, persistent body variations and authored clothing are the next major
character work. The wider menus and training spaces need their own visual pass. Tripo can help
provide starting meshes, but anatomy, topology and rigging must be checked before replacing these
working figures. Validate the first complete character and its striking/grappling poses before
producing a roster.
