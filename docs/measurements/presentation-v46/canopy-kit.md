# Wetland representative canopy and stonework candidate

Unpublished-to-playtest presentation candidate after v45. Thirty-three distant trees now use opaque, layered broadleaf crowns and buttress trunks in two batches per grove. Face headdress and inner sanctuary lintels connect the existing stone silhouettes. Terrain, water, collision, routes, spawn rules, rewards and saves are unchanged.

Local Godot 4.6.3 checks: 39,015 geometry/footprint assertions passed; 12,825 canopy triangles. The initial north-band test found four footprint samples outside water; its center band was moved ten map units inward and all samples then passed. Representative wetland 247, whole field 3,190 and full run 26 checks passed; existing root-grove test passed.

Actual two-resolution render, body visibility, static cost and human aesthetic acceptance remain pending. This is representative art development, not final region art.

## Actual render review

Source 134fd9c full verification37084469988 and render37084469969 passed. Comparison-only follow-up3308f6d full verification37085381921 and render37085381919 passed. The fixed comparison uses delivered v45 2eae097 as baseline with identical screenshot fixture, camera and frozen simulation, at960×540 and1280×720.

Four views (procession/face-bank/court/inner-court) have draw calls80→81,94→99,93→92,75→79 respectively at both resolutions. Rendered primitives4192→16192,4782→16950,4740→16656,3980→16805. Whole-grove batching keeps objects low but draws the batch's triangles even when only part is in view; this is not a frame-rate improvement claim. Raw counts are adjacent JSON.

Expanded12points×2resolutions opaque player-visibility check:24cases,0failures, minimum visibility ratio0.9893138. This samples the player body, not every possible enemy position or attack warning. Root reviewed face bank/court/inner court/procession and overview PNGs: uniform tall cylinder foliage is replaced with lower layered crowns and buttress roots, face/temple silhouettes remain rough representative assets. Walkable shore and background water are still visually simple; this does not close the whole region's art. Human aesthetics, listening and long-session GPU performance remain unverified.
