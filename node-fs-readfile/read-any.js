// var args = process.argv;
// console.log('number of arguments is ' + args.length);
// args.forEach((val, index) => {
//   console.log(`${index}: ${val}`);
// });

const fs = require('fs');

fs.readFile('./' + process.argv[2], 'utf8', (err, data) => {
  if (err) throw err;
  console.log(data);
});
