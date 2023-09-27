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
                id = this.addUint(TASK_ID_KEY, 1);
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

    // Invoked only by Quests
    function setMetricValue(uint256 missionId, uint256 value) external payable onlyOperator {
        // Compute total metric value
        this.addUint(keccak256(abi.encode(address(this), missionId, ".metric.total")), value);

        // Increment number of metric entries
        this.addUint(keccak256(abi.encode(address(this), missionId, ".metric.count")), 1);

        // Set metric entry
        this.setUint(
            keccak256(
                abi.encode(
                    address(this),
                    missionId,
                    ".metric.",
                    this.getUint(keccak256(abi.encode(address(this), missionId, ".metric.count")))
                )
            ),
            value
        );
    }

    /// -----------------------------------------------------------------------
    /// Helper Logic
    /// -----------------------------------------------------------------------

    function getMissionId() external view returns (uint256) {
        return this.getUint(keccak256(abi.encode("missions.count")));
    }

    /// @dev Retrieve a Mission
    function getMission(uint256 missionId) external view returns (Mission memory mission) {
        uint256 taskCount = this.getMissionTaskCount(missionId);

        mission.forPurchase = this.getBool(keccak256(abi.encode(address(this), missionId, ".forPurchase")));
        mission.creator = this.getAddress(keccak256(abi.encode(address(this), missionId, ".creator")));
        mission.detail = this.getString(keccak256(abi.encode(address(this), missionId, ".detail")));
        mission.title = this.getString(keccak256(abi.encode(address(this), missionId, ".title")));

        for (uint256 i; i < taskCount;) {
            mission.taskIds[i] = this.getUint(keccak256(abi.encode(address(this), missionId, i)));

            unchecked {
                ++i;
            }
        }

        return mission;
    }

    function getMissionTitle(uint256 missionId) external view returns (string memory) {
        return this.getString(keccak256(abi.encode(address(this), missionId, ".title")));
    }

    function getMissionTaskCount(uint256 missionId) external view returns (uint256 taskCount) {
        return this.getUint(keccak256(abi.encode(address(this), missionId, ".taskCount")));
    }

    function getMissionDeadline(uint256 missionId) external view returns (uint256) {
        uint256 taskCount = this.getUint(keccak256(abi.encode(address(this), missionId, ".taskCount")));
        uint256 deadline;

        for (uint256 i; i < taskCount;) {
            uint256 _deadline = this.getUint(keccak256(abi.encode(address(this), i, ".deadline")));
            if (deadline < _deadline) deadline = _deadline;
            unchecked {
                ++i;
            }
        }

        return (deadline);
    }

    function getMetrics(uint256 missionId) external view returns (Metric memory metric) {
        uint256 total = this.getUint(keccak256(abi.encode(address(this), missionId, ".metric.total")));
        uint256 count = this.getUint(keccak256(abi.encode(address(this), missionId, ".metric.count")));
        return Metric({total: total, mean: total / count, numberOfEntries: count});
    }

    function getSingleMetricValue(uint256 missionId, uint256 count) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), missionId, ".metric.", count)));
    }

    function getMetricTitle(uint256 missionId) external view returns (string memory) {
        return this.getString(keccak256(abi.encode(address(this), missionId, ".metric.title")));
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

    function getTaskId() external view returns (uint256) {
        return this.getUint(keccak256(abi.encode("tasks.count")));
    }

    /// @dev Retrieve a Task.
    function getTask(uint256 taskId) external view returns (Task memory task) {
        task.deadline = uint40(this.getUint(keccak256(abi.encode(address(this), taskId, ".deadline"))));
        task.creator = this.getAddress(keccak256(abi.encode(address(this), taskId, ".creator")));
        task.detail = this.getString(keccak256(abi.encode(address(this), taskId, ".detail")));

        return (task);
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
