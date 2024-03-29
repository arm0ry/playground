// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IMission {
    error InvalidMission();

    /// @dev DAO methods
    function initialize(address dao) external payable;
    function setFee(uint256 fee) external payable;
    function getFee() external view returns (uint256);

    /// @dev Quest methods
    function authorizeQuest(address quest) external payable;
    function isQuestAuthorized(address target) external view returns (bool);

    /// @dev Task set methods
    function setTask(address creator, uint256 deadline, string calldata detail) external payable;
    function setTaskCreator(uint256 taskId, address creator) external payable;
    function setTaskDeadline(uint256 taskId, uint256 deadline) external payable;
    function setTaskDetail(uint256 taskId, string calldata detail) external payable;

    /// @dev Task get methods
    function getTaskId() external view returns (uint256);
    function getTotalTaskCompletions(uint256 taskId) external view returns (uint256);
    function getTotalTaskCompletionsByMission(uint256 missionId, uint256 taskId) external view returns (uint256);
    function getTaskCreator(uint256 taskId) external view returns (address);
    function getTaskDeadline(uint256 taskId) external view returns (uint256);
    function getTaskTitle(uint256 taskId) external view returns (string memory);
    function getTaskDetail(uint256 taskId) external view returns (string memory);
    function isTaskInMission(uint256 missionId, uint256 taskId) external view returns (bool);

    /// @dev Mission set methods
    function setMission(address creator, string calldata title, string calldata detail, uint256[] calldata taskIds)
        external
        payable;
    function setMissionCreator(uint256 missionId, address creator) external payable;
    function setMissionTitle(uint256 missionId, string calldata title) external payable;
    function setMissionDetail(uint256 missionId, string calldata detail) external payable;
    function setMissionTasks(uint256 missionId, uint256[] calldata taskIds) external payable;

    /// @dev Mission get methods
    function getMissionId() external view returns (uint256);
    function getMissionTitle(uint256 missionId) external view returns (string memory);
    function getMissionTaskCount(uint256 missionId) external view returns (uint256 count);
    function getMissionTaskId(uint256 missionId, uint256 order) external view returns (uint256);
    function getMissionTaskIds(uint256 missionId) external view returns (uint256[] memory);
    function getMissionStarts(uint256 missionId) external view returns (uint256);
    function getMissionCompletions(uint256 missionId) external view returns (uint256);
    function getMissionCreator(uint256 missionId) external view returns (address);
    function getMissionDetail(uint256 missionId) external view returns (string memory);
    function getMissionDeadline(uint256 missionId) external view returns (uint256);

    /// @dev Mission set methods
    function incrementTotalTaskCompletions(uint256 taskId) external payable;
    function incrementTotalTaskCompletionsByMission(uint256 missionId, uint256 taskId) external payable;
    function incrementMissionStarts(uint256 missionId) external payable;
    function incrementMissionCompletions(uint256 missionId) external payable;
}
