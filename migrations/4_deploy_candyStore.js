const candyStore = artifacts.require("CandyStore");
const governance = artifacts.require("Governance");

module.exports = async function(deployer, network, accounts) {
    // const userAddress = accounts[3];
    var governanceContract = await governance.deployed();
    let args = [governanceContract.address]
    await deployer.deploy(candyStore, ...args);
};
