# Temple monumental backdrop v47: bounded comparison, not adopted art

Base: production `8380c69b92e4c8cc880239c6b0259841259c72f5`. Cloud-only isolated worktree. No publishing, user save access, camera change, new interaction, or application delivery.

## Design and geometry

Hierarchy: Southeast Asia → existing reclaimed temple circuit → northern sanctuary backdrop → reused stone/moss, low apron and one entrance frame. Court, ramps, far-bank groves and playable battle floor stay at original scale.

Measured original authored stone bounds: x5092–5548, z950–1450, height554. Original pivot(5320,0,1450) is the actual front-line center. Initial uniform1.7× at front240 produced60 blocked shrine-only rays at the northwest shoulder. Moving its front north to40 eliminated shrine-only blockage but opened a pocket behind the unchanged court cap and removed the doorway from normal combat framing. Both initial options were rejected.

Final root-directed revision:
- Horizontal/depth1.7× about that original pivot, then200 map units north
- Original heights0..220 compressed to0..88; higher vertices map to88+(y−220)×1.7
- Every triangle normal recomputed from transformed geometry; colors/materials reused
- Resulting shrine bounds x2412.4..3187.6, z−810..40, top655.8
- Original blocked rectangle x2572..3028/z0..240 retained as visible55-high stone apron
- New collision rectangle x2412.4..3187.6/z0..40 seals the actual enlarged northern base; no newly open pocket
- One restrained two-pier/lintel entrance on apron: x2726..2874, front240, top240. Existing court cap spans z160..240 at height180, so the entrance face is placed flush to its south frontage, rather than invisibly behind it. The dark solid face is at240.06 (0.06map-unit anti-z-fighting epsilon), not a traversable opening
- Two architectural masses: shrine, apron/entrance. Three opaque mesh batches: stone, moss, apron/entrance stone

Ground collision is the union of two rectangles. Existing authored bevel/chamfer corners are conservatively rectangle-bounded, as before; physical coverage samples use14map-unit inset to exclude the scaled12.75-unit chamfers. This is not a new broad invisible exclusion area.

## Checked locally, Godot4.6.3 headless

With the supplied mount patch applied:
- `verify_temple_monument_scale.gd`:108,017 checks,0 failures
- Actual vertex bounds versus wall union/off-map, opaque materials, nondegenerate triangles and recomputed normals, physical mass above collider interiors, unchanged court geometry and court/grove global transforms
- Main/water route landmarks, garden return, boss and retry points remain open/reachable; original blocked footprint remains blocked
-10-unit grid x2000..3560/z30..1100:13,665 reachable positions,81,990 camera-facing actual triangle rays at heights5/30/65/95/150/250. Includes unchanged court geometry in both baseline and candidate
- Candidate1,866 blocked rays vs original1,920;0 new blocked rays. These are known preexisting architecture rays, not a claim of globally zero occlusion
- `verify_circuit_route_completion.gd`:12 real input checkpoints,0 failures; accelerated navigation and injected boss kill, not human difficulty evidence
- `verify_temple_circuit_run.gd`:0 failures, save/garden/boss/settlement checks; isolated normal-prefix bytes unchanged
- `verify_circuit_court_elevation.gd`:0 failures
- Capture script parsed via `--check-only`; actual rendered screenshots NOT produced in this worker

Each invocation uses a fresh `/tmp/temple-scale-*` XDG data directory. No regular user save was read or modified.

## Framing: projection only

Full960/1280 projected coordinates are in `geometry-and-projection.log`. Coordinates are scaled from the actual viewport to the named output size.

At1280, rear doorway corners:
- sanctuary(2800,460):x796..897/y−125..134; lower two corners visible
- boss(2800,620):x886..987/y−177..82; lower two corners visible
- arrival(2800,900):x1045..1146/y−267..−9; rear doorway absent
- threshold(2650,1000):x1186..1287/y−251..7; rear doorway not usefully in frame
- westside(2270,660):x1209..1310/y−18..241; only one corner visible

The new near entrance's four corners are within the normal1280/960 frames at all five positions. The larger rear architectural mass remains intentionally cropped and reveals more on approach. Projection alone does not prove image readability, awe or art acceptance; the parent must inspect actual renders before adoption.

## Mount and reproduce

The commit owns only the new helper, tests, and this report/patch. Integration owns shared files and DEV_STATUS. Apply `mount.patch` after cherry-picking this commit:

```
git apply docs/measurements/temple-monument-v47/mount.patch
XDG_DATA_HOME=/tmp/temple-study-new XDG_CACHE_HOME=/tmp/temple-study-cache godot --headless --path . --script tests/verify_temple_monument_scale.gd
```

Actual-render capture (parent's permitted renderer):

```
TEMPLE_MONUMENT_CAPTURE_DIR=/absolute/output XDG_DATA_HOME=/tmp/temple-capture-new godot --path . --script tests/capture_temple_monument_scale.gd
```

Capture script supplies matched960/1280 threshold, arrival, sanctuary, westside, both north shoulders, frozen boss ring, overview. It does not alter camera size except the existing overview toggle. Boss ring is a frozen fixture, not normal gameplay/performance evidence. Copy the capture script into the baseline checkout for exact viewpoint matches.

Integration status-note suggestion: reversible second monumental-backdrop study implemented and focused geometry/navigation tests pass; production/app unchanged; actual renders and human scale/identity acceptance still pending. Do not mark the first region complete or claim aesthetics from headless tests.
