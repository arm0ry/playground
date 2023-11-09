// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {IQuest} from "./interface/IQuest.sol";
import {LibClone} from "solbase/utils/LibClone.sol";

contract QuestFactory {
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

    function deployQuest(
        address dao // create2 salt.
    ) public payable virtual returns (address) {
        address quest = template.cloneDeterministic(abi.encodePacked(dao), bytes32(uint256(uint160(dao))));
        IQuest(quest).initialize(dao);
        return quest;
    }
}
