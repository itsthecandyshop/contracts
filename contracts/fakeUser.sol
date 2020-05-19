pragma solidity ^0.6.2;

// interface compound {
//     function AllocateTo(address, uint);
// }

interface TokenInterface {
    function approve(address, uint) external;
    function transfer(address, uint) external;
    function transferFrom(address, address, uint) external;
    function deposit() external payable;
    function withdraw(uint) external;
    function balanceOf(address) external view returns (uint);
}

interface AaveTokenInterface {
    function mint(uint256 value) external returns (bool);
}

interface CandyStoreInterface {
    function swap(address feeToken, uint sellAmt) external;
    function depositSponsor(address token, uint amt) external;
}

contract User {
    address public aaveDai = 0xf80A32A835F79D7787E8a8ee5721D0fEaFd78108;

    constructor () public {
        AaveTokenInterface(aaveDai).mint(10**24);
    }

    function swap(address candyStoreAddr, uint amt) external {
        TokenInterface(aaveDai).approve(candyStoreAddr, 2**255);
        CandyStoreInterface(candyStoreAddr).swap(aaveDai, amt);
    }
}