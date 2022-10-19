const express = require('express');
const app = express();
app.listen(3000, () => {
  // eslint-disable-next-line no-console
  console.log('Express server listening on post 3000');
});

const $data = require('./data.json');

app.use(express.json());

// Clients can GET a list of notes
app.get('/api/notes', (req, res) => {
  const array = [];
  for (const prop in $data.notes) {
    array.push($data.notes[prop]);
  }
  res.status(200).json(array);
});

// http -v get localhost:3000/api/notes

// Clients can GET a single note by id
app.get('/api/notes/:id', (req, res) => {
  if (req.params.id <= 0 || isNaN(req.params.id)) {
    res.status(400).json({ error: 'id must use a positive integer ' });
  } else if ($data.notes[req.params.id]) { // note w/ specified id exists
    res.status(200).json($data.notes[req.params.id]); // json OBJECT representing note w/ id -- not array
  } else {
    res.status(404).json({ error: `there is no note with id ${req.params.id}` });
  }
});
