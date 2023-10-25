// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {IStorage} from "./interface/IStorage.sol";
import {IMissions} from "./interface/IMissions.sol";
import {Storage} from "./Storage.sol";

/// @title Missions
/// @notice A list of missions and tasks.
/// @author audsssy.eth
contract Missions is Storage {
    /// -----------------------------------------------------------------------
    /// Custom Errors
    /// -----------------------------------------------------------------------

    error NotAuthorized();
    error InvalidMission();

    /// -----------------------------------------------------------------------
    /// Modifier
    /// -----------------------------------------------------------------------

    modifier onlyQuest() {
        if (!this.isQuestAllowed(msg.sender)) revert NotAuthorized();
        _;
    }

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    function initialize(address dao) external payable {
        init(dao);
    }

    /// -----------------------------------------------------------------------
    /// DAO Logic
    /// ----------------------------------------------------------------------

    function coordinate(address quest) external payable onlyOperator {
        allowQuest(quest);
    }

    function allowQuest(address quest) internal {
        _setBool(keccak256(abi.encodePacked(quest, ".allowed")), true);
    }

    function isQuestAllowed(address target) external view returns (bool) {
        return this.getBool(keccak256(abi.encodePacked(target, ".allowed")));
    }

    /// -----------------------------------------------------------------------
    /// Mission / Task Logic
    /// -----------------------------------------------------------------------

    /// @dev  Create or update tasks.
    function setTask(address creator, uint256 deadline, string calldata detail) external payable onlyOperator {
        // Retrieve taskId.
        uint256 taskId = incrementTaskId();

        // Set new task content.
        _setTaskCreator(taskId, creator);
        _setTaskDeadline(taskId, deadline);
        _setTaskDetail(taskId, detail);
    }

    /// @dev Create or update a Mission.
    function setMission(address creator, string calldata title, string calldata detail, uint256[] calldata taskIds)
        external
        payable
        onlyOperator
    {
        // Confirm tasks exist.
        if (taskIds.length == 0) revert InvalidMission();

        // Retrieve missionId.
        uint256 missionId = incrementMissionId();

        // Set new mission content.
        _setMissionTasks(missionId, taskIds);
        _setMissionCreator(missionId, creator);
        _setMissionDetail(missionId, detail);
        _setMissionTitle(missionId, title);
        if (setMissionDeadline(missionId) == 0) revert InvalidMission();
    }

    /// -----------------------------------------------------------------------
    /// Mission Setter Logic
    /// -----------------------------------------------------------------------

    function setMissionCreator(uint256 missionId, address creator) external payable onlyOperator {
        _setAddress(keccak256(abi.encode(address(this), missionId, ".creator")), creator);
    }

    function setMissionTitle(uint256 missionId, string calldata title) external payable onlyOperator {
        _setString(keccak256(abi.encode(address(this), missionId, ".title")), title);
    }

    function setMissionDetail(uint256 missionId, string calldata detail) external payable onlyOperator {
        _setString(keccak256(abi.encode(address(this), missionId, ".detail")), detail);
    }

    /// @notice Associate multple tasks with a mission.
    function setMissionTasks(uint256 missionId, uint256[] calldata taskIds) external payable onlyOperator {
        _setMissionTasks(missionId, taskIds);
    }

    function incrementMissionId() internal returns (uint256) {
        return addUint(keccak256(abi.encode(address(this), "missions.count")), 1);
    }

    /// @notice Associate multple tasks with a mission.
    function _setMissionTasks(uint256 missionId, uint256[] calldata taskIds) internal {
        uint256 length = taskIds.length;
        for (uint256 i = 0; i < length;) {
            setMissionTaskId(missionId, taskIds[i]);
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Associate a single task with a mission.
    function setMissionTaskId(uint256 missionId, uint256 taskId) internal {
        uint256 count = incrementMissionTaskCount(missionId);
        _setUint(keccak256(abi.encode(address(this), missionId, ".taskIds.", count)), taskId);
        setIsTaskInMission(missionId, taskId);
    }

    function setIsTaskInMission(uint256 missionId, uint256 taskId) internal {
        _setBool(keccak256(abi.encode(address(this), missionId, taskId)), true);
    }

    function _setMissionCreator(uint256 missionId, address creator) internal {
        _setAddress(keccak256(abi.encode(address(this), missionId, ".creator")), creator);
    }

    function _setMissionDetail(uint256 missionId, string calldata detail) internal {
        _setString(keccak256(abi.encode(address(this), missionId, ".detail")), detail);
    }

    function _setMissionTitle(uint256 missionId, string calldata title) internal {
        _setString(keccak256(abi.encode(address(this), missionId, ".title")), title);
    }

    function setMissionDeadline(uint256 missionId) internal returns (uint256) {
        uint256 deadline = _getMissionDeadline(missionId);

        if (deadline == 0) {
            if (this.getMissionTaskCount(missionId) > 0) {
                return _setMissionDeadline(missionId);
            } else {
                return 0;
            }
        } else {
            return deadline;
        }
    }

    function incrementMissionStarts(uint256 missionId) external onlyQuest {
        addUint(keccak256(abi.encode(address(this), missionId, ".starts")), 1);
    }

    function incrementMissionCompletions(uint256 missionId) external onlyQuest {
        addUint(keccak256(abi.encode(address(this), missionId, ".completions")), 1);
    }

    function incrementMissionTaskCount(uint256 missionId) internal returns (uint256) {
        return addUint(keccak256(abi.encode(address(this), missionId, ".taskCount")), 1);
    }

    /// -----------------------------------------------------------------------
    /// Mission Getter Logic
    /// -----------------------------------------------------------------------

    function getMissionId() external view returns (uint256) {
        return this.getUint(keccak256(abi.encode("missions.count")));
    }

    function getMissionCreator(uint256 missionId) external view returns (address) {
        return this.getAddress(keccak256(abi.encode(address(this), missionId, ".creator")));
    }

    function getMissionDetail(uint256 missionId) external view returns (string memory) {
        return this.getString(keccak256(abi.encode(address(this), missionId, ".detail")));
    }

    function getMissionTitle(uint256 missionId) external view returns (string memory) {
        return this.getString(keccak256(abi.encode(address(this), missionId, ".title")));
    }

    function getMissionTaskCount(uint256 missionId) external view returns (uint256 taskCount) {
        return this.getUint(keccak256(abi.encode(address(this), missionId, ".taskCount")));
    }

    function getMissionTaskId(uint256 missionId, uint256 order) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), missionId, ".taskIds.", order)));
    }

    function getMissionTaskIds(uint256 missionId) external view returns (uint256[] memory) {
        uint256[] memory taskIds;
        uint256 count = this.getMissionTaskCount(missionId);
        for (uint256 i; i < count;) {
            taskIds[i] = this.getMissionTaskId(missionId, i);

            unchecked {
                ++i;
            }
        }

        return taskIds;
    }

    function _getMissionDeadline(uint256 missionId) internal view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), missionId, ".deadline")));
    }

    /// @notice May trigger gas if Mission is newly set.
    function getMissionDeadline(uint256 missionId) external payable returns (uint256) {}

    function getMissionStarts(uint256 missionId) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), missionId, ".starts")));
    }

    function getMissionCompletions(uint256 missionId) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), missionId, ".completions")));
    }

    /// -----------------------------------------------------------------------
    /// Task Setter Logic
    /// -----------------------------------------------------------------------

    function setTaskCreator(uint256 taskId, address creator) external payable {
        _setAddress(keccak256(abi.encode(address(this), taskId, ".creator")), creator);
    }

    function setTaskDeadline(uint256 taskId, uint256 deadline) external payable {
        _setUint(keccak256(abi.encode(address(this), taskId, ".deadline")), deadline);
    }

    function setTaskDetail(uint256 taskId, string calldata detail) external payable {
        _setString(keccak256(abi.encode(address(this), taskId, ".detail")), detail);
    }

    function incrementTaskId() internal returns (uint256) {
        return addUint(keccak256(abi.encode("tasks.count")), 1);
    }

    function _setTaskCreator(uint256 taskId, address creator) internal {
        _setAddress(keccak256(abi.encode(address(this), taskId, ".creator")), creator);
    }

    function _setTaskDeadline(uint256 taskId, uint256 deadline) internal {
        _setUint(keccak256(abi.encode(address(this), taskId, ".deadline")), deadline);
    }

    function _setTaskDetail(uint256 taskId, string calldata detail) internal {
        _setString(keccak256(abi.encode(address(this), taskId, ".detail")), detail);
    }

    function incrementTaskCompletions(uint256 taskId) external payable onlyQuest {
        addUint(keccak256(abi.encode(address(this), taskId, ".completions")), 1);
    }

    function isTaskInMission(uint256 missionId, uint256 taskId) external view returns (bool) {
        return this.getBool(keccak256(abi.encode(address(this), missionId, taskId)));
    }

    /// -----------------------------------------------------------------------
    /// Task Getter Logic
    /// -----------------------------------------------------------------------

    function getTaskId() external view returns (uint256) {
        return this.getUint(keccak256(abi.encode("tasks.count")));
    }

    function getTaskCreator(uint256 taskId) external view returns (address) {
        return this.getAddress(keccak256(abi.encode(address(this), taskId, ".creator")));
    }

    function getTaskDeadline(uint256 taskId) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), taskId, ".deadline")));
    }

    function getTaskDetail(uint256 taskId) external view returns (string memory) {
        return this.getString(keccak256(abi.encode(address(this), taskId, ".detail")));
    }

    function getTaskCompletions(uint256 taskId) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), taskId, ".completions")));
    }

    /// -----------------------------------------------------------------------
    /// Helper Logic
    /// -----------------------------------------------------------------------

    function _setMissionDeadline(uint256 missionId) internal returns (uint256) {
        uint256 deadline;
        uint256[] memory taskIds = this.getMissionTaskIds(missionId);

        for (uint256 i; i < taskIds.length;) {
            uint256 _deadline = this.getUint(keccak256(abi.encode(address(this), taskIds[i], ".deadline")));
            if (deadline < _deadline) deadline = _deadline;
            unchecked {
                ++i;
            }
        }

        _setUint(keccak256(abi.encode(address(this), missionId, ".deadline")), deadline);
        return deadline;
    }
}
