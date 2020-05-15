pragma solidity ^0.6.0;

import {DSMath} from "./libraries/DSMath.sol";

contract Governance is DSMath {
    address public admin;

    uint public fee;
    uint public candyPrice;
    uint public lotteryDuration;

    address public lendingProxy;
    address public swapProxy;

    uint public lendingId;

    modifier isAdmin {
        require(admin == msg.sender, "not-a-admin");
        _;
    }

    function changeFee(uint _fee) external isAdmin {
        require(_fee < 5 * 10 ** 15, "governance/over-fee"); // 0.5% Max Fee.
        fee = _fee;
    }

    function changeCandyPrice(uint _price) external isAdmin {
        require(_price < 1 * WAD, "governance/over-price"); // 1$ Max Price.
        candyPrice = _price;
    }

    function changeDuration(uint _time) external isAdmin {
        require(_time <= 30 days, "governance/over-price"); // 30 days Max duration
        // require(_time >= 7 days, "governance/over-price"); // 7 days min duration
        lotteryDuration = _time;
    }

    function changelendingProxy(address _proxy) external isAdmin {
        require(_proxy != address(0), "governance/no-deposit-proxy-address");
        require(_proxy == lendingProxy, "governance/same-deposit-proxy-address");
        lendingProxy = _proxy;
    }

    function changeSwapProxy(address _proxy) external isAdmin {
        require(_proxy != address(0), "governance/no-swap-proxy-address");
        require(_proxy == swapProxy, "governance/same-swap-proxy-address");
        swapProxy = _proxy;
    }

    function changeAdmin(address _admin) external isAdmin {
        require(_admin != address(0), "governance/no-admin-address");
        require(admin != _admin, "governance/same-admin");
        admin = _admin;
    }

    constructor (
        uint _fee,
        uint _candyPrice,
        uint _duration,
        address _lendingProxy,
        address _swapProxy
    ) public {
        assert(_fee != 0);
        assert(_candyPrice != 0);
        assert(_duration != 0);
        assert(_lendingProxy != address(0));
        assert(_swapProxy != address(0));
        admin = 0xe866ecE4bbD0Ac75577225Ee2C464ef16DC8b1F3;
        fee = _fee;
        candyPrice = _candyPrice;
        lotteryDuration = _duration;
        lendingProxy = _lendingProxy;
        swapProxy = _swapProxy;
    }
}