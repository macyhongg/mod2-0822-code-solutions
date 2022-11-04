process.on('unhandledRejection', () => {});

module.exports = function takeAChance(name) {
  return new Promise((resolve, reject) => {
    setTimeout(() => {
      Math.random() <= 0.5
        ? resolve(`Hooray! You're so lucky, ${name}!`)
        : reject(new Error(`It's just bad luck, ${name}.`));
    }, 2000);
  });
};
