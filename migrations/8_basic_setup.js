const randomness = artifacts.require("Randomness");
const candyStore = artifacts.require("CandyStore");
const governance = artifacts.require("Governance");

module.exports = async function(deployer, network, accounts) {
    var governanceContract = await governance.deployed();
    var candyStoreContract = await candyStore.deployed();
    var randomnessContract = await randomness.deployed();
    
    await candyStoreContract.addStableCoin(
        "0xb5e5d0f8c0cba267cd3d7035d6adc8eba7df7cdd",
        "1"
    );

    await candyStoreContract.openNewDraw();
};
