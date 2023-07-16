// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {IMissions} from "./interface/IMissions.sol";
import {IKaliTokenManager} from "./interface/IKaliTokenManager.sol";
import {IERC721} from "forge-std/interfaces/IERC721.sol";

/// @title  Quests
/// @notice RPG for NFTs.
/// @author audsssy.eth

struct QuestDetail {
    bool active; // Indicates whether a quest is active
    uint16 nonce; // Number of times a user activated quest
    uint40 timestamp; // Timestamp to calculate
    uint40 timeLeft; // Time left to complete quest
    uint40 completed; // Number of tasks completed in quest
    uint8 progress; // 0-100%
}

struct Reward {
    uint40 earned; // Rewards earned from quests
    uint40 claimed; // Rewards claimed to date
}

enum Review {
    NA, // Not available
    PASS,
    FAIL
}

contract Quests {
    /// -----------------------------------------------------------------------
    /// Custom Errors
    /// -----------------------------------------------------------------------

    error InvalidMission();

    error NotAuthorized();

    error InvalidUser();

    error NothingToClaim();

    error QuestInactive();

    error QuestInProgress();

    error QuestLapsed();

    error InvalidReviewer();

    error InvalidResponse();

    error InvalidReview();

    error NeedMoreXp();

    /// -----------------------------------------------------------------------
    /// Quest Storage
    /// -----------------------------------------------------------------------

    address payable public admin;

    IMissions public mission;

    // questKey => QuestDetail
    mapping(bytes => QuestDetail) public questDetail;

    // msg.sender => questKey
    mapping(address => bytes[]) public quests;

    // taskKey => [string]
    mapping(bytes => string[]) public responses;

    // taskKey => [Review]
    mapping(bytes => Review[]) public reviews;

    // questKey => Reward
    mapping(bytes => Reward) public rewards;

    // Status indicating if an address is a Manager
    // Account -> True/False
    mapping(address => bool) public isReviewer;

    // Tally xp per creator
    // Tasks & Missions creators => Reward
    mapping(address => Reward) public creatorRewards;

    // Users per Mission Id
    // Mission Id => Users
    mapping(uint256 => address[]) public missionStarts;

    // Traveler completions by Mission Id
    // Mission Id => Users
    mapping(uint256 => address[]) public missionCompeletions;

    /// -----------------------------------------------------------------------
    /// Modifier
    /// -----------------------------------------------------------------------

    modifier onlyReviewer() {
        if (!isReviewer[msg.sender]) revert InvalidReviewer();
        _;
    }

    modifier onlyAdmin() {
        if (admin != msg.sender) revert NotAuthorized();
        _;
    }

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(IMissions _mission, address payable _admin) {
        mission = _mission;
        admin = _admin;
    }

    /// -----------------------------------------------------------------------
    /// Quest Logic
    /// -----------------------------------------------------------------------

    /// @notice Traveler to start a new Quest.
    /// @param tokenAddress .
    /// @param tokenId .
    /// @param missionId .
    /// @dev
    function startQuest(address tokenAddress, uint256 tokenId, uint256 missionId) external payable {
        (, uint40 duration,,,,, uint256 requiredXp,,) = mission.getMission(missionId);

        // Confirm Mission is questable
        if (duration == 0) revert InvalidMission();

        // Confirm Traveler has sufficient xp to quest Misson
        if (IKaliTokenManager(admin).balanceOf(msg.sender) < requiredXp) revert NeedMoreXp();

        // Confirm User is owner of NFT
        if (IERC721(tokenAddress).ownerOf(tokenId) != msg.sender) revert InvalidUser();

        // Retrieve quest id and corresponding quest detail
        bytes memory questKey = this.encode(tokenAddress, tokenId, missionId, 0);
        QuestDetail memory qd = questDetail[questKey];

        // Confirm Quest is not already in progress
        if (qd.active) revert QuestInProgress();

        // Check if quest was previously paused
        if (qd.timeLeft > 0) {
            // Update quest detail
            questDetail[questKey].active = true;
            questDetail[questKey].timestamp = uint40(block.timestamp);
        } else {
            // initialize quest detail
            questDetail[questKey].active = true;
            questDetail[questKey].nonce = ++qd.nonce;
            questDetail[questKey].timestamp = uint40(block.timestamp);
            questDetail[questKey].timeLeft = duration;

            missionStarts[missionId].push(msg.sender);
        }
    }

    /// @notice Traveler to pause an active Quest.
    /// @param tokenAddress .
    /// @param tokenId .
    /// @param missionId .
    /// @dev
    function pauseQuest(address tokenAddress, uint256 tokenId, uint256 missionId) external payable {
        // Confirm User is owner of NFT
        if (IERC721(tokenAddress).ownerOf(tokenId) != msg.sender) revert InvalidUser();

        // Retrieve quest id and corresponding quest detail
        bytes memory questKey = this.encode(tokenAddress, tokenId, missionId, 0);
        QuestDetail memory qd = questDetail[questKey];

        // Confirm Quest is active
        if (!qd.active) revert QuestInactive();

        uint40 lapse = uint40(block.timestamp) - qd.timestamp;
        if (qd.timeLeft > lapse) {
            questDetail[questKey] = QuestDetail({
                active: false,
                nonce: qd.nonce,
                timestamp: 0,
                timeLeft: qd.timeLeft - lapse,
                completed: qd.completed,
                progress: qd.progress
            });
        } else {
            questDetail[questKey] = QuestDetail({
                active: false,
                nonce: qd.nonce,
                timestamp: 0,
                timeLeft: 0,
                completed: qd.completed,
                progress: qd.progress
            });

            revert QuestLapsed();
        }
    }

    /// @notice Traveler to submit Homework for Task completion.
    /// @param tokenAddress .
    /// @param tokenId .
    /// @param missionId .
    /// @param taskId .
    /// @param response .
    /// @dev
    function addResponse(
        address tokenAddress,
        uint256 tokenId,
        uint256 missionId,
        uint256 taskId,
        string calldata response
    ) external payable {
        // Confirm User is owner of NFT
        if (IERC721(tokenAddress).ownerOf(tokenId) != msg.sender) revert InvalidUser();

        // Retrieve quest id and corresponding quest detail
        bytes memory questKey = this.encode(tokenAddress, tokenId, missionId, 0);
        QuestDetail memory qd = questDetail[questKey];

        // Confirm Quest is active
        if (!qd.active) revert QuestInactive();

        // Confirm Task is part of Mission
        if (!mission.isTaskInMission(missionId, uint8(taskId))) revert InvalidMission();

        // Add response to Task
        bytes memory taskKey = this.encode(tokenAddress, tokenId, missionId, taskId);
        uint256 responsesLength = responses[taskKey].length;
        uint256 reviewsLength = reviews[taskKey].length;

        if (responsesLength == reviewsLength && bytes(response).length != 0) {
            responses[taskKey].push(response);
        }
    }

    /// -----------------------------------------------------------------------
    /// Review Functions
    /// -----------------------------------------------------------------------

    /// @notice Reviewer to submit review of task completion.
    /// @param tokenAddress .
    /// @param tokenId .
    /// @param missionId .
    /// @param taskId .
    /// @param review .
    /// @dev
    function reviewTasks(address tokenAddress, uint256 tokenId, uint256 missionId, uint256 taskId, Review review)
        external
        payable
        onlyReviewer
    {
        // Confirm Reviewer has submitted valid review data
        if (review == Review.NA) revert InvalidReview();

        bytes memory taskKey = this.encode(tokenAddress, tokenId, missionId, taskId);
        reviews[taskKey].push(review);

        // Update quest detail
        if (review == Review.PASS) {
            distributeTaskRewards(tokenAddress, tokenId, missionId, taskId);
            updateQuestDetail(tokenAddress, tokenId, missionId);
        }
    }

    /// -----------------------------------------------------------------------
    /// Claim Rewards Functions
    /// -----------------------------------------------------------------------

    /// @notice User function to claim rewards.
    /// @dev
    function claimRewards(address tokenAddress, uint256 tokenId, uint256 missionId) external payable {
        // Confirm User is owner of NFT
        if (IERC721(tokenAddress).ownerOf(tokenId) != msg.sender) revert InvalidUser();

        // Retrieve quest id and corresponding quest detail
        bytes memory questKey = this.encode(tokenAddress, tokenId, missionId, 0);
        Reward memory r = rewards[questKey];

        if (r.earned > r.claimed) {
            IKaliTokenManager(admin).mintShares(msg.sender, r.earned - r.claimed);
            r.claimed = r.earned;
        } else {
            revert NothingToClaim();
        }
    }

    /// @notice Creator function to claim rewards.
    /// @dev
    function claimCreatorReward() external payable {
        Reward memory r = creatorRewards[msg.sender];

        if (r.earned > r.claimed) {
            IKaliTokenManager(admin).mintShares(msg.sender, r.earned - r.claimed);
            r.claimed = r.earned;
        } else {
            revert NothingToClaim();
        }
    }

    /// -----------------------------------------------------------------------
    /// Admin Functions
    /// -----------------------------------------------------------------------

    /// @notice Update contracts.
    /// @param _mission Contract address of Missions.sol.
    /// @dev
    function updateContracts(IMissions _mission) external payable onlyAdmin {
        mission = _mission;
    }

    /// @notice Update reviewers
    /// @param reviewers The addresses to update managers to
    /// @dev
    function updateReviewers(address[] calldata reviewers, bool[] calldata status) external payable onlyAdmin {
        uint256 length = reviewers.length;

        for (uint8 i = 0; i < length;) {
            isReviewer[reviewers[i]] = status[i];

            // cannot possibly overflow
            unchecked {
                ++i;
            }
        }
    }

    function updateAdmin(address payable _admin) external payable onlyAdmin {
        admin = _admin;
    }

    /// -----------------------------------------------------------------------
    /// Getter Functions
    /// -----------------------------------------------------------------------

    function getQuestDetail(address tokenAddress, uint256 tokenId, uint256 missionId)
        external
        view
        returns (bool, uint16, uint40, uint40, uint40, uint8)
    {
        // Retrieve quest id and corresponding quest detail
        bytes memory questKey = this.encode(tokenAddress, tokenId, missionId, 0);
        QuestDetail memory qd = questDetail[questKey];
        return (qd.active, qd.nonce, qd.timestamp, qd.timeLeft, qd.completed, qd.progress);
    }

    function getMissionCompletionsCount(uint256 missionId) external view returns (uint256) {
        return missionCompeletions[missionId].length;
    }

    function getMissionStartCount(uint256 missionId) external view returns (uint256) {
        return missionStarts[missionId].length;
    }

    /// -----------------------------------------------------------------------
    /// Helper Functions
    /// -----------------------------------------------------------------------

    function encode(address tokenAddress, uint256 tokenId, uint256 missionId, uint256 taskId)
        external
        pure
        returns (bytes memory)
    {
        if (taskId == 0) return abi.encode(tokenAddress, tokenId, missionId);
        else return abi.encode(tokenAddress, tokenId, missionId, taskId);
    }

    function decode(bytes calldata b)
        external
        pure
        returns (address tokenAddress, uint256 tokenId, uint256 missionId, uint256 taskId)
    {
        if (bytes(b).length == 128) {
            return abi.decode(b, (address, uint256, uint256, uint256));
        } else {
            (tokenAddress, tokenId, missionId) = abi.decode(b, (address, uint256, uint256));
            return (tokenAddress, tokenId, missionId, 0);
        }
    }

    /// @notice Calculate a percentage.
    /// @param numerator The numerator.
    /// @param denominator The denominator.
    /// @dev
    function calculateProgress(uint256 numerator, uint256 denominator) private pure returns (uint8) {
        return uint8(numerator * (10 ** 2) / denominator);
    }

    /// -----------------------------------------------------------------------
    /// Internal Functions
    /// -----------------------------------------------------------------------

    /// @notice Update, and finalize when appropriate, the Quest detail.
    /// @param tokenAddress .
    /// @param tokenId .
    /// @param missionId .
    /// @dev
    function updateQuestDetail(address tokenAddress, uint256 tokenId, uint256 missionId) internal {
        // Retrieve to update Mission reward
        (uint8 missionXp,,,,, address missionCreator,,, uint256 missionTaskCount) = mission.getMission(missionId);

        // Retrieve quest id and corresponding quest detail
        bytes memory questKey = this.encode(tokenAddress, tokenId, missionId, 0);
        QuestDetail memory qd = questDetail[questKey];

        // Calculate and udpate quest detail
        ++qd.completed;
        qd.progress = calculateProgress(qd.completed, missionTaskCount);

        // Store quest detail
        questDetail[questKey].completed = qd.completed;
        questDetail[questKey].progress = qd.progress;

        // Finalize quest
        if (qd.progress == 100) {
            // Toggle active status
            questDetail[questKey].active = false;

            // Reward Mission creator
            creatorRewards[missionCreator].earned += missionXp;

            // Add User to completion array
            missionCompeletions[missionId].push(msg.sender);
        }
    }

    /// @notice Distribute Task rewards.
    /// @param tokenAddress .
    /// @param tokenId .
    /// @param missionId .
    /// @param taskId .
    /// @dev
    function distributeTaskRewards(address tokenAddress, uint256 tokenId, uint256 missionId, uint256 taskId) internal {
        // Distribute creator rewards
        (uint8 taskXp,, address taskCreator,,) = mission.getTask(taskId);
        creatorRewards[taskCreator].earned += taskXp;

        // Distribute user rewards
        bytes memory questKey = this.encode(tokenAddress, tokenId, missionId, 0);
        rewards[questKey].earned += taskXp;
    }

    receive() external payable {}
}
