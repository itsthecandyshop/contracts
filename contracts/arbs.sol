pragma solidity ^0.6.2;

import {DSMath} from "./libraries/DSMath.sol";

import {GovernanceInterface} from "./interfaces/governance.sol";
import {CandyStoreInterface} from "./interfaces/candyStore.sol";
import {TokenInterface} from "./interfaces/token.sol";

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

contract Helpers is DSMath {
    address public factory;
    IUniswapV2Router01 public router01;
    GovernanceInterface public governance;
    TokenInterface public stableToken;
    TokenInterface public WETH;

    function getEthToDaiProfit(uint totalProfit) public view returns(uint requiredAmt){
        uint candyPrice = governance.candyPrice();
        uint candyProfit = totalProfit * 2 / 10;
        address[] memory paths = new address[](2);
        paths[0] = router01.WETH();
        paths[1] = address(stableToken);
        uint[] memory amts = router01.getAmountsOut(
            candyProfit,
            paths
        );

        require(amts[1] >= candyPrice, "CS: Total amount was less than candy price");
        uint extraAmount = mod(amts[1], candyPrice);
        requiredAmt = extraAmount > (candyPrice * 6 / 10) ? amts[1] + (candyPrice - extraAmount) : amts[1] - extraAmount;
    }

    function getEthToDaiFee(uint totalAmt) public view returns(uint requiredAmt){
        uint candyFee = governance.fee();
        uint candyProfit = wmul(totalAmt, candyFee);
        uint candyPrice = governance.candyPrice();
        address[] memory paths = new address[](2);
        paths[0] = router01.WETH();
        paths[1] = address(stableToken);
        uint[] memory amts = router01.getAmountsOut(
            candyProfit,
            paths
        );

        require(amts[1] >= candyPrice, "CS: Total amount was less than candy price");
        uint extraAmount = mod(amts[1], candyPrice);
        requiredAmt = extraAmount > (candyPrice * 8 / 10) ? amts[1] + (candyFee - extraAmount) : amts[1] - extraAmount;
    }

    function getTokenToDaiProfit(address token, uint totalProfit) public view returns(uint requiredAmt){
        uint candyPrice = governance.candyPrice();
        uint candyProfit = totalProfit * 2 / 10;
        address[] memory paths = new address[](2);
        paths[0] = token;
        paths[1] = address(stableToken);
        uint[] memory amts = router01.getAmountsOut(
            candyProfit,
            paths
        );

        require(amts[1] >= candyPrice, "CS: Total profit was less than candy price");
        uint extraAmount = mod(amts[1], candyPrice);
        requiredAmt = extraAmount > (candyPrice * 6 / 10) ? amts[1] + (candyPrice - extraAmount) : amts[1] - extraAmount;
    }

    function getTokenToDaiFee(address token, uint totalAmt) public view returns(uint requiredAmt){
        uint candyFee = governance.fee();
         uint candyProfit = wmul(totalAmt, candyFee);
        uint candyPrice = governance.candyPrice();
        address[] memory paths = new address[](2);
        paths[0] = token;
        paths[1] = address(stableToken);
        uint[] memory amts = router01.getAmountsOut(
            candyProfit,
            paths
        );

        require(amts[1] >= candyPrice, "CS: Total amount was less than candy price");
        uint extraAmount = mod(amts[1], candyPrice);
        requiredAmt = extraAmount > (candyPrice * 8 / 10) ? amts[1] + (candyPrice - extraAmount) : amts[1] - extraAmount;
    }
}

contract ArbsResolver is Helpers {
    event LogLeftAmount(uint amt);

    modifier isArbs {
        require(msg.sender == governance.candyStoreArbs(), "not-candyStoreArbs-address");
        _;
    }

    function swapEthToDai(
        address payable user,
        uint totalAmt,
        bool isFee,
        bool isIn
    ) public payable isArbs returns(uint leftAmt) {
        require(totalAmt == msg.value, "arbs: msg.value is not same");
        address[] memory paths = new address[](2);
        uint daiAmt;
        if (isFee) {
            daiAmt = getEthToDaiFee(totalAmt);
        } else {
            daiAmt = getEthToDaiProfit(totalAmt);
        }
        paths[0] = router01.WETH();
        paths[1] = address(stableToken);
        uint intialBal = address(this).balance;
        router01.swapETHForExactTokens.value(totalAmt)(
            daiAmt,
            paths,
            address(this),
            now + 1 days
        );
        uint finialBal = address(this).balance;
        stableToken.approve(governance.candyStore(), daiAmt);
        CandyStoreInterface(governance.candyStore()).buyCandy(
            address(stableToken),
            daiAmt,
            user, //TODO - have to set `to` address,
            isIn
        );
        uint usedAmt = sub(intialBal, finialBal);
        leftAmt = sub(totalAmt, usedAmt); // TODO -check this.
        if (isFee) {
            user.transfer(leftAmt);
        } else {
            msg.sender.transfer(leftAmt);
        }
        emit LogLeftAmount(leftAmt);
    }

    function swapTokenToDai(
        address user,
        address token,
        uint totalAmt,
        bool isFee,
        bool isIn
    ) public isArbs returns(uint leftAmt) {
        TokenInterface tokenContract = TokenInterface(token);
        tokenContract.transferFrom(msg.sender, address(this), totalAmt);
        uint daiAmt;
        if (isFee) {
            daiAmt = getTokenToDaiFee(token, totalAmt);
        } else {
            daiAmt = getTokenToDaiProfit(token, totalAmt);
        }
        address[] memory paths = new address[](2);
        paths[0] = token;
        paths[1] = address(stableToken);
        uint intialBal = tokenContract.balanceOf(address(this));
        router01.swapTokensForExactTokens(
            daiAmt,
            totalAmt,
            paths,
            address(this),
            now + 1 days
        );
        uint finialBal = tokenContract.balanceOf(address(this));
        stableToken.approve(governance.candyStore(), daiAmt);
        CandyStoreInterface(governance.candyStore()).buyCandy(
            address(stableToken),
            daiAmt,
            user, //TODO - have to set `to` address,
            isIn
        );
        uint usedAmt = sub(intialBal, finialBal);
        leftAmt = sub(totalAmt, usedAmt); // TODO -check this.
        if (isFee) {
            tokenContract.transfer(user, totalAmt);
        } else {
            tokenContract.transfer(msg.sender, totalAmt);
        }
        emit LogLeftAmount(leftAmt);
    }
}

contract Swap is Helpers {
    constructor(
        address router,
        address _governance,
        address token
    ) public {
        router01 = IUniswapV2Router01(router);
        factory = router01.factory();
        WETH = TokenInterface(IUniswapV2Router01(router).WETH());
        governance = GovernanceInterface(_governance);
        stableToken = TokenInterface(token);
    }
}