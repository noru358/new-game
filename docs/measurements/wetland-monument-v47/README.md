# Monumental wetland face: spatial composition experiment

User direction, 2026-10-03: selected standing/background Southeast Asian face ruins may be enormous and overwhelming. Contrast them against human-scale traces; do not shrink every landmark to fit a single combat view.

## Rejected first comparison

Source 7b81b61: existing face scaled (2,3,1.7), visual origin (2540,900), height11.4. Exact render37095139901 captured the comparison and failed4 of48 visibility cases: at(2050,650) player was about50% visible, at(2100,620)0%, at both960/1280. The unequal scale also elongated the face into a column. It was not merged or delivered. This failed render is useful evidence, not a passing build.

## Revised composition

Source f37e202: uniform2.4 scale, origin(2440,950), height9.12. A connected sacred pool adds Rect2(1350,500,1430,430) through the existing rounded-water generator. The incidental northwest walk-behind shoulder is deliberately water now. This is an authored terrain change, not preserved collision or a transparency workaround.

The main procession, root detour, temple approach and eight authored encounter points remain open and reachable. Geometry bounds in map coordinates: x2185.79–2711.19/y651.96–1260.30. Reviewer sampled30492 triangle points, all wet. A10-unit grid across x1200–2900/y590–1350 had4223 open30-radius actor positions:114021 rays across ±20 body offsets and heights0/.35/.8 found no monument intersections. These are geometric diagnostics, not rendered readability or aesthetic acceptance.

## Local checks

Official Godot4.6.3: monument488, representative wetland258, full field3201, actual run26, canopy39015 checks passed. Root and waterbank contracts passed. Accelerated real-input collision routes reached12 representative and22 whole-field checkpoints. Acceleration/disabled enemies make these path checks, not travel-time, natural combat or fun tests.

## Render acceptance

Exact-head rendering37095809833 and full CI37095809777 both succeeded. Rendered player visibility:44 playable samples,0 failures,min ratio0.9893;14 former points are now authored water and reported separately. Same-camera comparison was delivered to the user; no new app was delivered. Compare v46d1 with the same cameras/resolutions. Capture approach, face bank, side route, east bank and overview. New water-only former samples are reported separately; current shoreline samples are added rather than silently dropping failing points. Check actual existing-role enemies and warnings as well as isolated player pixels.

No automatic fade/cutaway, camera change, save-format change or reward/damage tuning. Delivered v46 and canonical d1 remain unchanged. Human monumental impact, final art acceptance and long-session performance are not proven by these tests.

## Carved face follow-through

Exact game sourced0f84da replaced the11 primitive parts with2 opaque batches/484triangles inside the previous local envelope. Broad cheek planes, closed heavy lids, short nose, restrained lips, ear relief and a low worn crown keep the mass recognizable as carved temple architecture. No further terrain, camera or gameplay change. Parent reviewed actual1280/960 renders. Render37097226465 and completeCI37097226471 passed; PR48 merged production8380c69.

Rendered player visibility remains44/0failures,min0.9893. Side-route static drawcalls80→72, face-bank80→76; primitive counts vary with culling and do not prove frame-time gains. Sculpture geometry7276 assertions and mounted monument1460 assertions passed locally. Human acceptance and long-session performance remain open.
