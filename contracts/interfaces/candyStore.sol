pragma solidity ^0.6.2;
pragma experimental ABIEncoderV2;

interface CandyStoreInterface {
    // State of the lottery.
    enum LotteryState {
        draw,
        committed,
        rewarded
    }
    struct LendingBalance {
        uint userAmount; // token amount collected from fee/arbs profit from swapping.
        uint sponsorAmount; // token amount deposited by sponsor.
    }

    struct LotteryData {
        address lendingProxy; // Proxy contract for interaction with Lending protocols.
        address swapProxy; // Swap contract for interaction with Dex.
        uint lotteryId; // Lottery Id.
        uint fee; // Swapping fee to buy candy.
        uint candyPrice; // Price of candy.
        LotteryState state; // State of the lottery.
        mapping (address => LendingBalance) tokenBalances; // Token balances of each stable token.
        uint winners;
        uint totalCandy; // Total candies distributed.
        uint startTime; // Start time of Lottery.
        uint duration; // Duration of each phase in the lottery.
        uint[] lotteryWinners; // Winners of this lottery.
    }

    struct StableCoin {
        bool isEnabled;
        uint lendingId;
    }

    struct SponsorData {
        address token;
        uint principalAmt;
    }

    // Current Lottery ID
    function openDraw() external view returns (uint);
    // Lottery Details
    function lottery(uint) external view returns (LotteryData memory);
    // Token Amount locked in specific lottery.
    function getAssetLocked(uint lotteryId, address token) external view returns(uint _userAmt, uint _sponsorAmt, uint _prizeAmt);
    // Total no of stable coins enabled
    function totalStableCoins() external view returns(uint);
    // Total no of lottery users for a specific lottery
    function totalUsers(uint lotteryId) external view returns(uint);
    // Total no of lottery sponsor for a specific lottery
    function totalSponsors(uint lotteryId) external view returns(uint);
    // Stable coins array
    function stableCoinsArr(uint id) external view returns(address);
    // Stable coin data
    function stableCoins(uint lotteryId) external view returns(StableCoin memory);
    // lottery candies for a user for a specific lottery.
    function lotteryTickets(uint lotteryId, address user) external view returns(uint candies);
    // Sponsor balance for a specific lottery.
    function sponsorBalance(uint lotteryId, address sponsor) external view returns(SponsorData memory);

    // To buy candy.(Can only be called by arbs contract)
    function buyCandy(address token, uint amt, address to) external;
}