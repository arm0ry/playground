// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Mission, Task} from "../Missions.sol";

interface IMissions {
    error InvalidMission();

    /// @dev Mission get methods
    function getTasId() external view returns (uint256);
    function getTask(uint256 taskId) external view returns (Task memory);
    function getTaskStarts(uint256 taskId) external view returns (uint256);
    function getTaskCompletions(uint256 taskId) external view returns (uint256);
    function isTaskInMission(uint256 missionId, uint256 taskId) external returns (bool);
    function getMissionId() external view returns (uint256);
    function getMission(uint256 missionId) external view returns (Mission memory);
    function getMissionTitle(uint256 missionId) external view returns (string memory);
    function getMissionTaskCount(uint256 missionId) external view returns (uint256 taskCount);
    function getMissionTaskIds(uint256 missionId) external view returns (uint256[] memory);
    function getMissionStarts(uint256 missionId) external view returns (uint256);
    function getMissionCompletions(uint256 missionId) external view returns (uint256);
    function getMissionCreator(uint256 missionId) external view returns (address);
    function getMissionDetail(uint256 missionId) external view returns (string memory);
    function getMissionPurchaseStatus(uint256 missionId) external view returns (bool);
    function getMissionDeadline(uint256 missionId) external view returns (uint256);

    /// @dev Mission set methods
    function incrementTaskId() external returns (uint256);
    function incrementTaskStarts(uint256 taskId) external payable;
    function incrementTaskCompletions(uint256 taskId) external payable;
    function incrementMissionId() external returns (uint256);
    function incrementMissionStarts(uint256 missionId) external payable;
    function incrementMissionCompletions(uint256 missionId) external payable;

    function aggregateMissionsCompletions(uint256 missionId, address[] calldata storages) external payable;

    /// @dev Mission delete methods

    /// @dev Mission arithmetic methods
}
