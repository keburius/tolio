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
