const express = require('express');
const app = express();
app.listen(3000, () => {
  // eslint-disable-next-line no-console
  console.log('Express server listening on port 3000');
});

var nextId = 1;
var grades = {};

app.get('/api/grades', (req, res) => {
  const array = [];
  for (const obj in grades) {
    array.push(grades[obj]);
  }
  res.json(array);
});

app.use(express.json());

app.post('/api/grades', (req, res) => {
  grades[nextId] = req.body;
  grades[nextId].id = nextId;
  res.status(201).send(grades[nextId]);
  nextId++;
});

// http -v get localhost:3000/api/grades
// http -v post localhost:3000/api/grades name="Brendan Eich" course="JavaScript" score:=100
// http -v post localhost:3000/api/grades name="Macy Hong" course="CSS" score:=80
