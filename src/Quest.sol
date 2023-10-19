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

    error InvalidUser();

    error QuestInactive();

    error QuestInProgress();

    error InvalidReview();

    error InvalidReviewer();

    error NeedMoreTokens();

    error InvalidMission();

    error Cooldown();

    error MustBeginOneQuest();

    /// -----------------------------------------------------------------------
    /// Sign Storage
    /// -----------------------------------------------------------------------

    bytes32 public constant START_TYPEHASH = keccak256("Start(address signer, address missions, uint256 missionId)");
    bytes32 public constant RESPOND_TYPEHASH = keccak256(
        "Respond(address signer, address missions, uint256 missionId, uint256 taskId, string response, uint256 metricValue)"
    );
    bytes32 public constant REVIEW_TYPEHASH = keccak256(
        "Review(address signer, address user, address missions, uint256 missionId, uint256 taskId, bool result)"
    );

    uint256 internal INITIAL_CHAIN_ID;
    bytes32 internal INITIAL_DOMAIN_SEPARATOR;

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
    }

    /// @notice Traveler to respond to Task in order to progress Quest.
    /// @param missionId .
    /// @param taskId .
    /// @param response .
    /// @dev
    function respond(address missions, uint256 missionId, uint256 taskId, string calldata response) external payable {
        _respond(msg.sender, missions, missionId, taskId, response);
    }

    function respondBySig(
        address signer,
        address missions,
        uint256 missionId,
        uint256 taskId,
        string calldata response,
        uint256 metricValue,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public payable virtual {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(abi.encode(RESPOND_TYPEHASH, signer, missions, missionId, taskId, response, metricValue))
            )
        );

        address recoveredAddress = ecrecover(digest, v, r, s);
        if (recoveredAddress == address(0) || recoveredAddress != signer) revert InvalidUser();
    }

    /// -----------------------------------------------------------------------
    /// Review Logic
    /// -----------------------------------------------------------------------

    /// @notice Reviewer to submit review of task completion.
    /// @param missionId .
    /// @param taskId .
    /// @param result .
    /// @dev
    function review(address user, address missions, uint256 missionId, uint256 taskId, bool result)
        external
        payable
        onlyReviewer
    {
        _review(user, missions, missionId, taskId, result);
    }

    function reviewBySig(
        address signer,
        address user,
        address missions,
        uint256 missionId,
        uint256 taskId,
        bool result,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public payable virtual onlyReviewer {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(abi.encode(REVIEW_TYPEHASH, signer, user, missions, missionId, taskId, result))
            )
        );

        address recoveredAddress = ecrecover(digest, v, r, s);
        if (recoveredAddress == address(0) || recoveredAddress != msg.sender) revert InvalidUser();
    }

    /// -----------------------------------------------------------------------
    /// User Logic
    /// -----------------------------------------------------------------------

    function setProfilePicture(string calldata url) external payable {
        // Retrieve user quest start count.
        uint256 questId = this.getUint(keccak256(abi.encode(msg.sender, ".questId")));

        if (questId > 0) {
            this.setString(keccak256(abi.encode(msg.sender, ".profile")), url);
        } else {
            revert MustBeginOneQuest();
        }
    }

    /// -----------------------------------------------------------------------
    /// DAO Logic
    /// -----------------------------------------------------------------------

    function setMissions(address missions) external payable onlyOperator {
        setAddress(keccak256(abi.encode("missions")), missions);
    }

    /// @notice Update reviewers
    /// @param reviewer The addresses to update managers to
    function setReviewerStatus(uint256 questId, address reviewer, bool status) external payable onlyOperator {
        // Store new reviewer status
        if (status) setBool(keccak256(abi.encode(questId, reviewer, ".exists")), status);
    }

    /// @notice Set review status for all quest
    function setGlobalReview(bool status) external payable onlyOperator {
        if (status) setBool(keccak256(abi.encode("quest.review")), status);
    }

    function setResponseCoolDown(uint40 cd) external payable onlyOperator {
        if (cd > 0) setUint(keccak256(abi.encode("quest.cd")), cd);
    }
    /// -----------------------------------------------------------------------
    /// Getter Logic
    /// -----------------------------------------------------------------------

    function getQuestStatus(address user, uint256 questId) external view returns (bool) {
        return this.getBool(keccak256(abi.encode(user, questKey, ".active")));
    }

    function getQuestReviewStatus(address user, uint256 questId) external view returns (bool) {
        return this.getBool(keccak256(abi.encode(user, questKey, ".review")));
    }

    function getQuestProgress(address user, uint256 questId) external view returns (uint256) {
        return this.getBool(keccak256(abi.encode(user, questKey, ".progress")));
    }

    function getQuestTasksCompletionCount(address user, uint256 questId) external view returns (uint256) {
        return this.getBool(keccak256(abi.encode(user, questKey, ".completed")));
    }

    function getQuestDeadline(address missions, uint256 missionId) external payable returns (uint256) {
        // Confirm quest deadline has not passed
        uint256 deadline = IMissions(missions).getMissionDeadline(missionId);
        if (block.timestamp > deadline) return 0;
        return deadline;
    }

    /// -----------------------------------------------------------------------
    /// Helper Logic
    /// -----------------------------------------------------------------------

    function encodeKey(address missions, uint48 missionId, uint48 taskId) external pure returns (bytes32) {
        return bytes32(abi.encodePacked(missions, missionId, taskId));
    }

    function decodeKey(bytes32 key) external pure returns (address, uint256, uint256) {
        address missions;
        uint48 missionId;
        uint48 taskId;

        assembly {
            taskId := key
            missionId := shr(48, key)
            missions := shr(96, key)
        }

        return (missions, uint256(missionId), uint256(taskId));
    }

    /// @notice Calculate a percentage.
    /// @param numerator The numerator.
    /// @param denominator The denominator.
    /// @dev
    function calculateProgress(uint256 numerator, uint256 denominator) private pure returns (uint256) {
        return numerator * 100 / denominator;
    }

    /// -----------------------------------------------------------------------
    /// Internal Logic
    /// -----------------------------------------------------------------------

    /// @notice Update, and finalize when appropriate, the Quest detail.
    /// @param questKey .
    /// @param missionId .
    /// @dev
    function updateQuestDetail(address user, bytes32 questKey, uint256 missionId, uint256 completed) internal {
        // Retrieve number of Tasks to update Quest progress
        address missions = this.getAddress(keccak256(abi.encode("missions")));
        uint256 tasksCount = IMissions(missions).getMissionTaskCount(missionId);

        // Calculate and udpate quest detail
        ++completed;
        uint256 progress = calculateProgress(completed, tasksCount);

        // Store quest detail
        this.setUint(keccak256(abi.encode(user, questKey, ".detail.progress")), progress);
        this.setUint(keccak256(abi.encode(user, questKey, ".detail.completed")), completed);

        // Finalize quest
        if (progress == 100) {
            this.deleteBool(keccak256(abi.encode(user, questKey, ".detail.active")));
            this.deleteUint(keccak256(abi.encode(user, questKey, ".detail.timeLeft")));

            // Increment number of mission completions.
            IMissions(missions).incrementMissionCompletions(missionId);

            // Increment number of mission completions per questKey.
            this.addUint(keccak256(abi.encode(user, questKey, ".stats.completions")), 1);
        }
    }

    /// @notice Internal function using signature to start quest.
    /// @param user.
    /// @param missions.
    /// @param missionId.
    /// @dev
    function _start(address user, address missions, uint256 missionId) internal virtual {
        // Confirm mission has not expired.
        uint256 deadline = this.getQuestDeadline(missions, missionId);
        if (deadline == 0) revert InvalidMission();

        // Retrieve user quest start count.
        uint256 questId = this.getUint(keccak256(abi.encode(user, ".questId")));

        // Confirm Quest is not already in progress.
        if (questId != 0) {
            (, QuestDetail memory qd) = this.getQuestDetail(msg.sender, uint96(questId));
            if (qd.active) revert QuestInProgress();
        }

        // Initialize quest detail.
        bytes32 questKey = this.encodeKey(missions, uint48(missionId), 0);

        this.setBool(keccak256(abi.encode(user, questKey, ".detail.active")), true);
        this.setUint(keccak256(abi.encode(user, questKey, ".detail.deadline")), deadline);

        if (this.getBool(keccak256(abi.encode("quest.toReview")))) {
            bool toReview = this.getBool(keccak256(abi.encode("quest.toReview")));
            this.setBool(keccak256(abi.encode(user, questKey, ".detail.toReview")), toReview);
        }

        // Increment number of questId by user and store corresponding questKey
        this.addUint(keccak256(abi.encode(user, ".questId")), 1);
        this.setUint(keccak256(abi.encode(user, questId, "questKey")), uint256(questKey));

        // Increment number of mission starts by questKey.
        this.addUint(keccak256(abi.encode(questKey, ".stats.starts")), 1);

        // Increment number of mission starts by questKey by user.
        this.addUint(keccak256(abi.encode(user, questKey, ".stats.starts")), 1);

        // Increment number of mission starts
        IMissions(missions).incrementMissionStarts(missionId);
    }

    // TODO: CONSIDER ADDING SELF-ASSESSMENT METRICS TO QUEST CONTRACT
    /// @notice Internal function using signature to respond to quest tasks.
    /// @param user .
    /// @param missions .
    /// @param missionId .
    /// @param taskId .
    /// @param response .
    /// @dev
    function _respond(address user, address missions, uint256 missionId, uint256 taskId, string calldata response)
        internal
        virtual
    {
        // Retrieve user questId.
        uint256 questId = this.getUint(keccak256(abi.encode(user, ".questId")));

        // Retrieve questKey and QuestDetail.
        (bytes32 questKey, QuestDetail memory qd) = this.getQuestDetail(msg.sender, uint96(questId));
        bytes32 taskKey = this.encodeKey(missions, uint48(missionId), uint48(taskId));

        // Confirm Quest is active.
        if (!qd.active) revert QuestInactive();

        // Confirm Task is valid
        if (!IMissions(missions).isTaskInMission(missionId, taskId)) revert InvalidMission();

        // Confirm cooldown has expired.
        uint256 taskCd = this.getUint(keccak256(abi.encode(taskKey, ".review.cd")));
        if (block.timestamp < taskCd) revert Cooldown();

        // Store quest task responses.
        this.setString(keccak256(abi.encode(taskKey, ".review.response")), response);

        // Initiate/Reset cooldown.
        uint256 cd = this.getUint(keccak256(abi.encode("quest.cd")));
        this.setUint(keccak256(abi.encode(taskKey, ".review.cd")), cd + block.timestamp);

        // Increment number of responses for the task.
        // Data also applies to public use to signal frequency of interacting with a Task.
        this.addUint(keccak256(abi.encode(taskKey, ".review.responseCount")), 1);

        // If review is not necessary, proceed to distribute reward and update quest detail.
        if (!qd.toReview) {
            updateQuestDetail(user, questKey, missionId, qd.completed);

            // Increment task completion
            IMissions(missions).incrementTaskCompletions(taskId);
        }
    }

    /// @notice Internal function using signature to review quest tasks.
    /// @param user .
    /// @param missions .
    /// @param missionId .
    /// @param taskId .
    /// @param reviewResult .
    /// @dev
    function _review(address user, address missions, uint256 missionId, uint256 taskId, bool reviewResult) internal {
        // Retrieve user questId.
        uint256 questId = this.getUint(keccak256(abi.encode(user, ".questId")));

        // Retrieve quest id and corresponding quest detail
        bytes32 taskKey = this.encodeKey(missions, uint48(missionId), uint48(taskId));
        (bytes32 questKey, QuestDetail memory qd) = this.getQuestDetail(msg.sender, uint96(questId));
        if (!qd.toReview) revert InvalidReview();

        if (!reviewResult) {
            // Store review result
            this.deleteBool(keccak256(abi.encode(taskKey, ".review.result")));
        } else {
            // Store review result
            this.setBool(keccak256(abi.encode(taskKey, ".review.result")), reviewResult);

            // Update quest detail
            updateQuestDetail(user, questKey, missionId, qd.completed);

            // Increment task completion
            IMissions(missions).incrementTaskCompletions(taskId);
        }
    }
}
