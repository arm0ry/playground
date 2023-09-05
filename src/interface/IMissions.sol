// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

struct Mission {
    bool forPurchase;
    address creator;
    string title;
    string detail;
    uint256[] taskIds;
    uint256 fee;
}

struct Task {
    uint8 xp;
    uint40 duration;
    address creator;
    string detail;
}

interface IMissions {
    function isTaskInMission(uint256 missionId, uint256 taskId) external returns (bool);

    function getTask(uint256 taskId) external view returns (Task memory);

    function getMissionId() external view returns (uint256);

    function getMission(uint256 missionId) external view returns (Mission memory, uint256);

    function getMissionTaskCount(uint256 missionId) external view returns (uint256 taskCount);

    function getMissionDeadline(uint256 missionId) external view returns (uint256);

    function aggregateMissionsCompletions(uint256 missionId, address[] calldata storages) external payable;
}
