pragma solidity ^0.6.2;

interface GovernanceInterface {
    function getEthToDaiProfit(uint totalProfit) external view returns(uint requiredAmt);
    function getTokenToDaiProfit(uint totalProfit) external view returns(uint requiredAmt);
    function getEthToDaiFee(uint totalAmt) external view returns(uint requiredAmt);
    function getTokenToDaifee(uint totalAmt) external view returns(uint requiredAmt);

    function swapEthToDai(
        address payable user,
        address candyFor,
        uint totalAmt,
        bool isFee,
        bool isIn
    ) external payable returns(uint leftAmt);

    function swapTokenToDai(
        address user,
        address candyFor,
        address token,
        uint totalAmt,
        bool isFee,
        bool isIn
    ) external returns(uint leftAmt);
}