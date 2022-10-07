// write to note.txt
// node note-to-self.js 'I should buy a boat'

const fs = require('fs');

fs.writeFile('./note.txt', process.argv[2] + '\n', 'utf8', err => {
  if (err) throw err;
});
