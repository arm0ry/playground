// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import { ERC1155 } from "solbase/tokens/ERC1155/ERC1155.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { IQuests } from "./interface/IQuests.sol";
import { Base64 } from "solbase/utils/Base64.sol";
import { LibString } from "solbase/utils/LibString.sol";

import "forge-std/console2.sol";

/// @title Arm0ry Mission
/// @notice A list of missions and tasks.
/// @author audsssy.eth

struct Mission {
    uint8 xp; // Total XP
    uint8 requiredXp; // Xp required to participate
    uint40 duration; // Time allotted to complete Mission
    address creator; // Creator of Mission
    string title; // Title of Mission
    string details; // Additional detail of Mission
    uint256[] taskIds; // Tasks associated with Mission
    uint256 fee;
}

struct Task {
    uint8 xp; // Xp of a Task
    uint40 duration; // Time allocated to complete a Task
    address creator; // Creator of a Task
    string title; // Title of a Task
    string details; // Additional Task detail
}

contract Missions is ERC1155 {
    using SafeTransferLib for address;

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event MissionUpdated(uint8 missionId);

    event TaskUpdated(
        uint40 duration,
        uint8 points,
        address creator,
        string details
    );

    event PermissionUpdated(
        address indexed caller,
        address indexed admin
    );

    /// -----------------------------------------------------------------------
    /// Custom Errors
    /// -----------------------------------------------------------------------

    error NotAuthorized();

    error InvalidMission();

    /// -----------------------------------------------------------------------
    /// Task Storage
    /// -----------------------------------------------------------------------

    address public admin;

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
        if (admin == msg.sender) {
            _;
        } else {
            revert NotAuthorized();
        }
    }

    /// -----------------------------------------------------------------------
    /// Metadata Storage & Logic
    /// -----------------------------------------------------------------------

    function uri(uint256 _missionId)
        public
        view
        override
        virtual
        returns (string memory)
    {
        string memory name = string(
            abi.encodePacked(
                "Mission #",
                LibString.toString(_missionId)
            )
        );
        string memory description = "Arm0ry Missions";
        string memory image = generateBase64Image(_missionId);

        return
            string(
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

    function generateBase64Image(uint256 _missionId)
        public
        view
        returns (string memory)
    {
        return Base64.encode(bytes(generateImage(_missionId)));
    }

    function generateImage(uint256 _missionId)
        public
        view
        returns (string memory)
    {
        (, , , , string memory _title, , , , ) = this.getMission(_missionId);
        uint256 completions = quests.getMissionCompletionsCount(uint8(_missionId));
        uint256 ratio = quests.getMissionImpact(uint8(_missionId));
        
        return
            string(
                abi.encodePacked(
                    '<svg class="svgBody" width="300" height="300" viewBox="0 0 300 300" xmlns="http://www.w3.org/2000/svg">',
                    '<rect width="300" height="300" rx="10" style="fill:#FFFFFF" />',
                    '<text x="15" y="100" class="medium" stroke="black">',_title,'</text>',
                    '<text x="15" y="150" class="medium" stroke="grey">COMPLETIONS: </text>',
                    '<rect x="15" y="155" width="300" height="30" style="fill:yellow;opacity:0.2"/>',
                    '<text x="20" y="173" class="small">', LibString.toString(completions),'</text>',
                    '<rect x="15" y="215" width="300" height="30" style="fill:yellow;opacity:0.2"/>',
                    '<text x="20" y="235" class="small">',LibString.toString(ratio),'%</text>',
                    '<text x="270" y="280" class="small" stroke="#FFBE0B" opacity=".3">A</text>',
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

        console2.log(admin);
    }

    /// -----------------------------------------------------------------------
    /// Mission / Task Logic
    /// -----------------------------------------------------------------------

    /// @notice Create tasks
    /// @param taskData Encoded data to store as Task
    /// @dev
    function setTasks(bytes[] calldata taskData) 
        onlyAdmin 
        external 
        payable 
    {
        uint256 length = taskData.length;

        for (uint256 i = 0; i < length; ) {
            unchecked {
                ++taskId;
            }

            (
                uint8 xp, 
                uint40 duration,
                address creator,
                string memory title,
                string memory details
            ) = abi.decode(taskData[i], (uint8, uint40, address, string, string));

            tasks[taskId] = Task({
                xp: xp,
                duration: duration,
                creator: creator,
                title: title,
                details: details
            });

            emit TaskUpdated(duration, xp, creator, details);

            // Unchecked because the only math done is incrementing
            // the array index counter which cannot possibly overflow.
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Update tasks
    /// @param taskIds A list of tasks to be updated
    /// @param taskData Encoded data to update as Task
    /// @dev
    function updateTasks(uint8[] calldata taskIds, bytes[] calldata taskData)
        onlyAdmin
        external
        payable
    {
        uint256 length = taskIds.length;

        if (length != taskData.length) revert LengthMismatch();

        for (uint256 i = 0; i < length; ) {
            (
                uint8 xp, 
                uint40 duration, 
                address creator, 
                string memory title, 
                string memory details 
            ) = abi.decode(taskData[i], (uint8, uint40, address, string, string));

            tasks[taskId] = Task({
                xp: xp,
                duration: duration,
                creator: creator,
                title: title,
                details: details
            });

            emit TaskUpdated(duration, xp, creator, details);

            // Unchecked because the only math done is incrementing
            // the array index counter which cannot possibly overflow.
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Create missions
    /// @param _taskIds A list of tasks to be added to a Mission
    /// @param _details Docs of a Mission
    /// @param _title Title of a Mission
    /// @dev
    function setMission(
        uint256[] calldata _taskIds,
        string calldata _details,
        string calldata _title,
        address _creator,
        uint8 _requiredXp,
        uint256 _fee
    ) onlyAdmin external payable {
        unchecked {
            ++missionId;
        }

        // Calculate xp and duration for Mission
        (uint8 totalXp, uint40 duration) = 
            calculateMissionDetail(missionId, _taskIds);

        // Create a Mission
         missions[missionId] = Mission({
            xp: totalXp,
            requiredXp: _requiredXp,
            duration: duration,
            creator: _creator,
            title: _title,
            details: _details,
            taskIds: _taskIds,
            fee: _fee
        });

        // emit MissionUpdated(missionId);
    }

    /// @notice Update missions
    /// @param _missionId Identifiers of Mission to be updated
    /// @param _taskIds Identifiers of tasks to be updated
    /// @param _details Docs of a Mission
    /// @param _title Title of a Mission
    /// @dev
    function updateMission(
        uint8 _missionId, 
        uint8 _requiredXp,
        string calldata _details,
        string calldata _title,
        address _creator,
        uint256 _fee,
        uint256[] calldata _taskIds
    ) onlyAdmin external payable {
        // Calculate xp and duration for Mission
        (uint8 totalXp, uint40 duration) = 
            calculateMissionDetail(_missionId, _taskIds);

        // Update existing Mission
        missions[_missionId] = Mission({
            xp: totalXp,
            requiredXp: _requiredXp,
            duration: duration,
            creator: _creator,
            title: _title,
            details: _details,
            taskIds: _taskIds,
            fee: _fee
        });

        // emit MissionUpdated(_missionId);
    }

    /// @notice Update missions
    /// @param _admin The address to update admin to
    /// @dev
    function updateAdmin(address _admin)
        onlyAdmin
        external
        payable
    {
        if (_admin != admin) {
            admin = _admin;
        }

        emit PermissionUpdated(msg.sender, admin);
    }

    /// @notice Update Arm0ry contracts.
    /// @param _quests Contract address of Arm0ryTraveler.sol.
    /// @dev 
    function updateContracts(IQuests _quests) onlyAdmin external payable {
        quests = _quests;
    }

    /// -----------------------------------------------------------------------
    /// Mint Logic
    /// -----------------------------------------------------------------------

    /// @notice Purchase a Mission NFT 
    /// @param _missionId The identifier of the Mission.
    /// @dev
    function purchase(uint256 _missionId) external payable {
        (, , , ,, address creator, , uint256 fee, ) = this.getMission(_missionId);

        uint256 royalties = fee * 10 / 100;
        creator.safeTransferETH(royalties);
        admin.safeTransferETH(fee - royalties);

        _mint(msg.sender, _missionId, 1, "0x");
    }

    /// -----------------------------------------------------------------------
    /// Getter Functions
    /// -----------------------------------------------------------------------

    function getTask(uint256 _taskId) external view returns (uint8, uint40, address, string memory, string memory) {
        Task memory task = tasks[_taskId];
        return (task.xp, task.duration, task.creator, task.title, task.details);
    }

    function getMission(uint256 _missionId) external view returns (uint8, uint40, uint256[] memory, string memory, string memory, address, uint8, uint256, uint256) {
        Mission memory mission = missions[_missionId];
        return (mission.xp, mission.duration, mission.taskIds, mission.details, mission.title, mission.creator, mission.requiredXp, mission.fee, mission.taskIds.length);
    }

    /// -----------------------------------------------------------------------
    /// Internal Functions
    /// -----------------------------------------------------------------------

    function calculateMissionDetail(uint256 _missionId, uint256[] calldata _taskIds) internal returns (uint8, uint40) {
        // Calculate xp and duration for Mission
        uint8 totalXp;
        uint40 duration;
        for (uint256 i = 0; i < _taskIds.length; ) {
            // Aggregate Task duration to create Mission duration
            (uint8 taskXp, uint40 _duration, , , ) = this.getTask(_taskIds[i]);
            duration += _duration;
            totalXp += taskXp;

            // Update task status
            isTaskInMission[_missionId][_taskIds[i]] = true;

            // cannot possibly overflow
            unchecked {
                ++i;
            }
        }

        return  (totalXp, duration);
    }
}
