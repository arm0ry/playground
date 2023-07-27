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

    function getMission(uint256 missionId) external view returns (Mission memory, uint256);

    function aggregateTasksData(uint256[] calldata taskIds) external payable returns (uint256, uint40);
}
