// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {IMissions, Mission, Task} from "./interface/IMissions.sol";
import {Directory} from "./Directory.sol";
import {IDirectory} from "./interface/IDirectory.sol";
import {IERC721} from "forge-std/interfaces/IERC721.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IKaliTokenManager} from "./interface/IKaliTokenManager.sol";

/// @title  Quests
/// @notice RPG for NFTs.
/// @author audsssy.eth

struct QuestDetail {
    bool active; // Indicates whether a quest is active.
    bool reviewStatus; // Indicates whether quest tasks require reviews.
    uint8 progress; // 0-100%.
    uint40 timestamp; // Temporary timestamp.
    uint40 timeLeft; // Time left to complete quest.
    uint40 completed; // Number of tasks completed in quest.
}

struct Reward {
    uint256 multiplier;
    address gateToken;
    uint256 gateAmount;
    address rewardToken;
}

struct RewardBalance {
    uint256 earned; // Reward earned from quests
    uint256 claimed; // Reward claimed to date
}

contract Quests is Directory {
    /// -----------------------------------------------------------------------
    /// Custom Errors
    /// -----------------------------------------------------------------------

    error InvalidUser();

    error NothingToClaim();

    error QuestInactive();

    error QuestInProgress();

    error InvalidReview();

    error InvalidReviewer();

    error InvalidReward();

    error NeedMoreXp();

    /// -----------------------------------------------------------------------
    /// Sign Storage
    /// -----------------------------------------------------------------------

    bytes32 public constant START_TYPEHASH = keccak256("Start(address signer, uint256 missionId)");
    bytes32 public constant PAUSE_TYPEHASH = keccak256("Pause(address signer, uint256 missionId)");
    bytes32 public constant RESPOND_TYPEHASH =
        keccak256("Respond(address signer, uint256 missionId, uint256 taskId, string response)");
    bytes32 public constant REVIEW_TYPEHASH = keccak256("Review(uint256 missionId, uint256 taskId, string review)");

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
                keccak256(bytes("Quests")),
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

    modifier onlyHodler(address tokenAddress, uint256 tokenId) {
        if (IERC721(tokenAddress).ownerOf(tokenId) != msg.sender) revert InvalidUser();
        _;
    }

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    function initialize(address missions) public payable {
        // Store address of missions contract
        this.setAddress(keccak256(abi.encodePacked("missions")), missions);

        // Store address of quests contract
        this.setAddress(keccak256(abi.encodePacked("quests")), address(this));
    }

    /// -----------------------------------------------------------------------
    /// Quest Logic
    /// -----------------------------------------------------------------------

    /// @notice Traveler to pause an active Quest.
    /// @param tokenAddress .
    /// @param tokenId .
    /// @param missionId .
    /// @dev
    function start(address tokenAddress, uint256 tokenId, uint256 missionId)
        external
        payable
        onlyHodler(tokenAddress, tokenId)
    {
        _start(tokenAddress, tokenId, missionId);
    }

    /// @notice Traveler to start a new Quest.
    /// @param tokenAddress .
    /// @param tokenId .
    /// @param missionId .
    /// @dev
    function startBySig(
        address signer,
        address tokenAddress,
        uint256 tokenId,
        uint256 missionId,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public payable virtual onlyHodler(tokenAddress, tokenId) {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(abi.encode(START_TYPEHASH, signer, tokenAddress, tokenId, missionId))
            )
        );

        address recoveredAddress = ecrecover(digest, v, r, s);
        if (recoveredAddress == address(0) || recoveredAddress != signer) revert InvalidUser();

        _start(tokenAddress, tokenId, missionId);
    }

    /// @notice Traveler to pause an active Quest.
    /// @param tokenAddress .
    /// @param tokenId .
    /// @param missionId .
    /// @dev
    function pause(address tokenAddress, uint256 tokenId, uint256 missionId)
        external
        payable
        onlyHodler(tokenAddress, tokenId)
    {
        _pause(tokenAddress, tokenId, missionId);
    }

    function pauseBySig(
        address signer,
        address tokenAddress,
        uint256 tokenId,
        uint256 missionId,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public payable virtual onlyHodler(tokenAddress, tokenId) {
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR(), keccak256(abi.encode(PAUSE_TYPEHASH, signer, missionId)))
        );

        address recoveredAddress = ecrecover(digest, v, r, s);
        if (recoveredAddress == address(0) || recoveredAddress != signer) revert InvalidUser();

        _pause(tokenAddress, tokenId, missionId);
    }

    /// @notice Traveler to submit Homework for Task completion.
    /// @param tokenAddress .
    /// @param tokenId .
    /// @param missionId .
    /// @param taskId .
    /// @param response .
    /// @dev
    function respond(address tokenAddress, uint256 tokenId, uint256 missionId, uint256 taskId, string calldata response)
        external
        payable
        onlyHodler(tokenAddress, tokenId)
    {
        _respond(tokenAddress, tokenId, missionId, taskId, response);
    }

    function respondBySig(
        address signer,
        address tokenAddress,
        uint256 tokenId,
        uint256 missionId,
        uint256 taskId,
        string calldata response,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public payable virtual onlyHodler(tokenAddress, tokenId) {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(abi.encode(RESPOND_TYPEHASH, signer, missionId, tokenId, response))
            )
        );

        address recoveredAddress = ecrecover(digest, v, r, s);
        if (recoveredAddress == address(0) || recoveredAddress != signer) revert InvalidUser();

        _respond(tokenAddress, tokenId, missionId, taskId, response);
    }

    /// -----------------------------------------------------------------------
    /// Review Logic
    /// -----------------------------------------------------------------------

    /// @notice Reviewer to submit review of task completion.
    /// @param tokenAddress .
    /// @param tokenId .
    /// @param missionId .
    /// @param taskId .
    /// @param reviewResult .
    /// @dev
    function review(address tokenAddress, uint256 tokenId, uint256 missionId, uint256 taskId, bool reviewResult)
        external
        payable
        onlyReviewer
    {
        _review(tokenAddress, tokenId, missionId, taskId, reviewResult);
    }

    function reviewBySig(
        address tokenAddress,
        uint256 tokenId,
        uint256 missionId,
        uint256 taskId,
        bool reviewResult,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public payable virtual onlyReviewer {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01", DOMAIN_SEPARATOR(), keccak256(abi.encode(REVIEW_TYPEHASH, missionId, taskId, reviewResult))
            )
        );

        address recoveredAddress = ecrecover(digest, v, r, s);
        if (recoveredAddress == address(0) || recoveredAddress != msg.sender) revert InvalidUser();

        _review(tokenAddress, tokenId, missionId, taskId, reviewResult);
    }

    /// -----------------------------------------------------------------------
    /// Claim Reward Logic
    /// -----------------------------------------------------------------------

    /// @notice User function to claim Reward.
    /// @dev
    function claimReward(address tokenAddress, uint256 tokenId, uint256 missionId)
        external
        payable
        onlyHodler(tokenAddress, tokenId)
    {
        bytes32 questKey = this.encode(tokenAddress, tokenId, missionId, 0);
        RewardBalance memory r = this.getRewardBalance(questKey);
        Reward memory reward = this.getRewards(missionId);

        if (r.earned > r.claimed) {
            if (reward.rewardToken == dao) {
                IKaliTokenManager(reward.rewardToken).mintShares(msg.sender, (r.earned - r.claimed) * reward.multiplier);
            } else {
                if (
                    !IERC20(reward.rewardToken).transferFrom(
                        address(this), msg.sender, (r.earned - r.claimed) * reward.multiplier
                    )
                ) {
                    revert NothingToClaim();
                }
            }

            r.claimed = r.earned;
        } else {
            revert NothingToClaim();
        }
    }

    /// -----------------------------------------------------------------------
    /// DAO Logic
    /// -----------------------------------------------------------------------

    /// @notice Update contracts.
    /// @param missions Contract address of Missions.sol.
    /// @dev
    function setMissionsContract(address missions) external payable onlyPlaygroundOperators {
        this.setAddress(keccak256(abi.encodePacked("missions")), missions);
    }

    /// @notice Update reviewers
    /// @param reviewer The addresses to update managers to
    /// @dev
    function setReviewer(address reviewer, bool status) external payable onlyPlaygroundOperators {
        // Increment and store global number of reviewers.
        uint256 reviewerId = this.getUint(keccak256(abi.encodePacked("quests.reviewerCount")));
        this.setUint(keccak256(abi.encodePacked("quests.reviewerCount")), ++reviewerId);

        if (status) {
            // Store new reviewer status and id
            this.setBool(keccak256(abi.encodePacked(reviewer, ".exists")), status);
            this.setUint(keccak256(abi.encodePacked(reviewer, ".reviewerId")), reviewerId);
        } else {
            // Delete reviewer status and id.
            this.deleteBool(keccak256(abi.encodePacked(reviewer, ".exists")));
            this.deleteUint(keccak256(abi.encodePacked(reviewer, ".reviewerId")));
        }
    }

    /// @notice Set review status for one specific quest based on questKey
    function setReviewStatus(address tokenAddress, uint256 tokenId, uint256 missionId, bool reviewStatus)
        external
        payable
        onlyPlaygroundOperators
    {
        bytes32 questKey = this.encode(tokenAddress, tokenId, missionId, 0);
        this.setBool(keccak256(abi.encodePacked(questKey, ".detail.review")), reviewStatus);
    }

    /// @notice Set review status for all quests
    function setGlobalReviewStatus(bool reviewStatus) external payable onlyPlaygroundOperators {
        this.setBool(keccak256(abi.encodePacked("quests.reviewStatus")), reviewStatus);
    }

    function setReward(uint256 missionId, Reward calldata _reward) external payable onlyPlaygroundOperators {
        // Confirm Mission is questable
        (, uint256 tasksCount) = IMissions(this.getMissionsAddress()).getMission(missionId);
        if (tasksCount == 0) revert InvalidMission();

        _setReward(missionId, _reward);
    }

    /// -----------------------------------------------------------------------
    /// Getter Logic
    /// -----------------------------------------------------------------------

    function getMissionsAddress() external view returns (address) {
        return this.getAddress(keccak256(abi.encodePacked("missions")));
    }

    function getQuestDetail(bytes32 questKey) external view returns (QuestDetail memory) {
        return QuestDetail({
            active: this.getBool(keccak256(abi.encodePacked(questKey, ".detail.active"))),
            reviewStatus: this.getBool(keccak256(abi.encodePacked(questKey, ".detail.reviewStatus"))),
            progress: uint8(this.getUint(keccak256(abi.encodePacked(questKey, ".detail.progress")))),
            timestamp: uint40(this.getUint(keccak256(abi.encodePacked(questKey, ".detail.timestamp")))),
            timeLeft: uint40(this.getUint(keccak256(abi.encodePacked(questKey, ".detail.timeLeft")))),
            completed: uint40(this.getUint(keccak256(abi.encodePacked(questKey, ".detail.completed"))))
        });
    }

    function getRewards(uint256 missionId) external view returns (Reward memory) {
        address missions = this.getMissionsAddress();

        return Reward({
            multiplier: this.getUint(keccak256(abi.encodePacked(missions, missionId, ".reward.multiplier"))),
            gateToken: this.getAddress(keccak256(abi.encodePacked(missions, missionId, ".reward.gateToken"))),
            gateAmount: this.getUint(keccak256(abi.encodePacked(missions, missionId, ".reward.gateAmount"))),
            rewardToken: this.getAddress(keccak256(abi.encodePacked(missions, missionId, ".reward.rewardToken")))
        });
    }

    function getRewardBalance(bytes32 questKey) external view returns (RewardBalance memory) {
        return RewardBalance({
            earned: this.getUint(keccak256(abi.encodePacked(questKey, ".reward.earned"))),
            claimed: this.getUint(keccak256(abi.encodePacked(questKey, ".reward.claimed")))
        });
    }

    function isReviewer(address account) external view returns (bool) {
        return this.getBool(keccak256(abi.encodePacked(account, ".exists")));
    }

    /// -----------------------------------------------------------------------
    /// Helper Logic
    /// -----------------------------------------------------------------------

    function encode(address tokenAddress, uint256 tokenId, uint256 missionId, uint256 taskId)
        external
        view
        returns (bytes32)
    {
        address missions = this.getMissionsAddress();

        // Retrieve questKey
        if (taskId == 0) return keccak256(abi.encodePacked(tokenAddress, tokenId, missions, missionId));
        // Retrieve taskKey
        else return keccak256(abi.encodePacked(tokenAddress, tokenId, missions, missionId, taskId));
    }

    /// @notice Calculate a percentage.
    /// @param numerator The numerator.
    /// @param denominator The denominator.
    /// @dev
    function calculateProgress(uint256 numerator, uint256 denominator) private pure returns (uint8) {
        return uint8(numerator * (10 ** 2) / denominator);
    }

    /// -----------------------------------------------------------------------
    /// Quest Internal Logic
    /// -----------------------------------------------------------------------

    /// @notice Update, and finalize when appropriate, the Quest detail.
    /// @param questKey .
    /// @param missionId .
    /// @dev
    function updateQuestDetail(bytes32 questKey, uint256 missionId) internal {
        address missions = this.getMissionsAddress();

        // Retrieve to update Mission reward
        (, uint256 tasksCount) = IMissions(missions).getMission(missionId);

        // Retrieve quest detail
        QuestDetail memory qd = this.getQuestDetail(questKey);

        // Calculate and udpate quest detail
        ++qd.completed;
        qd.progress = calculateProgress(qd.completed, tasksCount);

        // Store quest detail
        this.setUint(keccak256(abi.encodePacked(questKey, ".detail.progress")), qd.progress);
        this.setUint(keccak256(abi.encodePacked(questKey, ".detail.completed")), qd.completed);

        // Finalize quest
        if (qd.progress == 100) {
            this.deleteBool(keccak256(abi.encodePacked(questKey, ".detail.active")));
            this.deleteUint(keccak256(abi.encodePacked(questKey, ".detail.timeLeft")));

            // Retrieve, increment, and store number of mission completions.
            uint256 count = this.getUint(keccak256(abi.encodePacked(missions, missionId, ".completions")));
            this.setUint(keccak256(abi.encodePacked(missions, missionId, ".completions")), ++count);

            // Retrieve, increment, and store number of mission starts per user.
            uint256 userStarts = this.getUint(keccak256(abi.encodePacked(questKey, ".stats.completions")));
            this.setUint(keccak256(abi.encodePacked(questKey, ".stats.completions")), ++userStarts);
        }
    }

    /// @notice Distribute Task reward.
    /// @param questKey .
    /// @param taskId .
    /// @dev
    function distributeTaskReward(bytes32 questKey, uint256 taskId) internal {
        address missions = this.getMissionsAddress();

        Task memory t = IMissions(missions).getTask(taskId);

        // Retrieve, increment by task xp, and store earned xp per user quest.
        uint256 earned = this.getUint(keccak256(abi.encodePacked(questKey, ".reward.earned")));
        this.setUint(keccak256(abi.encodePacked(questKey, ".reward.earned")), earned + t.xp);
    }

    /// @notice Traveler to pause an active Quest.
    /// @param timestamp .
    /// @param timeLeft .
    /// @dev
    function calculateTimeLeft(uint40 timestamp, uint40 timeLeft) internal view returns (uint40) {
        uint40 lapse = uint40(block.timestamp) - timestamp;
        if (timestamp < lapse) {
            return 0;
        }

        return timeLeft - lapse;
    }

    /// @notice Internal function using signature to start quest.
    /// @param tokenAddress .
    /// @param tokenId .
    /// @param missionId .
    /// @dev
    function _start(address tokenAddress, uint256 tokenId, uint256 missionId) internal virtual {
        address missions = this.getMissionsAddress();
        (Mission memory _mission, uint256 mLength) = IMissions(missions).getMission(missionId);

        // Confirm Mission is questable
        if (mLength == 0) revert InvalidMission();

        // Confirm user has sufficient xp to quest Misson
        Reward memory reward = this.getRewards(missionId);
        if (reward.rewardToken == address(0)) revert InvalidMission();
        if (reward.gateToken != address(0) && IERC20(reward.gateToken).balanceOf(msg.sender) <= reward.gateAmount) {
            revert NeedMoreXp();
        }

        // Retrieve quest key and corresponding quest detail
        bytes32 questKey = this.encode(tokenAddress, tokenId, missionId, 0);
        QuestDetail memory qd = this.getQuestDetail(questKey);

        // Confirm Quest is not already in progress
        if (qd.active) revert QuestInProgress();

        // Check if quest was previously paused.
        if (qd.timeLeft > 0) {
            // Update quest detail
            this.setBool(keccak256(abi.encodePacked(questKey, ".detail.active")), true);
            this.setUint(keccak256(abi.encodePacked(questKey, ".detail.timestamp")), uint40(block.timestamp));
        } else {
            // Calculate Task duration in aggregate
            (, uint40 duration) = IMissions(missions).aggregateTasksData(_mission.taskIds);

            // Initialize quest detail.
            this.setBool(keccak256(abi.encodePacked(questKey, ".detail.active")), true);
            this.setUint(keccak256(abi.encodePacked(questKey, ".detail.timestamp")), uint40(block.timestamp));
            this.setUint(keccak256(abi.encodePacked(questKey, ".detail.timeLeft")), duration);

            // Retrieve, increment, and store number of mission starts.
            uint256 missionStarts = this.getUint(keccak256(abi.encodePacked(missions, missionId, ".starts")));
            this.setUint(keccak256(abi.encodePacked(missions, missionId, ".starts")), ++missionStarts);

            // Retrieve, increment, and store number of mission starts per user.
            uint256 userStarts = this.getUint(keccak256(abi.encodePacked(questKey, ".stats.starts")));
            this.setUint(keccak256(abi.encodePacked(questKey, ".stats.starts")), ++userStarts);
        }
    }

    /// @notice Internal function using signature to pause quest.
    /// @param tokenAddress .
    /// @param tokenId .
    /// @param missionId .
    /// @dev
    function _pause(address tokenAddress, uint256 tokenId, uint256 missionId) internal virtual {
        // Retrieve quest id and corresponding quest detail.
        bytes32 questKey = this.encode(tokenAddress, tokenId, missionId, 0);
        QuestDetail memory qd = this.getQuestDetail(questKey);

        // Confirm Quest is active.
        if (!qd.active) revert QuestInactive();

        uint40 timeLeft = calculateTimeLeft(qd.timestamp, qd.timeLeft);

        if (timeLeft > 0) {
            this.deleteBool(keccak256(abi.encodePacked(questKey, ".detail.active")));
            this.deleteUint(keccak256(abi.encodePacked(questKey, ".detail.timestamp")));
            this.setUint(keccak256(abi.encodePacked(questKey, ".detail.timeLeft")), timeLeft);
        }
    }

    /// @notice Internal function using signature to respond to quest tasks.
    /// @param tokenAddress .
    /// @param tokenId .
    /// @param missionId .
    /// @param taskId .
    /// @param response .
    /// @dev
    function _respond(
        address tokenAddress,
        uint256 tokenId,
        uint256 missionId,
        uint256 taskId,
        string calldata response
    ) internal virtual {
        address missions = this.getMissionsAddress();

        // Retrieve questKey and corresponding QuestDetail.
        bytes32 questKey = this.encode(tokenAddress, tokenId, missionId, 0);
        QuestDetail memory qd = this.getQuestDetail(questKey);

        // Retrieve taskKey.
        bytes32 taskKey = this.encode(tokenAddress, tokenId, missionId, taskId);

        // Confirm Quest is active.
        if (!qd.active) revert QuestInactive();

        // Confirm Task is part of Mission.
        if (!IMissions(missions).isTaskInMission(missionId, taskId)) revert InvalidMission();

        // Store quest task responses.
        this.setString(keccak256(abi.encodePacked(taskKey, ".review.response")), response);

        // Retrieve, increment, and store number of responses for the task..
        uint256 count = this.getUint(keccak256(abi.encodePacked(taskKey, ".review.responseCount")));
        this.setUint(keccak256(abi.encodePacked(taskKey, ".review.responseCount")), ++count);

        // Check if quest completions require review.
        if (!qd.reviewStatus) {
            distributeTaskReward(questKey, taskId);
            updateQuestDetail(questKey, missionId);
        }
    }

    /// @notice Internal function using signature to review quest tasks.
    /// @param tokenAddress .
    /// @param tokenId .
    /// @param missionId .
    /// @param taskId .
    /// @param reviewResult .
    /// @dev
    function _review(address tokenAddress, uint256 tokenId, uint256 missionId, uint256 taskId, bool reviewResult)
        internal
    {
        // Retrieve quest id and corresponding quest detail
        bytes32 questKey = this.encode(tokenAddress, tokenId, missionId, 0);
        bytes32 taskKey = this.encode(tokenAddress, tokenId, missionId, taskId);
        QuestDetail memory qd = this.getQuestDetail(questKey);
        if (!qd.reviewStatus) revert InvalidReview();

        if (!reviewResult) {
            // Store review result
            this.setBool(keccak256(abi.encodePacked(taskKey, ".review.result")), reviewResult);
        } else {
            // Store review result
            this.setBool(keccak256(abi.encodePacked(taskKey, ".review.result")), reviewResult);

            // Increment reward by task xp
            distributeTaskReward(questKey, taskId);

            // Update quest detail
            updateQuestDetail(questKey, missionId);
        }
    }

    function _setReward(uint256 missionId, Reward calldata _reward) internal {
        address missions = this.getMissionsAddress();

        if (_reward.rewardToken == dao) {
            this.setUint(keccak256(abi.encodePacked(missions, missionId, ".reward.multiplier")), _reward.multiplier);
            this.setAddress(keccak256(abi.encodePacked(missions, missionId, ".reward.gateToken")), _reward.gateToken);
            this.setUint(keccak256(abi.encodePacked(missions, missionId, ".reward.gateAmount")), _reward.gateAmount);
            this.setAddress(keccak256(abi.encodePacked(missions, missionId, ".reward.rewardToken")), dao);
        } else {
            // Confirm reward is supplied
            if (_reward.rewardToken == address(0)) revert InvalidReward();

            this.setUint(keccak256(abi.encodePacked(missions, missionId, ".reward.multiplier")), _reward.multiplier);
            this.setAddress(keccak256(abi.encodePacked(missions, missionId, ".reward.gateToken")), _reward.gateToken);
            this.setUint(keccak256(abi.encodePacked(missions, missionId, ".reward.gateAmount")), _reward.gateAmount);
            this.setAddress(
                keccak256(abi.encodePacked(missions, missionId, ".reward.rewardToken")), _reward.rewardToken
            );
        }
    }

    receive() external payable {}
}
