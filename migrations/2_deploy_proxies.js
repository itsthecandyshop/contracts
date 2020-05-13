const lending = artifacts.require("LendingProxy");

module.exports = function(deployer) {
  deployer.deploy(lending);
};
