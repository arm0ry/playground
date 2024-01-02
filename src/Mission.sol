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
    error InvalidFee();

    /// -----------------------------------------------------------------------
    /// Modifier
    /// -----------------------------------------------------------------------

    modifier onlyQuest() {
        if (!this.isQuestAuthorized(msg.sender)) revert NotAuthorized();
        _;
    }

    modifier priceCheck() {
        uint256 fee = this.getFee();
        if (fee > 0 && msg.value == this.getFee()) _;
        else if (fee == 0) _;
        else revert InvalidFee();
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

    function setFee(uint256 fee) external payable onlyOperator {
        _setUint(keccak256(abi.encode(address(this), ".fee")), fee);
    }

    function getFee() external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), ".fee")));
    }
    /// -----------------------------------------------------------------------
    /// Task Logic - Setter
    /// -----------------------------------------------------------------------
    /// @notice  Create task by dao.

    function setTasks(address[] calldata creators, uint256[] calldata deadlines, string[] calldata detail)
        external
        payable
        onlyOperator
    {
        _setTasks(creators, deadlines, detail);
    }

    /// @notice  Create task with payment.
    function payToSetTasks(address[] calldata creators, uint256[] calldata deadlines, string[] calldata detail)
        external
        payable
        priceCheck
    {
        _setTasks(creators, deadlines, detail);
    }

    /// @notice Update creator of a task.
    function setTaskCreator(uint256 taskId, address creator) external payable onlyOperator {
        _setTaskCreator(taskId, creator);
    }

    /// @notice Update deadline of a task.
    function setTaskDeadline(uint256 taskId, uint256 deadline) external payable onlyOperator {
        _setTaskDeadline(taskId, deadline);

        // Update deadline of associated missions, if any.
        uint256 count = this.getTaskMissionCount(taskId);
        if (count != 0) {
            uint256 missionId;
            for (uint256 i = 0; i < count; ++i) {
                missionId = this.getTaskMissionId(taskId, i + 1);
                if (deadline > this.getMissionDeadline(missionId)) {
                    __setMissionDeadline(missionId, deadline);
                }
            }
        }
    }

    /// @notice  Internal function to create task.
    function _setTasks(address[] calldata creators, uint256[] calldata deadlines, string[] calldata detail) internal {
        uint256 taskId;

        // Confirm inputs are valid.
        uint256 length = creators.length;
        if (length != deadlines.length || length != detail.length) revert LengthMismatch();
        if (length == 0) revert InvalidTask();

        // Set new task content.
        for (uint256 i = 0; i < length; ++i) {
            // Increment and retrieve taskId.
            taskId = incrementTaskId();
            _setTaskCreator(taskId, creators[i]);
            _setTaskDeadline(taskId, deadlines[i]);
            _setTaskDetail(taskId, detail[i]);
        }
    }

    /// @notice Update detail of a task.
    function setTaskDetail(uint256 taskId, string calldata detail) external payable onlyOperator {
        _setTaskDetail(taskId, detail);
    }

    /// @notice Internal function to set creator of a task.
    function _setTaskCreator(uint256 taskId, address creator) internal {
        if (creator == address(0)) revert InvalidTask();
        _setAddress(keccak256(abi.encode(address(this), ".tasks.", taskId, ".creator")), creator);
    }

    /// @notice Internal function to set deadline of a task.
    function _setTaskDeadline(uint256 taskId, uint256 deadline) internal {
        if (deadline == 0) revert InvalidTask();
        _setUint(keccak256(abi.encode(address(this), ".tasks.", taskId, ".deadline")), deadline);
    }

    /// @notice Internal function to set detail of a task.
    function _setTaskDetail(uint256 taskId, string calldata detail) internal {
        if (bytes(detail).length == 0) deleteString(keccak256(abi.encode(address(this), ".tasks.", taskId, ".detail")));
        _setString(keccak256(abi.encode(address(this), ".tasks.", taskId, ".detail")), detail);
    }

    /// @notice Increment and return task id.
    function incrementTaskId() internal returns (uint256) {
        return addUint(keccak256(abi.encode(address(this), "tasks.count")), 1);
    }

    /// @notice Increment number of task completions by task id by authorized Quest contracts only.
    function incrementTotalTaskCompletions(uint256 taskId) external payable onlyQuest {
        addUint(keccak256(abi.encode(address(this), ".tasks.", taskId, ".completions")), 1);
    }

    /// @notice Increment and return number of tasks a mission.
    function incrementTaskMissionCount(uint256 taskId) internal returns (uint256) {
        return addUint(keccak256(abi.encode(address(this), ".tasks.", taskId, ".missionCount")), 1);
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
        _setMission(creator, title, detail, taskIds);
    }

    /// @notice Create mission with payment.
    function payToSetMission(address creator, string calldata title, string calldata detail, uint256[] calldata taskIds)
        external
        payable
        priceCheck
    {
        _setMission(creator, title, detail, taskIds);
    }

    /// @notice Update creator of a mission.
    function setMissionCreator(uint256 missionId, address creator) external payable onlyOperator {
        _setMissionCreator(missionId, creator);
    }

    /// @notice Update title of a mission.
    function setMissionTitle(uint256 missionId, string calldata title) external payable onlyOperator {
        _setMissionTitle(missionId, title);
    }

    /// @notice Update detail of a mission.
    function setMissionDetail(uint256 missionId, string calldata detail) external payable onlyOperator {
        _setMissionDetail(missionId, detail);
    }

    /// @notice Add tasks to a mission.
    function addMissionTasks(uint256 missionId, uint256[] calldata taskIds) external payable onlyOperator {
        if (taskIds.length > 0) _addMissionTasks(missionId, taskIds);
    }

    /// @notice Update a task by its order in a given mission.
    function setMissionTaskId(uint256 missionId, uint256 order, uint256 newTaskId) external payable onlyOperator {
        if (this.getTaskCreator(newTaskId) == address(0)) revert InvalidTask();

        // Delete status of old task id.
        uint256 oldTaskId = this.getMissionTaskId(missionId, order);
        deleteIsTaskInMission(missionId, oldTaskId);

        // Update task by its order.
        updateTaskInMission(missionId, order, newTaskId);

        // Associate mission with new task.
        associateMissionWithTask(missionId, newTaskId);

        // Update status of new task.
        setIsTaskInMission(missionId, newTaskId, true);

        // Update mission deadline, if needed.
        updateMissionDeadline(missionId, newTaskId);
    }

    /// @notice Increment and return mission id.
    function incrementMissionId() internal returns (uint256) {
        return addUint(keccak256(abi.encode(address(this), "missions.count")), 1);
    }

    /// @notice Internal function to create a mission.
    function _setMission(address creator, string calldata title, string calldata detail, uint256[] calldata taskIds)
        internal
    {
        // Retrieve missionId.
        uint256 missionId = incrementMissionId();

        // Set new mission content.
        if (taskIds.length == 0) revert InvalidMission();
        _addMissionTasks(missionId, taskIds);
        _setMissionDeadline(missionId, taskIds);
        _setMissionCreator(missionId, creator);
        _setMissionDetail(missionId, detail);
        _setMissionTitle(missionId, title);
    }

    /// @notice Add tasks to a mission.
    function _addMissionTasks(uint256 missionId, uint256[] calldata taskIds) internal {
        uint256 length = taskIds.length;
        for (uint256 i = 0; i < length; ++i) {
            // Add task.
            addNewTaskToMission(missionId, taskIds[i]);

            // Associate mission with given task.
            associateMissionWithTask(missionId, taskIds[i]);

            // Update status of task id in given mission.
            setIsTaskInMission(missionId, taskIds[i], true);
        }
    }

    /// @notice Set whether a task is part of a mission.
    function setIsTaskInMission(uint256 missionId, uint256 taskId, bool status) internal {
        _setBool(keccak256(abi.encode(address(this), ".missions.", missionId, ".taskIds.", taskId, ".exists")), status);
    }

    /// @notice Set whether a task is part of a mission.
    function deleteIsTaskInMission(uint256 missionId, uint256 taskId) internal {
        deleteBool(keccak256(abi.encode(address(this), ".missions.", missionId, ".taskIds.", taskId, ".exists")));
    }

    /// @notice Associate a task with a given mission.
    function addNewTaskToMission(uint256 missionId, uint256 taskId) internal {
        uint256 count = incrementMissionTaskCount(missionId);
        _setUint(keccak256(abi.encode(address(this), ".missions.", missionId, ".taskIds.", count)), taskId);
    }

    /// @notice Increment and return number of tasks a mission.
    function incrementMissionTaskCount(uint256 missionId) internal returns (uint256) {
        return addUint(keccak256(abi.encode(address(this), ".missions.", missionId, ".taskCount")), 1);
    }

    /// @notice Associate a task with a given mission.
    function updateTaskInMission(uint256 missionId, uint256 order, uint256 taskId) internal {
        _setUint(keccak256(abi.encode(address(this), ".missions.", missionId, ".taskIds.", order)), taskId);
    }

    /// @notice Associate a mission with a given task.
    function associateMissionWithTask(uint256 missionId, uint256 taskId) internal {
        uint256 count = incrementTaskMissionCount(taskId);
        _setUint(keccak256(abi.encode(address(this), ".tasks.", taskId, ".missionIds.", count)), missionId);
    }

    /// @notice Internal function to set creator of a mission.
    function _setMissionCreator(uint256 missionId, address creator) internal {
        if (creator == address(0)) revert InvalidMission();
        _setAddress(keccak256(abi.encode(address(this), ".missions.", missionId, ".creator")), creator);
    }

    /// @notice Internal function to set detail of a mission.
    function _setMissionDetail(uint256 missionId, string calldata detail) internal {
        if (bytes(detail).length == 0) {
            deleteString(keccak256(abi.encode(address(this), ".missions.", missionId, ".detail")));
        }
        _setString(keccak256(abi.encode(address(this), ".missions.", missionId, ".detail")), detail);
    }

    /// @notice Internal function to set title of a mission.
    function _setMissionTitle(uint256 missionId, string calldata title) internal {
        if (bytes(title).length == 0) revert InvalidMission();
        _setString(keccak256(abi.encode(address(this), ".missions.", missionId, ".title")), title);
    }

    // /// @notice Set mission deadline.
    // function setMissionDeadline(uint256 missionId) internal returns (uint256) {
    //     uint256 deadline = this.getMissionDeadline(missionId);

    //     // Confirm deadline is initialized.
    //     if (deadline == 0) {
    //         // If not, confirm mission is initialized.
    //         if (this.getMissionTaskCount(missionId) > 0) {
    //             // If so, set mission deadline.
    //             return _setMissionDeadline(missionId);
    //         } else {
    //             return 0;
    //         }
    //     } else {
    //         return deadline;
    //     }
    // }

    /// @notice Internal function to retrieve and set deadline of mission by using the latest task deadline.
    function _setMissionDeadline(uint256 missionId, uint256[] calldata taskIds) internal returns (uint256) {
        uint256 deadline;
        uint256 _deadline;

        for (uint256 i = 0; i < taskIds.length; ++i) {
            _deadline = this.getTaskDeadline(taskIds[i]);
            if (_deadline > deadline) deadline = _deadline;
        }

        __setMissionDeadline(missionId, deadline);
        return deadline;
    }

    function __setMissionDeadline(uint256 missionId, uint256 deadline) internal {
        _setUint(keccak256(abi.encode(address(this), ".missions.", missionId, ".deadline")), deadline);
    }

    /// @notice Internal function to retrieve and set deadline of mission by using the latest task deadline.
    function updateMissionDeadline(uint256 missionId, uint256 newTaskId) internal {
        uint256 deadline = this.getMissionDeadline(missionId);
        uint256 _deadline = this.getTaskDeadline(newTaskId);
        if (_deadline > deadline) __setMissionDeadline(missionId, _deadline);
    }

    // /// @notice Internal function to retrieve and set deadline of mission by using the latest task deadline.
    // function _setMissionDeadline(uint256 missionId) internal returns (uint256) {
    //     uint256 deadline;
    //     uint256[] memory taskIds = this.getMissionTaskIds(missionId);

    //     uint256 _deadline;
    //     for (uint256 i = 0; i < taskIds.length; ++i) {
    //         _deadline = this.getTaskDeadline(taskIds[i]);
    //         if (_deadline > deadline) deadline = _deadline;
    //     }

    //     __setMissionDeadline(missionId, deadline);
    //     return deadline;
    // }

    /// @notice Increment number of mission starts by mission id by authorized Quest contracts only.
    function incrementMissionStarts(uint256 missionId) external payable onlyQuest {
        addUint(keccak256(abi.encode(address(this), ".missions.", missionId, ".starts")), 1);
    }

    /// @notice Increment number of mission completions by mission id by authorized Quest contracts only.
    function incrementMissionCompletions(uint256 missionId) external payable onlyQuest {
        addUint(keccak256(abi.encode(address(this), ".missions.", missionId, ".completions")), 1);
    }

    /// @notice Increment number of task completions by task id by authorized Quest contracts only.
    function incrementTotalTaskCompletionsByMission(uint256 missionId, uint256 taskId) external payable onlyQuest {
        addUint(keccak256(abi.encode(address(this), ".missions.", missionId, ".taskIds.", taskId, ".completions")), 1);
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
        return this.getAddress(keccak256(abi.encode(address(this), ".tasks.", taskId, ".creator")));
    }

    /// @notice Get deadline of a task.
    function getTaskDeadline(uint256 taskId) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), ".tasks.", taskId, ".deadline")));
    }

    /// @notice Get detail of a task.
    function getTaskDetail(uint256 taskId) external view returns (string memory) {
        return this.getString(keccak256(abi.encode(address(this), ".tasks.", taskId, ".detail")));
    }

    /// @notice Returns whether a task is part of a mission.
    function isTaskInMission(uint256 missionId, uint256 taskId) external view returns (bool) {
        return this.getBool(
            keccak256(abi.encode(address(this), ".missions.", missionId, ".taskIds.", taskId, ".exists"))
        );
    }

    /// @notice Get number of task completions by task id.
    function getTotalTaskCompletions(uint256 taskId) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), ".tasks.", taskId, ".completions")));
    }

    /// @notice Get number of task completions by task id.
    function getTotalTaskCompletionsByMission(uint256 missionId, uint256 taskId) external view returns (uint256) {
        return this.getUint(
            keccak256(abi.encode(address(this), ".missions.", missionId, ".taskIds.", taskId, ".completions"))
        );
    }

    /// @notice Get number of missions that are associated with a task.
    function getTaskMissionCount(uint256 taskId) external view returns (uint256 missionCount) {
        return this.getUint(keccak256(abi.encode(address(this), ".tasks.", taskId, ".missionCount")));
    }

    /// @notice Get mission ids associated with a task.
    function getTaskMissionId(uint256 taskId, uint256 order) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), ".tasks.", taskId, ".missionIds.", order)));
    }

    /// @notice Get all mission ids associated with a given task.
    function getTaskMissionIds(uint256 taskId) external view returns (uint256[] memory) {
        uint256 count = this.getTaskMissionCount(taskId);
        uint256[] memory missionIds = new uint256[](count);
        for (uint256 i; i < count; ++i) {
            missionIds[i] = this.getTaskMissionId(taskId, i + 1);
        }
        return missionIds;
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
        return this.getAddress(keccak256(abi.encode(address(this), ".missions.", missionId, ".creator")));
    }

    /// @notice Get deadline of a mission.
    function getMissionDeadline(uint256 missionId) external payable returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), ".missions.", missionId, ".deadline")));
    }

    /// @notice Get detail of a mission.
    function getMissionDetail(uint256 missionId) external view returns (string memory) {
        return this.getString(keccak256(abi.encode(address(this), ".missions.", missionId, ".detail")));
    }

    /// @notice Get title of a mission.
    function getMissionTitle(uint256 missionId) external view returns (string memory) {
        return this.getString(keccak256(abi.encode(address(this), ".missions.", missionId, ".title")));
    }

    /// @notice Get the number of mission starts by missionId.
    function getMissionStarts(uint256 missionId) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), ".missions.", missionId, ".starts")));
    }

    /// @notice Get the number of mission completions by missionId.
    function getMissionCompletions(uint256 missionId) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), ".missions.", missionId, ".completions")));
    }

    /// @notice Get number of tasks in a mission.
    function getMissionTaskCount(uint256 missionId) external view returns (uint256 taskCount) {
        return this.getUint(keccak256(abi.encode(address(this), ".missions.", missionId, ".taskCount")));
    }

    /// @notice Get a task id associated with in a given mission by order.
    function getMissionTaskId(uint256 missionId, uint256 order) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), ".missions.", missionId, ".taskIds.", order)));
    }

    /// @notice Get all task ids associated with a given mission.
    function getMissionTaskIds(uint256 missionId) external view returns (uint256[] memory) {
        uint256 count = this.getMissionTaskCount(missionId);
        uint256[] memory taskIds = new uint256[](count);
        for (uint256 i; i < count; ++i) {
            taskIds[i] = this.getMissionTaskId(missionId, i + 1);
        }

        return taskIds;
    }
}
