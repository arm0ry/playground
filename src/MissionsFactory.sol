// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import {Missions} from "./Missions.sol";
import {IQuests} from "./interface/IQuests.sol";
import {LibClone} from "solbase/utils/LibClone.sol";

contract MissionsFactory {
    /// -----------------------------------------------------------------------
    /// Library Usage
    /// -----------------------------------------------------------------------

    using LibClone for address;

    /// -----------------------------------------------------------------------
    /// Storage
    /// -----------------------------------------------------------------------

    address internal immutable missionsTemplate;

    constructor(address _missionsTemplate) payable {
        missionsTemplate = _missionsTemplate;
    }

    /// -----------------------------------------------------------------------
    /// Deployment Logic
    /// -----------------------------------------------------------------------

    function determineAddress(bytes32 daoName) public view virtual returns (address) {
        return missionsTemplate.predictDeterministicAddress(abi.encodePacked(daoName), daoName, address(this));
    }

    function deployMissions(
        bytes32 daoName, // create2 salt.
        address daoAdmin
    ) public payable virtual {
        address mission = missionsTemplate.cloneDeterministic(abi.encodePacked(daoName), daoName);

        Missions(payable(mission)).initialize(daoAdmin);
    }
}
