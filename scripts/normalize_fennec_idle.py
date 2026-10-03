"""Deterministic import preparation only: crop/pad/resize, no repainting.
The generated alpha is preserved. Renderer scissor is 0.5.
Usage: python normalize_fennec_idle.py front.png side.png back.png output-dir
"""
import hashlib
import json
import sys
from pathlib import Path
from PIL import Image

destination = Path(sys.argv[4])
destination.mkdir(parents=True, exist_ok=True)
records = []
for view, source, foot_x in zip(('front', 'side', 'back'), sys.argv[1:4], (580, 710, 584)):
    image = Image.open(source).convert('RGBA')
    mask = image.getchannel('A').point(lambda a: 255 if a >= 128 else 0)
    bounds = mask.getbbox()
    assert bounds and bounds[3] < image.height, (view, 'opaque silhouette clipped')
    # Equal visible ear-to-ground height; fixed foot center, NOT alpha centroid.
    scale = 384 / (bounds[3] - bounds[1])
    cropped = image.crop(bounds)
    resized = cropped.resize((round(cropped.width * scale), 384), Image.Resampling.LANCZOS)
    x = round(192 - (foot_x - bounds[0]) * scale)
    assert x >= 0 and x + resized.width <= 384, (view, 'silhouette outside canvas')
    canvas = Image.new('RGBA', (384, 448))
    canvas.paste(resized, (x, 32))
    target = destination / (view + '.png')
    canvas.save(target)
    assert canvas.getchannel('A').getextrema()[0] == 0
    records.append({'view':view, 'source_sha256':hashlib.sha256(Path(source).read_bytes()).hexdigest(), 'source_size':image.size, 'crop':bounds, 'source_foot_x':foot_x, 'scale':scale, 'canvas':[384,448], 'foot':[192,416], 'alpha_preserved':True, 'sha256':hashlib.sha256(target.read_bytes()).hexdigest()})
(destination / 'manifest.json').write_text(json.dumps({'invariant':'equal 384px ear-to-foot height, pelvic/feet anchor x192, foot y416; idle only', 'records':records}, indent=2) + '\n')
