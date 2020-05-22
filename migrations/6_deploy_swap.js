const lotterySwap = artifacts.require("LotterySwap");
const governance = artifacts.require("Governance");

module.exports = async function(deployer, network, accounts) {
    var governanceContract = await governance.deployed();
    let args = [
        governanceContract.address,
        "0xf164fC0Ec4E93095b804a4795bBe1e041497b92a", //Uniswap v2 router
        "0xb5e5d0f8c0cba267cd3d7035d6adc8eba7df7cdd" // compound Dai
    ]
    await deployer.deploy(lotterySwap, ...args);
};
