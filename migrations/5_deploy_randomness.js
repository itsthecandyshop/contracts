const randomness = artifacts.require("Randomness");
const governance = artifacts.require("Governance");

module.exports = async function(deployer, network, accounts) {
    // const userAddress = accounts[3];
    var governanceContract = await governance.deployed();
    let args = [
        governanceContract.address,
        "0xf720CF1B963e0e7bE9F58fd471EFa67e7bF00cfb",
        "0x20fE562d797A42Dcb3399062AE9546cd06f63280"
    ]
    await deployer.deploy(randomness, ...args);
};
