pragma solidity ^0.6.0;

interface TokenInterface {
    function allowance(address, address) external view returns (uint);
    function balanceOf(address) external view returns (uint);
    function approve(address, uint) external;
    function transfer(address, uint) external returns (bool);
    function transferFrom(address, address, uint) external returns (bool);
}

contract DSMath {

    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, "math-not-safe");
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, "math-not-safe");
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, "sub-overflow");
    }

    uint constant WAD = 10 ** 18;

    function wmul(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, y), WAD / 2) / WAD;
    }

    function wdiv(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, WAD), y / 2) / y;
    }

}


contract Helpers is DSMath {
    /**
     * @dev Return ethereum address
     */
    function getAddressETH() internal pure returns (address) {
        return 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE; // ETH Address
    }
}


contract UniswapHelpers is Helpers {
    /**
     * @dev Return Uniswap Address
     */
    function getUniswapAddress() internal pure returns (address) {
        return 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B; // TODO - Dummp address for now.
    }
}


contract UniswapResolver is UniswapHelpers {
    function uniswap(
        address buyToken,
        address sellToken,
        address feeToken,
        uint sellAmt,
        uint buyAmt,
        uint slippage
    ) internal returns (uint _buyAmt, uint _feeAmt) {
        uint _sellAmt = sellAmt;
        // SWAP LOGIC
        // RETURN _buyAmt
    }
}


contract Proxy is UniswapResolver {
    string public name = "uniswap";

    function swap(
        uint swapId,
        address buyToken,
        address sellToken,
        address feeToken,
        uint sellAmt,
        uint buyAmt,
        uint slippage
    ) external payable returns (uint _buyAmt, uint _feeAmt) {
        if (swapId == 1) {
            (_buyAmt, _feeAmt) = uniswap(
                buyToken,
                sellToken,
                feeToken,
                sellAmt,
                buyAmt,
                slippage
            );
        } else if (swapId == 2) {
            // swap with other dex
        } else {
            revert("not-vaild-swapId");
        }
    }
}