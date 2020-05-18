pragma solidity ^0.6.2;

import {GovernanceInterface} from "./interfaces/governance.sol";
import {VRFConsumerBase} from "./vrf/VRFConsumerBase.sol";

contract Randomness is VRFConsumerBase {
    GovernanceInterface public governanceContract;
    // Mapping of lottery id => randomness number
    mapping (uint => uint) public randomNumber;
    mapping (bytes32 => uint) public requestIds;

    constructor (
        address _governance,
        address _vrfCoordinator,
        address _link
    ) public VRFConsumerBase(_vrfCoordinator, _link) {
        governanceContract = GovernanceInterface(_governance);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness)
    external override
    {
        require(vrfCoordinator == msg.sender, "not-vrf-coordinator");
        require(requestIds[requestId] != 0, "request-id-not-vaild");
        uint lotteryId = requestIds[requestId];
        randomNumber[lotteryId] = randomness;
    }

    function getRandom(uint lotteryId, uint seed) external {
        require(randomNumber[lotteryId] == 0, "Already-found-random");
        require(governanceContract.candyStore() == msg.sender, "not-candyStore-address");
        // TODO - check time
        uint linkFee = 10**18;
        LINK.transferFrom(governanceContract.admin(), address(this), linkFee);

        bytes32 _requestId = requestRandomness(
            0xced103054e349b8dfb51352f0f8fa9b5d20dde3d06f9f43cb2b85bc64b238205,
            linkFee,
            seed
        );
        requestIds[_requestId] = lotteryId;
    }
}