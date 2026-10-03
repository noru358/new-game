# Palace representative native sequence — 2026-10-03 UTC

The prepared approach was reviewed in actual native pixels, revealing guardian/pier occlusion that the projection boxes did not detect. The new sequence moves the pair forward while preserving their size and spacing, and removes overlapping paving faces. This document supersedes the pending-native state in `PALACE_APPROACH_READY.md`; earlier captures and failures remain preserved.

## Exact tested state

Game/evidence commit `0e6950cd51e389e3373979c7f9fd466837027457`, branch `codex/palace-temple-preview-oct03`, draft PR55 based on PR54 HEAD296bde54. Subsequent handoff/manifest commits preserve identical tested game files. No merge, main/production/canonical movement, package or campaign mounting.

Only `palace_temple_terrain.gd` and `palace_temple_kit.gd` changed after the prepared approach:

- Both guardians translate300local ground units toward the camera/front of piers. Their shape, size and750unit pair spacing remain unchanged. The existing rotated collision records use the same new centers, leaving the central passage clear.
- Later floor records own overlaps using existing `surface_areas` cutouts. The floor union, walk height0, original paving lift0.5 and actor shadow1.2 are preserved; coincident top faces no longer cause the visible stripes. No other terrain, collision policy or navigation changes.

Manifest confirms byte equality to296bde54 for original project/player/enemy/growth/profile/hybrid/shared scenes and existing temple/jungle/wetland scripts. Original Library concept stays outside public repository.

## Four actual images

All are native960×540, same camera9 / offset(14,13.864,14), same player sprite scale, no camera zoom/position workaround or automatic transparency. Captured after normal Input actions, bounded18physics frames /1process frame /force_draw. Walk-only mode suppresses3development enemies; no combat success claim.

| Image | Actual actor position | PNG bytes |
|---|---|---|
| `evidence/palace-temple-native/01-approach-960.png` |1290.769,1607.024|116750|
| `evidence/palace-temple-native/02-under-gate-960.png` |1492.475,1793.060|123516|
| `evidence/palace-temple-native/03-open-court-960.png` |2292.453,2592.827|66115|
| `evidence/palace-temple-native/04-cloister-960.png` |3549.846,1951.590|139713|

Actual pixels of all4were opened. Approach now shows both turquoise/vermilion faces, shoulders, bodies and complete gate roof silhouette together. Under-gate frame shows the player/feet/shadow between widely separated statues; upper roofs naturally crop as the player passes underneath. The open court and cloister frames also show feet/shadow. The paving interference stripes are absent in these new frames. This is implementer inspection of these4samples, not final human art approval or an all-route visibility percentage.

## Automatic evidence and boundaries

Headless and native both reach all7targets with unchanged input/speed; final native16.1333active seconds.4sampled orthographic actor-head rays clear the palace geometry. Failures array empty; logs contain no script/engine errors. Final UUID userdata top-level game files0 and profile group nodes0.

One headless engine then one GUI engine at a time, parent-assigned slots, fresh UUIDuserdata in copied QA config. Engine copy is the documented official4.6stable.89cea1439 hash974197a7e6663dba803ae97c3b2d987b77a37b6e70088400ecf0ccc591cbdfbc. User app/save/settings and checkout preserved. Own native/headless0 and whole-Mac Godot0 checked after termination; other tasks' transient headless processes observed earlier were not modified.

The initially occluded new4native frames and corresponding successful input/ray report are retained under `occluded-before/`. They show why bbox/headray PASS alone was insufficient for the guardian objective. The first prototype3frames and earlier failed projection/type checks also remain in their original evidence folders.

Not checked: every intermediate frame's whole actor/feet mask, natural user play/fun, final art acceptance, dash/melee/enemy telegraph visibility in live combat,1280, full campaign/region, long performance, export or user launch. No broad regression or additional decoration was added to claim these.

## Library and delivery

The current supported Library skill's batch helper and all3companions were obtained unchanged in a private local folder and offered the4confirmed native PNGs in order. The helper exited1 before preparation, reporting `Library prepare_uploads is not available`; stdout was empty, and no saved file ID was returned. No alternate API or direct upload bypass was attempted. Library delivery is therefore blocked in this consumer runtime, and exact GitHub commit/image paths are the verified delivery route.

Progress dashboard:3-stage content/art, Southeast Asia palace representative slice / completed independent approach-gate-court-cloister source plus actual4native images / next parent visual adoption and then any requested combat/1280 follow-up / human place/aesthetic/fun and production mounting pending. Shared DEV_STATUS update is offered as `patches/palace-temple-native-status.patch`, not applied to a shared integration owner's file.
