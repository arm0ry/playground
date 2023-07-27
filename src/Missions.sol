// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {ERC1155} from "solbase/tokens/ERC1155/ERC1155.sol";
import {IQuests} from "./interface/IQuests.sol";
import {Base64} from "solbase/utils/Base64.sol";
import {LibString} from "solbase/utils/LibString.sol";

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

    error NotForSale();

    error AmountMismatch();

    /// -----------------------------------------------------------------------
    /// Task Storage
    /// -----------------------------------------------------------------------

    address public admin;

    uint256 public royalties;

    uint256 public taskId;

    // A list of tasks ordered by taskId
    mapping(uint256 => Task) public tasks;

    uint256 public missionId;

    // A list of missions ordered by missionId
    mapping(uint256 => Mission) public missions;

    IQuests public quests;

    /// -----------------------------------------------------------------------
    /// Modifier
    /// -----------------------------------------------------------------------

    modifier onlyAdmin() {
        if (admin != msg.sender) revert Unauthorized();
        _;
    }

    /// -----------------------------------------------------------------------
    /// Metadata Storage & Logic
    /// -----------------------------------------------------------------------

    function uri(uint256 _missionId) public view virtual override returns (string memory) {
        string memory name = string(abi.encodePacked("Mission #", LibString.toString(_missionId)));
        string memory description = "Arm0ry Missions";
        string memory image = generateBase64Image(_missionId);

        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                            '{"name":"',
                            name,
                            '", "description":"',
                            description,
                            '", "image": "',
                            "data:image/svg+xml;base64,",
                            image,
                            '"}'
                        )
                    )
                )
            )
        );
    }

    function generateBase64Image(uint256 _missionId) public view returns (string memory) {
        return Base64.encode(bytes(generateImage(_missionId)));
    }

    function generateImage(uint256 _missionId) public view returns (string memory) {
        (Mission memory mission,) = this.getMission(_missionId);
        uint256 completions = quests.getMissionCompletionsCount(uint8(_missionId));

        return string(
            abi.encodePacked(
                '<svg class="svgBody" width="300" height="300" viewBox="0 0 300 300" xmlns="http://www.w3.org/2000/svg">',
                '<rect width="300" height="300" rx="10" style="fill:#FFFFFF" />',
                '<text x="15" y="100" class="medium" stroke="black">',
                mission.title,
                "</text>",
                '<text x="15" y="150" class="medium" stroke="grey">COMPLETIONS: </text>',
                '<rect x="15" y="155" width="300" height="30" style="fill:yellow;opacity:0.2"/>',
                '<text x="20" y="173" class="small">',
                LibString.toString(completions),
                "</text>",
                '<style>.svgBody {font-family: "Courier New" } .small {font-size: 12px;}.medium {font-size: 18px;}</style>',
                "</svg>"
            )
        );
    }

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor() {
        royalties = 10; // default royalties 10%
    }

    function initialize(IQuests _quests, address _admin) public payable {
        admin = _admin;
        quests = _quests;
    }

    /// -----------------------------------------------------------------------
    /// Mission / Task Logic
    /// -----------------------------------------------------------------------

    /// @dev  Create or update tasks.
    /// Note: Recommend calling updateMission immediately after to update associated missions.
    function setTasks(uint256[] calldata taskIds, Task[] calldata _tasks) external payable onlyAdmin {
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
    ) external payable onlyAdmin {
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
                fee: _fee
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
                fee: _fee
            });
        }
    }

    /// -----------------------------------------------------------------------
    /// Admin Logic
    /// -----------------------------------------------------------------------

    /// @dev Update missions
    function updateAdmin(address _admin) external payable onlyAdmin {
        if (_admin != admin) {
            admin = _admin;
        }
    }

    /// @dev Update royalties.
    function updateRoyalties(uint256 _royalties) external payable onlyAdmin {
        if (_royalties > 100) revert InvalidRoyalties();
        royalties = _royalties;
    }

    /// @dev Update contracts.
    function updateContracts(IQuests _quests) external payable onlyAdmin {
        if (address(_quests) == address(0)) revert InvalidContract();
        quests = _quests;
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

        (success,) = admin.call{value: mission.fee - r}("");
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

    receive() external payable {}
}
