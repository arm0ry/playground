// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {IStorage} from "./interface/IStorage.sol";
import {IMissions} from "./interface/IMissions.sol";
import {Storage} from "./Storage.sol";

/// @title Missions
/// @notice A list of missions and tasks.
/// @author audsssy.eth

struct Mission {
    bool forPurchase; // Status for purchase
    address creator; // Creator of Mission
    string title; // Title of Mission
    string detail; // Mission detail
    uint256[] taskIds; // Tasks associated with Mission
    uint256 taskCount; // Number of Tasks
    uint256 starts; // The number of mission completions
    uint256 completions; // The number of mission completions
}

struct Metric {
    uint256 total;
    uint256 mean;
    uint256 numberOfEntries;
}

struct Task {
    uint40 deadline; // Deadline to complete a Task
    address creator; // Creator of a Task
    string detail; // Task detail
    uint256 starts;
    uint256 completions;
}

contract Missions is Storage {
    /// -----------------------------------------------------------------------
    /// Custom Errors
    /// -----------------------------------------------------------------------

    error TransferFailed();

    error InvalidMission();

    error NotForSale();

    error AmountMismatch();

    /// -----------------------------------------------------------------------
    /// Immutable Storage
    /// -----------------------------------------------------------------------

    bytes32 immutable MISSION_ID_KEY = keccak256(abi.encode("missions.count"));
    bytes32 immutable TASK_ID_KEY = keccak256(abi.encode("tasks.count"));

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor() {}

    function initialize() internal virtual {}

    /// -----------------------------------------------------------------------
    /// Modifier
    /// ----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// Mission / Task Logic
    /// -----------------------------------------------------------------------

    /// @dev  Create or update tasks.
    function setTask(uint256 taskId, Task calldata task) external payable onlyOperator {
        uint256 id;

        if (taskId == 0) {
            // Unchecked because the only math done is incrementing
            // the array index counter which cannot possibly overflow.
            unchecked {
                // Increment task id.
                id = this.incrementTaskId();
            }

            // Instantiate a new Task.
            _setTask(id, task);
        }

        // Update existing Task.
        _setTask(taskId, task);
    }

    /// @dev Create or update missions with optional metric.
    function setMission(uint256 missionId, Mission calldata mission, string calldata metricTitle)
        external
        payable
        onlyOperator
    {
        if (mission.taskIds.length == 0) revert InvalidMission();

        if (missionId == 0) {
            uint256 id;
            unchecked {
                // Increment mission id.
                id = this.addUint(MISSION_ID_KEY, 1);
            }

            // Instantiate a new Mission.
            _setMission(id, mission);
            _setMetricTitle(id, metricTitle);
        } else {
            // Update existing Mission.
            _setMission(missionId, mission);
            _setMetricTitle(missionId, metricTitle);
        }
    }

    /// -----------------------------------------------------------------------
    /// Helper Logic
    /// -----------------------------------------------------------------------
    function incrementMissionId() external returns (uint256) {
        return this.addUint(keccak256(abi.encode("missions.count")), 1);
    }

    function getMissionId() external view returns (uint256) {
        return this.getUint(keccak256(abi.encode("missions.count")));
    }

    /// @dev Retrieve a Mission
    function getMission(uint256 missionId) external view returns (Mission memory mission) {
        mission.forPurchase = this.getMissionPurchaseStatus(missionId);
        mission.creator = this.getMissionCreator(missionId);
        mission.detail = this.getMissionDetail(missionId);
        mission.title = this.getMissionTitle(missionId);
        mission.taskIds = this.getMissionTaskIds(missionId);
        mission.taskCount = this.getMissionTaskCount(missionId);
        mission.starts = this.getMissionStarts(missionId);
        mission.completions = this.getMissionCompletions(missionId);

        return mission;
    }

    function getMissionPurchaseStatus(uint256 missionId) external view returns (bool) {
        return this.getBool(keccak256(abi.encode(address(this), missionId, ".forPurchase")));
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

    function getMissionTaskIds(uint256 missionId) external view returns (uint256[] memory) {
        uint256[] memory taskIds;

        uint256 taskCount = this.getMissionTaskCount(missionId);

        for (uint256 i; i < taskCount;) {
            taskIds[i] = this.getUint(keccak256(abi.encode(address(this), missionId, i)));

            unchecked {
                ++i;
            }
        }

        return taskIds;
    }

    function getMissionDeadline(uint256 missionId) external view returns (uint256) {
        uint256[] memory taskIds = this.getMissionTaskIds(missionId);
        uint256 deadline;

        for (uint256 i; i < taskIds.length;) {
            uint256 _deadline = this.getUint(keccak256(abi.encode(address(this), taskIds[i], ".deadline")));
            if (deadline < _deadline) deadline = _deadline;
            unchecked {
                ++i;
            }
        }

        return (deadline);
    }

    function getMissionLoops(uint256 missionId) external view returns (uint256, uint256[] memory) {
        uint256[] memory taskIds;
        uint256 taskCount = this.getMissionTaskCount(missionId);

        uint256 deadline;

        for (uint256 i; i < taskCount;) {
            taskIds[i] = this.getUint(keccak256(abi.encode(address(this), missionId, i)));

            uint256 _deadline = this.getUint(keccak256(abi.encode(address(this), taskIds[i], ".deadline")));
            if (deadline < _deadline) deadline = _deadline;
            unchecked {
                ++i;
            }
        }

        return (deadline, taskIds);
    }

    function incrementTaskStarts(uint256 taskId) external onlyOperator {
        this.addUint(keccak256(abi.encode(address(this), taskId, ".starts")), 1);
    }

    function getTaskStarts(uint256 taskId) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), taskId, ".starts")));
    }

    function incrementTaskCompletions(uint256 taskId) external onlyOperator {
        this.addUint(keccak256(abi.encode(address(this), taskId, ".completions")), 1);
    }

    function getTaskCompletions(uint256 taskId) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), taskId, ".completions")));
    }

    function getTaskDeadline(uint256 taskId) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), taskId, ".deadline")));
    }

    function getTaskCreator(uint256 taskId) external view returns (address) {
        return this.getAddress(keccak256(abi.encode(address(this), taskId, ".creator")));
    }

    function getTaskDetail(uint256 taskId) external view returns (string memory) {
        return this.getString(keccak256(abi.encode(address(this), taskId, ".detail")));
    }

    function isTaskInMission(uint256 missionId, uint256 taskId) external payable returns (bool) {
        Mission memory mission = this.getMission(missionId);
        uint256 length = this.getMissionTaskCount(missionId);

        if (length > 1) {
            for (uint256 i; i < length;) {
                if (mission.taskIds[i] == taskId) return true;

                unchecked {
                    ++i;
                }
            }
            return false;
        } else if (length == 1) {
            if (mission.taskIds[0] == taskId) return true;
            else return false;
        } else {
            revert InvalidMission();
        }
    }

    function incrementTaskId() external returns (uint256) {
        return this.addUint(keccak256(abi.encode("tasks.count")), 1);
    }

    function getTaskId() external view returns (uint256) {
        return this.getUint(keccak256(abi.encode("tasks.count")));
    }

    /// @dev Retrieve a Task.
    function getTask(uint256 taskId) external view returns (Task memory task) {
        task.deadline = uint40(this.getTaskDeadline(taskId));
        task.creator = this.getTaskCreator(taskId);
        task.detail = this.getTaskDetail(taskId);
        task.starts = this.getTaskStarts(taskId);
        task.completions = this.getTaskCompletions(taskId);

        return task;
    }

    function incrementMissionStarts(uint256 missionId) external onlyOperator {
        this.addUint(keccak256(abi.encode(address(this), missionId, ".starts")), 1);
    }

    function getMissionStarts(uint256 missionId) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), missionId, ".starts")));
    }

    function incrementMissionCompletions(uint256 missionId) external onlyOperator {
        this.addUint(keccak256(abi.encode(address(this), missionId, ".completions")), 1);
    }

    function getMissionCompletions(uint256 missionId) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), missionId, ".completions")));
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

    /// -----------------------------------------------------------------------
    /// Internal Functions
    /// -----------------------------------------------------------------------

    function _setTask(uint256 taskId, Task calldata task) internal {
        this.setUint(keccak256(abi.encode(address(this), taskId, ".deadline")), task.deadline);
        this.setAddress(keccak256(abi.encode(address(this), taskId, ".creator")), task.creator);
        this.setString(keccak256(abi.encode(address(this), taskId, ".detail")), task.detail);
    }

    function _setMission(uint256 missionId, Mission calldata mission) internal {
        this.setBool(keccak256(abi.encode(address(this), missionId, ".forPurchase")), mission.forPurchase);
        this.setUint(keccak256(abi.encode(address(this), missionId, ".taskCount")), mission.taskIds.length);
        this.setAddress(keccak256(abi.encode(address(this), missionId, ".creator")), mission.creator);
        this.setString(keccak256(abi.encode(address(this), missionId, ".detail")), mission.detail);
        this.setString(keccak256(abi.encode(address(this), missionId, ".title")), mission.title);

        for (uint256 i; i < mission.taskIds.length;) {
            this.setUint(keccak256(abi.encode(address(this), missionId, i)), mission.taskIds[i]);
            unchecked {
                ++i;
            }
        }
    }

    // Invoked only when creating new Missions
    function _setMetricTitle(uint256 missionId, string calldata title) internal {
        if (bytes(title).length > 0) {
            this.setString(keccak256(abi.encode(address(this), missionId, ".metric.title")), title);
        }
    }
}
