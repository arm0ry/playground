// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {IDirectory} from "./interface/IDirectory.sol";
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
    uint256 fee; // Amount for purchase
    uint256 completions; // The number of mission completions
}

struct Task {
    uint40 deadline; // Deadline to complete a Task
    address creator; // Creator of a Task
    string detail; // Task detail
}

// TODO: Separate Missions from Impact NFT minter
// TODO: Move royalties to Impact NFT minter
contract Missions is Storage {
    /// -----------------------------------------------------------------------
    /// Custom Errors
    /// -----------------------------------------------------------------------

    error TransferFailed();

    error InvalidRoyalties();

    error InvalidContract();

    error InvalidMission();

    error InvalidMetric();

    error NotForSale();

    error AmountMismatch();

    error Unauthorized();

    /// -----------------------------------------------------------------------
    /// Task Storage
    /// -----------------------------------------------------------------------

    // address public dao;

    uint256 public royalties;

    bytes32 immutable MISSION_ID_KEY = keccak256(abi.encodePacked(address(this), "missionCount"));

    bytes32 immutable TASK_ID_KEY = keccak256(abi.encodePacked(address(this), "taskCount"));

    // A list of tasks ordered by taskId
    // mapping(uint256 => Task) public tasks;

    // A list of missions ordered by missionId
    // mapping(uint256 => Mission) public missions;

    // Mission Id -> number of completions
    // mapping(uint256 => uint256) public completions;

    /// -----------------------------------------------------------------------
    /// Modifier
    /// -----------------------------------------------------------------------

    // modifier onlyOperator() {
    //     if (dao != msg.sender) revert Unauthorized();
    //     _;
    // }

    /// -----------------------------------------------------------------------
    /// Metadata Storage & Logic
    /// -----------------------------------------------------------------------

    // function uri(uint256 _missionId) public view override returns (string memory) {
    //     return _buildURI(_missionId);
    // }

    // function _buildURI(uint256 _missionId) private view returns (string memory) {
    //     (Mission memory m,) = this.getMission(_missionId);
    //     return JSON._formattedMetadata(
    //         string.concat("Mission #", SVG._uint2str(_missionId)),
    //         m.title,
    //         string.concat(
    //             '<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300" style="background:#191919">',
    //             SVG._rect(
    //                 string.concat(
    //                     SVG._prop("fill", "maroon"),
    //                     SVG._prop("x", "20"),
    //                     SVG._prop("y", "50"),
    //                     SVG._prop("width", SVG._uint2str(160)),
    //                     SVG._prop("height", SVG._uint2str(10))
    //                 ),
    //                 SVG.NULL
    //             ),
    //             SVG._text(
    //                 string.concat(
    //                     SVG._prop("x", "20"),
    //                     SVG._prop("y", "90"),
    //                     SVG._prop("font-size", "12"),
    //                     SVG._prop("fill", "white")
    //                 ),
    //                 string.concat("Completions: ", SVG._uint2str(completions[_missionId]))
    //             ),
    //             SVG._image(
    //                 "https://gateway.pinata.cloud/ipfs/Qmb2AWDjE8GNUob83FnZfuXLj9kSs2uvU9xnoCbmXhH7A1",
    //                 string.concat(SVG._prop("x", "215"), SVG._prop("y", "220"), SVG._prop("width", "80"))
    //             ),
    //             "</svg>"
    //         )
    //     );
    // }

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor() {}

    // function initialize(address _dao) public payable {
    //     dao = _dao;
    // }

    /// -----------------------------------------------------------------------
    /// Mission / Task Logic
    /// -----------------------------------------------------------------------

    /// @dev  Create or update tasks.
    /// Note: Recommend calling updateMission immediately after to update associated missions.
    function setTasks(uint256 _taskId, Task calldata task) external payable onlyOperator {
        uint256 id;

        if (_taskId == 0) {
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
        _setTask(_taskId, task);
    }

    /// @dev Create missions.
    function setMission(uint256 _missionId, Mission calldata mission) external payable onlyOperator {
        uint256 length = mission.taskIds.length;
        if (length == 0) revert InvalidMission();

        if (_missionId == 0) {
            uint256 id;

            unchecked {
                // Increment mission id.
                id = this.addUint(MISSION_ID_KEY, 1);
            }

            // Instantiate a new Mission.
            _setMission(id, mission);
        } else {
            // Update existing Mission.
            _setMission(_missionId, mission);
        }
    }

    /// -----------------------------------------------------------------------
    /// Mint Logic
    /// -----------------------------------------------------------------------

    /// @dev Purchase an Impact NFT.
    // function purchase(uint256 _missionId) external payable {
    //     (Mission memory mission,) = this.getMission(_missionId);

    //     // Confirm Mission is for purchase
    //     if (!mission.forPurchase) revert NotForSale();
    //     if (mission.fee != msg.value) revert AmountMismatch();

    //     uint256 r = msg.value * royalties / 100;
    //     (bool success,) = mission.creator.call{value: r}("");
    //     if (!success) revert TransferFailed();

    //     (success,) = dao.call{value: mission.fee - r}("");
    //     if (!success) revert TransferFailed();

    //     // _mint(msg.sender, _missionId, 1, "0x");
    // }

    /// -----------------------------------------------------------------------
    /// Helper Functions
    /// -----------------------------------------------------------------------

    /// @dev Retrieve royalties by mission id.
    // function getRoyalties(uint256 _missionId) external view returns (uint256) {
    //     return uintStorage[ROYALTIES_KEY];
    // }

    /// @dev Retrieve a Task.
    function getTask(uint256 taskId) external view returns (Task memory task) {
        task.deadline = uint40(this.getUint(keccak256(abi.encodePacked(address(this), taskId, ".deadline"))));
        task.creator = this.getAddress(keccak256(abi.encodePacked(address(this), taskId, ".creator")));
        task.detail = this.getString(keccak256(abi.encodePacked(address(this), taskId, ".detail")));

        return (task);
    }

    /// @dev Retrieve a Mission
    function getMission(uint256 missionId) external view returns (Mission memory mission, uint256 taskCount) {
        taskCount = this.getUint(keccak256(abi.encodePacked(address(this), missionId, ".taskCount")));

        mission.forPurchase = this.getBool(keccak256(abi.encodePacked(address(this), missionId, ".forPurchase")));
        mission.fee = this.getUint(keccak256(abi.encodePacked(address(this), missionId, ".fee")));
        mission.creator = this.getAddress(keccak256(abi.encodePacked(address(this), missionId, ".creator")));
        mission.detail = this.getString(keccak256(abi.encodePacked(address(this), missionId, ".detail")));
        mission.title = this.getString(keccak256(abi.encodePacked(address(this), missionId, ".title")));

        for (uint256 i; i < taskCount;) {
            mission.taskIds[i] = this.getUint(keccak256(abi.encodePacked(address(this), missionId, i)));

            unchecked {
                ++i;
            }
        }

        return (mission, taskCount);
    }

    function getMissionDeadline(uint256 missionId) external view returns (uint256) {
        uint256 taskCount = this.getUint(keccak256(abi.encodePacked(address(this), missionId, ".taskCount")));

        uint256 deadline;

        for (uint256 i; i < taskCount;) {
            uint256 _deadline = this.getUint(keccak256(abi.encodePacked(address(this), i, ".deadline")));
            if (deadline < _deadline) deadline = _deadline;

            unchecked {
                ++i;
            }
        }

        return (deadline);
    }

    function isTaskInMission(uint256 _missionId, uint256 _taskId) external payable returns (bool) {
        (Mission memory mission, uint256 length) = this.getMission(_missionId);
        if (length > 1) {
            for (uint256 i; i < length;) {
                if (mission.taskIds[i] == _taskId) return true;

                unchecked {
                    ++i;
                }
            }
            return false;
        } else if (length == 1) {
            if (mission.taskIds[0] == _taskId) return true;
            else return false;
        } else {
            revert InvalidMission();
        }
    }

    /// @dev Calculate total xp and duration of a set of Tasks
    function aggregateTasksData(uint256[] calldata _taskIds) external payable returns (uint256, uint40) {
        // Calculate xp and duration for Mission
        uint8 totalXp;
        uint40 duration;

        for (uint256 i; i < _taskIds.length;) {
            // Aggregate Task duration to create Mission duration
            // Task memory task = this.getTask(_taskIds[i]);
            // duration += task.duration;
            // totalXp += task.xp;

            // cannot possibly overflow
            unchecked {
                ++i;
            }
        }

        return (totalXp, duration);
    }

    /// @dev Calculate and update number of completions by mission id
    function aggregateMissionsCompletions(uint256 missionId, address[] calldata directories) external payable {
        uint256 count;

        for (uint256 i; i < directories.length;) {
            unchecked {
                count += IDirectory(directories[i]).getUint(
                    keccak256(abi.encodePacked(address(this), missionId, ".completions"))
                );
                ++i;
            }
        }

        this.setUint(keccak256(abi.encodePacked(address(this), missionId, ".completions")), count);
    }

    /// -----------------------------------------------------------------------
    /// Internal Functions
    /// -----------------------------------------------------------------------

    function _setTask(uint256 taskId, Task calldata task) internal {
        this.setUint(keccak256(abi.encodePacked(address(this), taskId, ".deadline")), task.deadline);
        this.setAddress(keccak256(abi.encodePacked(address(this), taskId, ".creator")), task.creator);
        this.setString(keccak256(abi.encodePacked(address(this), taskId, ".detail")), task.detail);
    }

    function _setMission(uint256 missionId, Mission calldata mission) internal {
        this.setBool(keccak256(abi.encodePacked(address(this), missionId, ".forPurchase")), mission.forPurchase);
        this.setUint(keccak256(abi.encodePacked(address(this), missionId, ".fee")), mission.fee);
        this.setUint(keccak256(abi.encodePacked(address(this), missionId, ".taskCount")), mission.taskIds.length);
        this.setAddress(keccak256(abi.encodePacked(address(this), missionId, ".creator")), mission.creator);
        this.setString(keccak256(abi.encodePacked(address(this), missionId, ".detail")), mission.detail);
        this.setString(keccak256(abi.encodePacked(address(this), missionId, ".title")), mission.title);

        for (uint256 i; i < mission.taskIds.length;) {
            this.setUint(keccak256(abi.encodePacked(address(this), missionId, i)), mission.taskIds[i]);
            unchecked {
                ++i;
            }
        }
    }

    receive() external payable {}
}
