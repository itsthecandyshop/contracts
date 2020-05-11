pragma solidity ^0.6.0;

interface CTokenInterface {
    function mint(uint mintAmount) external returns (uint);
    function redeem(uint redeemTokens) external returns (uint);
    function borrow(uint borrowAmount) external returns (uint);
    function repayBorrow(uint repayAmount) external returns (uint);
    function repayBorrowBehalf(address borrower, uint repayAmount) external returns (uint); // For ERC20
    function liquidateBorrow(address borrower, uint repayAmount, address cTokenCollateral) external returns (uint);

    function borrowBalanceCurrent(address account) external returns (uint);
    function redeemUnderlying(uint redeemAmount) external returns (uint);
    function exchangeRateCurrent() external returns (uint);

    function balanceOf(address owner) external view returns (uint256 balance);
}

interface AaveContract {
    function deposit(address _reserve, uint256 _amount, uint16 _referralCode) external payable;
    function redeemUnderlying(
        address _reserve,
        address payable _user,
        uint256 _amount,
        uint256 _aTokenBalanceAfterRedeem
    ) external;
    function setUserUseReserveAsCollateral(address _reserve, bool _useAsCollateral) external;
    function getUserReserveData(address _reserve, address _user) external view returns (
            uint256 currentATokenBalance,
            uint256 currentBorrowBalance,
            uint256 principalBorrowBalance,
            uint256 borrowRateMode,
            uint256 borrowRate,
            uint256 liquidityRate,
            uint256 originationFee,
            uint256 variableBorrowIndex,
            uint256 lastUpdateTimestamp,
            bool usageAsCollateralEnabled
        );
}


interface CETHInterface {
    function mint() external payable;
    function repayBorrow() external payable;
    function repayBorrowBehalf(address borrower) external payable;
    function liquidateBorrow(address borrower, address cTokenCollateral) external payable;
}

interface TokenInterface {
    function allowance(address, address) external view returns (uint);
    function balanceOf(address) external view returns (uint);
    function approve(address, uint) external;
    function transfer(address, uint) external returns (bool);
    function transferFrom(address, address, uint) external returns (bool);
}

interface ComptrollerInterface {
    function enterMarkets(address[] calldata cTokens) external returns (uint[] memory);
    function exitMarket(address cTokenAddress) external returns (uint);
    function getAssetsIn(address account) external view returns (address[] memory);
    function getAccountLiquidity(address account) external view returns (uint, uint, uint);
}

interface Mapping {
    function cTokenMapping(address) external view returns (address);
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


    /**
     * @dev Return Mapping Addresses
     */
    function getMappingAddr() internal pure returns (address) {
        return 0xe81F70Cc7C0D46e12d70efc60607F16bbD617E88; // Mapping Address
    }
}


contract CompoundHelpers is Helpers {
    /**
     * @dev Return Compound Comptroller Address
     */
    function getComptrollerAddress() internal pure returns (address) {
        return 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;
    }

    /**
     * @dev enter compound market
     */
    function enterMarket(address cToken) internal {
        ComptrollerInterface troller = ComptrollerInterface(getComptrollerAddress());
        address[] memory markets = troller.getAssetsIn(address(this));
        bool isEntered = false;
        for (uint i = 0; i < markets.length; i++) {
            if (markets[i] == cToken) {
                isEntered = true;
            }
        }
        if (!isEntered) {
            address[] memory toEnter = new address[](1);
            toEnter[0] = cToken;
            troller.enterMarkets(toEnter);
        }
    }
}


contract CompoundResolver is CompoundHelpers {
    event LogDepositCompound(address indexed token, address cToken, uint256 tokenAmt);
    event LogWithdrawCompound(address indexed token, address cToken, uint256 tokenAmt);

    /**
     * @dev Deposit ETH/ERC20_Token.
     * @param token token address to deposit.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param amt token amount to deposit.
    */
    function compoundDeposit(address token, uint amt) internal returns (uint _amt) {
        _amt = amt;
        address cToken = Mapping(getMappingAddr()).cTokenMapping(token);
        enterMarket(cToken);
        if (token == getAddressETH()) {
            require(_amt == msg.value, "not-enought-eth");
            CETHInterface(cToken).mint.value(_amt)();
        } else {
            TokenInterface tokenContract = TokenInterface(token);
            tokenContract.approve(cToken, _amt);
            require(CTokenInterface(cToken).mint(_amt) == 0, "mint-failed");
        }

        emit LogDepositCompound(token, cToken, _amt);
    }

    /**
     * @dev Withdraw ETH/ERC20_Token.
     * @param token token address to withdraw.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param amt token amount to withdraw.
    */
    function compoundWithdraw(address token, uint amt) internal returns (uint _amt) {
        _amt = amt;
        address cToken = Mapping(getMappingAddr()).cTokenMapping(token);
        CTokenInterface cTokenContract = CTokenInterface(cToken);
        if (_amt == uint(-1)) {
            TokenInterface tokenContract = TokenInterface(token);
            uint initialBal = token == getAddressETH() ? address(this).balance : tokenContract.balanceOf(address(this));
            require(cTokenContract.redeem(cTokenContract.balanceOf(address(this))) == 0, "full-withdraw-failed");
            uint finalBal = token == getAddressETH() ? address(this).balance : tokenContract.balanceOf(address(this));
            _amt = finalBal - initialBal;
        } else {
            require(cTokenContract.redeemUnderlying(_amt) == 0, "withdraw-failed");
        }

        emit LogWithdrawCompound(token, cToken, _amt);
    }
}

contract AaveHelpers is CompoundResolver {
    /**
     * @dev get Aave Address
    */
    function getAaveAddress() internal pure returns (address) {
        return 0x398eC7346DcD622eDc5ae82352F02bE94C62d119;
    }

    /**
     * @dev get Aave Address
    */
    function getAaveProviderAddress() internal pure returns (address) {
        return 0x398eC7346DcD622eDc5ae82352F02bE94C62d119;
    }

    function getWithdrawBalance(address token) internal view returns (uint bal) {
        (bal, , , , , , , , , ) = AaveContract(getAaveProviderAddress()).getUserReserveData(token, msg.sender);
    }
}

contract AaveResolver is AaveHelpers {
    event LogDepositAave(address indexed token, uint256 tokenAmt);
    event LogWithdrawAave(address indexed token, uint256 tokenAmt);

    /**
     * @dev Deposit ETH/ERC20
     */
    function aaveDeposit(address token, uint amt) internal returns (uint _amt) {
        _amt = amt;
        AaveContract aave = AaveContract(getAaveAddress());

        uint ethAmt;
        if (token == getAddressETH()) {
            require(_amt == msg.value, "not-enought-eth");
            ethAmt = _amt;
        } else {
            TokenInterface tokenContract = TokenInterface(token);
            tokenContract.approve(getAaveProviderAddress(), _amt);
        }

        aave.setUserUseReserveAsCollateral(token, true);
        aave.deposit.value(ethAmt)(token, amt, 0); // TODO - need to set referralCode;

       emit LogDepositAave(token, _amt);
    }


    function aaveWithdraw(address token, uint amt) internal returns (uint _amt) {
        _amt = amt;

        AaveContract aave = AaveContract(getAaveAddress());
        uint totalBal = getWithdrawBalance(token);

        _amt = _amt == uint(-1) ? totalBal : _amt;
        uint _amtLeft = sub(totalBal, _amt);

        uint initialBal = token == getAddressETH() ? address(this).balance : TokenInterface(token).balanceOf(address(this));
        aave.redeemUnderlying(
            token,
            payable(address(this)),
            _amt,
            _amtLeft
        );
        uint finialBal = token == getAddressETH() ? address(this).balance : TokenInterface(token).balanceOf(address(this));
        uint withdrawnAmt = sub(finialBal, initialBal);
        require(withdrawnAmt >= _amt, "withdraw-error");

        emit LogWithdrawAave(token, _amt);
    }
}

contract Proxy is AaveResolver {
    string public name = "Compound-Aave";

    function deposit(uint lendingId, address token, uint256 amount) external payable returns (uint depositAmt) {
        if (lendingId == 1) {
            depositAmt = compoundDeposit(token, amount);
        } else if (lendingId == 2) {
            depositAmt = aaveDeposit(token, amount);
        } else {
            revert("not-vaild-lendingId");
        }
    }

    function withdraw(uint lendingId, address token, uint256 amount) external returns (uint withdrawAmt) {
        if (lendingId == 1) {
            withdrawAmt = compoundWithdraw(token, amount);
        } else if (lendingId == 2) {
            withdrawAmt = aaveWithdraw(token, amount);
        } else {
            revert("not-vaild-lendingId");
        }
    }
}