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

});

// ---- Live desktop: plays real Tolio use cases, scene by scene ----
document.addEventListener("DOMContentLoaded", () => {
  const desk = document.getElementById("desk");
  if (!desk) return;
  const $ = (id) => document.getElementById(id);
  const screen = $("d-screen"), cursor = $("d-cursor"), keysEl = $("d-keys"), hudEl = $("d-hud");
  const browser = $("w-browser"), notes = $("w-notes"), sel = $("d-sel"), editor = $("d-editor");
  const drop = $("d-drop"), launcher = $("d-launcher"), ctx = $("d-ctx"), note = $("d-note");
  const tabs = $("scenes"), cap = $("scene-cap");

  let run = 0, current = 0, visible = false;
  const Cancel = Symbol("cancel");
  const wait = (ms, id) => new Promise((res, rej) => setTimeout(() => (id === run ? res() : rej(Cancel)), ms));
  // Position of an element in % of the desktop.
  const rel = (el) => {
    const s = screen.getBoundingClientRect(), r = el.getBoundingClientRect();
    return { x: ((r.left - s.left) / s.width) * 100, y: ((r.top - s.top) / s.height) * 100, w: (r.width / s.width) * 100, h: (r.height / s.height) * 100 };
  };
  const moveTo = (x, y) => { cursor.style.left = x + "%"; cursor.style.top = y + "%"; };
  const click = async (id) => { cursor.classList.add("click"); await wait(140, id); cursor.classList.remove("click"); };
  const keys = async (list, id, hold = 900) => {
    keysEl.innerHTML = list.map((k) => "<kbd>" + k + "</kbd>").join("");
    keysEl.classList.add("on"); await wait(hold, id); keysEl.classList.remove("on");
  };
  const hud = (text) => { hudEl.textContent = text; hudEl.classList.add("on"); };
  const type = async (el, text, id, speed = 45) => { for (const ch of text) { el.textContent += ch; await wait(speed, id); } };
  const app = (name) => { $("d-app").textContent = name; };
  const front = (w) => { browser.classList.toggle("front", w === browser); notes.classList.toggle("front", w === notes); };
  const selection = async (box, id, { text = false, label = "" } = {}) => {
    sel.classList.toggle("text", text);
    sel.style.transition = "none";
    sel.style.left = box.x + "%"; sel.style.top = box.y + "%"; sel.style.width = "0"; sel.style.height = "0";
    $("d-size").textContent = label;
    void sel.offsetWidth; sel.style.transition = "";
    sel.classList.add("on");
    sel.style.width = box.w + "%"; sel.style.height = box.h + "%";
    moveTo(box.x + box.w, box.y + box.h);
    await wait(1100, id);
  };

  const reset = () => {
    for (const el of [sel, editor, drop, launcher, ctx, note, hudEl, keysEl, $("d-bolt"), $("d-t"), $("dl-res")]) el.classList.remove("on", "draw", "counting", "scanning");
    browser.classList.remove("left", "front"); notes.classList.remove("right", "front");
    $("n-paste").textContent = ""; $("note-text").textContent = ""; $("dl-typed").textContent = "";
    document.querySelectorAll(".desk .hl").forEach((e) => e.classList.remove("hl"));
    app("Safari");
  };

  const slide = () => rel(document.querySelector(".w-browser .d-slide"));
  const scenes = [
    { name: "Screenshot", cap: "⇧⌘4, drag, mark it up. Leave it alone and it’s on your clipboard.", dur: 9000, play: async (id) => {
      front(browser); const r = slide(); moveTo(r.x - 2, r.y - 4); await wait(500, id);
      await keys(["⇧", "⌘", "4"], id, 800);
      await selection({ x: r.x - 1.5, y: r.y - 2.5, w: r.w + 3, h: r.h + 5 }, id, { label: "1280 × 640" });
      sel.classList.remove("on"); editor.classList.add("on"); moveTo(30, 62); await wait(500, id);
      editor.classList.add("draw"); moveTo(66, 60); await wait(1300, id);
      editor.classList.add("counting"); moveTo(88, 86); await wait(3000, id);
      editor.classList.remove("on"); hud("📋 Screenshot copied"); await wait(1600, id); hudEl.classList.remove("on");
    } },
    { name: "Copy text from an image", cap: "⇧⌘2 reads text inside images and videos, then you just paste it.", dur: 9500, play: async (id) => {
      front(browser); const r = slide(); moveTo(r.x, r.y); await wait(400, id);
      await keys(["⇧", "⌘", "2"], id, 800);
      await selection({ x: r.x - 0.5, y: r.y - 1, w: r.w + 1, h: r.h + 2 }, id, { text: true });
      sel.classList.add("scanning"); await wait(1200, id);
      sel.classList.remove("on", "scanning"); hud("✓ Copied 32 characters"); await wait(1100, id); hudEl.classList.remove("on");
      const n = rel(notes); moveTo(n.x + n.w * 0.5, n.y + n.h * 0.5); await wait(850, id); await click(id);
      front(notes); app("Notes"); await keys(["⌘", "V"], id, 600);
      await type($("n-paste"), "· Q3 Roadmap: Launch on Oct 14", id, 28); await wait(1500, id);
    } },
    { name: "Clipboard History", cap: "⌃⌥V brings back anything you copied earlier.", dur: 8500, play: async (id) => {
      front(notes); app("Notes"); const n = rel(notes); moveTo(n.x + n.w * 0.6, n.y + n.h * 0.6); await wait(400, id);
      await keys(["⌃", "⌥", "V"], id, 700);
      $("d-t").classList.add("on"); drop.classList.add("on"); await wait(600, id);
      const pick = $("dd-pick"); const p = rel(pick); moveTo(p.x + p.w * 0.4, p.y + p.h * 0.5); await wait(900, id);
      pick.classList.add("hl"); await wait(400, id); await click(id);
      drop.classList.remove("on"); $("d-t").classList.remove("on"); await wait(300, id);
      await type($("n-paste"), "· github.com/keburius/tolio", id, 26); await wait(1800, id);
    } },
    { name: "Launcher", cap: "⌃⌥Space: apps, settings, math and currencies in one box.", dur: 8000, play: async (id) => {
      moveTo(80, 75); await keys(["⌃", "⌥", "Space"], id, 700);
      launcher.classList.add("on"); await wait(300, id);
      await type($("dl-typed"), "20 usd", id, 140);
      $("dl-res").classList.add("on"); await wait(1200, id);
      await keys(["↩"], id, 500);
      launcher.classList.remove("on"); hud("📋 Copied 54.12 GEL"); await wait(1600, id); hudEl.classList.remove("on");
    } },
    { name: "Window layouts", cap: "⌃⌥← and ⌃⌥→ put two windows side by side in a second.", dur: 7000, play: async (id) => {
      moveTo(40, 40); front(browser); await wait(400, id);
      await keys(["⌃", "⌥", "←"], id, 600); browser.classList.add("left"); await wait(900, id);
      const n = rel(notes); moveTo(n.x + n.w * 0.5, n.y + 3); await wait(700, id); await click(id); front(notes); app("Notes");
      await keys(["⌃", "⌥", "→"], id, 600); notes.classList.add("right"); await wait(2200, id);
    } },
    { name: "Sticky Notes", cap: "Right-click the desktop to pin a glass note right there.", dur: 8500, play: async (id) => {
      moveTo(72, 66); await wait(900, id); await click(id);
      ctx.style.left = "72.5%"; ctx.style.top = "67%"; ctx.classList.add("on"); app("Finder"); await wait(500, id);
      const c = rel($("ctx-pick")); moveTo(c.x + 4, c.y + c.h * 0.5); await wait(700, id);
      $("ctx-pick").classList.add("hl"); await wait(300, id); await click(id);
      ctx.classList.remove("on"); note.style.left = "66%"; note.style.top = "58%"; note.classList.add("on"); await wait(500, id);
      moveTo(92, 88); await type($("note-text"), "Call the dentist at 9:00", id, 55); await wait(1800, id);
    } },
    { name: "Energy Mode", cap: "⌃⌥⌘A keeps your Mac awake for a download, a talk or a long build.", dur: 6000, play: async (id) => {
      moveTo(55, 55); await wait(400, id);
      await keys(["⌃", "⌥", "⌘", "A"], id, 800);
      $("d-bolt").classList.add("on"); hud("⚡ Staying awake for 1 hour"); await wait(2200, id); hudEl.classList.remove("on"); await wait(800, id);
    } },
  ];

  // Tabs
  scenes.forEach((sc, i) => {
    const b = document.createElement("button");
    b.className = "scene-tab"; b.setAttribute("role", "tab"); b.innerHTML = '<span class="bar"></span>' + sc.name;
    b.addEventListener("click", () => start(i));
    tabs.appendChild(b);
  });

  async function start(i) {
    const id = ++run; current = i;
    reset();
    tabs.querySelectorAll(".scene-tab").forEach((t, k) => {
      t.setAttribute("aria-selected", String(k === i));
      const bar = t.querySelector(".bar"); bar.style.animation = "none"; void bar.offsetWidth; bar.style.animation = "";
      t.style.setProperty("--dur", scenes[i].dur + "ms");
    });
    tabs.classList.remove("paused");
    cap.textContent = scenes[i].cap;
    const began = Date.now();
    try {
      await scenes[i].play(id);
      await wait(Math.max(300, scenes[i].dur - (Date.now() - began)), id);
      if (visible) start((i + 1) % scenes.length);
    } catch (e) { if (e !== Cancel) throw e; }
  }

  // Play only while the desktop is on screen.
  if ("IntersectionObserver" in window) {
    new IntersectionObserver(([entry]) => {
      const was = visible; visible = entry.isIntersecting;
      if (visible && !was) start(current);
      if (!visible && was) { run++; tabs.classList.add("paused"); }
    }, { threshold: 0.25 }).observe(desk);
  } else { visible = true; start(0); }
});
