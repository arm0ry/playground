// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IQuest {
    /// @notice DAO logic.
    function initialize(address dao) external payable;
    function setCooldown(uint40 cd) external payable;
    function getCooldown() external view returns (uint256);
    function setGasbot(address bot) external payable;
    function isGasBot(address bot) external view returns (bool);

    /// @notice Public logic.
    function getNumOfPublicUsers() external view returns (uint256);
    function isPublicUser(string calldata username) external view returns (bool);
    function getNumOfStartsByMissionByPublic(address missions, uint256 missionId) external view returns (uint256);

    /// @notice User logic.
    function start(address missions, uint256 missionId) external payable;
    function startBySig(address signer, address missions, uint256 missionId, uint8 v, bytes32 r, bytes32 s)
        external
        payable;
    function sponsoredStart(string calldata username, address missions, uint256 missionId) external payable;
    function respond(address missions, uint256 missionId, uint256 taskId, uint256 response, string calldata feedback)
        external
        payable;
    function respondBySig(
        address signer,
        uint256 taskKey,
        uint256 response,
        string calldata feedback,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable;
    function sponsoredRespond(
        string calldata username,
        address missions,
        uint256 missionId,
        uint256 taskId,
        uint256 response,
        string calldata feedback
    ) external payable;

    /// @notice Quest logic.
    function getQuestId() external view returns (uint256);
    function getQuestIdByUserAndMission(address user, address missions, uint256 missionId)
        external
        view
        returns (uint256);
    function getQuest(uint256 questId) external view returns (address, address, uint256);
    function isTaskAccomplished(address user, address missions, uint256 missionId, uint256 taskId)
        external
        view
        returns (bool);
    function isMissionAccomplished(address user, address missions, uint256 missionId) external view returns (bool);
    function getNumOfCompletedTasksInMission(address user, address missions, uint256 missionId)
        external
        view
        returns (uint256);
    function getTimeLastTaskCompleted(address user) external view returns (uint256);
    function hasCooledDown(address user) external view returns (bool);

    /// @notice Reviewer logic.
    function setReviewer(address reviewer, bool status) external payable;
    function isReviewer(address user) external view;
    function getReviewStatus() external view returns (bool);
    function setReviewStatus(bool status) external payable;
    function review(
        address user,
        address missions,
        uint256 missionId,
        uint256 taskId,
        uint256 response,
        string calldata feedback
    ) external payable;
    function reviewBySig(
        address signer,
        address user,
        address missions,
        uint256 missionId,
        uint256 taskId,
        uint256 response,
        string calldata feedback,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable;

    /// @notice Get response & feedback.
    function getTaskResponse(uint256 questId, uint256 taskId) external view returns (uint256);
    function getTaskFeedback(uint256 questId, uint256 taskId) external view returns (string memory);
    function getReviewResponse(address reviewer, uint256 questId) external view returns (uint256);
    function getReviewFeedback(address reviewer, uint256 questId) external view returns (string memory);

    /// @notice Get quest related stats.
    function getNumOfMissionsStarted() external view returns (uint256);
    function getNumOfMissionsCompleted() external view returns (uint256);
    function getNumOfTaskCompleted() external view returns (uint256);
    function getNumOfTimesQuestedByUser(address user) external view returns (uint256);
    function getNumOfMissionQuested(address missions, uint256 missionId) external view returns (uint256, uint256);
}
