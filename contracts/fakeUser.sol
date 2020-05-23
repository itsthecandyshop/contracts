pragma solidity ^0.6.2;

interface compoundTokenInterface {
    function allocateTo(address _owner, uint256 value) external;
}

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
   function buyCandy(
        address token,
        uint amount,
        address to,
        bool lottery
    ) external returns(uint candies);
    function depositSponsor(address token, uint amt) external;
}

contract User {
    address public aaveDai = 0xf80A32A835F79D7787E8a8ee5721D0fEaFd78108;
    address public compoundDai = 0xB5E5D0F8C0cbA267CD3D7035d6AdC8eBA7Df7Cdd;

    constructor () public {
        AaveTokenInterface(aaveDai).mint(10**24);
        compoundTokenInterface(compoundDai).allocateTo(address(this), 10**24);
    }

    function swap1(address candyStoreAddr, uint amt, address x) external {
        TokenInterface(aaveDai).approve(candyStoreAddr, 2**255);
        CandyStoreInterface(candyStoreAddr).buyCandy(aaveDai, amt, x, true);
    }

    function swap2(address candyStoreAddr, uint amt, address x) external {
        TokenInterface(compoundDai).approve(candyStoreAddr, 2**255);
        CandyStoreInterface(candyStoreAddr).buyCandy(compoundDai, amt, x, true);
    }
    

    function getToken(uint id, address user) external {
        if( id == 1) {
            compoundTokenInterface(compoundDai).allocateTo(address(this), 10**24);
            TokenInterface(compoundDai).transfer(user, 10**24);
        } else {
            AaveTokenInterface(aaveDai).mint(10**24);
            TokenInterface(aaveDai).transfer(user, 10**24);
        }
    }

    function deposit(uint id, address candyStoreAddr, uint amt) external {
        if( id == 1) {
            compoundTokenInterface(compoundDai).allocateTo(address(this), 10**24);
            TokenInterface(compoundDai).approve(candyStoreAddr, 2**255);
            CandyStoreInterface(candyStoreAddr).depositSponsor(compoundDai, amt);
        } else {
            AaveTokenInterface(aaveDai).mint(10**24);
            TokenInterface(compoundDai).approve(candyStoreAddr, 2**255);
            CandyStoreInterface(candyStoreAddr).depositSponsor(aaveDai, amt);
        }
    }
}