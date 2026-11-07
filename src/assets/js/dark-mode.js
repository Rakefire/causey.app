var modeButton = document.getElementById('js-dark-mode');
var modeLabel = document.getElementById('js-mode-label');
// No saved choice: follow the system setting. The toggle saves an override.
var mode = localStorage.getItem('mode') ||
  (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');

function changeMode() {
  document.body.classList.toggle('dark');

  if (document.body.classList.contains('dark')) {
    modeLabel.innerText = 'Light mode'
    localStorage.setItem('mode', 'dark')
    document.documentElement.classList.add("sl-theme-dark")
  } else {
    modeLabel.innerText = 'Dark mode'
    localStorage.setItem('mode', 'light')
    document.documentElement.classList.remove("sl-theme-dark")
  }
}

function checkMode() {
  if (mode) {
    if (mode == 'dark') {
      document.body.classList.add('dark');
      document.documentElement.classList.add('sl-theme-dark');
      modeLabel.innerText = 'Light mode';
    } else {
      document.body.classList.remove('dark');
    }
  }
}

checkMode();

modeButton.addEventListener('click', changeMode);