// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {IMissions, Mission} from "./interface/IMissions.sol";
import {IERC721} from "forge-std/interfaces/IERC721.sol";
import {IKaliTokenManager} from "./interface/IKaliTokenManager.sol";

/// @title  Quests
/// @notice RPG for NFTs.
/// @author audsssy.eth

struct QuestDetail {
    bool active; // Indicates whether a quest is active.
    bool review; // Indicates whether quest tasks require reviews.
    uint8 progress; // 0-100%.
    uint16 nonce; // Number of times a user activated quest.
    uint40 timestamp; // Timestamp to calculate.
    uint40 timeLeft; // Time left to complete quest.
    uint40 completed; // Number of tasks completed in quest.
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

    // Status indicating if an address is a Manager
    // Account -> True/False
    mapping(address => bool) public isReviewer;

    // questKey => Reward
    mapping(bytes => Reward) public rewards;

    // Tally xp per creator
    // Tasks & Missions creators => Reward
    mapping(address => Reward) public creatorRewards;

    // Users per Mission Id
    // Mission Id => Users
    mapping(uint256 => address[]) public missionStarts;

    // Traveler completions by Mission Id
    // Mission Id => Users
    mapping(uint256 => address[]) public missionCompeletions;

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

    constructor(IMissions _mission, address payable _admin) {
        mission = _mission;
        admin = _admin;

        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = _computeDomainSeparator();
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
            distributeTaskRewards(tokenAddress, tokenId, missionId, taskId);
            updateQuestDetail(tokenAddress, tokenId, missionId);
        }
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
        Reward memory cr = creatorRewards[msg.sender];

        if (cr.earned > cr.claimed) {
            IKaliTokenManager(admin).mintShares(msg.sender, cr.earned - cr.claimed);
            cr.claimed = cr.earned;
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
        returns (QuestDetail memory)
    {
        bytes memory questKey = this.encode(tokenAddress, tokenId, missionId, 0);
        QuestDetail memory qd = questDetail[questKey];
        return qd;
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
    /// Quest Internal Functions
    /// -----------------------------------------------------------------------

    /// @notice Update, and finalize when appropriate, the Quest detail.
    /// @param tokenAddress .
    /// @param tokenId .
    /// @param missionId .
    /// @dev
    function updateQuestDetail(address tokenAddress, uint256 tokenId, uint256 missionId) internal {
        // Retrieve to update Mission reward
        (Mission memory m, uint256 tasksCount) = mission.getMission(missionId);

        // Retrieve quest id and corresponding quest detail
        bytes memory questKey = this.encode(tokenAddress, tokenId, missionId, 0);
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

            // Reward Mission creator
            creatorRewards[m.creator].earned += m.xp;

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

    /// @notice Traveler to pause an active Quest.
    /// @param timestamp .
    /// @param questKey .
    /// @dev
    function hasQuestExpired(uint40 timestamp, bytes memory questKey) internal returns (uint40) {
        uint40 lapse = uint40(block.timestamp) - timestamp;
        if (timestamp < lapse) {
            delete questDetail[questKey];
            return 0;
        }

        return lapse;
    }

    /// -----------------------------------------------------------------------
    /// EIP-2612 Internal Functions
    /// -----------------------------------------------------------------------

    /// @notice Internal function using signature to start quest.
    /// @param tokenAddress .
    /// @param tokenId .
    /// @param missionId .
    /// @dev
    function _start(address tokenAddress, uint256 tokenId, uint256 missionId) internal virtual {
        (Mission memory m,) = mission.getMission(missionId);

        // Confirm Mission is questable
        if (m.duration == 0) revert InvalidMission();

        // Confirm Traveler has sufficient xp to quest Misson
        if (IKaliTokenManager(admin).balanceOf(msg.sender) < m.requiredXp) revert NeedMoreXp();

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
            // Initialize quest detail.
            // By default, no review is required.
            questDetail[questKey].active = true;
            questDetail[questKey].nonce = ++qd.nonce;
            questDetail[questKey].timestamp = uint40(block.timestamp);
            questDetail[questKey].timeLeft = m.duration;

            missionStarts[missionId].push(msg.sender);
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

        uint40 timeLeft = hasQuestExpired(qd.timestamp, questKey);

        if (timeLeft > 0) {
            questDetail[questKey] = QuestDetail({
                active: false,
                review: qd.review,
                nonce: qd.nonce,
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
        if (!mission.isTaskInMission(missionId, uint8(taskId))) revert InvalidMission();

        // Add response to Task
        bytes memory taskKey = this.encode(tokenAddress, tokenId, missionId, taskId);
        uint256 responsesLength = responses[taskKey].length;
        uint256 reviewsLength = reviews[taskKey].length;

        if (responsesLength == reviewsLength && bytes(response).length != 0) {
            responses[taskKey].push(response);
        }

        if (!qd.review) {
            responses[taskKey].push(response);
            distributeTaskRewards(tokenAddress, tokenId, missionId, taskId);
            updateQuestDetail(tokenAddress, tokenId, missionId);
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
            distributeTaskRewards(tokenAddress, tokenId, missionId, taskId);
            updateQuestDetail(tokenAddress, tokenId, missionId);
        }
    }

    receive() external payable {}
}
