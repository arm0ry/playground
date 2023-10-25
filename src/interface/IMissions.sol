// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IMissions {
    error InvalidMission();

    /// @dev DAO methods
    function getDao() external view returns (address);

    /// @dev Quest methods
    function isQuestAllowed(address target) external view returns (bool);

    /// @dev Mission get methods
    function getTaskId() external view returns (uint256);
    function getTaskCompletions(uint256 taskId) external view returns (uint256);
    function isTaskInMission(uint256 missionId, uint256 taskId) external view returns (bool);
    function getMissionId() external view returns (uint256);
    function getMissionTitle(uint256 missionId) external view returns (string memory);
    function getMissionTaskCount(uint256 missionId) external view returns (uint256 count);
    function getMissionTaskIds(uint256 missionId) external view returns (uint256[] memory);
    function getMissionStarts(uint256 missionId) external view returns (uint256);
    function getMissionCompletions(uint256 missionId) external view returns (uint256);
    function getMissionCreator(uint256 missionId) external view returns (address);
    function getMissionDetail(uint256 missionId) external view returns (string memory);
    function getMissionDeadline(uint256 missionId) external view returns (uint256);

    /// @dev Mission set methods
    function incrementTaskCompletions(uint256 taskId) external payable;
    function incrementMissionStarts(uint256 missionId) external payable;
    function incrementMissionCompletions(uint256 missionId) external payable;

    /// @dev Mission delete methods

    /// @dev Mission arithmetic methods
}
