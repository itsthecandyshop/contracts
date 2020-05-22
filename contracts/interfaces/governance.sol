pragma solidity ^0.6.2;

interface GovernanceInterface {
    function lendingProxy() external view returns (address);
    function swapProxy() external view returns (address);

    function candyStore() external view returns (address);
    function randomness() external view returns (address);

    function lotteryDuration() external view returns (uint);
    function admin() external view returns (address);
    function candyPrice() external view returns (uint);
    function profitShare() external view returns (uint);
    function fee() external view returns (uint);
}