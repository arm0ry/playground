// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {IERC721} from "forge-std/interfaces/IERC721.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IKaliTokenManager} from "kali-markets/interface/IKaliTokenManager.sol";

import {IMission} from "./interface/IMission.sol";
import {Mission} from "./Mission.sol";
import {IStorage} from "kali-markets/interface/IStorage.sol";
import {Storage} from "kali-markets/Storage.sol";

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
    bytes32 public constant RESPOND_TYPEHASH = keccak256(
        "Respond(address signer, address missions, uint256 missionId, uint256 taskId, uint256 response, string feedback)"
    );
    bytes32 public constant REVIEW_TYPEHASH = keccak256(
        "Review(address signer, address user, address missions, uint256 missionId, uint256 taskId, uint256 response, string feedback)"
    );

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

    function getReviewCountByReviewer(address reviewer) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), ".reviewers.", reviewer, ".reviews.count")));
    }

    function getReviewFeedback(address reviewer, uint256 order, address missions, uint256 missionId, uint256 taskId)
        external
        view
        returns (string memory)
    {
        if (order > 0) {
            return this.getString(
                keccak256(abi.encode(address(this), ".reviewers.", reviewer, ".reviewId.", order, ".feedback"))
            );
        } else {
            order = this.getUint(
                keccak256(
                    abi.encode(
                        address(this), ".reviewers.", reviewer, ".quests.", missions, missionId, taskId, ".count"
                    )
                )
            );
            return this.getString(
                keccak256(abi.encode(address(this), ".reviewers.", reviewer, ".reviewId.", order, ".feedback"))
            );
        }
    }

    // TODO: Update below to same as feedback
    function getReviewResponse(address reviewer, uint256 order, address missions, uint256 missionId, uint256 taskId)
        external
        view
        returns (uint256)
    {
        return this.getUint(
            keccak256(
                abi.encode(
                    address(this), ".reviewers.", reviewer, ".quests.", missions, missionId, taskId, ".review.response"
                )
            )
        );
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
        if (count == 0) revert NotInitialized();
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

    function getUserFeedback(address user, uint256 order, address missions, uint256 missionId, uint256 taskId)
        external
        view
        returns (string memory)
    {
        if (order > 0) {
            return this.getString(
                keccak256(abi.encode(address(this), ".responses.", user, ".responseId.", order, ".feedback"))
            );
        } else {
            order = this.getUint(
                keccak256(
                    abi.encode(address(this), ".responses.", user, ".quests.", missions, missionId, taskId, ".count")
                )
            );
            return this.getString(
                keccak256(abi.encode(address(this), ".responses.", user, ".responseId.", order, ".feedback"))
            );
        }
    }

    function getUserResponse(address user, uint256 order, address missions, uint256 missionId, uint256 taskId)
        external
        view
        returns (uint256)
    {
        if (order > 0) {
            return this.getUint(
                keccak256(abi.encode(address(this), ".responses.", user, ".responseId.", order, ".response"))
            );
        } else {
            order = this.getUint(
                keccak256(
                    abi.encode(address(this), ".responses.", user, ".quests.", missions, missionId, taskId, ".count")
                )
            );
            return this.getUint(
                keccak256(abi.encode(address(this), ".responses.", user, ".responseId.", order, ".response"))
            );
        }
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

    function getQuestCount() internal returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), ".quests.count")));
    }

    /// -----------------------------------------------------------------------
    /// Quest Logic - Stats Setter
    /// -----------------------------------------------------------------------

    function incrementNumOfMissionsStarted() internal {
        addUint(keccak256(abi.encode(address(this), ".stats.missionStarts")), 1);
    }

    function incrementNumOfMissionsCompleted() internal {
        addUint(keccak256(abi.encode(address(this), ".stats.missionCompletions")), 1);
    }

    function incrementNumOfTaskCompleted() internal {
        addUint(keccak256(abi.encode(address(this), ".stats.taskCompletions")), 1);
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
        return this.getUint(keccak256(abi.encode(address(this), ".stats.missionStarts")));
    }

    function getNumOfMissionsCompleted() external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), ".stats.mission.completions")));
    }

    function getNumOfTaskCompleted() external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), ".stats.taskCompletions")));
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
        return addUint(keccak256(abi.encode(address(this), ".users.", user, ".count")), 1);
    }

    function incrementMissionQuested(address missions, uint256 missionId) internal returns (uint256, uint256) {
        return (
            addUint(keccak256(abi.encode(address(this), ".quests.", missions, missionId, ".count")), 1),
            addUint(keccak256(abi.encode(address(this), ".quests.", missions, ".count")), 1)
        );
    }

    function incrementResponseCountByUser(address user, address missions, uint256 missionId, uint256 taskId)
        internal
        returns (uint256, uint256)
    {
        return (
            addUint(
                keccak256(
                    abi.encode(address(this), ".responses.", user, ".quests.", missions, missionId, taskId, ".count")
                ),
                1
                ),
            addUint(keccak256(abi.encode(address(this), ".users.", user, "responses.count")), 1)
        );
    }

    function incrementReviewCount(address reviewer, address missions, uint256 missionId, uint256 taskId)
        internal
        returns (uint256, uint256)
    {
        return (
            // TODO: Separate updating review count from per task updating number of reveiws by reviewer
            addUint(keccak256(abi.encode(address(this), ".reviews.", missions, missionId, taskId, ".count")), 1),
            addUint(keccak256(abi.encode(address(this), ".reviewers.", reviewer, ".reviews.count")), 1)
        );
    }

    /// -----------------------------------------------------------------------
    /// Quest Logic - Counter Getter
    /// -----------------------------------------------------------------------

    function getMissionQuestedCount(address missions, uint256 missionId) external view returns (uint256, uint256) {
        return (
            this.getUint(keccak256(abi.encode(address(this), ".quests.", missions, missionId, ".count"))),
            this.getUint(keccak256(abi.encode(address(this), ".quests.", missions, ".count")))
        );
    }

    function getResponseCountByUser(address user, address missions, uint256 missionId, uint256 taskId)
        external
        view
        returns (uint256, uint256)
    {
        return (
            this.getUint(
                keccak256(
                    abi.encode(address(this), ".responses.", user, ".quests.", missions, missionId, taskId, ".count")
                )
                ),
            this.getUint(keccak256(abi.encode(address(this), ".users.", user, "responses.count")))
        );
    }

    function getReviewCountByReviewer(address reviewer, address missions, uint256 missionId, uint256 taskId)
        external
        view
        returns (uint256, uint256)
    {
        return (
            this.getUint(keccak256(abi.encode(address(this), ".reviews.", missions, missionId, taskId, ".count"))),
            this.getUint(keccak256(abi.encode(address(this), reviewer, "review.count")))
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

    function setQuestActivity(address user, address missions, uint256 missionId, bool status) internal virtual {
        _setBool(
            keccak256(abi.encode(address(this), ".users.", user, ".quests.", missions, missionId, ".active")), status
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
        (, uint256 count) = incrementResponseCountByUser(user, address(0), 0, 0);

        // Use response count as response id to associate with Task.
        _setUint(
            keccak256(abi.encode(address(this), ".responses.", user, ".quests.", missions, missionId, taskId, ".count")),
            count
        );

        // Set response content.
        _setUint(
            keccak256(abi.encode(address(this), ".responses.", user, ".responseId.", count, ".response")), response
        );

        // Set any response feedback.
        if (bytes(feedback).length > 0) {
            _setString(
                keccak256(abi.encode(address(this), ".responses.", user, ".responseId.", count, ".feedback")), feedback
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
        setReview(reviewer, user, missions, missionId, taskId, response, feedback);

        // Update quest detail.
        updateQuestAndStats(user, missions, missionId, taskId);
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
        (, uint256 numOfReviewsByReviewer) = incrementReviewCount(reviewer, missions, missionId, taskId);

        // Using number of reviews by a reviewer as review id, establish link between task id to reviewer's review id.
        // TODO: Consider using encodePacked to store missions + missionId + taskId in
        _setUint(
            keccak256(abi.encode(address(this), ".reviewers.", reviewer, ".reviewId.", numOfReviewsByReviewer, ".task")),
            this.getTokenId(missions, missionId, taskId)
        );

        // Set review content.
        _setUint(
            keccak256(
                abi.encode(address(this), ".reviewers.", reviewer, ".reviewId.", numOfReviewsByReviewer, ".response")
            ),
            response
        );

        // Set any review feedback.
        if (bytes(feedback).length > 0) {
            _setString(
                keccak256(
                    abi.encode(
                        address(this), ".reviewers.", reviewer, ".reviewId.", numOfReviewsByReviewer, ".feedback"
                    )
                ),
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

    function getTokenId(address user, uint256 missionId, uint256 curveId) external pure returns (uint256) {
        return uint256(bytes32(abi.encodePacked(user, uint48(missionId), uint48(curveId))));
    }

    function decodeTokenId(uint256 tokenId) external pure returns (address, uint256, uint256) {
        // Convert tokenId from type uint256 to bytes32.
        bytes32 key = bytes32(tokenId);

        // Declare variables to return later.
        uint48 curveId;
        uint48 missionId;
        address user;

        // Parse data via assembly.
        assembly {
            curveId := key
            missionId := shr(48, key)
            user := shr(96, key)
        }

        return (user, uint256(missionId), uint256(curveId));
    }
}
