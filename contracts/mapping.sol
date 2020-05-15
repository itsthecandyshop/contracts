pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import {GovernanceInterface} from "./interfaces/governance.sol";
import {CTokenInterface} from "./interfaces/compound.sol";

contract Helpers {
    GovernanceInterface public governance;

    mapping (address => address) public cTokenMapping;

    event LogAddCTokenMapping(address cToken);

    modifier isAdmin {
        require(governance.admin() == msg.sender, "not-admin");
        _;
    }

    function addCtknMapping(address[] memory cTkn) public isAdmin {
        require(cTkn.length > 0, "No-CTokens-Address");
        for (uint i = 0; i < cTkn.length; i++) {
            _addCtknMapping(cTkn[i]);
        }
    }

    function _addCtknMapping(address cErc20) internal {
        address erc20 = CTokenInterface(cErc20).underlying();
        require(cTokenMapping[erc20] == address(0), "Token-Already-Added");
        cTokenMapping[erc20] = cErc20;
        emit LogAddCTokenMapping(cErc20);
    }
}


contract Mapping is Helpers {
    constructor(address _governance) public {
        governance = GovernanceInterface(_governance);

        address ethAddress = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

        // address cEth = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5; //mainnet
        // address cDai = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5; //mainnet
        // address cUsdc = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5; //mainnet

        address cEth = 0xf92FbE0D3C0dcDAE407923b2Ac17eC223b1084E4; //kovan
        address cDai = 0xe7bc397DBd069fC7d0109C0636d06888bb50668c; //kovan
        address cUsdc = 0xcfC9bB230F00bFFDB560fCe2428b4E05F3442E35; //kovan

        _addCtknMapping(cDai);
        _addCtknMapping(cUsdc);
        cTokenMapping[ethAddress] = cEth;
    }
}