
function ExampleConstructor() {
}

console.log('value of ExampleConstructor prototype:', ExampleConstructor.prototype);
console.log('typeof ExampleConstructor prototype:', typeof ExampleConstructor.prototype);

const newEC = new ExampleConstructor();
console.log('new ExampleConstructor function', newEC);

var instance = newEC instanceof ExampleConstructor;
console.log('newEC instanceof ExampleConstructor:', instance);
