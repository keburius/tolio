// All Set landing page. Loaded in <head> so the "js" class is set before
// anything paints. Without this script the page is complete and static.
// - .reveal elements fade in the first time they scroll into view.
// - Each feature illustration plays a short loop only while it is on screen.
// - Pressing a feature's shortcut on this page highlights its card.
// Everything that moves respects "Reduce motion".
document.documentElement.classList.add("js");

const still = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

document.addEventListener("DOMContentLoaded", () => {
  // ---- Reveal on scroll; "live" while visible ----
  const loops = new Map(); // element -> { start, stop }
  const reveal = document.querySelectorAll(".reveal, #hero, #tray");
  const setLive = (el, on) => {
    el.classList.toggle("live", on);
    const loop = loops.get(el);
    if (!loop || still) return;
    if (on && !loop.running) { loop.running = true; loop.start(); }
    if (!on && loop.running) { loop.running = false; loop.stop(); }
  };
  if ("IntersectionObserver" in window) {
    const io = new IntersectionObserver((entries) => {
      for (const e of entries) {
        if (e.isIntersecting) e.target.classList.add("in");
        setLive(e.target, e.isIntersecting);
      }
    }, { rootMargin: "0px 0px -8% 0px", threshold: 0.12 });
    reveal.forEach((el) => io.observe(el));
  } else {
    reveal.forEach((el) => el.classList.add("in", "live"));
  }

  // ---- Header border once scrolled ----
  const bar = document.getElementById("topbar");
  const onScroll = () => bar && bar.classList.toggle("scrolled", window.scrollY > 8);
  window.addEventListener("scroll", onScroll, { passive: true });
  onScroll();

  // ---- Pointer glow and a gentle tilt on the icon tray ----
  const tray = document.getElementById("tray");
  if (!still) {
    let frame = 0;
    window.addEventListener("pointermove", (e) => {
      if (frame) return;
      frame = requestAnimationFrame(() => {
        frame = 0;
        document.documentElement.style.setProperty("--cx", e.clientX + "px");
        document.documentElement.style.setProperty("--cy", e.clientY + "px");
        if (!tray) return;
        const r = tray.getBoundingClientRect();
        if (r.bottom < 0 || r.top > window.innerHeight) return;
        const x = (e.clientX - (r.left + r.width / 2)) / window.innerWidth;
        const y = (e.clientY - (r.top + r.height / 2)) / window.innerHeight;
        tray.style.setProperty("--tx", Math.max(-1, Math.min(1, x * 2)).toFixed(3));
        tray.style.setProperty("--ty", Math.max(-1, Math.min(1, y * 2)).toFixed(3));
      });
    }, { passive: true });
  }

  // A repeating step function that runs only while its card is visible.
  const every = (card, ms, step) => {
    if (!card) return;
    let timer = 0;
    loops.set(card, {
      start: () => { step(); timer = setInterval(step, ms); },
      stop: () => clearInterval(timer),
    });
  };
  const $ = (id) => document.getElementById(id);

  // ---- Clipboard: the selection walks down the list ----
  (() => {
    const clip = $("clip");
    if (!clip) return;
    const rows = [...clip.querySelectorAll(".row")];
    let i = 1;
    every($("f-clipboard"), 1500, () => {
      i = (i + 1) % rows.length;
      rows.forEach((r, n) => r.classList.toggle("sel", n === i));
      clip.style.transform = `translateY(${-Math.max(0, i - 2) * 38}px)`;
    });
  })();

  // ---- Drop Ring: the file travels to a different circle each time ----
  (() => {
    const ring = $("ring"), drag = $("ringdrag");
    if (!ring || !drag) return;
    const slots = [...ring.querySelectorAll(".slot")];
    let i = 0;
    every($("f-dropring"), 1700, () => {
      i = (i + 1) % slots.length;
      slots.forEach((s, n) => s.classList.toggle("hot", n === i));
      const x = parseFloat(slots[i].dataset.x), y = parseFloat(slots[i].dataset.y);
      // Move the pointer and file a third of the way toward the circle.
      drag.style.transform = `translate(${((x - 172) * 0.35).toFixed(1)}px, ${((y - 85) * 0.35).toFixed(1)}px)`;
    });
  })();

  // ---- Desk Minder: the bar stretches and the time follows ----
  (() => {
    const fill = $("mfill"), bubble = $("mbubble"), time = $("mtime");
    if (!fill) return;
    let t = 0;
    const clock = (minutes) => {
      const total = 14 * 60 + 30 + minutes; // from 2:30 PM
      const h = Math.floor(total / 60) % 12 || 12, m = total % 60;
      return `${h}:${String(m).padStart(2, "0")}`;
    };
    every($("f-deskminder"), 90, () => {
      t = (t + 1) % 120;
      // Ease out to the right, pause, then spring back.
      const p = t < 70 ? 1 - Math.pow(1 - t / 70, 3) : t < 100 ? 1 : 1 - (t - 100) / 20;
      const w = 30 + p * 176;
      fill.setAttribute("width", w.toFixed(1));
      bubble.style.transform = `translateX(${(110 + w - 206).toFixed(1)}px)`;
      time.textContent = clock(Math.round((w / 206) * 120 / 5) * 5);
    });
  })();

  // ---- Energy Mode: the time left counts down around the cup ----
  (() => {
    const arc = $("earc"), left = $("eleft");
    if (!arc) return;
    let minutes = 45;
    every($("f-energy"), 1200, () => {
      minutes = minutes <= 15 ? 60 : minutes - 1;
      arc.setAttribute("stroke-dasharray", `${(339.3 * minutes / 60).toFixed(1)} 340`);
      left.textContent = `${minutes} minutes left`;
    });
  })();

  // ---- Window Layouts: the window snaps from layout to layout ----
  (() => {
    const main = $("wmain"), ghost = $("wghost"), name = $("lname");
    if (!main) return;
    const g = 8, gap = 6;
    const layouts = [
      { n: "Left half", k: ["⌃", "⌥", "←"], x: 0, y: 0, w: 0.5, h: 1 },
      { n: "Right half", k: ["⌃", "⌥", "→"], x: 0.5, y: 0, w: 0.5, h: 1 },
      { n: "Maximize", k: ["⌃", "⌥", "↩"], x: 0, y: 0, w: 1, h: 1 },
      { n: "First third", k: ["⌃", "⌥", "D"], x: 0, y: 0, w: 1 / 3, h: 1 },
      { n: "Center third", k: ["⌃", "⌥", "F"], x: 1 / 3, y: 0, w: 1 / 3, h: 1 },
      { n: "Top right quarter", k: ["⌃", "⌥", "I"], x: 0.5, y: 0, w: 0.5, h: 0.5 },
    ];
    const place = (el, l) => {
      const box = main.parentElement;
      const W = box.clientWidth - 2 * g, H = box.clientHeight - 2 * g; // inside the border
      const inset = (edge, total) => (edge > 0 && edge < 1 ? gap / 2 : 0);
      el.style.left = `${g + l.x * W + inset(l.x)}px`;
      el.style.top = `${g + l.y * H + inset(l.y)}px`;
      el.style.width = `${l.w * W - inset(l.x) - inset(l.x + l.w)}px`;
      el.style.height = `${l.h * H - inset(l.y) - inset(l.y + l.h)}px`;
    };
    let i = 0;
    every($("f-windows"), 1800, () => {
      i = (i + 1) % layouts.length;
      const l = layouts[i];
      place(main, l);
      // The other window takes what's left, when there's room for it.
      const rest = l.w === 1 ? null : l.h < 1 ? { x: 0, y: 0, w: 0.5, h: 1 } : { x: l.x === 0 ? l.w : 0, y: 0, w: 1 - l.w, h: 1 };
      if (rest && l.x > 0 && l.x + l.w < 1) Object.assign(rest, { x: 0, w: l.x });
      ghost.style.opacity = rest ? "1" : "0";
      if (rest) place(ghost, rest);
      name.innerHTML = `<span>${l.n}</span><span class="lk">${l.k.map((k) => `<kbd>${k}</kbd>`).join("")}</span>`;
    });
  })();

  // ---- Screenshots: a new area is picked, then captured with a flash ----
  (() => {
    const sel = $("ssel"), size = $("ssize"), badge = $("sbadge"), flash = $("sflash");
    if (!sel) return;
    const hs = ["h1", "h2", "h3", "h4"].map($);
    const areas = [[62, 30, 176, 74, "640 × 360"], [40, 26, 120, 90, "480 × 360"], [96, 40, 150, 60, "600 × 240"], [52, 34, 196, 82, "780 × 330"]];
    let i = 0, tick = 0;
    every($("f-screenshots"), 1100, () => {
      tick++;
      if (tick % 3 === 0) { flash.classList.remove("on"); void flash.offsetWidth; flash.classList.add("on"); return; }
      if (tick % 3 !== 1) return;
      i = (i + 1) % areas.length;
      const [x, y, w, h, label] = areas[i];
      sel.setAttribute("x", x); sel.setAttribute("y", y); sel.setAttribute("width", w); sel.setAttribute("height", h);
      [[x, y], [x + w, y], [x, y + h], [x + w, y + h]].forEach(([cx, cy], n) => { hs[n].setAttribute("cx", cx); hs[n].setAttribute("cy", cy); });
      badge.style.transform = `translate(${(x + w / 2 - 150).toFixed(0)}px, ${Math.min(0, y + h + 7 - 111)}px)`;
      size.textContent = label;
    });
  })();

  // ---- Lock Keyboard: keys get pressed while wiping, nothing happens ----
  (() => {
    const kb = $("kb");
    if (!kb) return;
    const keys = [...kb.querySelectorAll(".k")];
    every($("f-lock"), 260, () => {
      keys.forEach((k) => k.classList.remove("hit"));
      for (let n = 0; n < 3; n++) keys[Math.floor(Math.random() * keys.length)].classList.add("hit");
    });
  })();

  // ---- Shortcuts typed on this page light up their feature ----
  const targets = [...document.querySelectorAll("[data-keys]")];
  const comboOf = (e) => {
    const parts = [];
    if (e.ctrlKey) parts.push("ctrl");
    if (e.altKey) parts.push("alt");
    if (e.shiftKey) parts.push("shift");
    if (e.metaKey) parts.push("meta");
    // Option changes e.key on a Mac, so use the physical key where it helps.
    let key = e.key.toLowerCase();
    if (/^Key[A-Z]$/.test(e.code)) key = e.code.slice(3).toLowerCase();
    else if (/^Digit\d$/.test(e.code)) key = e.code.slice(5);
    else if (e.code === "Slash") key = "/";
    parts.push(key);
    return parts.join("+");
  };
  const highlight = (el) => {
    el.scrollIntoView({ behavior: still ? "auto" : "smooth", block: "center" });
    const card = el.closest(".card") || el;
    card.classList.add("flash");
    const keys = el.querySelector(".keys");
    if (keys) { keys.classList.remove("press"); void keys.offsetWidth; keys.classList.add("press"); }
    setTimeout(() => card.classList.remove("flash"), 1400);
  };
  document.addEventListener("keydown", (e) => {
    if (!(e.ctrlKey || e.altKey || e.metaKey)) return;
    const combo = comboOf(e);
    const hit = targets.find((t) => t.dataset.keys === combo);
    if (!hit) return;
    e.preventDefault();
    highlight(hit);
  });

  // Clicking a shortcut's keys presses them.
  document.querySelectorAll(".keys").forEach((keys) => {
    keys.addEventListener("click", () => { keys.classList.remove("press"); void keys.offsetWidth; keys.classList.add("press"); });
  });

  // Tray icons glide to their feature and flash it.
  if (tray) {
    tray.querySelectorAll("a").forEach((a) => {
      a.addEventListener("click", (e) => {
        const target = document.getElementById(a.getAttribute("href").slice(1));
        if (!target) return;
        e.preventDefault();
        highlight(target);
        history.replaceState(null, "", a.getAttribute("href"));
      });
    });
  }
});
