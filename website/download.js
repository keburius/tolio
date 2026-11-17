// Starts the download shortly after the page loads, giving Vercel Web
// Analytics a moment to record the /download page view first.
window.addEventListener("load", () => {
  setTimeout(() => { window.location.href = document.getElementById("link").href; }, 700);
});
