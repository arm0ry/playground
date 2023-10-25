// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IQuest {
    /// @notice DAO logic.
    function setCoolDown(uint40 cd) external payable;
    function getCoolDown() external view returns (uint256);

    /// @notice User logic.
    function start(address missions, uint256 missionId) external payable;
    function startBySig(address signer, address missions, uint256 missionId, uint8 v, bytes32 r, bytes32 s)
        external
        payable;
    function respond(address missions, uint256 missionId, uint256 taskId, string calldata feedback, uint256 response)
        external
        payable;
    function respondBySig(
        address signer,
        address missions,
        uint256 missionId,
        uint256 taskId,
        string calldata feedback,
        uint256 response,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable;
    function isQuestActive(address user, address missions, uint256 missionId) external view returns (bool);
    function hasCooledDown(address user) external view returns (bool);
    function getQuestProgress(address user, address missions, uint256 missionId) external view returns (uint256);
    function getCompletedTaskCount(address user, address missions, uint256 missionId) external view returns (uint256);
    function getTimeLastTaskCompleted(address user) external view returns (uint256);

    /// @notice Reviewer mechanics.
    function getReviewStatus() external view;
    function setReviewStatus(bool status) external payable;
    function setReviewer(address reviewer, bool status) external payable;
    function isReviewer(address user) external view;
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

    /// @notice Response & Feedback storage.
    function getUserResponse(address user, address missions, uint256 missionId, uint256 taskId)
        external
        view
        returns (uint256);
    function getUserFeedback(address user, address missions, uint256 missionId, uint256 taskId)
        external
        view
        returns (string memory);
    function getReviewResponse(address reviewer, address user, address missions, uint256 missionId, uint256 taskId)
        external
        view
        returns (uint256);
    function getReviewFeedback(address reviewer, address user, address missions, uint256 missionId, uint256 taskId)
        external
        view
        returns (string memory);
}
