// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {IERC721} from "forge-std/interfaces/IERC721.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IKaliTokenManager} from "kali-markets/interface/IKaliTokenManager.sol";
import {IStorage} from "kali-markets/interface/IStorage.sol";
import {Storage} from "kali-markets/Storage.sol";

import {IMission} from "./interface/IMission.sol";
import {Mission} from "./Mission.sol";

/// @title An interface between physical and digital operation.
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
    bytes32 public constant RESPOND_TYPEHASH =
        keccak256("Respond(address signer, bytes32 taskKey, uint256 response, string feedback)");
    bytes32 public constant REVIEW_TYPEHASH =
        keccak256("Review(address signer, address user, bytes32 taskKey, uint256 response, string feedback)");

    /// -----------------------------------------------------------------------
    /// Modifier
    /// -----------------------------------------------------------------------

    modifier onlyReviewer(address reviewer) {
        if (!this.isReviewer((reviewer == address(0)) ? msg.sender : reviewer)) revert InvalidReviewer();
        _;
    }

    modifier hasExpired(address missions, uint256 missionId) {
        checkExpiry(missions, missionId);
        _;
    }

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    function initialize(address dao) external payable {
        init(dao);
    }

    /// -----------------------------------------------------------------------
    /// DAO Logic
    /// -----------------------------------------------------------------------

    function setCooldown(uint40 cd) external payable onlyOperator {
        _setCooldown(cd);
    }

    /// @notice Set reviewer status.
    function _setCooldown(uint40 cd) internal {
        if (cd > 0) _setUint(keccak256(abi.encode(address(this), ".quests.cd")), cd);
    }

    function getCooldown() external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), ".quests.cd")));
    }

    /// @notice Review status applies to all quests.
    function setReviewStatus(bool status) external payable onlyOperator {
        if (status) _setBool(keccak256(abi.encode(address(this), ".quests.review")), status);
    }

    function getReviewStatus() external view returns (bool) {
        return this.getBool(keccak256(abi.encode(address(this), ".quests.review")));
    }

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
    /// User Logic
    /// -----------------------------------------------------------------------

    /// @notice Set profile picture.
    function setProfilePicture(string calldata url) external payable {
        if (bytes(url).length == 0) {
            deleteString(keccak256(abi.encode(address(this), ".users.", msg.sender, ".profile")));
        }
        _setString(keccak256(abi.encode(address(this), ".users.", msg.sender, ".profile")), url);
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
    /// @notice User to respond to Task in order to progress Quest.
    /// @param missionId .
    /// @param taskId .
    /// @param response .
    /// @dev
    function respond(address missions, uint256 missionId, uint256 taskId, uint256 response, string calldata feedback)
        external
        payable
        hasExpired(missions, missionId)
    {
        _respond(msg.sender, missions, missionId, taskId, response, feedback);
    }

    /// @notice Start a quest (gasless).
    /// @param signer .
    /// @param missions .
    /// @param missionId .
    /// @dev
    function respondBySig(
        address signer,
        address missions,
        uint256 missionId,
        uint256 taskId,
        uint256 response,
        string calldata feedback,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable virtual hasExpired(missions, missionId) {
        uint256 taskKey = this.getTaskKey(missions, missionId, taskId);
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(abi.encode(RESPOND_TYPEHASH, signer, taskKey, response, feedback))
            )
        );

        address recoveredAddress = ecrecover(digest, v, r, s);
        if (recoveredAddress == address(0) || recoveredAddress != signer) revert InvalidUser();

        _respond(signer, missions, missionId, taskId, response, feedback);
    }

    /// -----------------------------------------------------------------------
    /// Review Logic
    /// -----------------------------------------------------------------------

    /// @notice Review a task.
    function review(
        address user,
        address missions,
        uint256 missionId,
        uint256 taskId,
        uint256 response,
        string calldata feedback
    ) external payable onlyReviewer(address(0)) hasExpired(missions, missionId) {
        _review(msg.sender, user, missions, missionId, taskId, response, feedback);
    }

    /// @notice Review a task (gasless).
    // function reviewBySig(
    //     address reviewer,
    //     address user,
    //     address missions,
    //     uint256 missionId,
    //     uint256 taskId,
    //     uint256 response,
    //     string calldata feedback,
    //     uint8 v,
    //     bytes32 r,
    //     bytes32 s
    // ) external payable virtual onlyReviewer(reviewer) hasExpired(missions, missionId) {
    //     uint256 taskKey = this.getTaskKey(missions, missionId, taskId);
    //     bytes32 digest = keccak256(
    //         abi.encodePacked(
    //             "\x19\x01",
    //             DOMAIN_SEPARATOR(),
    //             keccak256(abi.encode(REVIEW_TYPEHASH, reviewer, user, taskKey, response, feedback))
    //         )
    //     );

    //     address recoveredAddress = ecrecover(digest, v, r, s);
    //     if (recoveredAddress == address(0) || recoveredAddress != reviewer) revert InvalidUser();

    //     _review(reviewer, user, missions, missionId, taskId, response, feedback);
    // }

    /// -----------------------------------------------------------------------
    /// Reviewer Logic - Setter
    /// -----------------------------------------------------------------------

    /// @notice Set reviewer status.
    function setReviewer(address reviewer, bool status) external payable onlyOperator {
        _setReviewer(reviewer, status);
    }

    /// @notice Set reviewer status.
    function _setReviewer(address reviewer, bool status) internal {
        if (status) _setBool(keccak256(abi.encode(address(this), ".reviewers.", reviewer, ".approved")), status);
    }

    /// @notice Review a Task.
    function isReviewer(address user) external view returns (bool) {
        return this.getBool(keccak256(abi.encode(address(this), ".reviewers.", user, ".approved")));
    }

    /// -----------------------------------------------------------------------
    /// Reviewer Logic - Getter
    /// -----------------------------------------------------------------------

    function getReviewFeedback(address reviewer, uint256 order) external view returns (string memory) {
        return (order == 0)
            ? this.getString(
                keccak256(
                    abi.encode(
                        address(this),
                        ".reviewers.",
                        reviewer,
                        ".reviewId.",
                        this.getNumOfReviewByReviewer(reviewer),
                        ".feedback"
                    )
                )
            )
            : this.getString(
                keccak256(abi.encode(address(this), ".reviewers.", reviewer, ".reviewId.", order, ".feedback"))
            );
    }

    function getReviewResponse(address reviewer, uint256 order) external view returns (uint256) {
        return (order == 0)
            ? this.getUint(
                keccak256(
                    abi.encode(
                        address(this),
                        ".reviewers.",
                        reviewer,
                        ".reviewId.",
                        this.getNumOfReviewByReviewer(reviewer),
                        ".response"
                    )
                )
            )
            : this.getUint(keccak256(abi.encode(address(this), ".reviewers.", reviewer, ".reviewId.", order, ".response")));
    }

    /// -----------------------------------------------------------------------
    /// User Logic - Internal
    /// -----------------------------------------------------------------------

    function deleteQuestActivity(address user, address missions, uint256 missionId) internal virtual {
        deleteBool(keccak256(abi.encode(address(this), ".users.", user, ".quests.", missions, missionId, ".active")));
    }

    function updateQuestProgress(address user, address missions, uint256 missionId, uint256 completed)
        internal
        virtual
        returns (uint256)
    {
        uint256 count = IMission(missions).getMissionTaskCount(missionId);
        uint256 progress = completed * 100 / count;
        _setUint(
            keccak256(abi.encode(address(this), ".users.", user, ".quests.", missions, missionId, ".progress")),
            progress
        );
        return progress;
    }

    /// -----------------------------------------------------------------------
    /// User Logic - Getter
    /// -----------------------------------------------------------------------

    /// @notice Get profile picture.
    function getProfilePicture(address user) external view returns (string memory) {
        return this.getString(keccak256(abi.encode(address(this), ".users.", user, ".profile")));
    }

    function isQuestActive(address user, address missions, uint256 missionId) external view returns (bool) {
        return this.getBool(
            keccak256(abi.encode(address(this), ".users.", user, ".quests.", missions, missionId, ".active"))
        );
    }

    function getQuestProgress(address user, address missions, uint256 missionId) external view returns (uint256) {
        return this.getUint(
            keccak256(abi.encode(address(this), ".users.", user, ".quests.", missions, missionId, ".progress"))
        );
    }

    function getCompletedTaskCount(address user, address missions, uint256 missionId) external view returns (uint256) {
        return this.getUint(
            keccak256(abi.encode(address(this), ".users.", user, ".quests.", missions, missionId, ".taskCompleted"))
        );
    }

    function getTimeLastTaskCompleted(address user) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), ".users.", user, ".timeLastCompleted")));
    }

    function hasCooledDown(address user) external view returns (bool) {
        return (block.timestamp >= this.getTimeLastTaskCompleted(user) + this.getCooldown()) ? true : false;
    }

    function getUserTask(address user, uint256 order)
        external
        view
        returns (address mission, uint256 missionId, uint256 taskId)
    {
        // Using number of responds by a user as respond id, establish link between task id to user's respond id.
        (mission, missionId, taskId) = this.decodeTaskKey(
            this.getUint(keccak256(abi.encode(address(this), ".users.", user, ".responseId.", order, ".task")))
        );
    }

    function getUserFeedback(address user, uint256 order) external view returns (string memory) {
        return (order == 0)
            ? this.getString(
                keccak256(
                    abi.encode(
                        address(this), ".users.", user, ".responseId.", this.getNumOfResponseByUser(user), ".feedback"
                    )
                )
            )
            : this.getString(keccak256(abi.encode(address(this), ".users.", user, ".responseId.", order, ".feedback")));
    }

    function getUserResponse(address user, uint256 order) external view returns (uint256) {
        return (order == 0)
            ? this.getUint(
                keccak256(
                    abi.encode(
                        address(this), ".users.", user, ".responseId.", this.getNumOfResponseByUser(user), ".response"
                    )
                )
            )
            : this.getUint(keccak256(abi.encode(address(this), ".users.", user, ".responseId.", order, ".response")));
    }

    /// -----------------------------------------------------------------------
    /// Quest Logic - Records
    /// -----------------------------------------------------------------------

    function getQuest(uint256 questId) external view returns (address, address, uint256) {
        return (
            this.getAddress(keccak256(abi.encode(address(this), ".quests.", questId, ".user"))),
            this.getAddress(keccak256(abi.encode(address(this), ".quests.", questId, ".missions"))),
            this.getUint(keccak256(abi.encode(address(this), ".quests.", questId, ".missionId")))
        );
    }

    function incrementQuestCount() internal returns (uint256) {
        return addUint(keccak256(abi.encode(address(this), ".quests.count")), 1);
    }

    function getQuestCount() external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), ".quests.count")));
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
        addUint(keccak256(abi.encode(address(this), ".users.", user, ".quests.", missions, missionId, ".starts")), 1);
    }

    function incrementNumOfMissionsCompletedByUser(address user, address missions, uint256 missionId) internal {
        addUint(
            keccak256(abi.encode(address(this), ".users.", user, ".quests.", missions, missionId, ".completions")), 1
        );
    }

    function incrementNumOfTasksCompletedByUser(address user, address missions, uint256 missionId, uint256 taskId)
        internal
    {
        addUint(
            keccak256(
                abi.encode(address(this), ".users.", user, ".quests.", missions, missionId, taskId, ".completions")
            ),
            1
        );
    }

    function incrementCompletedTaskInMission(address user, address missions, uint256 missionId)
        internal
        returns (uint256)
    {
        return addUint(
            keccak256(abi.encode(address(this), ".users.", user, ".quests.", missions, missionId, ".taskCompleted")), 1
        );
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
        return this.getUint(
            keccak256(abi.encode(address(this), ".users.", user, ".quests.", missions, missionId, ".starts"))
        );
    }

    function getNumOfMissionsCompletedByUser(address user, address missions, uint256 missionId)
        external
        view
        returns (uint256)
    {
        return this.getUint(
            keccak256(abi.encode(address(this), ".users.", user, ".quests.", missions, missionId, ".completions"))
        );
    }

    function getNumOfTasksCompletedByUser(address user, address missions, uint256 missionId, uint256 taskId)
        external
        view
        returns (uint256)
    {
        return this.getUint(
            keccak256(
                abi.encode(address(this), ".users.", user, ".quests.", missions, missionId, taskId, ".completions")
            )
        );
    }

    /// -----------------------------------------------------------------------
    /// Quest Logic - Counter Setter
    /// -----------------------------------------------------------------------

    function incrementQuestCountByUser(address user) internal returns (uint256) {
        return addUint(keccak256(abi.encode(address(this), ".users.", user, ".quests.count")), 1);
    }

    function getQuestCountByUser(address user) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), ".users.", user, ".quests.count")));
    }

    function incrementNumOfMissionQuested(address missions, uint256 missionId) internal returns (uint256, uint256) {
        return (
            addUint(keccak256(abi.encode(address(this), ".quests.", missions, missionId, ".count")), 1),
            addUint(keccak256(abi.encode(address(this), ".quests.", missions, ".count")), 1)
        );
    }

    function getNumOfMissionQuested(address missions, uint256 missionId) external view returns (uint256, uint256) {
        return (
            this.getUint(keccak256(abi.encode(address(this), ".quests.", missions, missionId, ".count"))),
            this.getUint(keccak256(abi.encode(address(this), ".quests.", missions, ".count")))
        );
    }

    function incrementNumOfResponseByUser(address user) internal returns (uint256) {
        return addUint(keccak256(abi.encode(address(this), ".users.", user, ".responses.count")), 1);
    }

    function getNumOfResponseByUser(address user) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), ".users.", user, ".responses.count")));
    }

    function incrementNumOfReviewByReviewer(address reviewer) internal returns (uint256) {
        return addUint(keccak256(abi.encode(address(this), ".reviewers.", reviewer, ".reviews.count")), 1);
    }

    function getNumOfReviewByReviewer(address reviewer) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), ".reviewers.", reviewer, ".reviews.count")));
    }

    /// -----------------------------------------------------------------------
    /// Quest Logic - Internal
    /// -----------------------------------------------------------------------

    /// @notice Internal function using signature to start quest.
    function _start(address user, address missions, uint256 missionId) internal virtual {
        // Confirm quest is inactive.
        if (this.isQuestActive(user, missions, missionId)) revert QuestInProgress();

        // Set quest status to active.
        setQuestActive(user, missions, missionId);

        // Update mission-related stats.
        updateMissionStartStats(user, missions, missionId);

        // Record quest.
        uint256 count = incrementQuestCount();
        setQuest(count, user, missions, missionId);

        // Increment Quest-related counter.
        incrementQuestCountByUser(user);
        incrementNumOfMissionQuested(missions, missionId);
    }

    function setQuestActive(address user, address missions, uint256 missionId) internal virtual {
        _setBool(
            keccak256(abi.encode(address(this), ".users.", user, ".quests.", missions, missionId, ".active")), true
        );
    }

    function updateMissionStartStats(address user, address missions, uint256 missionId) internal {
        // Increment number of missions started by user, as facilitated by this Quest contract.
        incrementNumOfMissionsStartedByUser(user, missions, missionId);

        // Increment number of missions started and facilitated by this Quest contract.
        incrementNumOfMissionsStarted();

        // Confirm Mission contract allows input from this Quest contract.
        if (IMission(missions).isQuestAuthorized(address(this))) {
            // Increment number of mission starts.
            IMission(missions).incrementMissionStarts(missionId);
        }
    }

    function setQuest(uint256 questId, address user, address missions, uint256 missionId) internal {
        _setAddress(keccak256(abi.encode(address(this), ".quests.", questId, ".user")), user);
        _setAddress(keccak256(abi.encode(address(this), ".quests.", questId, ".missions")), missions);
        _setUint(keccak256(abi.encode(address(this), ".quests.", questId, ".missionId")), missionId);
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
        if (!IMission(missions).isTaskInMission(missionId, taskId)) revert InvalidMission();

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

    function setResponse(
        address user,
        address missions,
        uint256 missionId,
        uint256 taskId,
        uint256 response,
        string calldata feedback
    ) internal virtual {
        // Retrieve number of responses as response id.
        uint256 count = incrementNumOfResponseByUser(user);

        setRespondTask(user, count, missions, missionId, taskId);
        setRespondResponse(user, count, response);
        setRespondFeedback(user, count, feedback);
    }

    function setRespondTask(address user, uint256 order, address missions, uint256 missionId, uint256 taskId)
        internal
        virtual
    {
        // Using number of responds by a user as respond id, establish link between task id to user's respond id.
        _setUint(
            keccak256(abi.encode(address(this), ".users.", user, ".responseId.", order, ".task")),
            this.getTaskKey(missions, missionId, taskId)
        );
    }

    function setRespondResponse(address user, uint256 order, uint256 response) internal virtual {
        // Set respond content.
        _setUint(keccak256(abi.encode(address(this), ".users.", user, ".responseId.", order, ".response")), response);
    }

    function setRespondFeedback(address user, uint256 order, string calldata feedback) internal virtual {
        // Set any respond feedback.
        if (bytes(feedback).length > 0) {
            _setString(
                keccak256(abi.encode(address(this), ".users.", user, ".responseId.", order, ".feedback")), feedback
            );
        }
    }

    function setTimeLastTaskCompleted(address user) internal virtual {
        _setUint(keccak256(abi.encode(address(this), ".users.", user, ".timeLastCompleted")), block.timestamp);
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
        setReview(reviewer, missions, missionId, taskId, response, feedback);

        // Update quest detail.
        updateQuestAndStats(user, missions, missionId, taskId);
    }

    /// @notice Add a review.
    function setReview(
        address reviewer,
        address missions,
        uint256 missionId,
        uint256 taskId,
        uint256 response,
        string calldata feedback
    ) internal virtual {
        // Retrieve number of responses as review id.
        uint256 count = incrementNumOfReviewByReviewer(reviewer);

        setReviewTaskId(reviewer, count, missions, missionId, taskId);
        setReviewResponse(reviewer, count, response);
        setReviewFeedback(reviewer, count, feedback);
    }

    function setReviewTaskId(address reviewer, uint256 order, address missions, uint256 missionId, uint256 taskId)
        internal
        virtual
    {
        // Using number of reviews by a reviewer as review id, establish link between task id to reviewer's review id.
        _setUint(
            keccak256(abi.encode(address(this), ".reviewers.", reviewer, ".reviewId.", order, ".task")),
            this.getTaskKey(missions, missionId, taskId)
        );
    }

    function setReviewResponse(address reviewer, uint256 order, uint256 response) internal virtual {
        // Set review content.
        _setUint(
            keccak256(abi.encode(address(this), ".reviewers.", reviewer, ".reviewId.", order, ".response")), response
        );
    }

    function setReviewFeedback(address reviewer, uint256 order, string calldata feedback) internal virtual {
        // Set any review feedback.
        if (bytes(feedback).length > 0) {
            _setString(
                keccak256(abi.encode(address(this), ".reviewers.", reviewer, ".reviewId.", order, ".feedback")),
                feedback
            );
        }
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

    function updateMissionCompletionStats(address user, address missions, uint256 missionId) internal {
        // Increment number of missions completed by user, as facilitated by this Quest contract.
        incrementNumOfMissionsCompletedByUser(user, missions, missionId);

        // Increment number of missions facilitated by this Quest contract.
        incrementNumOfMissionsCompleted();

        // Increment number of mission completions.
        if (IMission(missions).isQuestAuthorized(address(this))) {
            IMission(missions).incrementMissionCompletions(missionId);
        }
    }

    function updateTaskCompletionStats(address user, address missions, uint256 missionId, uint256 taskId) internal {
        // Increment number of missions facilitated by this Quest contract.
        incrementNumOfTaskCompleted();

        // Increment number of tasks completed by user, as facilitated by this Quest contract.
        incrementNumOfTasksCompletedByUser(user, missions, missionId, taskId);

        // Increment task completion at Missions contract.
        if (IMission(missions).isQuestAuthorized(address(this))) {
            IMission(missions).incrementTaskCompletions(taskId);
        }
    }

    /// -----------------------------------------------------------------------
    /// Helper Logic
    /// -----------------------------------------------------------------------

    function checkExpiry(address missions, uint256 missionId) internal view {
        uint256 deadline = IMission(missions).getMissionDeadline(missionId);
        if (deadline == 0) revert NotInitialized();
        if (block.timestamp > deadline) revert InvalidMission();
    }

    function getTaskKey(address mission, uint256 missionId, uint256 taskId) external pure returns (uint256) {
        return uint256(bytes32(abi.encodePacked(mission, uint48(missionId), uint48(taskId))));
    }

    function decodeTaskKey(uint256 tokenId) external pure returns (address, uint256, uint256) {
        // Convert tokenId from type uint256 to bytes32.
        bytes32 key = bytes32(tokenId);

        // Declare variables to return later.
        uint48 taskId;
        uint48 missionId;
        address mission;

        // Parse data via assembly.
        assembly {
            taskId := key
            missionId := shr(48, key)
            mission := shr(96, key)
        }

        return (mission, uint256(missionId), uint256(taskId));
    }
}
