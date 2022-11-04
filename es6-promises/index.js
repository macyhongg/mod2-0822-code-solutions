const takeAChance = require('./take-a-chance');

var promiseObj = takeAChance('Macy');

promiseObj.then(value => {
  console.log(value);
});

promiseObj.catch(error => {
  console.error(error.message);
});
