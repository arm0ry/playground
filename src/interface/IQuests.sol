// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IQuests {
    function questing(address traveler) external view returns (uint8);

    function getQuest(address traveler, uint8 missionId)
        external
        view
        returns (uint40, uint40, uint8, uint8, uint8, uint8, uint8, uint8);

    function getMissionStartCount(uint8 missionId) external view returns (uint8);

    function getMissionCompletionsCount(uint8 missionId) external view returns (uint256);

    function getMissionImpact(uint8 missionId) external view returns (uint256);
}
