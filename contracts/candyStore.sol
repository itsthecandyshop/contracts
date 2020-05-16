pragma solidity ^0.6.0;

import {DSMath} from "./libraries/DSMath.sol";

import {GovernanceInterface} from "./interfaces/governance.sol";
import {TokenInterface} from "./interfaces/token.sol";

contract CandyStoreData {
    GovernanceInterface public governanceContract;

    // Current Lottery Id to buy candy.
    uint public openDraw;

    // State of the lottery.
    enum LotteryState {
        draw,
        committed,
        rewarded
    }

    // Array of all the enabled Stable Tokens.
    address[] public stableCoinsArr;
    // Mapping of stable token => enabled/disabled.
    mapping (address => bool) public stableCoins;

    // Mapping lottery id => details of the lottery.
    mapping (uint => LotteryData) public lottery;

    struct LotteryData {
        address lendingProxy; // Proxy contract for interaction with Lending protocols.
        address swapProxy; // Swap contract for interaction with Dex.
        uint lotteryId; // Lottery Id.
        uint fee; // Swapping fee to buy candy.
        uint candyPrice; // Price of candy.
        LotteryState state; // State of the lottery.
        mapping (address => LendingBalance) tokenBalances; // Token balances of each stable token.
        uint totalCandy; // Total candies distributed.
        uint startTime; // Start time of Lottery.
        uint duration; // Duration of each phase in the lottery.
    }

    struct LendingBalance {
        uint userAmount; // token amount collected from fee/arbs profit from swapping.
        uint sponsorAmount; // token amount deposited by sponsor.
        uint lendingId; // To determine in which lending protocol Token has been deposited in committed phase.
    }

    // Mapping of lottery id => user address => no of candies
    mapping (uint => mapping (address => uint)) public lotteryTickets;
    // Mapping of lottery id => user address of each candy in sequence.
    mapping (uint => address[]) public lotteryUsers;

    // Mapping of lottery id => sponsor address => Token details
    mapping (uint => mapping (address => SponsorData)) public sponsorBalance;
    // Mapping of lottery id => all sponsor addresses
    mapping (uint => address[]) public lotterySponsors;

    struct SponsorData {
        address token;
        uint principalAmt;
    }

    /**
     * @dev Total no of stable Tokens enabled.
    */
    function getStableCoinsLength() public view returns(uint) {
        return stableCoinsArr.length;
    }

    /**
     * @dev Total no of user address of each candy.
     * @param lotteryId Lottery id.
    */
    function getUsersLength(uint lotteryId) public view returns(uint) {
        require(openDraw >= lotteryId, "lotteryId-not-vaild");
        return lotteryUsers[lotteryId].length;
    }

    /**
     * @dev Total no of sponsor.
     * @param lotteryId Lottery id.
    */
    function totalSponsors(uint lotteryId) public view returns(uint) {
        return lotterySponsors[lotteryId].length;
    }

    struct Assets {
        address token;
        uint amount;
    }

    /**
     * @dev Assets locked in a specific lottery.
     * @param lotteryId Lottery id.
     * @param token token address.
    */
    function getAssetLocked(uint lotteryId, address token) public view returns(uint _amt, uint _lendingId) {
        require(openDraw >= lotteryId, "lotteryId-not-vaild");
        LotteryData storage _lottery = lottery[lotteryId];
        _amt = _lottery.tokenBalances[token].userAmount;
        _amt += _lottery.tokenBalances[token].sponsorAmount;
        _lendingId = _lottery.tokenBalances[token].lendingId;
    }
}


contract LendingResolvers is CandyStoreData {
    /**
     * @dev Deposit in lending protocol using lending proxy contract.
     * @param lendingId Lending protcol Id to deposit.
     * @param token token address.
     * @param amt token amount.
    */
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

    /**
     * @dev Withdraw from lending protocol using lending proxy contract.
     * @param lendingId Lending protcol Id to withdraw.
     * @param token token address.
     * @param amt token amount.
    */
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

    /**
     * @dev Reward the winner of the lottery.
     * @param rewardDrawId Reward Lottery id.
    */
    function rewardDraw(uint rewardDrawId) external isAdmin {
        LotteryData storage rewardLottery = lottery[rewardDrawId];

        require(rewardLottery.state == LotteryState.committed, "lottery-not-committed");
        uint endTime = rewardLottery.startTime + rewardLottery.duration * 2;
        // solium-disable-next-line security/no-block-members
        require(endTime <= now, "timer-not-over-yet");

        uint random = 5; // random number b/w [0, lotteryUsers.length];
        address lotteryWinner = lotteryUsers[rewardDrawId][random]; // Lottery Winner.

        // Withdraw assets from the lending protocol and reward the winner address.
        for (uint i = 0; i < stableCoinsArr.length; i++) {
            address token = stableCoinsArr[i];
            uint lendingId = rewardLottery.tokenBalances[token].lendingId;

            uint totalPrizeAmt = _withdraw(lendingId, token, uint(-1));
            totalPrizeAmt -= rewardLottery.tokenBalances[token].sponsorAmount;

            uint amt = rewardLottery.tokenBalances[token].userAmount;
            require(totalPrizeAmt > amt, "withraw-error");
            TokenInterface(token).transfer(lotteryWinner, totalPrizeAmt);
        }

        address[] storage sponsors = lotterySponsors[rewardDrawId];
        // Transfer back the sponsor pricipal amount.
        for (uint i = 0; i < sponsors.length; i++) {
            address sponsor = sponsors[i];
            uint amt = sponsorBalance[rewardDrawId][sponsor].principalAmt;
            address token = sponsorBalance[rewardDrawId][sponsor].token;
            require(TokenInterface(token).balanceOf(address(this)) >= amt, "no-sufficient-sponsor-amt.");
            TokenInterface(token).transfer(sponsor, amt);
        }

        rewardLottery.state = LotteryState.rewarded;
    }

    /**
     * @dev Deposit assets locked for a specific lottery and earn interest.
     * @param commitDrawId commit lottery id.
     * @param lendingId lending proctocol id.
    */
    function _commit(uint commitDrawId, uint lendingId) internal {
        LotteryData storage commitLottery = lottery[commitDrawId];
        require(commitLottery.state == LotteryState.draw, "lottery-committed/rewarded");

        uint endTime = commitLottery.startTime + commitLottery.duration;
        // solium-disable-next-line security/no-block-members
        require(endTime <= now, "timer-not-over-yet");

        // Deposit assets in lending protocol.
        for (uint i = 0; i < stableCoinsArr.length; i++) {
            address token = stableCoinsArr[i];

            uint totalFeeAmt = commitLottery.tokenBalances[token].userAmount;
            totalFeeAmt += commitLottery.tokenBalances[token].sponsorAmount;

            uint depositedAmt = _deposit(lendingId, token, totalFeeAmt);

            require(depositedAmt >= totalFeeAmt, "deposited-amount-less");
            commitLottery.tokenBalances[token].lendingId = lendingId;
        }
        commitLottery.state = LotteryState.committed;
    }


    /**
     * @dev Create new lottery and commit the current on going lottery.
     * @param lendingId lending proctocol id.
    */
    function openNewDraw(uint lendingId) external isAdmin {
        uint currentDraw = openDraw;
        // solium-disable-next-line security/no-block-members
        uint timeNow = now;

        if (currentDraw != 0) {
            // Commit current lottery.
            _commit(currentDraw, lendingId);
            if (currentDraw >= 2) {
                require(lottery[currentDraw - 1].state == LotteryState.rewarded, "lottery-not-committed");
            }
        }

        // Open new lottery
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
                duration: governanceContract.lotteryDuration()
                }
            );
        require(lotteryUsers[nextDraw].length == 0, "error-opening-next-draw");

        openDraw++;
    }

    /**
     * @dev Enable stable token.
     * @param token token address.
    */
    function addStableCoin(address token) external isAdmin {
        require(!stableCoins[token], "Token-already-added");
        stableCoinsArr.push(token);
        stableCoins[token] = true;
    }

    /**
     * @dev disable stable token.
     * @param token token address.
    */
    function removeStableCoin(address token) external isAdmin {
        require(stableCoins[token], "Token-not-added");
        bool isFound = false;
        for (uint i = 0; i < stableCoinsArr.length; i++) {
            if (token == stableCoinsArr[i]) {
                isFound = true;
            }
            if (isFound) {
                if (stableCoinsArr.length - 1 == i) {
                    delete stableCoinsArr[i];
                } else {
                     stableCoinsArr[i] = stableCoinsArr[i + 1];
                }
            }
        }
        stableCoins[token] = false;
    }
}


contract CandyResolver is Admin, DSMath {
    /**
     * @dev mint candy.
     * @param token token address.
     * @param user candy receiver.
     * @param amt token amount.
    */
    function mintCandy(address token, address user, uint amt) internal returns (uint candyAmt) {
        require(user != address(0), "Not-vaild-user-address");
        LotteryData storage lotteryDraw = lottery[openDraw];
        uint candyPrice = lotteryDraw.candyPrice;
        candyAmt = mod(amt, candyPrice);
        require(candyAmt == 0 && amt != 0, "amt-is-not-vaild");
        lotteryDraw.tokenBalances[token].userAmount += amt;
        uint candies = amt / candyPrice;
        for (uint i = 0; i < candies; i++) {
            lotteryUsers[openDraw].push(user);
        }
        lotteryTickets[openDraw][user] += candies;
        lotteryDraw.totalCandy += candies;
    }
}

contract SponsorResolver is CandyResolver {
    /**
     * @dev deposit sponsor amount.
     * @param token token address.
     * @param amt token amount.
    */
    function depositSponsor(address token, uint amt) external {
        require(amt != 0, "amt-is-not-vaild");
        require(stableCoins[token], "token-not-allowed!");

        sponsorBalance[openDraw][msg.sender].token = token;
        if (sponsorBalance[openDraw][msg.sender].principalAmt == 0) {
            lotterySponsors[openDraw].push(msg.sender);
        }
        sponsorBalance[openDraw][msg.sender].principalAmt += amt;
        TokenInterface(token).transferFrom(msg.sender, address(this), amt);

        lottery[openDraw].tokenBalances[token].sponsorAmount += amt;
    }
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
