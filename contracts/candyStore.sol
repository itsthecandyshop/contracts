pragma solidity ^0.6.0;

interface GovernanceInterface {
    function lendingProxy() external view returns (address);
    function lotteryDuration() external view returns (uint);
    function admin() external view returns (address);
    function swapProxy() external view returns (address);
    function candyPrice() external view returns (uint);
    function fee() external view returns (uint);
    function lendingId() external view returns (uint);
}

interface TokenInterface {
    function approve(address, uint) external;
    function transfer(address, uint) external;
    function transferFrom(address, address, uint) external;
    function deposit() external payable;
    function withdraw(uint) external;
    function balanceOf(address) external view returns (uint);
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

contract Helpers {
    GovernanceInterface public governanceContract;
}

contract CandyStoreData is Helpers {
    uint public openDraw;

    enum LotteryState {
        draw,
        committed,
        rewarded
    }

    address[] stableCoinsArr;
    mapping (address => bool) public stableCoins;

    mapping (uint => LotteryData) public lottery;

    struct LotteryData {
        address lendingProxy;
        address swapProxy;
        uint lotteryId;
        uint fee;
        uint candyPrice;
        LotteryState state;
        mapping (address => LendingBalance) tokenBalances;
        uint totalCandy;
        uint startTime;
        uint duration;
        bool isDeposited;
    }

    struct LendingBalance {
        uint userAmount;
        uint sponsorAmount;
        uint lendingId;
    }

    mapping (uint => mapping (address => uint)) public lotteryTickets;
    mapping (uint => address[]) public lotteryUsers;

    mapping (uint => mapping (address => SponsorData)) public sponsorBalance;

    struct SponsorData {
        address token;
        uint principalAmt;
    }

    function getUsersLength(uint lotteryId) public view returns(uint) {
        require(openDraw >= lotteryId, "lotteryId-not-vaild");
        return lotteryUsers[lotteryId].length;
    }
}


contract LendingResolvers is CandyStoreData {
    function _deposit(uint lendingId, address token, uint amt) internal returns (uint _depositedAmt) {
        address _target = governanceContract.lendingProxy();
        (bool status, bytes memory returnedData) = _target
            .delegatecall(
            abi.encodeWithSelector(
                bytes4(
                    keccak256(
                        "deposit(uint256,address,uint256)"
                    )
                ),
                lendingId,
                token,
                amt
            )
        );
        require(status, "Delegate/deposit failed");
        _depositedAmt = abi.decode(returnedData, (uint));
    }

    function _withdraw(uint lendingId, address token, uint amt) internal returns (uint withdrawnAmt) {
        address _target = governanceContract.lendingProxy();
        (bool status, bytes memory returnedData) = _target
            .delegatecall(
            abi.encodeWithSelector(
                bytes4(
                    keccak256(
                        "withdraw(uint256,address,uint256)"
                    )
                ),
                lendingId,
                token,
                amt
            )
        );
        require(status, "Delegate/withdraw failed");
        withdrawnAmt = abi.decode(returnedData, (uint));
    }
}

contract Admin is LendingResolvers {
    modifier isAdmin {
        require(msg.sender == governanceContract.admin(), "not-auth");
        _;
    }

    function rewardDraw(uint rewardDrawId) external isAdmin {
        LotteryData storage rewardLottery = lottery[rewardDrawId];

        require(rewardLottery.state == LotteryState.committed, "lottery-not-committed");
        // solium-disable-next-line security/no-block-members
        require(rewardLottery.duration * 2 <= now, "timer-not-over-yet");
        require(rewardLottery.isDeposited, "tokens-not-deposited");

        uint random = 5; // random number b/w [0, lotteryUsers.length];
        address lotteryWinner = lotteryUsers[rewardDrawId][random];
        for (uint i = 0; i < stableCoinsArr.length; i++) {
            address token = stableCoinsArr[i];
            uint lendingId = rewardLottery.tokenBalances[token].lendingId;

            uint totalPrizeAmt = _withdraw(lendingId, token, uint(-1));
            totalPrizeAmt -= rewardLottery.tokenBalances[token].sponsorAmount;

            uint amt = rewardLottery.tokenBalances[token].userAmount;
            require(totalPrizeAmt > amt, "withraw-error");
            TokenInterface(token).transfer(lotteryWinner, totalPrizeAmt);
        }
        rewardLottery.state = LotteryState.rewarded;
        rewardLottery.isDeposited = false;

    }

    function _commit(uint commitDrawId, uint lendingId) internal {
        LotteryData storage commitLottery = lottery[commitDrawId];
        require(commitLottery.state == LotteryState.draw, "lottery-not-committed");
        // solium-disable-next-line security/no-block-members
        require(commitLottery.duration <= now, "timer-not-over-yet");
        require(!commitLottery.isDeposited, "tokens-deposited");

        for (uint i = 0; i < stableCoinsArr.length; i++) {
            address token = stableCoinsArr[i];

            uint totalFeeAmt = commitLottery.tokenBalances[token].userAmount;
            totalFeeAmt += commitLottery.tokenBalances[token].sponsorAmount;

            uint depositedAmt = _deposit(lendingId, token, totalFeeAmt);

            require(depositedAmt >= totalFeeAmt, "deposited-amount-less");
            commitLottery.tokenBalances[token].lendingId = lendingId;
        }
        commitLottery.state = LotteryState.committed;
        commitLottery.isDeposited = true;
    }


    function openNewDraw(uint lendingId) external isAdmin {
        uint currentDraw = openDraw;
        // solium-disable-next-line security/no-block-members
        uint timeNow = now;

        if (currentDraw != 0) {
            _commit(currentDraw, lendingId);
            if (currentDraw >= 2) {
                require(lottery[currentDraw - 1].state == LotteryState.draw, "lottery-not-committed");
            }
        }

        uint nextDraw = currentDraw + 1;
        lottery[nextDraw] = LotteryData({
                lendingProxy: governanceContract.lendingProxy(),
                swapProxy: governanceContract.swapProxy(),
                fee: governanceContract.fee(),
                candyPrice: governanceContract.candyPrice(),
                lotteryId: nextDraw,
                state: LotteryState.draw,
                totalCandy: 0,
                startTime: timeNow,
                isDeposited: false,
                duration: governanceContract.lotteryDuration()
                }
            );
        require(lotteryUsers[openDraw].length == 0, "error-opening-next-draw");

        openDraw++;
    }

    function addStableCoin(address token) external isAdmin {
        require(!stableCoins[token], "Token-already-added");
        stableCoinsArr.push(token);
        stableCoins[token] = true;
    }

    function removeStableCoin(address token) external isAdmin {
        require(stableCoins[token], "Token-not-added");
        bool isFound = false;
        for (uint i = 0; i < stableCoinsArr.length; i++) {
            if (token == stableCoinsArr[i]) {
                isFound = true;
            }
            if (isFound) {
                // TODO - Have to check what will happen at the last elem;
                stableCoinsArr[i] = stableCoinsArr[i + 1];
            }
        }
        stableCoins[token] = false;
    }
}


contract CandyResolver is Admin, DSMath {
    function getCandy(address token, uint amt) internal returns (uint candyAmt) {
        LotteryData storage lotteryDraw = lottery[openDraw];
        uint candyPrice = lotteryDraw.candyPrice;
        candyAmt = mod(amt, candyPrice);
        require(candyAmt == 0 && amt != 0, "amt-is-not-vaild");
        lotteryDraw.tokenBalances[token].userAmount += amt;
        uint candies = amt / candyPrice;
        for (uint i = 0; i < candies; i++) {
            lotteryUsers[openDraw].push(msg.sender);
        }
        lotteryTickets[openDraw][msg.sender] += candies;
        lotteryDraw.totalCandy += candies;
    }
}

contract SponsorResolver is CandyResolver {
    function depositSponsor(address token, uint amt, uint times) external {
        require(sponsorBalance[openDraw][msg.sender].token == address(0), "already-sponsor");
        require(times != 0, "times-invaild");

        sponsorBalance[openDraw][msg.sender].token = token;
        sponsorBalance[openDraw][msg.sender].principalAmt += amt;

        // TODO - swappedAmt => Stable coin amt after the swap if user deposits other than stable coins
        uint swappedAmt = amt;
        require(swappedAmt == 0, "amt-is-not-vaild");
        lottery[openDraw].tokenBalances[token].sponsorAmount = amt;
    }

    // TODO - have to discuss about this.
    // function withdrawSponsor(uint lotteryId, uint amt) external {
    //     require(lotteryId < openDraw, "Lottery-id-not-vaild");
    //     require(sponsorBalance[lotteryId][msg.sender].principalAmt > 0, "already-sponsor");

    //     uint _lendingId = sponsorBalance[lotteryId][msg.sender].lendingId;
    //     address _token = sponsorBalance[lotteryId][msg.sender].token;
    //     uint principalAmt = sponsorBalance[openDraw][msg.sender].principalAmt;
    //     uint _amt = amt > principalAmt ? principalAmt : amt;

    //     //TODO - (Swap to orginal token)

    //     require(_withdrawnAmt >= principalAmt, "withdrawn-more-amt");
    //     sponsorBalance[openDraw][msg.sender].principalAmt -= _withdrawnAmt;
    // }
}

contract SwapResolver is SponsorResolver {
    function _swap(
        uint _swapId,
        address buyToken,
        address sellToken,
        address feeToken,
        uint sellAmt,
        uint buyAmt,
        uint slippage
    ) internal returns (address token, uint _buyAmt, uint _feeAmt) {
        address _target = governanceContract.swapProxy();
        (bool status, bytes memory returnedData) = _target
            .delegatecall(
            abi.encodeWithSelector(
                bytes4(
                    keccak256(
                        "swap(uint256,address,address,address,uint256,uint256,uint256)"
                    )
                ),
                _swapId,
                buyToken,
                sellToken,
                feeToken,
                sellAmt,
                buyAmt,
                slippage
            )
        );
        require(status, "Delegate/swap failed");
        (token, _buyAmt, _feeAmt) = abi.decode(returnedData, (address, uint, uint));
    }

}

contract CandyStore is SwapResolver {
    constructor (address _governance) public {
        governanceContract = GovernanceInterface(_governance);
    }

    // function swap(
    //     uint swapId,
    //     address buyToken,
    //     address sellToken,
    //     address feeToken,
    //     uint sellAmt,
    //     uint buyAmt,
    //     uint slippage
    // ) external {
    //     (uint buyAmt, uint feeAmt) = _swap(
    //             swapId,
    //             buyToken,
    //             sellToken,
    //             feeToken,
    //             sellAmt,
    //             buyAmt,
    //             slippage
    //         );
    //     getCandy(feeToken, feeAmt);
    // }
}
