const express = require('express');
const app = express();
app.listen(3000, () => {
  // eslint-disable-next-line no-console
  console.log('Express server listening on post 3000');
});

const data = require('./data.json');
const fs = require('fs');

app.use(express.json());

// Clients can GET a list of notes
app.get('/api/notes', (req, res) => {
  const array = [];
  for (const prop in data.notes) {
    array.push(data.notes[prop]);
  }
  res.status(200).json(array);
});
// http -v get localhost:3000/api/notes

// Clients can GET a single note by id
app.get('/api/notes/:id', (req, res) => {
  if (req.params.id <= 0 || isNaN(req.params.id)) {
    res.status(400).json({ error: 'id must use a positive integer ' });
  } else if (data.notes[req.params.id]) { // note w/ specified id exists
    res.status(200).json(data.notes[req.params.id]); // json OBJECT representing note w/ id -- not array
  } else {
    res.status(404).json({ error: `there is no note with id ${req.params.id}` });
  }
});
// http -v get localhost:3000/api/notes/2

// Clients can POST a new note
app.post('/api/notes', (req, res) => {
  // does not include content property in req.body
  if (req.body.content === undefined) {
    res.status(400).json({ error: 'content is a required field' });
  } else {
    const newEntry = {
      id: data.nextId,
      content: req.body.content
    };
    data.notes[data.nextId] = newEntry;
    data.nextId++;
    fs.writeFile('data.json', JSON.stringify(data, null, 2), err => {
      if (err) { // content is present but note is not recorded
        res.status(500).json({ error: 'an unexpected error occured' });
      } else {
        res.status(201).json(newEntry); // created note w/ id as JSON object
      }
    });
  }
});
// http -v post localhost:3000/api/notes

// Clients can DELETE a note by id
app.delete('/api/notes/:id', (req, res) => {
  if (req.params.id <= 0 || isNaN(req.params.id)) {
    res.status(400).json({ error: 'id must use a positive integer ' });
  } else if (!data.notes[req.params.id]) {
    res.status(404).json({ error: 'matching note for id does not exist' });
  } else {
    delete data.notes[req.params.id];
    fs.writeFile('data.json', JSON.stringify(data, null, 2), err => {
      if (err) {
        res.status(500).json({ error: 'an unexpected error occured' });
      } else {
        res.sendStatus(204);
      }
    });
  }
});
// http -v delete localhost:3000/api/notes/10
