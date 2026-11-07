var modeButton = document.getElementById('js-dark-mode');
var modeLabel = document.getElementById('js-mode-label');
var mode = localStorage.getItem('mode');

function changeMode() {
  document.body.classList.toggle('dark');

  if (document.body.classList.contains('dark')) {
    modeLabel.innerText = 'Light mode'
    localStorage.setItem('mode', 'dark')
    document.html.classList.remove("sl-theme-dark")
  } else {
    modeLabel.innerText = 'Dark mode'
    localStorage.setItem('mode', 'light')
    document.html.classList.add("sl-theme-dark")
  }
}

function checkMode() {
  if (mode) {
    if (mode == 'dark') {
      document.body.classList.add('dark');
      modeLabel.innerText = 'Light mode';
    } else {
      document.body.classList.remove('dark');
    }
  }
}

checkMode();

modeButton.addEventListener('click', changeMode);