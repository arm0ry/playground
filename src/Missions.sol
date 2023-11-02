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
        if (!this.isQuestAuthorized(msg.sender)) revert NotAuthorized();
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

    /// @notice Authorize a Quest contract to export data to this Mission contract.
    function authorizeQuest(address quest, bool status) external payable onlyOperator {
        _setBool(keccak256(abi.encodePacked(quest, ".authorized")), status);
    }

    function isQuestAuthorized(address target) external view returns (bool) {
        return this.getBool(keccak256(abi.encodePacked(target, ".authorized")));
    }

    /// -----------------------------------------------------------------------
    /// Mission Logic - Setter
    /// -----------------------------------------------------------------------

    /// @notice Create a mission.
    function setMission(address creator, string calldata title, string calldata detail, uint256[] calldata taskIds)
        external
        payable
        onlyOperator
    {
        // Retrieve missionId.
        uint256 missionId = incrementMissionId();

        // Set new mission content.
        if (taskIds.length > 0) _setMissionTasks(missionId, taskIds);
        else revert InvalidMission();
        if (setMissionDeadline(missionId) == 0) revert InvalidMission();
        _setMissionCreator(missionId, creator);
        _setMissionDetail(missionId, detail);
        _setMissionTitle(missionId, title);
    }

    /// @notice Update creator of a mission.
    function setMissionCreator(uint256 missionId, address creator) external payable onlyOperator {
        if (creator != address(0)) _setMissionCreator(missionId, creator);
    }

    /// @notice Update title of a mission.
    function setMissionTitle(uint256 missionId, string calldata title) external payable onlyOperator {
        if (bytes(title).length > 0) _setMissionTitle(missionId, title);
    }

    /// @notice Update detail of a mission.
    function setMissionDetail(uint256 missionId, string calldata detail) external payable onlyOperator {
        if (bytes(detail).length > 0) _setMissionDetail(missionId, detail);
    }

    /// @notice Associate multple tasks with a mission.
    function setMissionTasks(uint256 missionId, uint256[] calldata taskIds) external payable onlyOperator {
        _setMissionTasks(missionId, taskIds);
    }

    /// @notice Increment and return mission id.
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

    /// @notice Set whether a task is part of a mission.
    function setIsTaskInMission(uint256 missionId, uint256 taskId) internal {
        _setBool(keccak256(abi.encode(address(this), missionId, taskId)), true);
    }

    /// @notice Internal function to set creator of a mission.
    function _setMissionCreator(uint256 missionId, address creator) internal {
        if (creator != address(0)) _setAddress(keccak256(abi.encode(address(this), missionId, ".creator")), creator);
    }

    /// @notice Internal function to set detail of a mission.
    function _setMissionDetail(uint256 missionId, string calldata detail) internal {
        if (bytes(detail).length > 0) _setString(keccak256(abi.encode(address(this), missionId, ".detail")), detail);
    }

    /// @notice Internal function to set title of a mission.
    function _setMissionTitle(uint256 missionId, string calldata title) internal {
        if (bytes(title).length > 0) _setString(keccak256(abi.encode(address(this), missionId, ".title")), title);
    }

    /// @notice Set mission deadline.
    function setMissionDeadline(uint256 missionId) internal returns (uint256) {
        uint256 deadline = this.getMissionDeadline(missionId);

        // Confirm deadline is initialized.
        if (deadline == 0) {
            // If not, confirm mission is initialized.
            if (this.getMissionTaskCount(missionId) > 0) {
                // If so, set mission deadline.
                return _setMissionDeadline(missionId);
            } else {
                return 0;
            }
        } else {
            return deadline;
        }
    }

    /// @notice Increment number of mission starts by mission id by authorized Quest contracts only.
    function incrementMissionStarts(uint256 missionId) external onlyQuest {
        addUint(keccak256(abi.encode(address(this), missionId, ".starts")), 1);
    }

    /// @notice Increment number of mission completions by mission id by authorized Quest contracts only.
    function incrementMissionCompletions(uint256 missionId) external onlyQuest {
        addUint(keccak256(abi.encode(address(this), missionId, ".completions")), 1);
    }

    /// @notice Increment and return number of tasks a mission.
    function incrementMissionTaskCount(uint256 missionId) internal returns (uint256) {
        return addUint(keccak256(abi.encode(address(this), missionId, ".taskCount")), 1);
    }

    /// -----------------------------------------------------------------------
    /// Mission Logic - Getter
    /// -----------------------------------------------------------------------

    /// @notice Get missoin id.
    function getMissionId() external view returns (uint256) {
        return this.getUint(keccak256(abi.encode("missions.count")));
    }

    /// @notice Get creator of a mission.
    function getMissionCreator(uint256 missionId) external view returns (address) {
        return this.getAddress(keccak256(abi.encode(address(this), missionId, ".creator")));
    }

    /// @notice Get detail of a mission.
    function getMissionDetail(uint256 missionId) external view returns (string memory) {
        return this.getString(keccak256(abi.encode(address(this), missionId, ".detail")));
    }

    /// @notice Get title of a mission.
    function getMissionTitle(uint256 missionId) external view returns (string memory) {
        return this.getString(keccak256(abi.encode(address(this), missionId, ".title")));
    }

    /// @notice Get number of tasks in a mission.
    function getMissionTaskCount(uint256 missionId) external view returns (uint256 taskCount) {
        return this.getUint(keccak256(abi.encode(address(this), missionId, ".taskCount")));
    }

    /// @notice Get a task id by its order in a mission.
    function getMissionTaskId(uint256 missionId, uint256 order) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), missionId, ".taskIds.", order)));
    }

    /// @notice Get all task ids in a mission.
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

    /// @notice Get deadline of a mission.
    function getMissionDeadline(uint256 missionId) external payable returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), missionId, ".deadline")));
    }

    /// @notice Get the number of mission starts by missionId.
    function getMissionStarts(uint256 missionId) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), missionId, ".starts")));
    }

    /// @notice Get the number of mission completions by missionId.
    function getMissionCompletions(uint256 missionId) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), missionId, ".completions")));
    }

    /// -----------------------------------------------------------------------
    /// Task Logic - Setter
    /// -----------------------------------------------------------------------

    /// @notice  Create task.
    function setTask(address creator, uint256 deadline, string calldata detail) external payable onlyOperator {
        // Retrieve taskId.
        uint256 taskId = incrementTaskId();

        // Set new task content.
        if (creator != address(0)) _setTaskCreator(taskId, creator);
        if (deadline > 0) _setTaskDeadline(taskId, deadline);
        if (bytes(detail).length > 0) _setTaskDetail(taskId, detail);
    }

    /// @notice Update creator of a task.
    function setTaskCreator(uint256 taskId, address creator) external payable {
        _setTaskCreator(taskId, creator);
    }

    /// @notice Update deadline of a task.
    function setTaskDeadline(uint256 taskId, uint256 deadline) external payable {
        _setTaskDeadline(taskId, deadline);
    }

    /// @notice Update detail of a task.
    function setTaskDetail(uint256 taskId, string calldata detail) external payable {
        _setTaskDetail(taskId, detail);
    }

    /// @notice Internal function to set creator of a task.
    function _setTaskCreator(uint256 taskId, address creator) internal {
        if (creator != address(0)) _setAddress(keccak256(abi.encode(address(this), taskId, ".creator")), creator);
    }

    /// @notice Internal function to set deadline of a task.
    function _setTaskDeadline(uint256 taskId, uint256 deadline) internal {
        if (deadline > 0) _setUint(keccak256(abi.encode(address(this), taskId, ".deadline")), deadline);
    }

    /// @notice Internal function to set detail of a task.
    function _setTaskDetail(uint256 taskId, string calldata detail) internal {
        if (bytes(detail).length > 0) _setString(keccak256(abi.encode(address(this), taskId, ".detail")), detail);
    }

    /// @notice Increment and return task id.
    function incrementTaskId() internal returns (uint256) {
        return addUint(keccak256(abi.encode("tasks.count")), 1);
    }

    /// @notice Increment number of task completions by task id by authorized Quest contracts only.
    function incrementTaskCompletions(uint256 taskId) external payable onlyQuest {
        addUint(keccak256(abi.encode(address(this), taskId, ".completions")), 1);
    }

    /// -----------------------------------------------------------------------
    /// Task Logic - Getter
    /// -----------------------------------------------------------------------

    /// @notice Get task id.
    function getTaskId() external view returns (uint256) {
        return this.getUint(keccak256(abi.encode("tasks.count")));
    }

    /// @notice Get creator of a task.
    function getTaskCreator(uint256 taskId) external view returns (address) {
        return this.getAddress(keccak256(abi.encode(address(this), taskId, ".creator")));
    }

    /// @notice Get deadline of a task.
    function getTaskDeadline(uint256 taskId) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), taskId, ".deadline")));
    }

    /// @notice Get detail of a task.
    function getTaskDetail(uint256 taskId) external view returns (string memory) {
        return this.getString(keccak256(abi.encode(address(this), taskId, ".detail")));
    }

    /// @notice Get number of task completions by task id.
    function getTaskCompletions(uint256 taskId) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), taskId, ".completions")));
    }

    /// @notice Returns whether a task is part of a mission.
    function isTaskInMission(uint256 missionId, uint256 taskId) external view returns (bool) {
        return this.getBool(keccak256(abi.encode(address(this), missionId, taskId)));
    }

    /// -----------------------------------------------------------------------
    /// Helper Logic
    /// -----------------------------------------------------------------------

    /// @notice Internal function to retrieve and set deadline of mission by using the latest task deadline.
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
