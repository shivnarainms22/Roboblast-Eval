"""Build viewable media from the verifier's captured frames:
   - a real-time animated GIF of each effect (flash vs. swell is obvious)
   - a single side-by-side comparison PNG of the peak frames.
"""
import glob
import os
from PIL import Image, ImageDraw

BASE = r"D:\Philo Labs\verifier\results"
NAMES = ["original", "ablated", "run1", "run2", "run3"]


def peak_frame_file(name):
    """Nearest saved frame (every 4th) to this effect's peak; f_032 for ablated
    (no blast, so just show the empty scene mid-window)."""
    try:
        pk = json.load(open(os.path.join(BASE, name, "visual.json")))["metrics"]["peak_frame"]
    except Exception:
        pk = 32
    if name == "ablated" or pk < 4:
        pk = 32
    near = int(round(pk / 4) * 4)
    while near > 0 and not os.path.exists(os.path.join(BASE, name, "frames", f"f_{near:03d}.png")):
        near -= 4
    return f"f_{near:03d}"


PEAK = {n: peak_frame_file(n) for n in NAMES}

# One GIF per effect (frames were saved every 4th of 60fps -> ~66ms/frame = real time).
for n in NAMES:
    frames = sorted(glob.glob(os.path.join(BASE, n, "frames", "f_*.png")))
    if not frames:
        print("skip", n, "(no frames)")
        continue
    imgs = [Image.open(f).convert("RGB") for f in frames]
    out = os.path.join(BASE, n + ".gif")
    imgs[0].save(out, save_all=True, append_images=imgs[1:], duration=66, loop=0)
    print("wrote", out)

# Side-by-side comparison of the peak frames, labelled.
tiles = []
for n in NAMES:
    p = os.path.join(BASE, n, "frames", PEAK[n] + ".png")
    if os.path.exists(p):
        tiles.append((n, Image.open(p).convert("RGB")))
if tiles:
    w, h = tiles[0][1].size
    pad = 22
    montage = Image.new("RGB", (w * len(tiles), h + pad), (18, 20, 26))
    d = ImageDraw.Draw(montage)
    for i, (n, im) in enumerate(tiles):
        montage.paste(im, (i * w, pad))
        d.text((i * w + 6, 6), n, fill=(255, 255, 255))
    montage.save(os.path.join(BASE, "comparison.png"))
    print("wrote comparison.png")
