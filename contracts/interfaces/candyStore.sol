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
        uint winners;
        uint totalCandy; // Total candies distributed.
        uint startTime; // Start time of Lottery.
        uint duration; // Duration of each phase in the lottery.
    }

    function openDraw() external view returns (uint);
    function lottery(uint) external view returns (LotteryData memory);
}