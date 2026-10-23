#!/usr/bin/env python3
import subprocess
import json
import sys
from collections import Counter

def get_window_color():
    try:
        raw_win = subprocess.check_output(['hyprctl', 'activewindow', '-j'], timeout=0.5)
        win = json.loads(raw_win)
        if not win or not win.get('class') or not win.get('mapped', True):
            return 'TRANSPARENT'

        is_floating = win.get('floating', False)
        is_fullscreen = win.get('fullscreen', 0) > 0

        # If floating and not fullscreen, the active window does not cover the top bar
        # (e.g. omacalc, dialogs, popups) -> Bar should stay transparent.
        if is_floating and not is_fullscreen:
            return 'TRANSPARENT'

        # Known frosted / transparent applications use the native desktop theme background
        win_class = (win.get('class') or '').lower()
        if any(c in win_class for c in ['alacritty', 'org.omarchy.agent', 'kitty', 'foot', 'ghostty', 'chrom', 'code', 'obsidian']):
            return 'DEFAULT'

        at_x, at_y = win.get('at', [0, 0])
        w, h = win.get('size', [0, 0])
        if w <= 0 or h <= 0:
            return '#1e1e2e'

        # Sample across full width at y = at_y + 8 (the header / tab area)
        y = at_y + min(8, max(2, h // 20))
        p = subprocess.run(['grim', '-g', f'{at_x},{y} {w}x1', '-t', 'ppm', '-'],
                           capture_output=True, timeout=0.5)
        data = p.stdout
        idx = data.find(b'255\n')
        if idx == -1:
            return '#1e1e2e'

        px = data[idx + 4:]
        colors = [(px[i], px[i+1], px[i+2]) for i in range(0, len(px), 3) if i + 2 < len(px)]
        if not colors:
            return '#1e1e2e'

        # Quantize colors into 16-step buckets to identify the dominant header color
        buckets = [(c[0] // 16, c[1] // 16, c[2] // 16) for c in colors]
        dominant_bucket, _ = Counter(buckets).most_common(1)[0]
        dom_pixels = [c for c in colors if (c[0] // 16, c[1] // 16, c[2] // 16) == dominant_bucket]

        r = sum(c[0] for c in dom_pixels) // len(dom_pixels)
        g = sum(c[1] for c in dom_pixels) // len(dom_pixels)
        b = sum(c[2] for c in dom_pixels) // len(dom_pixels)

        return f'#{r:02x}{g:02x}{b:02x}'
    except Exception:
        return '#1e1e2e'

if __name__ == '__main__':
    print(get_window_color())
