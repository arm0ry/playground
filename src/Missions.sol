// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {SVG} from "./utils/SVG.sol";
import {JSON} from "./utils/JSON.sol";

import {ERC1155} from "solbase/tokens/ERC1155/ERC1155.sol";
import {Base64} from "solbase/utils/Base64.sol";
import {LibString} from "solbase/utils/LibString.sol";

import {IDirectory} from "./interface/IDirectory.sol";

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
    uint8 xp; // Xp of a Task
    uint40 duration; // Time limit to complete a Task
    address creator; // Creator of a Task
    string detail; // Task detail
}

contract Missions is ERC1155 {
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

    /// -----------------------------------------------------------------------
    /// Task Storage
    /// -----------------------------------------------------------------------

    address public dao;

    uint256 public royalties;

    uint256 public missionId;

    uint256 public taskId;

    // A list of tasks ordered by taskId
    mapping(uint256 => Task) public tasks;

    // A list of missions ordered by missionId
    mapping(uint256 => Mission) public missions;

    // Mission Id -> number of completions
    mapping(uint256 => uint256) public completions;

    /// -----------------------------------------------------------------------
    /// Modifier
    /// -----------------------------------------------------------------------

    modifier onlyDao() {
        if (dao != msg.sender) revert Unauthorized();
        _;
    }

    /// -----------------------------------------------------------------------
    /// Metadata Storage & Logic
    /// -----------------------------------------------------------------------

    function uri(uint256 _missionId) public view override returns (string memory) {
        return _buildURI(_missionId);
    }

    function _buildURI(uint256 _missionId) private view returns (string memory) {
        return JSON._formattedMetadata(
            string.concat("Access # ", SVG._uint2str(_missionId)),
            "Kali Access Manager",
            string.concat(
                '<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300" style="background:#191919">',
                SVG._rect(
                    string.concat(
                        SVG._prop("fill", "maroon"),
                        SVG._prop("x", "20"),
                        SVG._prop("y", "50"),
                        SVG._prop("width", SVG._uint2str(160)),
                        SVG._prop("height", SVG._uint2str(10))
                    ),
                    SVG.NULL
                ),
                SVG._text(
                    string.concat(
                        SVG._prop("x", "20"),
                        SVG._prop("y", "90"),
                        SVG._prop("font-size", "12"),
                        SVG._prop("fill", "white")
                    ),
                    string.concat("Completions: ", SVG._uint2str(completions[_missionId]))
                ),
                SVG._image(
                    "https://gateway.pinata.cloud/ipfs/Qmb2AWDjE8GNUob83FnZfuXLj9kSs2uvU9xnoCbmXhH7A1",
                    string.concat(SVG._prop("x", "215"), SVG._prop("y", "220"), SVG._prop("width", "80"))
                ),
                "</svg>"
            )
        );
    }

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor() {
        royalties = 50; // default royalties 50%
    }

    function initialize(address _dao) public payable {
        dao = _dao;
    }

    /// -----------------------------------------------------------------------
    /// Mission / Task Logic
    /// -----------------------------------------------------------------------

    /// @dev  Create or update tasks.
    /// Note: Recommend calling updateMission immediately after to update associated missions.
    function setTasks(uint256[] calldata taskIds, Task[] calldata _tasks) external payable onlyDao {
        uint256 length = taskIds.length;

        if (taskIds.length == 0) {
            uint256 tasksLength = _tasks.length;

            for (uint256 i; i < tasksLength;) {
                unchecked {
                    ++taskId;
                }

                tasks[taskId] = Task({
                    xp: _tasks[i].xp,
                    duration: _tasks[i].duration,
                    creator: _tasks[i].creator,
                    detail: _tasks[i].detail
                });

                // Unchecked because the only math done is incrementing
                // the array index counter which cannot possibly overflow.
                unchecked {
                    ++i;
                }
            }
        } else {
            if (length != _tasks.length) revert LengthMismatch();

            for (uint256 i; i < length;) {
                tasks[taskIds[i]] = Task({
                    xp: _tasks[i].xp,
                    duration: _tasks[i].duration,
                    creator: _tasks[i].creator,
                    detail: _tasks[i].detail
                });

                // Unchecked because the only math done is incrementing
                // the array index counter which cannot possibly overflow.
                unchecked {
                    ++i;
                }
            }
        }
    }

    /// @dev Create missions.
    function setMission(
        uint8 _missionId,
        bool _forPurchase,
        address _creator,
        string calldata _title,
        string calldata _detail,
        uint256[] calldata _taskIds,
        uint256 _fee
    ) external payable onlyDao {
        if (_taskIds.length == 0) revert InvalidMission();

        if (_missionId == 0) {
            unchecked {
                ++missionId;
            }

            // Create a Mission
            missions[missionId] = Mission({
                forPurchase: _forPurchase,
                creator: _creator,
                title: _title,
                detail: _detail,
                taskIds: _taskIds,
                fee: _fee,
                completions: 0
            });
        } else {
            delete missions[_missionId];

            // Update a Mission
            missions[_missionId] = Mission({
                forPurchase: _forPurchase,
                creator: _creator,
                title: _title,
                detail: _detail,
                taskIds: _taskIds,
                fee: _fee,
                completions: 0
            });
        }
    }

    /// -----------------------------------------------------------------------
    /// dao Logic
    /// -----------------------------------------------------------------------

    /// @dev Update missions
    function updateDao(address _dao) external payable onlyDao {
        if (_dao != dao) {
            dao = _dao;
        }
    }

    /// @dev Update royalties.
    function updateRoyalties(uint256 _royalties) external payable onlyDao {
        if (_royalties > 100) revert InvalidRoyalties();
        royalties = _royalties;
    }

    /// -----------------------------------------------------------------------
    /// Mint Logic
    /// -----------------------------------------------------------------------

    /// @dev Purchase a Mission NFT.
    function purchase(uint256 _missionId) external payable {
        (Mission memory mission,) = this.getMission(_missionId);

        // Confirm Mission is for purchase
        if (!mission.forPurchase) revert NotForSale();
        if (mission.fee != msg.value) revert AmountMismatch();

        uint256 r = msg.value * royalties / 100;
        (bool success,) = mission.creator.call{value: r}("");
        if (!success) revert TransferFailed();

        (success,) = dao.call{value: mission.fee - r}("");
        if (!success) revert TransferFailed();

        _mint(msg.sender, _missionId, 1, "0x");
    }

    /// -----------------------------------------------------------------------
    /// Helper Functions
    /// -----------------------------------------------------------------------

    /// @dev Retrieve a Task.
    function getTask(uint256 _taskId) external view returns (Task memory) {
        return tasks[_taskId];
    }

    /// @dev Retrieve a Mission
    function getMission(uint256 _missionId) external view returns (Mission memory mission, uint256) {
        mission = missions[_missionId];
        return (mission, mission.taskIds.length);
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
            Task memory task = this.getTask(_taskIds[i]);
            duration += task.duration;
            totalXp += task.xp;

            // cannot possibly overflow
            unchecked {
                ++i;
            }
        }

        return (totalXp, duration);
    }

    /// @dev Calculate and update number of completions by mission id
    function aggregateMissionsCompletions(uint256 _missionId, address[] calldata directories) external payable {
        uint256 count;

        for (uint256 i; i < directories.length;) {
            unchecked {
                count += IDirectory(directories[i]).getUint(
                    keccak256(abi.encodePacked(address(this), _missionId, ".completions"))
                );
                ++i;
            }
        }

        completions[_missionId] = count;
    }

    receive() external payable {}
}
