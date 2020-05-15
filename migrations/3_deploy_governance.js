const governanceContract = artifacts.require("Governance");
const lending = artifacts.require("LendingProxy");

module.exports = async function(deployer, network, accounts) {
    var lendingContract = await lending.deployed();

    let args = [
        2 * 10 ** 15,
        String(10 ** 17),
        30,
        lendingContract.address,
        lendingContract.address
    ]
    await deployer.deploy(governanceContract, ...args);
};
