# Palace approach ready for native review — 2026-10-03 UTC

Current tested source `f5d8b96`: recompose the independent PR55 slice after parent reviewed first PNGs. First evidence and limitations remain in `PALACE_TEMPLE_PREVIEW.md`; its geometry/route descriptions are superseded by this document.

## Concrete sequence

- Actual walk starts outside at(180,2200), turns through(650,2100), and reaches reveal target(1300,1600).
- Gate center(1500,1800); original gate and roof dimensions/heights preserved, whole structure rotated135 degrees. Paired guardians now occupy the same screen height across the doorway. Their independent original large face/eyes/tusks, shoulder fan and crown masses are enlarged; minor wrist and decorative detail reduced.
- Walk through gate into(2300,2600), traverse the broad court to(3550,2850), return through shaded cloister(3550,1940), continue along gallery to(4100,1940).
- Court Rect(1550,1900,2450,1420), flat ground; local scene bounds4400×3600. This adjusts a representative slice, not a full campaign. No speed or dash reduction, forced puzzle or reward.

Existing `TempleBlock` and `ArenaNavigation` already support rotated rectangles. The preview reuses those angles for gate piers and guardian pedestals, rather than substituting oversized axis-aligned barriers. No shared terrain/navigation/player/AI/config changes.

## Headless facts

Import and corrected fixture have no script errors. First fixture type-inference errors and subsequent roof-intersection cases are preserved separately. A first projection report also used raw1280×720 coordinates against960 bounds; it is retained as a failed experiment. Final report explicitly records source viewport1280×720 and normalizes the same orthographic9 camera /16:9 aspect to960×540. This is projection math, not a new native render.

At actual reveal(1290.769,1607.024), estimated960 projection:

| Shape | Bounds x1,y1,x2,y2 | Bounding rectangle in frame |
|---|---|---|
| Gate with complete layered roofs |162.82,12.23,815.63,411.07|100%|
| Turquoise guardian |185.62,91.35,342.82,402.47|100%|
| Vermilion guardian |635.62,91.35,792.82,402.47|100%|
| Turquoise face |208.41,126.63,320.04,227.20|100%|
| Vermilion face |658.41,126.63,770.04,227.20|100%|

Faces each approximately112×101pixels. Dimensions demonstrate framing potential; they do not establish aesthetic success or pixels unobscured by another object.

All7 normal-input targets reached in16.133 active seconds (first raw prototype7.47). Open court legs are3.38 and3.80seconds at unchanged speed; no claim of full place experience based on time. Extra gallery/court exploration is possible but unmeasured.

Four sampled actual actor head rays—reveal, under gate, open court, cloister—clear opaque palace geometry. Uses billboard head and orthographic camera direction, not perspective rays. This does not prove every point between samples, full actor mask visibility, live attack/telegraph readability or user fun.

Final unique userdata has0top-level game files and0profile group nodes. Official copied engine/version/hash and source isolation follow the first handoff. Own headless/GUI0 and whole-Mac Godot0 were confirmed after completion. No GUI was launched in this follow-up: parent assigned it to existing temple then character review.

## Remaining and run

Ready for parent-assigned GUI1: actual-input approach→under gate→court→cloister four960 captures. Current capture helper still requires a real960 texture, minimum PNG size, bounded18physics frames/one process frame/force_draw. It leaves camera settings unchanged. Set `PALACE_CAPTURE_DIR`, use the isolated QA copy with fresh UUIDuserdata, script `tests/capture_palace_temple.gd`, args `-- --palace-walk-only`; avoid production user config.

After representative visual review, check actual actor masks and short dash/melee combat and1280. No broad regression or prop proliferation before that. Natural combat / human place/aesthetic/fun / full campaign / package remain unverified.

Current3-stage content/art / done new approach and paired guardian source plus bounded projection/input/headray evidence / next four native frames when GUI slot returns / human visual acceptance pending.
