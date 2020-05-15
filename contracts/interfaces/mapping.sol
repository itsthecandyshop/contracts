pragma solidity ^0.6.0;

interface Mapping {
    function cTokenMapping(address) external view returns (address);
}