// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IQuests {
    function getMissionCompletionsCount(uint8 missionId) external view returns (uint256);

    function mission() external view returns (address);
}
