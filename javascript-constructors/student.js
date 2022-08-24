/* exported Student */

function Student(firstName, lastName, subject) {
  this.firstName = firstName;
  this.lastName = lastName;
  this.subject = subject;
}

Student.prototype.getFullName = function () {
  return `${this.firstName} ${this.lastName}`;
};

Student.prototype.getIntroduction = function () {
  return `Hello, my name is ${this.firstName} ${this.lastName} and I am studying ${this.subject}.`;
};
