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
    bool review; // Indicates whether quest tasks require reviews.
    uint8 progress; // 0-100%.
    uint40 timestamp; // Temporary timestamp.
    uint40 timeLeft; // Time left to complete quest.
    uint40 completed; // Number of tasks completed in quest.
}

enum RewardType {
    DAO_ERC20, // default
    ERC20
}

struct QuestConfig {
    uint8 multiplier;
    address gateToken;
    uint256 gateAmount;
    RewardType rewardType;
    address rewardToken;
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

contract Quests is Directory {
    /// -----------------------------------------------------------------------
    /// Custom Errors
    /// -----------------------------------------------------------------------

    // error InvalidMission();

    error NotAuthorized();

    error InvalidUser();

    error NothingToClaim();

    error QuestInactive();

    error QuestInProgress();

    error InvalidResponse();

    error InvalidReview();

    error InvalidReward();

    error NeedMoreXp();

    /// -----------------------------------------------------------------------
    /// Quest Storage
    /// -----------------------------------------------------------------------

    address public admin;

    IMissions public missions;

    IDirectory public directory;

    // questKey => QuestDetail
    mapping(bytes => QuestDetail) public questDetail;

    // Status indicating if an address is a Manager
    // Account -> True/False
    mapping(address => bool) public isReviewer;

    // Reward per quest
    // questKey => Reward
    mapping(bytes => Reward) public rewards;

    // Reward type per Mission Id
    // Mission Id => QuestConfig
    mapping(uint256 => QuestConfig) public questConfigs;

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
        if (!isReviewer[msg.sender]) revert NotAuthorized();
        _;
    }

    modifier onlyAdmin() {
        if (admin != msg.sender) revert NotAuthorized();
        _;
    }

    modifier onlyHodler(address tokenAddress, uint256 tokenId) {
        if (IERC721(tokenAddress).ownerOf(tokenId) != msg.sender) revert InvalidUser();
        _;
    }

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    function initialize(IMissions _missions, IDirectory _directory, address _admin) public payable {
        missions = _missions;
        directory = _directory;
        admin = _admin;
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
    /// Review Functions
    /// -----------------------------------------------------------------------

    /// @notice Reviewer to submit review of task completion.
    /// @param tokenAddress .
    /// @param tokenId .
    /// @param missionId .
    /// @param taskId .
    /// @param review_ .
    /// @dev
    function review(address tokenAddress, uint256 tokenId, uint256 missionId, uint256 taskId, Review review_)
        external
        payable
        onlyReviewer
    {
        _review(tokenAddress, tokenId, missionId, taskId, review_);
    }

    function reviewBySig(
        address tokenAddress,
        uint256 tokenId,
        uint256 missionId,
        uint256 taskId,
        Review review_,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public payable virtual onlyReviewer {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01", DOMAIN_SEPARATOR(), keccak256(abi.encode(REVIEW_TYPEHASH, missionId, taskId, review_))
            )
        );

        address recoveredAddress = ecrecover(digest, v, r, s);
        if (recoveredAddress == address(0) || recoveredAddress != msg.sender) revert InvalidUser();

        _review(tokenAddress, tokenId, missionId, taskId, review_);
    }

    /// -----------------------------------------------------------------------
    /// Claim Rewards Functions
    /// -----------------------------------------------------------------------

    /// @notice User function to claim rewards.
    /// @dev
    function claimRewards(address tokenAddress, uint256 tokenId, uint256 missionId)
        external
        payable
        onlyHodler(tokenAddress, tokenId)
    {
        bytes memory questKey = this.encode(tokenAddress, tokenId, missionId, 0);
        Reward memory r = rewards[questKey];
        QuestConfig memory qc = questConfigs[missionId];

        if (r.earned > r.claimed) {
            if (qc.rewardType == RewardType.DAO_ERC20) {
                IKaliTokenManager(qc.rewardToken).mintShares(msg.sender, r.earned - r.claimed);
            } else {
                if (IERC20(qc.rewardToken).transferFrom(address(this), msg.sender, r.earned - r.claimed)) {
                    revert NothingToClaim();
                }
            }

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
        missions = _mission;
    }

    /// @notice Update reviewers
    /// @param reviewer The addresses to update managers to
    /// @dev
    function updateReviewer(address reviewer, bool status) external payable onlyAdmin {
        isReviewer[reviewer] = status;
    }

    function updateAdmin(address _admin) external payable onlyAdmin {
        admin = _admin;
    }

    function updateQuestReviewStatus(address tokenAddress, uint256 tokenId, uint256 missionId, bool __review)
        external
        payable
        onlyAdmin
    {
        bytes memory questKey = this.encode(tokenAddress, tokenId, missionId, 0);
        questDetail[questKey].review = __review;
    }

    function updateQuestConfigs(uint256 missionId, QuestConfig calldata _questConfig) external payable onlyAdmin {
        (, uint256 tasksCount) = missions.getMission(missionId);

        // Confirm Mission is questable
        if (tasksCount == 0) revert InvalidMission();

        if (_questConfig.rewardType == RewardType.DAO_ERC20) {
            questConfigs[missionId] = QuestConfig({
                multiplier: _questConfig.multiplier,
                gateToken: _questConfig.gateToken,
                gateAmount: _questConfig.gateAmount,
                rewardType: _questConfig.rewardType,
                rewardToken: admin
            });
        } else {
            // Confirm reward is supplied
            if (_questConfig.rewardToken == address(0)) revert InvalidReward();
            questConfigs[missionId] = QuestConfig({
                multiplier: _questConfig.multiplier,
                gateToken: _questConfig.gateToken,
                gateAmount: _questConfig.gateAmount,
                rewardType: _questConfig.rewardType,
                rewardToken: _questConfig.rewardToken
            });
        }
    }

    /// -----------------------------------------------------------------------
    /// Getter Functions
    /// -----------------------------------------------------------------------

    function getQuestDetail(address tokenAddress, uint256 tokenId, uint256 missionId)
        external
        view
        returns (QuestDetail memory)
    {
        bytes memory questKey = this.encode(tokenAddress, tokenId, missionId, 0);
        QuestDetail memory qd = questDetail[questKey];
        return qd;
    }

    function getQuestConfig(uint256 missionId) external view returns (QuestConfig memory) {
        QuestConfig memory qc = questConfigs[missionId];
        return qc;
    }

    /// -----------------------------------------------------------------------
    /// Helper Functions
    /// -----------------------------------------------------------------------

    function encode(address tokenAddress, uint256 tokenId, uint256 missionId, uint256 taskId)
        external
        pure
        returns (bytes32 memory)
    {
        // Retrieve questKey
        if (taskId == 0) return keccak256(abi.encodePacked(tokenAddress, tokenId, missions, missionId));
        // Retrieve taskKey
        else return keccak256(abi.encodePacked(tokenAddress, tokenId, missions, missionId, taskId));
    }

    // function decode(bytes calldata b)
    //     external
    //     pure
    //     returns (address tokenAddress, uint256 tokenId, address _missions, uint256 missionId, uint256 taskId)
    // {
    //     if (bytes(b).length == 322) {
    //         // Decode taskKey
    //         return abi.decode(b, (address, uint256, address, uint256, uint256));
    //     } else {
    //         // Decode questKey
    //         (tokenAddress, tokenId, _missions, missionId) = abi.decode(b, (address, uint256, address, uint256));
    //         return (tokenAddress, tokenId, _missions, missionId, 0);
    //     }
    // }

    /// @notice Calculate a percentage.
    /// @param numerator The numerator.
    /// @param denominator The denominator.
    /// @dev
    function calculateProgress(uint256 numerator, uint256 denominator) private pure returns (uint8) {
        return uint8(numerator * (10 ** 2) / denominator);
    }

    /// -----------------------------------------------------------------------
    /// Quest Internal Functions
    /// -----------------------------------------------------------------------

    /// @notice Update, and finalize when appropriate, the Quest detail.
    /// @param questKey .
    /// @param missionId .
    /// @dev
    function updateQuestDetail(bytes memory questKey, uint256 missionId) internal {
        // Retrieve to update Mission reward
        (, uint256 tasksCount) = missions.getMission(missionId);

        // Retrieve quest detail
        QuestDetail memory qd = questDetail[questKey];

        // Calculate and udpate quest detail
        ++qd.completed;
        qd.progress = calculateProgress(qd.completed, tasksCount);

        // Store quest detail
        questDetail[questKey].completed = qd.completed;
        questDetail[questKey].progress = qd.progress;

        // Finalize quest
        if (qd.progress == 100) {
            // Toggle active status
            questDetail[questKey].active = false;
            questDetail[questKey].timeLeft = 0;

            // Add user to completion array
            // directory.listAccount(ListType.MISSION_COMPLETE, missionId, msg.sender, true);
        }
    }

    /// @notice Distribute Task reward.
    /// @param questKey .
    /// @param taskId .
    /// @dev
    function distributeTaskRewards(bytes memory questKey, uint256 taskId) internal {
        Task memory t = missions.getTask(taskId);
        rewards[questKey].earned += t.xp;
    }

    /// @notice Traveler to pause an active Quest.
    /// @param timestamp .
    /// @param questKey .
    /// @dev
    function hasQuestExpired(uint40 timestamp, uint40 timeLeft, bytes memory questKey) internal returns (uint40) {
        uint40 lapse = uint40(block.timestamp) - timestamp;
        if (timestamp < lapse) {
            delete questDetail[questKey];
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
        (Mission memory _mission, uint256 mLength) = missions.getMission(missionId);

        // Confirm Mission is questable
        if (mLength == 0) revert InvalidMission();

        // Confirm user has sufficient xp to quest Misson
        QuestConfig memory rc = questConfigs[missionId];
        if (rc.rewardToken == address(0)) revert InvalidMission();
        if (rc.gateToken != address(0) && IERC20(rc.gateToken).balanceOf(msg.sender) <= rc.gateAmount) {
            revert NeedMoreXp();
        }

        // Retrieve quest id and corresponding quest detail
        bytes memory questKey = this.encode(tokenAddress, tokenId, missionId, 0);
        QuestDetail memory qd = questDetail[questKey];

        // Confirm Quest is not already in progress
        if (qd.active) revert QuestInProgress();

        // Check if quest was previously paused.
        if (qd.timeLeft > 0) {
            // Update quest detail
            questDetail[questKey].active = true;
            questDetail[questKey].timestamp = uint40(block.timestamp);
        } else {
            // Calculate Task duration in aggregate
            (, uint40 duration) = missions.aggregateTasksData(_mission.taskIds);

            // Initialize quest detail.
            questDetail[questKey].active = true;
            questDetail[questKey].timestamp = uint40(block.timestamp);
            questDetail[questKey].timeLeft = duration;

            // Add user to start array
            // directory.listAccount(ListType.MISSION_START, missionId, msg.sender, true);
        }
    }

    /// @notice Internal function using signature to pause quest.
    /// @param tokenAddress .
    /// @param tokenId .
    /// @param missionId .
    /// @dev
    function _pause(address tokenAddress, uint256 tokenId, uint256 missionId) internal virtual {
        // Retrieve quest id and corresponding quest detail.
        bytes memory questKey = this.encode(tokenAddress, tokenId, missionId, 0);
        QuestDetail memory qd = questDetail[questKey];

        // Confirm Quest is active.
        if (!qd.active) revert QuestInactive();

        uint40 timeLeft = hasQuestExpired(qd.timestamp, qd.timeLeft, questKey);

        if (timeLeft > 0) {
            questDetail[questKey] = QuestDetail({
                active: false,
                review: qd.review,
                timestamp: 0,
                timeLeft: timeLeft,
                completed: qd.completed,
                progress: qd.progress
            });
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
        // Retrieve quest id and corresponding quest detail
        bytes memory questKey = this.encode(tokenAddress, tokenId, missionId, 0);
        QuestDetail memory qd = questDetail[questKey];

        // Confirm Quest is active
        if (!qd.active) revert QuestInactive();

        // Confirm Task is part of Mission
        if (!missions.isTaskInMission(missionId, taskId)) revert InvalidMission();

        // Add response to Task
        bytes memory taskKey = this.encode(tokenAddress, tokenId, missionId, taskId);

        // TODO:
        // 1. Add respond in _response only when boolStorage[missionId.review] is true
        // 2. Set boolStorage[missionId.review] to false after respond is added
        // 3. Set boolStorage[missionId.review] to true after review is positively added

        uint256 responsesLength = responses[taskKey].length;
        uint256 reviewsLength = reviews[taskKey].length;

        if (responsesLength == reviewsLength && bytes(response).length != 0) {
            responses[taskKey].push(response);
        }

        if (!qd.review) {
            responses[taskKey].push(response);
            distributeTaskRewards(questKey, taskId);
            updateQuestDetail(questKey, missionId);
        } else if (responsesLength == reviewsLength && bytes(response).length != 0) {
            responses[taskKey].push(response);
        }
    }

    /// @notice Internal function using signature to review quest tasks.
    /// @param tokenAddress .
    /// @param tokenId .
    /// @param missionId .
    /// @param taskId .
    /// @param review_ .
    /// @dev
    function _review(address tokenAddress, uint256 tokenId, uint256 missionId, uint256 taskId, Review review_)
        internal
        virtual
    {
        // Confirm Reviewer has submitted valid review data
        if (review_ == Review.NA) revert InvalidReview();

        // Retrieve quest id and corresponding quest detail
        bytes memory questKey = this.encode(tokenAddress, tokenId, missionId, 0);
        QuestDetail memory qd = questDetail[questKey];
        if (!qd.review) revert InvalidReview();

        bytes memory taskKey = this.encode(tokenAddress, tokenId, missionId, taskId);
        reviews[taskKey].push(review_);

        // Update quest detail
        if (review_ == Review.PASS) {
            distributeTaskRewards(questKey, taskId);
            updateQuestDetail(questKey, missionId);
        }
    }

    receive() external payable {}
}
