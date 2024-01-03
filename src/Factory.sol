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
    address public immutable mSupportToken;
    address public immutable qSupportToken;
    mapping(address => uint256) public nonces;

    constructor(address _mission, address _mSupportToken, address _quest, address _qSupportToken) payable {
        mission = _mission;
        quest = _quest;
        mSupportToken = _mSupportToken;
        qSupportToken = _qSupportToken;
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

    function determineMissionTokenAddress(address user) external virtual returns (address) {
        return mSupportToken.predictDeterministicAddress(
            abi.encodePacked(user), keccak256(abi.encode(user, ++nonces[user])), address(this)
        );
    }

    function determineQuestTokenAddress(address user) external virtual returns (address) {
        return qSupportToken.predictDeterministicAddress(
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

    function deploySupportToken(
        string memory _name,
        string memory _symbol,
        address _owner,
        address _quest,
        address _mission,
        uint256 _missionId,
        address _curve
    ) public payable virtual returns (address) {
        if (_quest == address(0)) {
            address m = mSupportToken.cloneDeterministic(
                abi.encodePacked(_owner), keccak256(abi.encode(_owner, ++nonces[_owner]))
            );
            ISupportToken(m).init(_name, _symbol, _owner, _mission, _missionId, _curve);
            return m;
        } else {
            address q = qSupportToken.cloneDeterministic(
                abi.encodePacked(_owner), keccak256(abi.encode(_owner, ++nonces[_owner]))
            );
            ISupportToken(q).init(_name, _symbol, _owner, _quest, _mission, _missionId, _curve);
            return q;
        }
    }
}
