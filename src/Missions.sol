// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {IStorage} from "./interface/IStorage.sol";
import {IMissions} from "./interface/IMissions.sol";
import {Storage} from "./Storage.sol";

/// @title Missions
/// @notice A list of missions and tasks.
/// @author audsssy.eth

struct Mission {
    bool forPurchase; // Status for purchase.
    address creator; // Mission creator.
    uint40 deadline; // Mission deadline.
    uint40 starts; // Number of mission completions.
    uint40 completions; // Number of mission completions.
    uint256[] taskIds; // An array of Tasks by id.
    uint256 taskCount; // Number of Tasks in a Mission.
    string title; // Mission Title.
    string detail; // Mission detail.
}

struct Task {
    address creator; // Creator of a Task.
    uint40 deadline; // Deadline to complete a Task.
    uint40 completions; // Number of time a task completions.
    string detail; // Task detail.
}

contract Missions is Storage {
    /// -----------------------------------------------------------------------
    /// Custom Errors
    /// -----------------------------------------------------------------------

    error NotAuthorized();
    error TransferFailed();
    error InvalidMission();
    error NotForSale();
    error AmountMismatch();

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    modifier onlyQuest() {
        if (!this.getAllowedQuest(msg.sender)) revert NotAuthorized();
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

    function getAllowedQuest(address target) external view returns (bool) {
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
        setTaskCreator(taskId, creator);
        setTaskDeadline(taskId, deadline);
        setTaskDetail(taskId, detail);
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
        setMissionCreator(missionId, creator);
        setMissionDetail(missionId, detail);
        setMissionTitle(missionId, title);
        _setMissionTasks(missionId, taskIds);
    }

    /// -----------------------------------------------------------------------
    /// Mission Setter Logic
    /// -----------------------------------------------------------------------

    function incrementMissionId() internal returns (uint256) {
        return addUint(keccak256(abi.encode(address(this), "missions.count")), 1);
    }

    /// @notice Associate multple tasks with a mission.
    function setMissionTasks(uint256 missionId, uint256[] calldata taskIds) external payable onlyOperator {
        _setMissionTasks(missionId, taskIds);
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

    function setMissionCreator(uint256 missionId, address creator) internal {
        _setAddress(keccak256(abi.encode(address(this), missionId, ".creator")), creator);
    }

    function setMissionDetail(uint256 missionId, string calldata detail) internal {
        _setString(keccak256(abi.encode(address(this), missionId, ".detail")), detail);
    }

    function setMissionTitle(uint256 missionId, string calldata title) internal {
        _setString(keccak256(abi.encode(address(this), missionId, ".title")), title);
    }

    function setMissionDeadline(uint256 missionId, uint256 deadline) internal {
        _setUint(keccak256(abi.encode(address(this), missionId, ".deadline")), deadline);
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

    function getMissionTaskId(uint256 missionId, uint256 count) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), missionId, ".taskIds.", count)));
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
    function getMissionDeadline(uint256 missionId) external payable returns (uint256) {
        uint256 deadline = _getMissionDeadline(missionId);

        if (deadline == 0) {
            if (this.getMissionTaskCount(missionId) > 0) {
                return calculateMissionDeadline(missionId);
            } else {
                return 0;
            }
        } else {
            return deadline;
        }
    }

    function getMissionStarts(uint256 missionId) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), missionId, ".starts")));
    }

    function getMissionCompletions(uint256 missionId) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), missionId, ".completions")));
    }

    /// -----------------------------------------------------------------------
    /// Task Setter Logic
    /// -----------------------------------------------------------------------

    function incrementTaskId() internal returns (uint256) {
        return addUint(keccak256(abi.encode("tasks.count")), 1);
    }

    function setTaskCreator(uint256 taskId, address creator) internal {
        _setAddress(keccak256(abi.encode(address(this), taskId, ".creator")), creator);
    }

    function setTaskDeadline(uint256 taskId, uint256 deadline) internal {
        _setUint(keccak256(abi.encode(address(this), taskId, ".deadline")), deadline);
    }

    function setTaskDetail(uint256 taskId, string calldata detail) internal {
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

    function calculateMissionDeadline(uint256 missionId) internal returns (uint256) {
        uint256 deadline;
        uint256[] memory taskIds = this.getMissionTaskIds(missionId);

        for (uint256 i; i < taskIds.length;) {
            uint256 _deadline = this.getUint(keccak256(abi.encode(address(this), taskIds[i], ".deadline")));
            if (deadline < _deadline) deadline = _deadline;
            unchecked {
                ++i;
            }
        }

        setMissionDeadline(missionId, deadline);
        return deadline;
    }

    /// @dev Calculate and update number of completions by mission id
    function aggregateMissionsCompletions(address missions, uint256 missionId, address[] calldata storages)
        external
        payable
    {
        uint256 count;

        for (uint256 i; i < storages.length;) {
            unchecked {
                count += IStorage(storages[i]).getUint(keccak256(abi.encode(missions, missionId, ".completions")));
                ++i;
            }
        }

        this.setUint(keccak256(abi.encode(missions, missionId, ".completions")), count);
    }
}
