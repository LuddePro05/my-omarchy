// Catppuccin Mocha Cursor Trail for VS Code (Neovide / Kitty style)
(function () {
  'use strict';

  const DURATION = 170; // ms - silky smooth glide speed
  const COLOR = '137, 180, 250'; // #89b4fa (Catppuccin Mocha Lavender/Blue)
  const MAX_DIST = 700; // px - ignore huge jumps across tabs / large splits
  const MIN_DIST = 4.0; // px - ignore subpixel jitters
  const MAX_TRAIL_LEN = 95; // px - pronounced, balanced comet trail

  let canvas = null;
  let ctx = null;
  let activeTrails = [];
  let cursorMap = new Map();
  let isScrolling = false;
  let scrollTimeout = null;
  let isTyping = false;
  let typingTimeout = null;
  let hadTrails = false;

  // Suppress trail animation when typing regular text, but immediately allow arrows & navigation
  window.addEventListener(
    'keydown',
    (e) => {
      if (
        e.key.startsWith('Arrow') ||
        e.key === 'Home' ||
        e.key === 'End' ||
        e.key.startsWith('Page')
      ) {
        isTyping = false;
        clearTimeout(typingTimeout);
        return;
      }

      if (
        (e.key.length === 1 || e.key === 'Backspace' || e.key === 'Delete') &&
        !e.ctrlKey &&
        !e.metaKey &&
        !e.altKey
      ) {
        isTyping = true;
        clearTimeout(typingTimeout);
        typingTimeout = setTimeout(() => {
          isTyping = false;
        }, 120);
      }
    },
    { capture: true, passive: true }
  );

  function ensureCanvas() {
    const parent = document.querySelector('.monaco-workbench') || document.body;
    if (!parent) return;

    if (!canvas || !canvas.isConnected || canvas.parentElement !== parent) {
      if (canvas && canvas.parentElement) {
        canvas.remove();
      }
      canvas = document.createElement('canvas');
      canvas.id = 'vscode-neovide-cursor-trail';
      canvas.style.position = 'fixed';
      canvas.style.top = '0';
      canvas.style.left = '0';
      canvas.style.width = '100vw';
      canvas.style.height = '100vh';
      canvas.style.pointerEvents = 'none';
      canvas.style.zIndex = '99999';
      parent.appendChild(canvas);

      ctx = canvas.getContext('2d');
      resize();
    }
  }

  function resize() {
    if (!canvas || !ctx) return;
    const dpr = window.devicePixelRatio || 1;
    const w = window.innerWidth;
    const h = window.innerHeight;
    canvas.width = Math.floor(w * dpr);
    canvas.height = Math.floor(h * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }

  window.addEventListener('resize', resize, { passive: true });

  window.addEventListener(
    'wheel',
    () => {
      isScrolling = true;
      activeTrails = [];
      cursorMap.clear();
      if (ctx) ctx.clearRect(0, 0, window.innerWidth, window.innerHeight);
      clearTimeout(scrollTimeout);
      scrollTimeout = setTimeout(() => {
        isScrolling = false;
      }, 120);
    },
    { passive: true, capture: true }
  );

  function cross(o, a, b) {
    return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);
  }

  function getConvexHull(pts) {
    pts.sort((a, b) => (a.x === b.x ? a.y - b.y : a.x - b.x));
    const lower = [];
    for (let p of pts) {
      while (lower.length >= 2 && cross(lower[lower.length - 2], lower[lower.length - 1], p) <= 0) {
        lower.pop();
      }
      lower.push(p);
    }
    const upper = [];
    for (let i = pts.length - 1; i >= 0; i--) {
      const p = pts[i];
      while (upper.length >= 2 && cross(upper[upper.length - 2], upper[upper.length - 1], p) <= 0) {
        upper.pop();
      }
      upper.push(p);
    }
    upper.pop();
    lower.pop();
    return lower.concat(upper);
  }

  const easeOut = (t) => 1 - Math.pow(1 - t, 3);

  function getVisibleCursors() {
    const list = [];
    const elements = document.querySelectorAll('.monaco-editor .cursor');
    for (let i = 0; i < elements.length; i++) {
      const el = elements[i];
      const r = el.getBoundingClientRect();
      if (r.height > 1) {
        list.push({
          id: i,
          x: r.left,
          y: r.top,
          w: Math.max(r.width, 2.5),
          h: r.height
        });
      }
    }
    return list;
  }

  function step(now) {
    ensureCanvas();

    if (ctx && !isScrolling) {
      const currentCursors = getVisibleCursors();

      for (const cur of currentCursors) {
        const last = cursorMap.get(cur.id);
        if (!last) {
          cursorMap.set(cur.id, { ...cur });
        } else {
          const dx = cur.x - last.x;
          const dy = cur.y - last.y;
          const dist = Math.hypot(dx, dy);

          // Moving across lines (deleting a line break, wrapping with arrow keys, jumping lines):
          // ALWAYS animate line changes!
          const isLineJump = Math.abs(dy) >= 4;

          // Suppress only same-line typing advance or same-line backspace
          const isSameLineTyping = Math.abs(dy) < 4 && (isTyping || (dx > 0 && dx <= 14));

          if (!isLineJump && isSameLineTyping) {
            cursorMap.set(cur.id, { ...cur });
            continue;
          }

          if (dist >= MIN_DIST) {
            if (dist <= MAX_DIST) {
              // Clamp maximum trail distance so smear is never too big or long
              let startX = last.x;
              let startY = last.y;
              if (dist > MAX_TRAIL_LEN) {
                startX = cur.x - (dx / dist) * MAX_TRAIL_LEN;
                startY = cur.y - (dy / dist) * MAX_TRAIL_LEN;
              }

              const existingIdx = activeTrails.findIndex((t) => t.id === cur.id);
              if (existingIdx !== -1) {
                const prev = activeTrails[existingIdx];
                const elapsed = now - prev.startTime;
                const p = Math.min(elapsed / prev.duration, 1.0);
                const t = easeOut(p);
                const prevTailX = prev.fromX + (prev.toX - prev.fromX) * t;
                const prevTailY = prev.fromY + (prev.toY - prev.fromY) * t;
                const chainDist = Math.hypot(cur.x - prevTailX, cur.y - prevTailY);
                if (chainDist <= MAX_TRAIL_LEN) {
                  startX = prevTailX;
                  startY = prevTailY;
                }
                activeTrails.splice(existingIdx, 1);
              }

              activeTrails.push({
                id: cur.id,
                fromX: startX,
                fromY: startY,
                toX: cur.x,
                toY: cur.y,
                w: cur.w,
                h: cur.h,
                startTime: now,
                duration: DURATION
              });
            }
            cursorMap.set(cur.id, { ...cur });
          }
        }
      }
    }

    if (ctx && activeTrails.length > 0) {
      hadTrails = true;
      ctx.clearRect(0, 0, window.innerWidth, window.innerHeight);

      activeTrails = activeTrails.filter((trail) => {
        const elapsed = now - trail.startTime;
        const progress = Math.min(elapsed / trail.duration, 1.0);

        if (progress >= 1.0) {
          return false;
        }

        const t = easeOut(progress);
        const tailX = trail.fromX + (trail.toX - trail.fromX) * t;
        const tailY = trail.fromY + (trail.toY - trail.fromY) * t;

        const headX = trail.toX;
        const headY = trail.toY;
        const headW = trail.w;
        const headH = trail.h;

        // Taper tail height slightly for a sleek comet shape
        const tailH = headH * (1 - 0.2 * t);
        const tailW = Math.max(headW, 2.5);
        const tailYOffset = (headH - tailH) / 2;

        const dist = Math.hypot(headX - tailX, headY - tailY);
        if (dist > 1) {
          const T = [
            { x: tailX, y: tailY + tailYOffset },
            { x: tailX + tailW, y: tailY + tailYOffset },
            { x: tailX + tailW, y: tailY + tailYOffset + tailH },
            { x: tailX, y: tailY + tailYOffset + tailH }
          ];
          const H = [
            { x: headX, y: headY },
            { x: headX + headW, y: headY },
            { x: headX + headW, y: headY + headH },
            { x: headX, y: headY + headH }
          ];

          const hull = getConvexHull([...T, ...H]);

          if (hull.length >= 3) {
            const alpha = 0.85 * (1 - progress);
            const tailCenterX = tailX + tailW / 2;
            const tailCenterY = tailY + tailYOffset + tailH / 2;
            const headCenterX = headX + headW / 2;
            const headCenterY = headY + headH / 2;

            const grad = ctx.createLinearGradient(tailCenterX, tailCenterY, headCenterX, headCenterY);
            grad.addColorStop(0, `rgba(${COLOR}, 0)`);
            grad.addColorStop(0.35, `rgba(${COLOR}, ${(0.45 * (1 - progress)).toFixed(3)})`);
            grad.addColorStop(1, `rgba(${COLOR}, ${alpha.toFixed(3)})`);

            ctx.save();
            ctx.fillStyle = grad;
            ctx.beginPath();
            ctx.moveTo(hull[0].x, hull[0].y);
            for (let i = 1; i < hull.length; i++) {
              ctx.lineTo(hull[i].x, hull[i].y);
            }
            ctx.closePath();
            ctx.fill();
            ctx.restore();
          }
        }

        return true;
      });
    } else if (ctx && hadTrails) {
      hadTrails = false;
      ctx.clearRect(0, 0, window.innerWidth, window.innerHeight);
    }

    requestAnimationFrame(step);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => requestAnimationFrame(step));
  } else {
    requestAnimationFrame(step);
  }
})();
