// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {IMissions} from "./interface/IMissions.sol";
import {Missions} from "./Missions.sol";
import {IStorage} from "./interface/IStorage.sol";
import {Storage} from "./Storage.sol";
import {IERC721} from "../lib/forge-std/src/interfaces/IERC721.sol";
import {IERC20} from "../lib/forge-std/src/interfaces/IERC20.sol";
import {IKaliTokenManager} from "./interface/IKaliTokenManager.sol";

/// @title Quest captures intents and commitments while carrying out a Mission.
/// @author audsssy.eth
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
    error Cooldown();

    /// -----------------------------------------------------------------------
    /// Sign Storage
    /// -----------------------------------------------------------------------

    uint256 internal INITIAL_CHAIN_ID;
    bytes32 internal INITIAL_DOMAIN_SEPARATOR;
    bytes32 public constant START_TYPEHASH = keccak256("Start(address signer, address missions, uint256 missionId)");
    bytes32 public constant RESPOND_TYPEHASH = keccak256(
        "Respond(address signer, address missions, uint256 missionId, uint256 taskId, uint256 response, string feedback)"
    );
    bytes32 public constant REVIEW_TYPEHASH = keccak256(
        "Review(address signer, address user, address missions, uint256 missionId, uint256 taskId, uint256 response, string feedback)"
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
    /// Modifier
    /// -----------------------------------------------------------------------

    modifier onlyReviewer() {
        if (!this.isReviewer(msg.sender)) revert InvalidReviewer();
        _;
    }

    modifier hasExpired(address missions, uint256 missionId) {
        checkExpiry(missions, missionId);
        _;
    }

    /// -----------------------------------------------------------------------
    /// Operator Logic
    /// -----------------------------------------------------------------------

    function setCoolDown(uint40 cd) external payable onlyOperator {
        _setCoolDown(cd);
    }

    /// @notice Set reviewer status.
    function _setCoolDown(uint40 cd) internal {
        if (cd > 0) _setUint(keccak256(abi.encode("quest.cd")), cd);
    }

    function getCoolDown() external view returns (uint256) {
        return this.getUint(keccak256(abi.encode("quest.cd")));
    }

    /// -----------------------------------------------------------------------
    /// User Logic - External
    /// -----------------------------------------------------------------------

    /// @notice Set profile picture.
    function setProfilePicture(string calldata url) external payable {
        // Retrieve user quest start count.
        uint256 questId = this.getUint(keccak256(abi.encode(msg.sender, ".questId")));
        if (questId > 0) _setString(keccak256(abi.encode(msg.sender, ".profile")), url);
    }

    /// @notice Start a quest.
    /// @param missions .
    /// @param missionId .
    /// @dev
    function start(address missions, uint256 missionId) external payable hasExpired(missions, missionId) {
        _start(msg.sender, missions, missionId);
    }

    /// @notice Start a quest (gasless).
    /// @param signer .
    /// @param missions .
    /// @param missionId .
    /// @dev
    function startBySig(address signer, address missions, uint256 missionId, uint8 v, bytes32 r, bytes32 s)
        external
        payable
        virtual
        hasExpired(missions, missionId)
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

    /// @notice Respond to a task.
    /// @notice Traveler to respond to Task in order to progress Quest.
    /// @param missionId .
    /// @param taskId .
    /// @param response .
    /// @dev
    function respond(address missions, uint256 missionId, uint256 taskId, string calldata feedback, uint256 response)
        external
        payable
        hasExpired(missions, missionId)
    {
        _respond(msg.sender, missions, missionId, taskId, response, feedback);
    }

    /// @notice Respond to a task (gasless).
    function respondBySig(
        address signer,
        uint256 taskKey,
        string calldata feedback,
        uint256 response,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable virtual {
        (address missions, uint256 missionId, uint256 taskId) = this.decodeKey(taskKey);
        checkExpiry(missions, missionId);
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(abi.encode(RESPOND_TYPEHASH, signer, missions, missionId, taskId, feedback, response))
            )
        );

        address recoveredAddress = ecrecover(digest, v, r, s);
        if (recoveredAddress == address(0) || recoveredAddress != signer) revert InvalidUser();

        _respond(signer, missions, missionId, taskId, response, feedback);
    }

    /// -----------------------------------------------------------------------
    /// Review Logic
    /// -----------------------------------------------------------------------

    /// @notice Review status applies to all quests.
    function setReviewStatus(bool status) external payable onlyOperator {
        if (status) _setBool(keccak256(abi.encode("quest.review")), status);
    }

    function getReviewStatus() external view returns (bool) {
        return this.getBool(keccak256(abi.encode("quest.review")));
    }

    /// @notice Review a task.
    function review(
        address user,
        address missions,
        uint256 missionId,
        uint256 taskId,
        uint256 response,
        string calldata feedback
    ) external payable onlyReviewer hasExpired(missions, missionId) {
        _review(msg.sender, user, missions, missionId, taskId, response, feedback);
    }

    /// @notice Review a task (gasless).
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
    ) external payable virtual onlyReviewer hasExpired(missions, missionId) {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(abi.encode(REVIEW_TYPEHASH, signer, user, missions, missionId, taskId, response, feedback))
            )
        );

        address recoveredAddress = ecrecover(digest, v, r, s);
        if (recoveredAddress == address(0) || recoveredAddress != msg.sender) revert InvalidUser();

        _review(signer, user, missions, missionId, taskId, response, feedback);
    }

    /// @notice Add a review.
    function setReview(
        address reviewer,
        address user,
        address missions,
        uint256 missionId,
        uint256 taskId,
        uint256 response,
        string calldata feedback
    ) internal virtual {
        // Retrieve number of responses as review id.
        (, uint256 count) = incrementReviewCountByReviewer(reviewer, address(0), 0, 0);

        // Set review id to Task.
        _setUint(keccak256(abi.encode(user, missions, missionId, taskId, ".review")), count);

        // Set review content.
        _setUint(keccak256(abi.encode(user, ".review.", count, ".response")), response);

        // Set any review feedback.
        if (bytes(feedback).length > 0) {
            _setString(keccak256(abi.encode(reviewer, ".review.", count, ".feedback")), feedback);
        }
    }

    /// -----------------------------------------------------------------------
    /// Reviewer Logic - Setter
    /// -----------------------------------------------------------------------

    /// @notice Set reviewer status.
    function setReviewer(address reviewer, bool status) external payable onlyOperator {
        _setReviewer(reviewer, status);
    }

    /// @notice Set reviewer status.
    function _setReviewer(address reviewer, bool status) internal {
        if (status) _setBool(keccak256(abi.encode(reviewer, ".approved")), status);
    }

    /// @notice Review a Task.
    function isReviewer(address user) external view returns (bool) {
        return this.getBool(keccak256(abi.encode(user, ".approved")));
    }

    /// -----------------------------------------------------------------------
    /// Reviewer Logic - Getter
    /// -----------------------------------------------------------------------

    function getReviewFeedback(address reviewer, address user, address missions, uint256 missionId, uint256 taskId)
        external
        view
        returns (string memory)
    {
        return this.getString(
            keccak256(abi.encode(address(this), reviewer, user, missions, missionId, taskId, ".review.feedback"))
        );
    }

    function getReviewResponse(address reviewer, address user, address missions, uint256 missionId, uint256 taskId)
        external
        view
        returns (uint256)
    {
        return this.getUint(
            keccak256(abi.encode(address(this), reviewer, user, missions, missionId, taskId, ".review.response"))
        );
    }

    /// -----------------------------------------------------------------------
    /// User Logic - Internal
    /// -----------------------------------------------------------------------

    function setQuestActivity(address user, address missions, uint256 missionId, bool status) internal virtual {
        _setBool(keccak256(abi.encode(address(this), user, missions, missionId, ".active")), status);
    }

    function deleteQuestActivity(address user, address missions, uint256 missionId) internal virtual {
        deleteBool(keccak256(abi.encode(address(this), user, missions, missionId, ".active")));
    }

    function updateQuestProgress(address user, address missions, uint256 missionId, uint256 completed)
        internal
        virtual
        returns (uint256)
    {
        uint256 count = IMissions(missions).getMissionTaskCount(missionId);
        if (count == 0) revert NotInitialized();
        uint256 progress = completed * 100 / count;
        _setUint(keccak256(abi.encode(user, missions, missionId, ".progress")), progress);
        return progress;
    }

    function setTimeLastTaskCompleted(address user) internal virtual {
        _setUint(keccak256(abi.encode(user, ".timeLastCompleted")), block.timestamp);
    }

    function setResponse(
        address user,
        address missions,
        uint256 missionId,
        uint256 taskId,
        uint256 response,
        string calldata feedback
    ) internal virtual {
        // Retrieve number of responses as response id.
        (, uint256 count) = incrementResponseCountByUser(user, address(0), 0, 0);

        // Use response count as response id to associate with Task.
        _setUint(keccak256(abi.encode(user, missions, missionId, taskId, ".response")), count);

        // Set response content.
        _setUint(keccak256(abi.encode(user, ".response.", count, ".response")), response);

        // Set any response feedback.
        if (bytes(feedback).length > 0) {
            _setString(keccak256(abi.encode(user, ".response.", count, ".feedback")), feedback);
        }
    }

    /// -----------------------------------------------------------------------
    /// User Logic - Getter
    /// -----------------------------------------------------------------------

    /// @notice Get profile picture.
    function getProfilePicture(address user) external view returns (string memory) {
        return this.getString(keccak256(abi.encode(user, ".profile")));
    }

    function isQuestActive(address user, address missions, uint256 missionId) external view returns (bool) {
        return this.getBool(keccak256(abi.encode(address(this), user, missions, missionId, ".active")));
    }

    function getQuestProgress(address user, address missions, uint256 missionId) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), user, missions, missionId, ".progress")));
    }

    function getCompletedTaskCount(address user, address missions, uint256 missionId) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), user, missions, missionId, ".taskCompleted")));
    }

    function getTimeLastTaskCompleted(address user) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), user, ".timeLastCompleted")));
    }

    function hasCooledDown(address user) external view returns (bool) {
        return (block.timestamp >= this.getTimeLastTaskCompleted(user) + this.getCoolDown()) ? true : false;
    }

    function getUserFeedback(address user, address missions, uint256 missionId, uint256 taskId)
        external
        view
        returns (string memory)
    {
        return this.getString(keccak256(abi.encode(address(this), user, missions, missionId, taskId, ".feedback")));
    }

    function getUserResponse(address user, address missions, uint256 missionId, uint256 taskId)
        external
        view
        returns (uint256)
    {
        return this.getUint(keccak256(abi.encode(address(this), user, missions, missionId, taskId, ".response")));
    }

    /// -----------------------------------------------------------------------
    /// Quest Logic - Records
    /// -----------------------------------------------------------------------

    function setQuest(uint256 questId, address user, address missions, uint256 missionId) internal {
        _setAddress(keccak256(abi.encode(address(this), questId, ".user")), user);
        _setAddress(keccak256(abi.encode(address(this), questId, ".missions")), missions);
        _setUint(keccak256(abi.encode(address(this), questId, ".missionId")), missionId);
    }

    function getQuest(uint256 questId) external view returns (address, address, uint256) {
        return (
            this.getAddress(keccak256(abi.encode(address(this), questId, ".user"))),
            this.getAddress(keccak256(abi.encode(address(this), questId, ".missions"))),
            this.getUint(keccak256(abi.encode(address(this), questId, ".missionId")))
        );
    }

    function incrementQuestCount() internal returns (uint256) {
        return addUint(keccak256(abi.encode(address(this), ".count")), 1);
    }

    /// -----------------------------------------------------------------------
    /// Quest Logic - Stats Setter
    /// -----------------------------------------------------------------------

    function incrementNumOfMissionsStarted() internal {
        addUint(keccak256(abi.encode(address(this), ".stats.mission.starts")), 1);
    }

    function incrementNumOfMissionsCompleted() internal {
        addUint(keccak256(abi.encode(address(this), ".stats.mission.completions")), 1);
    }

    function incrementNumOfTaskCompleted() internal {
        addUint(keccak256(abi.encode(address(this), ".stats.task.completions")), 1);
    }

    function incrementNumOfMissionsStartedByUser(address user, address missions, uint256 missionId) internal {
        addUint(keccak256(abi.encode(user, missions, missionId, ".starts")), 1);
    }

    function incrementNumOfMissionsCompletedByUser(address user, address missions, uint256 missionId) internal {
        addUint(keccak256(abi.encode(user, missions, missionId, ".completions")), 1);
    }

    function incrementNumOfTasksCompletedByUser(address user, address missions, uint256 missionId, uint256 taskId)
        internal
    {
        addUint(keccak256(abi.encode(user, missions, missionId, taskId, ".completions")), 1);
    }

    function incrementCompletedTaskInMission(address user, address missions, uint256 missionId)
        internal
        returns (uint256)
    {
        return addUint(keccak256(abi.encode(user, missions, missionId, ".taskCompleted")), 1);
    }

    /// -----------------------------------------------------------------------
    /// Quest Logic - Stats Getter
    /// -----------------------------------------------------------------------

    function getNumOfMissionsStarted() external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), ".stats.mission.starts")));
    }

    function getNumOfMissionsCompleted() external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), ".stats.mission.completions")));
    }

    function getNumOfTaskCompleted() external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), ".stats.task.completions")));
    }

    function getNumOfMissionsStartedByUser(address user, address missions, uint256 missionId)
        external
        view
        returns (uint256)
    {
        return this.getUint(keccak256(abi.encode(user, missions, missionId, ".starts")));
    }

    function getNumOfMissionsCompletedByUser(address user, address missions, uint256 missionId)
        external
        view
        returns (uint256)
    {
        return this.getUint(keccak256(abi.encode(user, missions, missionId, ".completions")));
    }

    function getNumOfTasksCompletedByUser(address user, address missions, uint256 missionId, uint256 taskId)
        external
        view
        returns (uint256)
    {
        return this.getUint(keccak256(abi.encode(user, missions, missionId, taskId, ".completions")));
    }

    /// -----------------------------------------------------------------------
    /// Quest Logic - Counter
    /// -----------------------------------------------------------------------

    function getMissionQuestedCount(address missions, uint256 missionId) external view returns (uint256, uint256) {
        return (
            this.getUint(keccak256(abi.encode(address(this), missions, missionId, ".count"))),
            this.getUint(keccak256(abi.encode(address(this), missions, ".count")))
        );
    }

    function getResponseCountByUser(address user, address missions, uint256 missionId, uint256 taskId)
        external
        view
        returns (uint256, uint256)
    {
        return (
            this.getUint(keccak256(abi.encode(address(this), user, missions, missionId, taskId, ".count"))),
            this.getUint(keccak256(abi.encode(address(this), user, "task.count")))
        );
    }

    function getReviewCountByReviewer(address reviewer, address missions, uint256 missionId, uint256 taskId)
        external
        view
        returns (uint256, uint256)
    {
        return (
            this.getUint(keccak256(abi.encode(address(this), missions, missionId, taskId, reviewer, ".review.count"))),
            this.getUint(keccak256(abi.encode(address(this), reviewer, "review.count")))
        );
    }

    function incrementQuestCountByUser(address user) internal returns (uint256) {
        return addUint(keccak256(abi.encode(address(this), user, ".count")), 1);
    }

    function incrementMissionQuested(address missions, uint256 missionId) internal returns (uint256, uint256) {
        return (
            addUint(keccak256(abi.encode(address(this), missions, missionId, ".count")), 1),
            addUint(keccak256(abi.encode(address(this), missions, ".count")), 1)
        );
    }

    function incrementResponseCountByUser(address user, address missions, uint256 missionId, uint256 taskId)
        internal
        returns (uint256, uint256)
    {
        return (
            addUint(keccak256(abi.encode(address(this), user, missions, missionId, taskId, ".count")), 1),
            addUint(keccak256(abi.encode(address(this), user, "task.count")), 1)
        );
    }

    function incrementReviewCountByReviewer(address reviewer, address missions, uint256 missionId, uint256 taskId)
        internal
        returns (uint256, uint256)
    {
        return (
            addUint(keccak256(abi.encode(address(this), missions, missionId, taskId, reviewer, ".review.count")), 1),
            addUint(keccak256(abi.encode(address(this), reviewer, ".review.count")), 1)
        );
    }

    /// -----------------------------------------------------------------------
    /// Quest Logic - Internal
    /// -----------------------------------------------------------------------

    /// @notice Internal function using signature to start quest.
    function _start(address user, address missions, uint256 missionId) internal virtual {
        // Confirm quest is inactive.
        if (this.isQuestActive(user, missions, missionId)) revert QuestInProgress();

        // Set quest status to active.
        setQuestActivity(user, missions, missionId, true);

        // Update mission-related stats.
        updateMissionStartStats(user, missions, missionId);

        // Record quest.
        uint256 count = incrementQuestCount();
        setQuest(count, user, missions, missionId);

        // Increment Quest-related counter.
        incrementQuestCountByUser(user);
        incrementMissionQuested(missions, missionId);
    }

    /// @notice Internal function using signature to respond to quest tasks.
    function _respond(
        address user,
        address missions,
        uint256 missionId,
        uint256 taskId,
        uint256 response,
        string calldata feedback
    ) internal virtual {
        // Confirm quest is active.
        if (!this.isQuestActive(user, missions, missionId)) revert QuestInactive();

        // Confirm Task is valid
        if (!IMissions(missions).isTaskInMission(missionId, taskId)) revert InvalidMission();

        // Confirm user is no longer in cooldown.
        if (!this.hasCooledDown(user)) revert Cooldown();

        // Store responses.
        setResponse(user, missions, missionId, taskId, response, feedback);

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
        uint256 response,
        string calldata feedback
    ) internal virtual {
        if (!this.getReviewStatus()) revert InvalidReview();

        // Store review.
        setReview(reviewer, user, missions, missionId, taskId, response, feedback);

        // Update quest detail.
        updateQuestAndStats(user, missions, missionId, taskId);
    }

    /// @notice Update, and finalize when appropriate, the Quest detail.
    function updateQuestAndStats(address user, address missions, uint256 missionId, uint256 taskId) internal {
        // Calculate and udpate quest detail
        uint256 completed = incrementCompletedTaskInMission(user, missions, missionId);
        uint256 progress = updateQuestProgress(user, missions, missionId, completed);

        // Update Task-related stats
        updateTaskCompletionStats(user, missions, missionId, taskId);

        // Finalize quest
        if (progress == 100) {
            // Remove quest active status.
            deleteQuestActivity(user, missions, missionId);

            // Update Mission-related stats
            updateMissionCompletionStats(user, missions, missionId);
        }
    }

    /// -----------------------------------------------------------------------
    /// Stats Logic - Internal
    /// -----------------------------------------------------------------------

    function updateMissionStartStats(address user, address missions, uint256 missionId) internal {
        // Increment number of missions started by user, as facilitated by this Quest contract.
        incrementNumOfMissionsStartedByUser(user, missions, missionId);

        // Increment number of missions started and facilitated by this Quest contract.
        incrementNumOfMissionsStarted();

        // Confirm Mission contract allows input from this Quest contract.
        if (IMissions(missions).isQuestAllowed(address(this))) {
            // Increment number of mission starts.
            IMissions(missions).incrementMissionStarts(missionId);
        }
    }

    function updateMissionCompletionStats(address user, address missions, uint256 missionId) internal {
        // Increment number of missions completed by user, as facilitated by this Quest contract.
        incrementNumOfMissionsCompletedByUser(user, missions, missionId);

        // Increment number of missions facilitated by this Quest contract.
        incrementNumOfMissionsCompleted();

        // Increment number of mission completions.
        if (IMissions(missions).isQuestAllowed(address(this))) {
            IMissions(missions).incrementMissionCompletions(missionId);
        }
    }

    function updateTaskCompletionStats(address user, address missions, uint256 missionId, uint256 taskId) internal {
        // Increment number of missions facilitated by this Quest contract.
        incrementNumOfTaskCompleted();

        // Increment number of tasks completed by user, as facilitated by this Quest contract.
        incrementNumOfTasksCompletedByUser(user, missions, missionId, taskId);

        // Increment task completion at Missions contract.
        if (IMissions(missions).isQuestAllowed(address(this))) {
            IMissions(missions).incrementTaskCompletions(taskId);
        }
    }

    /// -----------------------------------------------------------------------
    /// Helper Logic
    /// -----------------------------------------------------------------------

    function encode(address addr, uint256 num1, uint256 num2) external pure returns (uint256) {
        return uint256(bytes32(abi.encodePacked(addr, uint48(num1), uint48(num2))));
    }

    function decodeKey(uint256 key) external pure returns (address, uint256, uint256) {
        // Convert tokenId from type uint256 to bytes32.
        bytes32 _key = bytes32(key);

        // Declare variables to return later.
        uint48 num2;
        uint48 num1;
        address addr;

        // Parse data via assembly.
        assembly {
            num2 := _key
            num1 := shr(48, _key)
            addr := shr(96, _key)
        }

        return (addr, uint256(num1), uint256(num2));
    }

    function checkExpiry(address missions, uint256 missionId) internal view {
        uint256 deadline = IMissions(missions).getMissionDeadline(missionId);
        if (deadline == 0) revert NotInitialized();
        if (block.timestamp > deadline) revert InvalidMission();
    }
}
