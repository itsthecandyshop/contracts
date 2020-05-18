pragma solidity ^0.6.2;

interface Mapping {
    function cTokenMapping(address) external view returns (address);
}