pragma solidity ^0.6.2;

interface RandomnessInterface {
    function randomNumber(uint) external view returns (uint);
    function getRandom(uint, uint) external;
}