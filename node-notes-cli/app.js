const fs = require('fs');
const data = require('./data.json'); // automatically parses into JS objects
const input = process.argv[2];

if (input === 'read') {
  for (const property in data.notes) {
    console.log(property + ': ' + data.notes[property]);
  }
} else if (input === 'create') {
  data.notes[data.nextId] = process.argv[3]; // green, single quotes
  data.nextId++;
  const newNotes = JSON.stringify(data, null, 2); // string (not green)
  fs.writeFile('data.json', newNotes, 'utf8', err => {
    if (err) throw err;
  });
} else if (input === 'delete') {
  delete data.notes[process.argv[3]];
  const newNotes = JSON.stringify(data, null, 2);
  fs.writeFile('data.json', newNotes, 'utf8', err => {
    if (err) throw err;
  });
} else if (input === 'update') {
  const id = process.argv[3];
  const text = process.argv[4];
  data.notes[id] = text;
  const newNotes = JSON.stringify(data, null, 2);
  fs.writeFile('data.json', newNotes, 'utf8', err => {
    if (err) throw err;
  });
}
