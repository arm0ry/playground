// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {IMission} from "./interface/IMission.sol";
import {Storage} from "kali-markets/Storage.sol";

/// @title Missions
/// @notice A list of missions and tasks.
/// @author audsssy.eth
contract Mission is Storage {
    /// -----------------------------------------------------------------------
    /// Custom Errors
    /// -----------------------------------------------------------------------

    error NotAuthorized();
    error InvalidTask();
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
        _setBool(keccak256(abi.encode(address(this), quest, ".authorized")), status);
    }

    function isQuestAuthorized(address target) external view returns (bool) {
        return this.getBool(keccak256(abi.encode(address(this), target, ".authorized")));
    }

    /// -----------------------------------------------------------------------
    /// Task Logic - Setter
    /// -----------------------------------------------------------------------

    /// @notice  Create task.
    function setTasks(address[] calldata creators, uint256[] calldata deadlines, string[] calldata detail)
        external
        payable
        onlyOperator
    {
        uint256 taskId;

        // Confirm inputs are valid.
        uint256 length = creators.length;
        if (length != deadlines.length || length != detail.length) revert LengthMismatch();
        if (length == 0) revert InvalidTask();

        // Set new task content.
        for (uint256 i = 0; i < length;) {
            // Increment and retrieve taskId.
            taskId = incrementTaskId();

            _setTaskCreator(taskId, creators[i]);
            _setTaskDeadline(taskId, deadlines[i]);
            _setTaskDetail(taskId, detail[i]);

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Update creator of a task.
    function setTaskCreator(uint256 taskId, address creator) external payable onlyOperator {
        _setTaskCreator(taskId, creator);
    }

    /// @notice Update deadline of a task.
    function setTaskDeadline(uint256 taskId, uint256 deadline) external payable onlyOperator {
        _setTaskDeadline(taskId, deadline);

        // Update any deadline of associated missions.
        uint256 count = this.getTaskMissionCount(taskId);
        for (uint256 i = 0; i < count;) {
            _setMissionDeadline(this.getTaskMissionId(taskId, i));

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Update detail of a task.
    function setTaskDetail(uint256 taskId, string calldata detail) external payable onlyOperator {
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
        return addUint(keccak256(abi.encode(address(this), "tasks.count")), 1);
    }

    /// @notice Increment number of task completions by task id by authorized Quest contracts only.
    function incrementTaskCompletions(uint256 taskId) external payable onlyQuest {
        addUint(keccak256(abi.encode(address(this), taskId, ".completions")), 1);
    }

    /// @notice Increment and return number of tasks a mission.
    function incrementTaskMissionCount(uint256 taskId) internal returns (uint256) {
        return addUint(keccak256(abi.encode(address(this), taskId, ".missionCount")), 1);
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
        if (taskIds.length > 0) _addMissionTasks(missionId, taskIds);
        else revert InvalidMission();
        if (_setMissionDeadline(missionId) == 0) revert InvalidMission();
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

    /// @notice Add tasks to a mission.
    function addMissionTasks(uint256 missionId, uint256[] calldata taskIds) external payable onlyOperator {
        _addMissionTasks(missionId, taskIds);
    }

    /// @notice Increment and return mission id.
    function incrementMissionId() internal returns (uint256) {
        return addUint(keccak256(abi.encode(address(this), "missions.count")), 1);
    }

    /// @notice Add tasks to a mission.
    function _addMissionTasks(uint256 missionId, uint256[] calldata taskIds) internal {
        uint256 length = taskIds.length;
        if (length == 0) revert InvalidMission();
        for (uint256 i = 0; i < length;) {
            if (!this.isTaskInMission(missionId, taskIds[i])) {
                // Add task.
                addNewTaskToMission(missionId, taskIds[i]);

                // Associate mission with given task.
                associateMissionWithTask(missionId, taskIds[i]);

                // Update status of task id in given mission.
                setIsTaskInMission(missionId, taskIds[i], true);
            }

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Update a task by its order in a given mission.
    function setMissionTaskId(uint256 missionId, uint256 order, uint256 newTaskId) external onlyOperator {
        if (!this.isTaskInMission(missionId, newTaskId)) {
            // Update status of old task id.
            uint256 oldTaskId = this.getMissionTaskId(missionId, order);
            deleteIsTaskInMission(missionId, oldTaskId);

            // Update task by its order.
            updateTaskInMission(missionId, order, newTaskId);

            // Associate mission with given task.
            associateMissionWithTask(missionId, newTaskId);

            // Update status of new task id.
            setIsTaskInMission(missionId, newTaskId, true);
        }
    }

    /// @notice Set whether a task is part of a mission.
    function setIsTaskInMission(uint256 missionId, uint256 taskId, bool status) internal {
        _setBool(keccak256(abi.encode(address(this), missionId, taskId)), status);
    }

    /// @notice Set whether a task is part of a mission.
    function deleteIsTaskInMission(uint256 missionId, uint256 taskId) internal {
        deleteBool(keccak256(abi.encode(address(this), missionId, taskId)));
    }

    /// @notice Associate a task with a given mission.
    function addNewTaskToMission(uint256 missionId, uint256 taskId) internal {
        _setUint(
            keccak256(abi.encode(address(this), missionId, ".taskIds.", incrementMissionTaskCount(missionId))), taskId
        );
    }

    /// @notice Associate a task with a given mission.
    function updateTaskInMission(uint256 missionId, uint256 order, uint256 taskId) internal {
        _setUint(keccak256(abi.encode(address(this), missionId, ".taskIds.", order)), taskId);
    }

    /// @notice Associate a mission with a given task.
    function associateMissionWithTask(uint256 missionId, uint256 taskId) internal {
        _setUint(
            keccak256(abi.encode(address(this), taskId, ".missionIds.", incrementTaskMissionCount(taskId))), missionId
        );
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
    function _setMissionDeadline(uint256 missionId) internal returns (uint256) {
        uint256 deadline = this.getMissionDeadline(missionId);

        // Confirm deadline is initialized.
        if (deadline == 0) {
            // If not, confirm mission is initialized.
            if (this.getMissionTaskCount(missionId) > 0) {
                // If so, set mission deadline.
                return __setMissionDeadline(missionId);
            } else {
                return 0;
            }
        } else {
            return deadline;
        }
    }

    /// @notice Internal function to retrieve and set deadline of mission by using the latest task deadline.
    function __setMissionDeadline(uint256 missionId) internal returns (uint256) {
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

    /// @notice Increment number of mission starts by mission id by authorized Quest contracts only.
    function incrementMissionStarts(uint256 missionId) external payable onlyQuest {
        addUint(keccak256(abi.encode(address(this), missionId, ".starts")), 1);
    }

    /// @notice Increment number of mission completions by mission id by authorized Quest contracts only.
    function incrementMissionCompletions(uint256 missionId) external payable onlyQuest {
        addUint(keccak256(abi.encode(address(this), missionId, ".completions")), 1);
    }

    /// @notice Increment and return number of tasks a mission.
    function incrementMissionTaskCount(uint256 missionId) internal returns (uint256) {
        return addUint(keccak256(abi.encode(address(this), missionId, ".taskCount")), 1);
    }

    /// -----------------------------------------------------------------------
    /// Task Logic - Getter
    /// -----------------------------------------------------------------------

    /// @notice Get task id.
    function getTaskId() external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), "tasks.count")));
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

    /// @notice Returns whether a task is part of a mission.
    function isTaskInMission(uint256 missionId, uint256 taskId) external view returns (bool) {
        return this.getBool(keccak256(abi.encode(address(this), missionId, taskId)));
    }

    /// @notice Get number of task completions by task id.
    function getTaskCompletions(uint256 taskId) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), taskId, ".completions")));
    }

    /// @notice Get number of tasks in a mission.
    function getTaskMissionCount(uint256 taskId) external view returns (uint256 missionCount) {
        return this.getUint(keccak256(abi.encode(address(this), taskId, ".missionCount")));
    }

    /// @notice Get a mission id associated with of a given task by order.
    function getTaskMissionId(uint256 taskId, uint256 order) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), taskId, ".missionIds.", order)));
    }

    /// @notice Get all mission ids associated with a given task.
    function getTaskMissionIds(uint256 taskId) external view returns (uint256[] memory missionIds) {
        uint256 count = this.getTaskMissionCount(taskId);
        for (uint256 i; i < count;) {
            missionIds[i] = this.getTaskMissionId(taskId, i);

            unchecked {
                ++i;
            }
        }
    }

    /// -----------------------------------------------------------------------
    /// Mission Logic - Getter
    /// -----------------------------------------------------------------------

    /// @notice Get missoin id.
    function getMissionId() external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), "missions.count")));
    }

    /// @notice Get creator of a mission.
    function getMissionCreator(uint256 missionId) external view returns (address) {
        return this.getAddress(keccak256(abi.encode(address(this), missionId, ".creator")));
    }

    /// @notice Get deadline of a mission.
    function getMissionDeadline(uint256 missionId) external payable returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), missionId, ".deadline")));
    }

    /// @notice Get detail of a mission.
    function getMissionDetail(uint256 missionId) external view returns (string memory) {
        return this.getString(keccak256(abi.encode(address(this), missionId, ".detail")));
    }

    /// @notice Get title of a mission.
    function getMissionTitle(uint256 missionId) external view returns (string memory) {
        return this.getString(keccak256(abi.encode(address(this), missionId, ".title")));
    }

    /// @notice Get the number of mission starts by missionId.
    function getMissionStarts(uint256 missionId) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), missionId, ".starts")));
    }

    /// @notice Get the number of mission completions by missionId.
    function getMissionCompletions(uint256 missionId) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), missionId, ".completions")));
    }

    /// @notice Get number of tasks in a mission.
    function getMissionTaskCount(uint256 missionId) external view returns (uint256 taskCount) {
        return this.getUint(keccak256(abi.encode(address(this), missionId, ".taskCount")));
    }

    /// @notice Get a task id associated with in a given mission by order.
    function getMissionTaskId(uint256 missionId, uint256 order) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), missionId, ".taskIds.", order)));
    }

    /// @notice Get all task ids associated with a given mission.
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
}
