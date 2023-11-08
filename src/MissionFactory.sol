// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {IMission} from "./interface/IMission.sol";
import {LibClone} from "solbase/utils/LibClone.sol";

contract MissionFactory {
    /// -----------------------------------------------------------------------
    /// Library Usage
    /// -----------------------------------------------------------------------

    using LibClone for address;

    /// -----------------------------------------------------------------------
    /// Storage
    /// -----------------------------------------------------------------------

    address internal immutable template;

    constructor(address _template) payable {
        template = _template;
    }

    /// -----------------------------------------------------------------------
    /// Deployment Logic
    /// -----------------------------------------------------------------------

    function determineAddress(address dao) public view virtual returns (address) {
        return template.predictDeterministicAddress(
            abi.encodePacked(dao), bytes32(uint256(uint160(dao))), address(this)
        );
    }

    function deployMission(
        address dao // create2 salt.
    ) public payable virtual {
        address mission = template.cloneDeterministic(abi.encodePacked(dao), bytes32(uint256(uint160(dao))));
        IMission(mission).initialize(dao);
    }
}
