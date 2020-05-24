pragma solidity ^0.6.2;

interface IUniswapV1Factory {
    function getExchange(address) external view returns (address);
    function createExchange(address) external returns (address);
}

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV1Exchange {
    function addLiquidity(uint256 minLiquidity, uint256 maxTokens, uint256 deadline) external payable returns (uint256);
    function removeLiquidity(
        uint256 amount,
        uint256 minEth,
        uint256 minTokens,
        uint256 deadline
        ) external returns (uint256, uint256);

    function totalSupply() external view returns (uint);
    function getEthToTokenInputPrice(uint eth_sold) external view returns (uint);
    function getEthToTokenOutputPrice(uint tokens_bought) external view returns (uint);
    function getTokenToEthInputPrice(uint tokens_sold) external view returns (uint);
    function getTokenToEthOutputPrice(uint eth_bought) external view returns (uint);
}

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

interface TokenInterface {
    function balanceOf(address) external view returns (uint);
    function decimals() external view returns (uint);
}

contract DSMath {
    uint constant WAD = 10 ** 18;

    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, "math-not-safe");
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, "math-not-safe");
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, "sub-overflow");
    }

    function wmul(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, y), WAD / 2) / WAD;
    }

    function wdiv(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, WAD), y / 2) / y;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "modulo-by-zero");
        return a % b;
    }
}

contract Arbs is DSMath {

    IUniswapV1Factory public uniswapV1 = IUniswapV1Factory(0x9c83dCE8CA20E9aAF9D3efc003b2ea62aBC08351);
    IUniswapV2Factory public uniswapV2 = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
    IUniswapV2Router01 public router = IUniswapV2Router01(0xf164fC0Ec4E93095b804a4795bBe1e041497b92a);
    TokenInterface public WETH = TokenInterface(0xc778417E063141139Fce010982780140Aa0cD5Ab);

   function getBalance(address token, uint tokenSold, bool EtoT) public view returns(
       uint ethBalanceV1,
       uint tokenBalaceV1,
       uint ethBalanceV2,
       uint tokenBalaceV2
    ) {
       address exchangeV1 = uniswapV1.getExchange(token);
       address exchangeV2 = uniswapV2.getPair(token, address(WETH));
       TokenInterface tokenContract = TokenInterface(token);
       ethBalanceV1 = exchangeV1.balance;
       tokenBalaceV1 = tokenContract.balanceOf(exchangeV1);
       ethBalanceV2 = WETH.balanceOf(exchangeV2);
       tokenBalaceV2 = tokenContract.balanceOf(exchangeV2);

       if (EtoT) {
           uint _t1 = IUniswapV1Exchange(exchangeV1).getEthToTokenInputPrice(tokenSold);
           ethBalanceV1 = add(ethBalanceV1, tokenSold);
           tokenBalaceV1 = sub(tokenBalaceV1, _t1);
       } else {
           uint _e1 = IUniswapV1Exchange(exchangeV1).getTokenToEthInputPrice(tokenSold);
           tokenBalaceV1 = add(tokenBalaceV1, tokenSold);
           ethBalanceV1 = sub(ethBalanceV1, _e1);
       }
   }
}