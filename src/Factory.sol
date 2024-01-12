// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {IQuest} from "./interface/IQuest.sol";
import {IMission} from "./interface/IMission.sol";
import {ISupportToken} from "./interface/ISupportToken.sol";

import {LibClone} from "solbase/utils/LibClone.sol";

contract Factory {
    /// -----------------------------------------------------------------------
    /// Library Usage
    /// -----------------------------------------------------------------------

    using LibClone for address;

    /// -----------------------------------------------------------------------
    /// Storage
    /// -----------------------------------------------------------------------

    address public immutable mission;
    address public immutable quest;
    mapping(address => uint256) public nonces;

    constructor(address _mission, address _quest) payable {
        mission = _mission;
        quest = _quest;
    }

    /// -----------------------------------------------------------------------
    /// Determine Address Logic
    /// -----------------------------------------------------------------------

    function determineMissionAddress(address user) external virtual returns (address) {
        return mission.predictDeterministicAddress(
            abi.encodePacked(user), keccak256(abi.encode(user, ++nonces[user])), address(this)
        );
    }

    function determineQuestAddress(address user) external virtual returns (address) {
        return quest.predictDeterministicAddress(
            abi.encodePacked(user), keccak256(abi.encode(user, ++nonces[user])), address(this)
        );
    }

    /// -----------------------------------------------------------------------
    /// Deployment Logic
    /// -----------------------------------------------------------------------

    function deployMission(
        address user // create2 salt.
    ) public payable virtual returns (address) {
        address m = mission.cloneDeterministic(abi.encodePacked(user), keccak256(abi.encode(user, ++nonces[user])));
        IMission(m).initialize(user);
        return (m);
    }

    function deployQuest(
        address user // create2 salt.
    ) public payable virtual returns (address) {
        address q = quest.cloneDeterministic(abi.encodePacked(user), keccak256(abi.encode(user, ++nonces[user])));
        IQuest(q).initialize(user);
        return (q);
    }
}
