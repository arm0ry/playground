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

    constructor(address _mission, address _mSupportToken, address _quest, address _qSupportToken) payable {
        mission = _mission;
        quest = _quest;
        mSupportToken = _mSupportToken;
        qSupportToken = _qSupportToken;
    }

    /// -----------------------------------------------------------------------
    /// Deployment Logic
    /// -----------------------------------------------------------------------

    function determineAddress(address user) public view virtual returns (address) {
        return mission.predictDeterministicAddress(
            abi.encodePacked(user), bytes32(uint256(uint160(user))), address(this)
        );
    }

    // TODO: Do we need to use a better salt?
    function deploy(
        address user // create2 salt.
    ) public payable virtual returns (address, address) {
        address m = mission.cloneDeterministic(abi.encodePacked(user), bytes32(uint256(uint160(user))));
        address q = quest.cloneDeterministic(abi.encodePacked(user), bytes32(uint256(uint160(user))));

        IMission(m).initialize(user);
        IQuest(q).initialize(user);
        return (m, q);
    }

    function deploySupportToken(
        string memory _name,
        string memory _symbol,
        address _owner,
        address _quest,
        address _mission,
        uint256 _missionId,
        address _curve,
        uint256 _curveId
    ) public payable virtual returns (address) {
        if (_quest == address(0)) {
            address m = mSupportToken.cloneDeterministic(abi.encodePacked(_owner), bytes32(uint256(uint160(_owner))));
            ISupportToken(m).init(_name, _symbol, _owner, _mission, _missionId, _curve, _curveId);
            return m;
        } else {
            address q = qSupportToken.cloneDeterministic(abi.encodePacked(_owner), bytes32(uint256(uint160(_owner))));
            ISupportToken(q).init(_name, _symbol, _owner, _quest, _mission, _missionId, _curve, _curveId);
            return q;
        }
    }
}
