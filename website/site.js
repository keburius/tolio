// Loaded in <head> so the "js" class is set before anything paints.
// - .reveal elements fade in the first time they scroll into view.
// - Feature illustrations animate only while they are on screen ("live").
// Without this script everything is simply visible and animating.
document.documentElement.classList.add("js");

document.addEventListener("DOMContentLoaded", () => {
  const items = document.querySelectorAll(".reveal");
  if (!("IntersectionObserver" in window)) {
    items.forEach((el) => el.classList.add("in", "live"));
    return;
  }
  const observer = new IntersectionObserver((entries) => {
    for (const entry of entries) {
      if (entry.isIntersecting) entry.target.classList.add("in");
      entry.target.classList.toggle("live", entry.isIntersecting);
    }
  }, { rootMargin: "0px 0px -6% 0px", threshold: 0.1 });
  items.forEach((el) => observer.observe(el));
});

// ---- Hero: floating chips follow the pointer, a soft glow tracks it ----
document.addEventListener("DOMContentLoaded", () => {
  const hero = document.getElementById("hero");
  if (!hero) return;
  const still = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (!still) {
    let frame = 0;
    window.addEventListener("pointermove", (e) => {
      if (frame) return;
      frame = requestAnimationFrame(() => {
        frame = 0;
        const r = hero.getBoundingClientRect();
        if (r.bottom < 0) return;
        hero.style.setProperty("--mx", ((e.clientX / window.innerWidth) * 2 - 1).toFixed(3));
        hero.style.setProperty("--my", (((e.clientY - r.top) / r.height) * 2 - 1).toFixed(3));
        hero.style.setProperty("--sx", e.clientX + "px");
        hero.style.setProperty("--sy", (e.clientY - r.top + 40) + "px");
      });
    }, { passive: true });
  }

  // ---- Interactive demo in the menu bar mockup ----
  const demo = document.getElementById("demo");
  if (!demo) return;
  const screen = document.getElementById("screen");
  const panel = document.getElementById("panel");
  const toastEl = document.getElementById("toast");
  const locked = document.getElementById("locked");
  const tryHint = document.getElementById("try");
  let toastTimer = 0;

  const toast = (text) => {
    toastEl.textContent = text;
    toastEl.classList.add("show");
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toastEl.classList.remove("show"), 1800);
  };
  const replay = (cls, ms) => {
    screen.classList.remove(cls);
    void screen.offsetWidth; // restart the CSS animation
    screen.classList.add(cls);
    setTimeout(() => screen.classList.remove(cls), ms);
  };
  const fmt = (s) => {
    const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), sec = s % 60;
    return (h ? h + ":" + String(m).padStart(2, "0") : String(m)) + ":" + String(sec).padStart(2, "0");
  };

  // Recording timer and Energy Mode countdown.
  let recSeconds = 0, recTimer = 0;
  let energyLeft = 3600, energyOn = true;
  const recTile = demo.querySelector('[data-act="rec"]');
  const energyTile = demo.querySelector('[data-act="energy"]');
  setInterval(() => {
    if (energyOn && energyLeft > 0) energyTile.querySelector("span").textContent = fmt(--energyLeft);
  }, 1000);

  const actions = {
    panel(btn) {
      const closed = panel.classList.toggle("closed");
      btn.setAttribute("aria-expanded", String(!closed));
    },
    shot() {
      replay("shooting", 1300);
      setTimeout(() => { replay("flashing", 450); toast("📸 Screenshot copied"); }, 1000);
    },
    rec() {
      const label = recTile.querySelector("span");
      if (recTimer) {
        clearInterval(recTimer); recTimer = 0;
        screen.classList.remove("recording"); recTile.classList.remove("rec");
        label.textContent = label.dataset.label;
        toast("🎬 Recording saved (" + fmt(recSeconds) + ")");
      } else {
        recSeconds = 0; label.textContent = "0:00";
        screen.classList.add("recording"); recTile.classList.add("rec");
        recTimer = setInterval(() => { label.textContent = fmt(++recSeconds); }, 1000);
        toast("⏺ Recording… click again to stop");
      }
    },
    clip() {
      demo.querySelectorAll(".clip").forEach((c, i) => setTimeout(() => {
        c.classList.remove("bump"); void c.offsetWidth; c.classList.add("bump");
      }, i * 90));
      toast("📋 Click a row to copy it again");
    },
    energy() {
      energyOn = !energyOn;
      energyTile.classList.toggle("on", energyOn);
      energyTile.setAttribute("aria-pressed", String(energyOn));
      energyTile.querySelector("span").textContent = energyOn ? fmt(energyLeft = 3600) : energyTile.querySelector("span").dataset.label;
      toast(energyOn ? "⚡ Staying awake for 1 hour" : "😴 Sleep allowed again");
    },
    lock() {
      locked.hidden = false;
    },
  };

  demo.addEventListener("click", (e) => {
    const btn = e.target.closest("[data-act]");
    if (btn && actions[btn.dataset.act]) {
      actions[btn.dataset.act](btn);
      tryHint && tryHint.classList.add("used");
      return;
    }
    const row = e.target.closest(".clip");
    if (row) {
      const list = document.getElementById("clips");
      list.prepend(row);
      list.querySelectorAll(".clip i").forEach((n, i) => { n.textContent = i + 1; });
      row.classList.remove("bump"); void row.offsetWidth; row.classList.add("bump");
      toast("Copied “" + row.querySelector(".ct").textContent + "”");
      tryHint && tryHint.classList.add("used");
    }
  });
  locked.addEventListener("click", () => { locked.hidden = true; toast("⌨️ Keyboard unlocked"); });

  // Drag the sticky note around the screen.
  const note = document.getElementById("note");
  let drag = null;
  note.addEventListener("pointerdown", (e) => {
    const n = note.getBoundingClientRect(), sc = screen.getBoundingClientRect();
    drag = { dx: e.clientX - n.left, dy: e.clientY - n.top, sc };
    note.setPointerCapture(e.pointerId);
    note.classList.add("dragging");
  });
  note.addEventListener("pointermove", (e) => {
    if (!drag) return;
    const { sc } = drag;
    const x = Math.max(0, Math.min(sc.width - note.offsetWidth, e.clientX - sc.left - drag.dx));
    const y = Math.max(0, Math.min(sc.height - note.offsetHeight, e.clientY - sc.top - drag.dy));
    note.style.left = x + "px"; note.style.top = y + "px"; note.style.bottom = "auto";
  });
  const end = () => { if (drag) { drag = null; note.classList.remove("dragging"); tryHint && tryHint.classList.add("used"); } };
  note.addEventListener("pointerup", end);
  note.addEventListener("pointercancel", end);
});
