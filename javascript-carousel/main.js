// DATA
var $leftArr = document.querySelector('.fa-angle-left');
var $rightArr = document.querySelector('.fa-angle-right');
var $img = document.querySelectorAll('img');
var $dot = document.querySelectorAll('.fa-circle');
var $dots = document.querySelector('.buttons');
var timer = null;

clearInterval(timer);
timer = setInterval(next, 3000);

$rightArr.addEventListener('click', next);
function next() {
  for (let i = 0; i < $img.length; i++) {
    if ($img[i].className === 'show' && i !== $img.length - 1) {
      $img[i].className = 'hidden';
      $img[i].nextElementSibling.classList = 'show';
      $dot[i].classList.replace('fa-solid', 'fa-regular');
      $dot[i].nextElementSibling.classList.replace('fa-regular', 'fa-solid');
      clearInterval(timer);
      timer = setInterval(next, 3000);
      break;
    } if ($img[i].className === 'show' && i === $img.length - 1) {
      $img[0].className = 'show';
      $img[i].className = 'hidden';
      $dot[0].classList.replace('fa-regular', 'fa-solid');
      $dot[i].classList.replace('fa-solid', 'fa-regular');
      clearInterval(timer);
      timer = setInterval(next, 3000);
    }
  }
}

$leftArr.addEventListener('click', prev);
function prev() {
  for (let i = 0; i < $img.length; i++) {
    if ($img[i].className === 'show' && i !== 0) {
      $img[i].className = 'hidden';
      $img[i].previousElementSibling.className = 'show';
      $dot[i].classList.replace('fa-solid', 'fa-regular');
      $dot[i].previousElementSibling.classList.replace('fa-regular', 'fa-solid');
      clearInterval(timer);
      timer = setInterval(next, 3000);
      break;
    }
    if ($img[i].className === 'show' && i === 0) {
      $img[0].className = 'hidden';
      $img[$img.length - 1].className = 'show';
      $dot[0].classList.replace('fa-solid', 'fa-regular');
      $dot[$img.length - 1].classList.replace('fa-regular', 'fa-solid');
      clearInterval(timer);
      timer = setInterval(next, 3000);
      break;
    }
  }
}

$dots.addEventListener('click', update);
function update(event) {
  for (let i = 0; i < $dot.length; i++) {
    if ($dot[i].classList.contains('fa-solid')) {
      $dot[i].classList.replace('fa-solid', 'fa-regular');
      $img[i].className = 'hidden';
    } if (event.target.classList.contains('fa-regular')) {
      event.target.classList.replace('fa-regular', 'fa-solid');
      for (let j = 0; j < $dot.length; j++) {
        if ($dot[j].classList.contains('fa-solid')) {
          $img[j].className = 'show';
        }
      }
    }
  }
  clearInterval(timer);
  timer = setInterval(next, 3000);
}
