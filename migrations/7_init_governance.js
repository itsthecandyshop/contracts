const randomness = artifacts.require("Randomness");
const candyStore = artifacts.require("CandyStore");
const governance = artifacts.require("Governance");

module.exports = async function(deployer, network, accounts) {
    var governanceContract = await governance.deployed();
    var candyStoreContract = await candyStore.deployed();
    var randomnessContract = await randomness.deployed();

    await governanceContract.init(
        candyStoreContract.address,
        randomnessContract.address
    )
};
