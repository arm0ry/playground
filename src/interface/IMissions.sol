// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Mission, Metric, Task} from "../Missions.sol";

interface IMissions {
    function isTaskInMission(uint256 missionId, uint256 taskId) external returns (bool);

    function getTask(uint256 taskId) external view returns (Task memory);

    function setMetric(uint256 missionId, string calldata title, uint256 value) external payable;

    function getMissionId() external view returns (uint256);

    function getMission(uint256 missionId) external view returns (Mission memory);

    function getMissionTitle(uint256 missionId) external view returns (string memory);

    function getMissionTaskCount(uint256 missionId) external view returns (uint256 taskCount);

    function getMissionDeadline(uint256 missionId) external view returns (uint256);

    function getMetricTitle(uint256 missionId) external view returns (string memory);

    function getMetrics(uint256 missionId) external view returns (Metric memory metric);

    function getSingleMetricValue(uint256 missionId, uint256 count) external view returns (uint256);

    function aggregateMissionsCompletions(uint256 missionId, address[] calldata storages) external payable;
}
