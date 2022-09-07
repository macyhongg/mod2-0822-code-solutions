/* exported Bank */

function Bank() {
  this.nextAccountNumber = 1;
  this.accounts = [];
}

Bank.prototype.openAccount = function (holder, balance) {
  if (Number.isInteger(balance) === true && balance > 0) {
    var newAccount = new Account(this.nextAccountNumber, holder);
    newAccount.deposit(balance);
    this.accounts.push(newAccount);
    this.nextAccountNumber += 1;
    return newAccount.number;
  } else {
    return null;
  }
};

Bank.prototype.getAccount = function (number) {
  for (let i = 0; i < this.accounts.length; i++) {
    if (this.accounts[i].number === number) {
      return this.accounts[i];
    }
  } return null;
};

Bank.prototype.getTotalAssets = function () {
  if (this.accounts.length > 0) {
    var totalAssets = 0;
    for (let i = 0; i < this.accounts.length; i++) {
      var currentBalance = this.accounts[i].getBalance();
      totalAssets += currentBalance;
    }
    return totalAssets;
  } else {
    return 0;
  }
};
