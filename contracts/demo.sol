pragma solidity ^0.6.2;
pragma experimental ABIEncoderV2;

interface IUniswapV1Factory {
    function getExchange(address) external view returns (address);
    function createExchange(address) external returns (address);
}

interface IUniswapV2Factory {
  function createPair(address tokenA, address tokenB) external returns (address pair);
}

library SafeMath {
    uint constant WAD = 10 ** 18;

    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, 'ds-math-add-overflow');
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, 'ds-math-sub-underflow');
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, 'ds-math-mul-overflow');
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "modulo-by-zero");
        return a % b;
    }

    function wmul(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, y), WAD / 2) / WAD;
    }

    function wdiv(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, WAD), y / 2) / y;
    }

}

contract ERC20 {
    using SafeMath for uint256;

    string public constant name = 'Test Token';
    string public constant symbol = 'TT';
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    bytes32 public DOMAIN_SEPARATOR;
    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    mapping(address => uint256) public nonces;

    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

    constructor(uint256 _totalSupply) public {
        uint256 chainId;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            chainId := chainid()
        }
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
                keccak256(bytes(name)),
                keccak256(bytes('1')),
                chainId,
                address(this)
            )
        );
        _mint(msg.sender, _totalSupply);
    }

    function _mint(address to, uint256 value) internal {
        totalSupply = totalSupply.add(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint256 value) internal {
        balanceOf[from] = balanceOf[from].sub(value);
        totalSupply = totalSupply.sub(value);
        emit Transfer(from, address(0), value);
    }

    function _approve(
        address owner,
        address spender,
        uint256 value
    ) private {
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _transfer(
        address from,
        address to,
        uint256 value
    ) private {
        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(from, to, value);
    }

    function approve(address spender, uint256 value) external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool) {
        if (allowance[from][msg.sender] != uint256(-1)) {
            allowance[from][msg.sender] = allowance[from][msg.sender].sub(value);
        }
        _transfer(from, to, value);
        return true;
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(deadline >= block.timestamp, 'EXPIRED');
        bytes32 digest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline))
            )
        );
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == owner, 'INVALID_SIGNATURE');
        _approve(owner, spender, value);
    }
}

contract Demo {
    address public uniswapV1 = 0x9c83dCE8CA20E9aAF9D3efc003b2ea62aBC08351;
    address public uniswapV2 = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address public router = 0xf164fC0Ec4E93095b804a4795bBe1e041497b92a;
    address public WETH = 0xc778417E063141139Fce010982780140Aa0cD5Ab;
    struct TokenData {
        address token;
        address v1;
        address v2;
    }

    mapping (uint => TokenData) public exchangeAddress;
    uint public latestExchange;

    function newToken() external {
        latestExchange++;
        ERC20 tokenAddr = new ERC20(10**24);
        address exchangeV1 = IUniswapV1Factory(uniswapV1).createExchange(address(tokenAddr));
        address exchangeV2 = IUniswapV2Factory(uniswapV2).createPair(WETH, address(tokenAddr));
        exchangeAddress[latestExchange] = TokenData(
            address(tokenAddr),
            exchangeV1,
            exchangeV2
        );
    }

    function getLatest() external view returns (TokenData memory){
       return exchangeAddress[latestExchange];
    }

}