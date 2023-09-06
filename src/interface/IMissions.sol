// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Mission, Metric, Task} from "../Missions.sol";

interface IMissions {
    function isTaskInMission(uint256 missionId, uint256 taskId) external returns (bool);

    function getTask(uint256 taskId) external view returns (Task memory);

    function setTaskMetric(uint256 taskId, string calldata title, uint256 value) external payable;

    function getMissionId() external view returns (uint256);

    function getMission(uint256 missionId) external view returns (Mission memory);

    function getMissionTaskCount(uint256 missionId) external view returns (uint256 taskCount);

    function getMissionDeadline(uint256 missionId) external view returns (uint256);

    function getMetrics(uint256[] calldata taskIds) external view returns (Metric[] memory metrics);

    function aggregateMissionsCompletions(uint256 missionId, address[] calldata storages) external payable;
}
