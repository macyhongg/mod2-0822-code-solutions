var count = 3;

var id = setInterval(() => {
  if (count === 0) {
    console.log('Blast off!');
    clearInterval(id);
  } else if (count >= 1) {
    console.log(count);
    count--;
  }
}, 1000);
