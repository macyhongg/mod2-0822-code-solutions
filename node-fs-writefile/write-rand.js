const fs = require('fs');

fs.writeFile('./random.txt', Math.random().toString() + '\n', 'utf8', err => {
  if (err) throw err;
});
