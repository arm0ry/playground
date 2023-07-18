// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

struct Mission {
    bool forPurchase;
    uint8 xp;
    uint40 duration;
    address creator;
    string title;
    string detail;
    uint256 requiredXp;
    uint256[] taskIds;
    uint256 fee;
}

interface IMissions {
    function isTaskInMission(uint256 missionId, uint256 taskId) external returns (bool);

    function getTask(uint256 taskId) external view returns (uint8, uint40, address, string memory, string memory);

    function getMission(uint256 missionId) external view returns (Mission memory, uint256);
}
