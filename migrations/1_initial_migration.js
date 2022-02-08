const Migrations = artifacts.require("Migrations");

const { merge } = require('sol-merger');

module.exports = function (deployer) {
  deployer.deploy(Migrations);
};


// Get the merged code as a string
const mergedCode = await merge("./contracts/Reward.sol");
// Print it out or write it to a file etc.
console.log(mergedCode);