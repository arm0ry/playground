// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import {Quests} from "./Quests.sol";
import {IMissions} from "./interface/IMissions.sol";
import {IQuestsDirectory} from "./interface/IQuestsDirectory.sol";
import {LibClone} from "solbase/utils/LibClone.sol";

contract QuestsFactory {
    /// -----------------------------------------------------------------------
    /// Library Usage
    /// -----------------------------------------------------------------------

    using LibClone for address;

    /// -----------------------------------------------------------------------
    /// Storage
    /// -----------------------------------------------------------------------

    address internal immutable questsTemplate;

    constructor(address _questsTemplate) payable {
        questsTemplate = _questsTemplate;
    }

    /// -----------------------------------------------------------------------
    /// Deployment Logic
    /// -----------------------------------------------------------------------

    function determineAddress(bytes32 daoName) public view virtual returns (address) {
        return questsTemplate.predictDeterministicAddress(abi.encodePacked(daoName), daoName, address(this));
    }

    function deployQuests(
        bytes32 daoName, // create2 salt.
        IMissions mission,
        IQuestsDirectory questDirectory,
        address payable daoAdmin
    ) public payable virtual {
        address quest = questsTemplate.cloneDeterministic(abi.encodePacked(daoName), daoName);

        Quests(payable(quest)).initialize(mission, questDirectory, daoAdmin);
    }
}
