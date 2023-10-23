// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {IMissions, Mission, Task} from "./interface/IMissions.sol";
import {Missions} from "./Missions.sol";
import {IStorage} from "./interface/IStorage.sol";
import {Storage} from "./Storage.sol";
import {IERC721} from "../lib/forge-std/src/interfaces/IERC721.sol";
import {IERC20} from "../lib/forge-std/src/interfaces/IERC20.sol";
import {IKaliTokenManager} from "./interface/IKaliTokenManager.sol";

/// @title  Quest
/// @author audsssy.eth

struct QuestDetail {
    bool active; // Indicates whether a quest is active.
    bool toReview; // Indicates whether quest tasks require reviews.
    uint8 progress; // 0-100%.
    uint40 deadline; // Time left to complete quest.
    uint40 completed; // Number of tasks completed in quest.
}

contract Quest is Storage {
    /// -----------------------------------------------------------------------
    /// Custom Errors
    /// -----------------------------------------------------------------------

    error NotInitialized();
    error InvalidUser();
    error QuestInactive();
    error QuestInProgress();
    error InvalidReview();
    error InvalidReviewer();
    error InvalidMission();
    error InvalidProgress();
    error Cooldown();

    /// -----------------------------------------------------------------------
    /// Sign Storage
    /// -----------------------------------------------------------------------

    uint256 internal INITIAL_CHAIN_ID;
    bytes32 internal INITIAL_DOMAIN_SEPARATOR;
    bytes32 public constant START_TYPEHASH = keccak256("Start(address signer, address missions, uint256 missionId)");
    bytes32 public constant RESPOND_TYPEHASH = keccak256(
        "Respond(address signer, address missions, uint256 missionId, uint256 taskId, string feedback, uint256 response)"
    );
    bytes32 public constant REVIEW_TYPEHASH = keccak256(
        "Review(address signer, address user, address missions, uint256 missionId, uint256 taskId, bool result)"
    );

    /// -----------------------------------------------------------------------
    /// EIP-2612 LOGIC
    /// -----------------------------------------------------------------------

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : _computeDomainSeparator();
    }

    function _computeDomainSeparator() internal view virtual returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("Quest")),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// Modifier
    /// -----------------------------------------------------------------------

    modifier onlyReviewer() {
        if (!this.isReviewer(msg.sender)) revert InvalidReviewer();
        _;
    }

    /// -----------------------------------------------------------------------
    /// Quest Logic
    /// -----------------------------------------------------------------------

    /// @notice User to start a Quest by identifying the mission address and missionId.
    /// @param missions .
    /// @param missionId .
    /// @dev
    function start(address missions, uint256 missionId) external payable {
        _start(msg.sender, missions, missionId);
    }

    /// @notice Traveler to start a new Quest.
    /// @param signer .
    /// @param missions .
    /// @param missionId .
    /// @dev
    function startBySig(address signer, address missions, uint256 missionId, uint8 v, bytes32 r, bytes32 s)
        public
        payable
        virtual
    {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01", DOMAIN_SEPARATOR(), keccak256(abi.encode(START_TYPEHASH, signer, missions, missionId))
            )
        );

        address recoveredAddress = ecrecover(digest, v, r, s);
        if (recoveredAddress == address(0) || recoveredAddress != signer) revert InvalidUser();

        _start(signer, missions, missionId);
    }

    /// @notice Traveler to respond to Task in order to progress Quest.
    /// @param missionId .
    /// @param taskId .
    /// @param response .
    /// @dev
    function respond(address missions, uint256 missionId, uint256 taskId, string calldata feedback, uint256 response)
        external
        payable
    {
        _respond(msg.sender, missions, missionId, taskId, feedback, response);
    }

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
    ) public payable virtual {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(abi.encode(RESPOND_TYPEHASH, signer, missions, missionId, taskId, feedback, response))
            )
        );

        address recoveredAddress = ecrecover(digest, v, r, s);
        if (recoveredAddress == address(0) || recoveredAddress != signer) revert InvalidUser();

        _respond(signer, missions, missionId, taskId, feedback, response);
    }

    /// -----------------------------------------------------------------------
    /// Review Logic
    /// -----------------------------------------------------------------------

    /// @notice Reviewer to submit review of task completion.
    function review(
        address user,
        address missions,
        uint256 missionId,
        uint256 taskId,
        uint256 data,
        string calldata response
    ) external payable onlyReviewer {
        _review(msg.sender, user, missions, missionId, taskId, data, response);
    }

    function reviewBySig(
        address signer,
        address user,
        address missions,
        uint256 missionId,
        uint256 taskId,
        uint256 data,
        string calldata response,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public payable virtual onlyReviewer {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(abi.encode(REVIEW_TYPEHASH, signer, user, missions, missionId, taskId, data, response))
            )
        );

        address recoveredAddress = ecrecover(digest, v, r, s);
        if (recoveredAddress == address(0) || recoveredAddress != msg.sender) revert InvalidUser();

        _review(signer, user, missions, missionId, taskId, data, response);
    }

    /// -----------------------------------------------------------------------
    /// User Logic
    /// -----------------------------------------------------------------------

    function setProfilePicture(string calldata url) external payable {
        // Retrieve user quest start count.
        uint256 questId = this.getUint(keccak256(abi.encode(msg.sender, ".questId")));
        if (questId > 0) _setString(keccak256(abi.encode(msg.sender, ".profile")), url);
    }

    /// -----------------------------------------------------------------------
    /// DAO Logic
    /// -----------------------------------------------------------------------

    function setReviewerStatus(address reviewer, bool status) external payable onlyOperator {
        if (status) _setBool(keccak256(abi.encode(reviewer, ".approved")), status);
    }

    function isReviewer(address user) external view returns (bool) {
        return this.getBool(keccak256(abi.encode(user, ".approved")));
    }

    function getGlobalReview() external view returns (bool) {
        return this.getBool(keccak256(abi.encode("quest.review")));
    }

    /// @notice Review status applies to all quests.
    function setReviewStatus(bool status) external payable onlyOperator {
        if (status) _setBool(keccak256(abi.encode("quest.review")), status);
    }

    function getReviewStatus() external view returns (bool) {
        return this.getBool(keccak256(abi.encode("quest.review")));
    }

    function setCoolDown(uint40 cd) external payable onlyOperator {
        if (cd > 0) _setUint(keccak256(abi.encode("quest.cd")), cd);
    }

    /// -----------------------------------------------------------------------
    /// Quest Setter Logic
    /// -----------------------------------------------------------------------

    function toggleQuestActivity(address user, address missions, uint256 missionId) internal {
        _setBool(
            keccak256(abi.encode(user, missions, missionId, ".active")), !this.isQuestActive(user, missions, missionId)
        );
    }

    function deleteQuestActivity(address user, address missions, uint256 missionId) internal {
        deleteBool(keccak256(abi.encode(user, missions, missionId, ".active")));
    }

    function updateQuestProgress(address user, address missions, uint256 missionId, uint256 completed)
        internal
        returns (uint256)
    {
        uint256 progress = completed * 100 / IMissions(missions).getMissionTaskCount(missionId);
        _setUint(keccak256(abi.encode(user, missions, missionId, ".progress")), progress);
        return progress;
    }

    function setTimeLastTaskCompleted(address user) internal {
        _setUint(keccak256(abi.encode(user, ".timeLastCompleted")), block.timestamp);
    }

    function setFeedback(address user, address missions, uint256 missionId, uint256 taskId, string calldata feedback)
        internal
    {
        _setString(keccak256(abi.encode(user, missions, missionId, taskId, ".feedback")), feedback);
    }

    function setResponse(address user, address missions, uint256 missionId, uint256 taskId, uint256 response)
        internal
    {
        _setUint(keccak256(abi.encode(user, missions, missionId, taskId, ".response")), response);
    }

    function setReviewData(
        address reviewer,
        address user,
        address missions,
        uint256 missionId,
        uint256 taskId,
        uint256 reviewData
    ) internal {
        _setUint(keccak256(abi.encode(reviewer, user, missions, missionId, taskId, ".reviewData")), reviewData);
    }

    function setReviewResponse(
        address reviewer,
        address user,
        address missions,
        uint256 missionId,
        uint256 taskId,
        string calldata response
    ) internal {
        _setString(keccak256(abi.encode(reviewer, user, missions, missionId, taskId, ".reviewResponse")), response);
    }

    /// -----------------------------------------------------------------------
    /// Quest Getter Logic
    /// -----------------------------------------------------------------------

    function isQuestActive(address user, address missions, uint256 missionId) external view returns (bool) {
        return this.getBool(keccak256(abi.encode(user, missions, missionId, ".active")));
    }

    function getQuestProgress(address user, address missions, uint256 missionId) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(user, missions, missionId, ".progress")));
    }

    function getCompletedTaskCount(address user, address missions, uint256 missionId) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(user, missions, missionId, ".taskCompleted")));
    }

    function isEligibleToQuest(address missions, uint256 missionId) external view returns (bool) {
        uint256 deadline = IMissions(missions).getMissionDeadline(missionId);
        if (deadline != 0) return true;
        if (deadline > block.timestamp) return true;
        return false;
    }

    function getCoolDown() external view returns (uint256) {
        return this.getUint(keccak256(abi.encode("quest.cd")));
    }

    function getTimeLastTaskCompleted(address user) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(user, ".timeLastCompleted")));
    }

    function hasCooledDown(address user) external view returns (bool) {
        return (block.timestamp >= this.getTimeLastTaskCompleted(user) + this.getCoolDown()) ? true : false;
    }

    function getFeedback(address user, uint256 missionId, uint256 taskId) external view returns (string memory) {
        return this.getString(keccak256(abi.encode(user, missionId, taskId, ".feedback")));
    }

    function getResponse(address user, uint256 missionId, uint256 taskId) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(user, missionId, taskId, ".response")));
    }

    /// -----------------------------------------------------------------------
    /// Quest Counter Logic
    /// -----------------------------------------------------------------------

    function incrementMissionStarts() internal {
        addUint(keccak256(abi.encode(address(this), ".stats.mission.starts")), 1);
    }

    function incrementMissionCompletions() internal {
        addUint(keccak256(abi.encode(address(this), ".stats.mission.completed")), 1);
    }

    function incrementTaskCompletions() internal {
        addUint(keccak256(abi.encode(address(this), ".stats.task.completed")), 1);
    }

    function incrementUserMissionStarts(address user, address missions, uint256 missionId) internal {
        addUint(keccak256(abi.encode(user, missions, missionId, ".starts")), 1);
    }

    function incrementUserMissionCompletions(address user, address missions, uint256 missionId) internal {
        addUint(keccak256(abi.encode(user, missions, missionId, ".completed")), 1);
    }

    function incrementUserTaskCompletions(address user, address missions, uint256 missionId, uint256 taskId) internal {
        addUint(keccak256(abi.encode(user, missions, missionId, taskId, ".completed")), 1);
    }

    function incrementCompletedTaskInMission(address user, address missions, uint256 missionId)
        internal
        returns (uint256)
    {
        addUint(keccak256(abi.encode(user, missions, missionId, ".taskCompleted")), 1);
        return this.getCompletedTaskCount(user, missions, missionId);
    }

    /// -----------------------------------------------------------------------
    /// Internal Logic
    /// -----------------------------------------------------------------------

    /// @notice Internal function using signature to start quest.
    function _start(address user, address missions, uint256 missionId) internal virtual {
        // Confirm mission has been initialized and has not expired.
        if (!this.isEligibleToQuest(missions, missionId)) revert InvalidMission();
        if (this.isQuestActive(user, missions, missionId)) revert QuestInProgress();

        // Toggle quest activity status.
        toggleQuestActivity(user, missions, missionId);

        // Increment number of missions started by user, as facilitated by this Quest contract.
        incrementUserMissionStarts(user, missions, missionId);

        // Increment number of missions started and facilitated by this Quest contract.
        incrementMissionStarts();

        // Increment number of mission starts.
        IMissions(missions).incrementMissionStarts(missionId);
    }

    /// @notice Internal function using signature to respond to quest tasks.
    function _respond(
        address user,
        address missions,
        uint256 missionId,
        uint256 taskId,
        string calldata feedback,
        uint256 response
    ) internal virtual {
        // Confirm mission has been initialized and has not expired.
        if (!this.isEligibleToQuest(missions, missionId)) revert InvalidMission();
        if (this.isQuestActive(user, missions, missionId)) revert QuestInProgress();

        // Confirm Task is valid
        if (!IMissions(missions).isTaskInMission(missionId, taskId)) revert InvalidMission();

        // Confirm user is no longer in cooldown.
        if (!this.hasCooledDown(user)) revert Cooldown();

        // Store responses.
        setResponse(user, missions, missionId, taskId, response);
        setFeedback(user, missions, missionId, taskId, feedback);

        // Start cooldown.
        setTimeLastTaskCompleted(user);

        // When review is not required, update quest detail and stats.
        if (!this.getReviewStatus()) {
            updateQuestAndStats(user, missions, missionId, taskId);
        }
    }

    /// @notice Internal function using signature to review quest tasks.
    function _review(
        address reviewer,
        address user,
        address missions,
        uint256 missionId,
        uint256 taskId,
        uint256 reviewData,
        string calldata reviewResponse
    ) internal {
        if (!this.getReviewStatus()) revert InvalidReview();

        // Store review results.
        setReviewData(reviewer, user, missions, missionId, taskId, reviewData);
        setReviewResponse(reviewer, user, missions, missionId, taskId, reviewResponse);

        // Update quest detail.
        updateQuestAndStats(user, missions, missionId, taskId);
    }

    /// @notice Update, and finalize when appropriate, the Quest detail.
    function updateQuestAndStats(address user, address missions, uint256 missionId, uint256 taskId) internal {
        // Calculate and udpate quest detail
        uint256 completed = incrementCompletedTaskInMission(user, missions, missionId);
        uint256 progress = updateQuestProgress(user, missions, missionId, completed);

        // Update Task-related stats

        // Increment number of missions facilitated by this Quest contract.
        incrementTaskCompletions();

        // Increment number of tasks completed by user, as facilitated by this Quest contract.
        incrementUserTaskCompletions(user, missions, missionId, taskId);

        // Increment task completion at Missions contract.
        IMissions(missions).incrementTaskCompletions(taskId);

        // Finalize quest
        if (progress == 100) {
            // Remove quest active status.
            deleteQuestActivity(user, missions, missionId);

            // Update Mission-related stats

            // Increment number of mission completions.
            IMissions(missions).incrementMissionCompletions(missionId);

            // Increment number of missions facilitated by this Quest contract.
            incrementMissionCompletions();

            // Increment number of missions completed by user, as facilitated by this Quest contract.
            incrementUserMissionCompletions(user, missions, missionId);
        }
    }
}
