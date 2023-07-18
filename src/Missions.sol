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
    uint8 xp; // The sum of xp of all Tasks in Mission
    uint40 duration; // The sum of time limit of all Tasks in Mission
    address creator; // Creator of Mission
    string title; // Title of Mission
    string detail; // Mission detail
    uint256 requiredXp; // Xp required to participate
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

    // Status indicating if a Task is part of a Mission
    // MissionId => TaskId => True/False
    mapping(uint256 => mapping(uint256 => bool)) public isTaskInMission;

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

    constructor(address _admin, IQuests _quests) {
        admin = _admin;
        quests = _quests;
        royalties = 10; // default royalties 10%
    }

    /// -----------------------------------------------------------------------
    /// Mission / Task Logic
    /// -----------------------------------------------------------------------

    /// @notice Create tasks
    /// @param _tasks Encoded data to store as Task
    /// @dev
    function setTasks(Task[] calldata _tasks) external payable onlyAdmin {
        uint256 length = _tasks.length;

        for (uint256 i = 0; i < length;) {
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
    }

    /// @notice Update tasks
    /// @param taskIds A list of tasks to be updated
    /// @param _tasks Encoded data to update as Task
    /// @dev
    function updateTasks(uint8[] calldata taskIds, Task[] calldata _tasks) external payable onlyAdmin {
        uint256 length = taskIds.length;
        if (length != _tasks.length) revert LengthMismatch();

        for (uint256 i = 0; i < length;) {
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

    /// @notice Create missions
    /// @param _taskIds A list of tasks to be added to a Mission
    /// @param _detail Docs of a Mission
    /// @param _title Title of a Mission
    /// @dev
    function setMission(
        bool _forPurchase,
        uint256 _requiredXp,
        address _creator,
        string calldata _title,
        string calldata _detail,
        uint256[] calldata _taskIds,
        uint256 _fee
    ) external payable onlyAdmin {
        unchecked {
            ++missionId;
        }

        // Calculate xp and duration for Mission
        (uint8 totalXp, uint40 duration) = calculateMissionDetail(missionId, _taskIds);

        // Create a Mission
        missions[missionId] = Mission({
            forPurchase: _forPurchase,
            xp: totalXp,
            requiredXp: _requiredXp,
            duration: duration,
            creator: _creator,
            title: _title,
            detail: _detail,
            taskIds: _taskIds,
            fee: _fee
        });
    }

    /// @notice Update missions
    /// @param _missionId Identifiers of Mission to be updated
    /// @param _taskIds Identifiers of tasks to be updated
    /// @param _detail Docs of a Mission
    /// @param _title Title of a Mission
    /// @dev
    function updateMission(
        uint8 _missionId,
        bool _forPurchase,
        uint8 _requiredXp,
        address _creator,
        string calldata _title,
        string calldata _detail,
        uint256[] calldata _taskIds,
        uint256 _fee
    ) external payable onlyAdmin {
        // Calculate xp and duration for Mission
        (uint8 totalXp, uint40 duration) = calculateMissionDetail(_missionId, _taskIds);

        // Update existing Mission
        missions[_missionId] = Mission({
            forPurchase: _forPurchase,
            xp: totalXp,
            requiredXp: _requiredXp,
            duration: duration,
            creator: _creator,
            title: _title,
            detail: _detail,
            taskIds: _taskIds,
            fee: _fee
        });
    }

    /// -----------------------------------------------------------------------
    /// Admin Logic
    /// -----------------------------------------------------------------------

    /// @notice Update missions
    /// @param _admin The address to update admin to
    /// @dev
    function updateAdmin(address _admin) external payable onlyAdmin {
        if (_admin != admin) {
            admin = _admin;
        }
    }

    /// @notice Update royalties.
    /// @param _royalties address of Arm0ryTraveler.sol.
    /// @dev
    function updateRoyalties(uint256 _royalties) external payable onlyAdmin {
        if (_royalties > 100) revert InvalidRoyalties();
        royalties = _royalties;
    }

    /// @notice Update contracts.
    /// @param _quests Contract address of Quests.sol.
    /// @dev
    function updateContracts(IQuests _quests) external payable onlyAdmin {
        if (address(_quests) == address(0)) revert InvalidContract();
        quests = _quests;
    }

    /// -----------------------------------------------------------------------
    /// Mint Logic
    /// -----------------------------------------------------------------------

    /// @notice Purchase a Mission NFT
    /// @param _missionId The identifier of the Mission.
    /// @dev
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
    /// Getter Functions
    /// -----------------------------------------------------------------------

    function getTask(uint256 _taskId) external view returns (Task memory) {
        return tasks[_taskId];
    }

    function getMission(uint256 _missionId) external view returns (Mission memory mission, uint256) {
        mission = missions[_missionId];
        return (mission, mission.taskIds.length);
    }

    /// -----------------------------------------------------------------------
    /// Internal Functions
    /// -----------------------------------------------------------------------

    function calculateMissionDetail(uint256 _missionId, uint256[] calldata _taskIds) internal returns (uint8, uint40) {
        // Calculate xp and duration for Mission
        uint8 totalXp;
        uint40 duration;
        for (uint256 i = 0; i < _taskIds.length;) {
            // Aggregate Task duration to create Mission duration
            Task memory task = this.getTask(_taskIds[i]);
            duration += task.duration;
            totalXp += task.xp;

            // Update task status
            isTaskInMission[_missionId][_taskIds[i]] = true;

            // cannot possibly overflow
            unchecked {
                ++i;
            }
        }

        return (totalXp, duration);
    }

    receive() external payable {}
}
