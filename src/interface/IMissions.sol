// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IMissions {
    function isTaskInMission(uint256 missionId, uint256 taskId) external returns (bool);

    function getTask(uint256 taskId) external view returns (uint8, uint40, address, string memory, string memory);

    function getMission(uint256 _missionId)
        external
        view
        returns (uint8, uint40, uint8[] memory, string memory, string memory, address, uint256, uint256, uint256);
}
