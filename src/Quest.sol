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
/// @notice RPG for NFTs.
/// @author audsssy.eth

struct QuestDetail {
    bool active; // Indicates whether a quest is active.
    bool toReview; // Indicates whether quest tasks require reviews.
    uint8 progress; // 0-100%.
    uint40 deadline; // Time left to complete quest.
    uint40 completed; // Number of tasks completed in quest.
}

struct QuestConfig {
    address gateToken;
    uint256 gateTokenAmount;
    address rewardToken;
}

contract Quest is Storage {
    /// -----------------------------------------------------------------------
    /// Custom Errors
    /// -----------------------------------------------------------------------

    error InvalidDao();

    error InvalidUser();

    error NothingToClaim();

    error QuestInactive();

    error QuestInProgress();

    error InvalidReview();

    error InvalidReviewer();

    error NeedMoreTokens();

    error InvalidMission();

    error Cooldown();

    /// -----------------------------------------------------------------------
    /// Immutable Storage
    /// -----------------------------------------------------------------------

    bytes32 immutable MISSIONS_ADDRESS_KEY = keccak256(abi.encodePacked("missions"));

    /// -----------------------------------------------------------------------
    /// Sign Storage
    /// -----------------------------------------------------------------------

    bytes32 public constant START_TYPEHASH = keccak256("Start(address signer, bytes32 questKey)");
    bytes32 public constant RESPOND_TYPEHASH = keccak256(
        "Respond(address signer, address missions, uint256 missionId, uint256 taskId, string response, uint256 metricValue)"
    );
    bytes32 public constant REVIEW_TYPEHASH =
        keccak256("Review(address missions, uint256 missionId, uint256 taskId, string review)");

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

    constructor() {}

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
    /// Quest Logic
    /// -----------------------------------------------------------------------

    /// @notice Traveler to pause an active Quest.
    /// @param tokenAddress .
    /// @param tokenId .
    /// @param missionId .
    /// @dev
    function start(address tokenAddress, uint256 tokenId, address missions, uint256 missionId)
        external
        payable
        onlyHodler(tokenAddress, tokenId)
    {
        bytes32 questKey = this.encode(tokenAddress, tokenId, missions, missionId, 0);
        _start(questKey, missions, missionId);
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
        address missions,
        uint256 missionId,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public payable virtual onlyHodler(tokenAddress, tokenId) {
        bytes32 questKey = this.encode(tokenAddress, tokenId, missions, missionId, 0);
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR(), keccak256(abi.encode(START_TYPEHASH, signer, questKey)))
        );

        address recoveredAddress = ecrecover(digest, v, r, s);
        if (recoveredAddress == address(0) || recoveredAddress != signer) revert InvalidUser();

        _start(questKey, missions, missionId);
    }

    /// @notice Traveler to respond to Task in order to progress Quest.
    /// @param tokenAddress .
    /// @param tokenId .
    /// @param missionId .
    /// @param taskId .
    /// @param response .
    /// @dev
    function respond(
        address tokenAddress,
        uint256 tokenId,
        address missions,
        uint256 missionId,
        uint256 taskId,
        string calldata response,
        uint256 metricValue
    ) external payable onlyHodler(tokenAddress, tokenId) {
        bytes32 questKey = this.encode(tokenAddress, tokenId, missions, missionId, 0);
        bytes32 taskKey = this.encode(tokenAddress, tokenId, missions, missionId, taskId);

        _respond(questKey, taskKey, missions, missionId, taskId, response, metricValue);
    }

    function respondBySig(
        address signer,
        address tokenAddress,
        uint256 tokenId,
        address missions,
        uint256 missionId,
        uint256 taskId,
        string calldata response,
        uint256 metricValue,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public payable virtual onlyHodler(tokenAddress, tokenId) {
        bytes32 questKey = this.encode(tokenAddress, tokenId, missions, missionId, 0);
        bytes32 taskKey = this.encode(tokenAddress, tokenId, missions, missionId, taskId);

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(abi.encode(RESPOND_TYPEHASH, signer, questKey, taskKey, response))
            )
        );

        address recoveredAddress = ecrecover(digest, v, r, s);
        if (recoveredAddress == address(0) || recoveredAddress != signer) revert InvalidUser();

        _respond(questKey, taskKey, missions, missionId, taskId, response, metricValue);
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
    function review(
        address tokenAddress,
        uint256 tokenId,
        address missions,
        uint256 missionId,
        uint256 taskId,
        bool reviewResult
    ) external payable onlyReviewer {
        _review(tokenAddress, tokenId, missions, missionId, taskId, reviewResult);
    }

    function reviewBySig(
        address tokenAddress,
        uint256 tokenId,
        address missions,
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

        _review(tokenAddress, tokenId, missions, missionId, taskId, reviewResult);
    }

    /// -----------------------------------------------------------------------
    /// DAO Logic
    /// -----------------------------------------------------------------------

    function setMissions(address missions) external payable onlyOperator {
        this.setAddress(MISSIONS_ADDRESS_KEY, missions);
    }

    /// @notice Update reviewers
    /// @param reviewer The addresses to update managers to
    /// @dev
    function setReviewer(address reviewer, bool status) external payable onlyOperator {
        if (status) {
            if (!this.getBool(keccak256(abi.encodePacked(reviewer, ".exists")))) {
                uint256 reviewerCount = this.getUint(keccak256(abi.encodePacked("quest.reviewerCount")));

                // Store new reviewer status and id
                this.setBool(keccak256(abi.encodePacked(reviewer, ".exists")), status);
                this.setUint(keccak256(abi.encodePacked(reviewer, ".reviewerId")), ++reviewerCount);

                // Increment and store global number of reviewers.
                this.addUint(keccak256(abi.encodePacked("quest.reviewerCount")), 1);
            }
        } else {
            // Delete reviewer status and id.
            this.deleteBool(keccak256(abi.encodePacked(reviewer, ".exists")));
            this.deleteUint(keccak256(abi.encodePacked(reviewer, ".reviewerId")));
        }
    }

    /// @notice Set review status for all quest
    function setGlobalReview(bool toReview) external payable onlyOperator {
        this.setBool(keccak256(abi.encodePacked("quest.toReview")), toReview);
    }

    function setResponseCoolDown(uint40 cd) external payable onlyOperator {
        this.setUint(keccak256(abi.encodePacked("quest.cd")), cd);
    }
    /// -----------------------------------------------------------------------
    /// Getter Logic
    /// -----------------------------------------------------------------------

    function getQuestDetail(bytes32 questKey) external view returns (QuestDetail memory) {
        return QuestDetail({
            active: this.getBool(keccak256(abi.encodePacked(questKey, ".detail.active"))),
            toReview: this.getBool(keccak256(abi.encodePacked(questKey, ".detail.toReview"))),
            progress: uint8(this.getUint(keccak256(abi.encodePacked(questKey, ".detail.progress")))),
            deadline: uint40(this.getUint(keccak256(abi.encodePacked(questKey, ".detail.deadline")))),
            completed: uint40(this.getUint(keccak256(abi.encodePacked(questKey, ".detail.completed"))))
        });
    }

    function getQuestConfig(address missions, uint256 missionId) external view returns (QuestConfig memory) {
        return QuestConfig({
            gateToken: this.getAddress(keccak256(abi.encodePacked(missions, missionId, ".reward.gateToken"))),
            gateTokenAmount: this.getUint(keccak256(abi.encodePacked(missions, missionId, ".reward.gateTokenAmount"))),
            rewardToken: this.getAddress(keccak256(abi.encodePacked(missions, missionId, ".reward.rewardToken")))
        });
    }

    function isReviewer(address account) external view returns (bool) {
        return this.getBool(keccak256(abi.encodePacked(account, ".exists")));
    }

    /// -----------------------------------------------------------------------
    /// Helper Logic
    /// -----------------------------------------------------------------------

    function encode(address tokenAddress, uint256 tokenId, address missions, uint256 missionId, uint256 taskId)
        external
        pure
        returns (bytes32)
    {
        // Retrieve questKey
        if (taskId == 0) return keccak256(abi.encode(tokenAddress, tokenId, missions, missionId));
        // Retrieve taskKey
        else return keccak256(abi.encode(tokenAddress, tokenId, missions, missionId, taskId));
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
    function updateQuestDetail(bytes32 questKey, uint256 missionId, QuestDetail memory qd) internal {
        // Retrieve number of Tasks to update Quest progress
        address missions = this.getAddress(MISSIONS_ADDRESS_KEY);
        uint256 tasksCount = IMissions(missions).getMissionTaskCount(missionId);

        // Calculate and udpate quest detail
        ++qd.completed;
        uint256 progress = calculateProgress(qd.completed, tasksCount);

        // Store quest detail
        this.setUint(keccak256(abi.encodePacked(questKey, ".detail.progress")), progress);
        this.setUint(keccak256(abi.encodePacked(questKey, ".detail.completed")), qd.completed);

        // Finalize quest
        if (qd.progress == 100) {
            this.deleteBool(keccak256(abi.encodePacked(questKey, ".detail.active")));
            this.deleteUint(keccak256(abi.encodePacked(questKey, ".detail.timeLeft")));

            // Increment number of mission completions.
            this.addUint(keccak256(abi.encodePacked(missions, missionId, ".completions")), 1);

            // Increment number of mission completions per questKey.
            this.addUint(keccak256(abi.encodePacked(questKey, ".stats.completions")), 1);
        }
    }

    /// @notice Internal function using signature to start quest.
    /// @param questKey.
    /// @param missions.
    /// @param missionId .
    /// @dev
    function _start(bytes32 questKey, address missions, uint256 missionId) internal virtual {
        // Confirm quest deadline has not passed
        uint256 deadline = IMissions(missions).getMissionDeadline(missionId);
        if (deadline < block.timestamp) revert InvalidMission();

        // Confirm user has sufficient xp to quest Misson
        QuestConfig memory qc = this.getQuestConfig(missions, missionId);
        if (qc.gateToken != address(0) && IERC20(qc.gateToken).balanceOf(msg.sender) < qc.gateTokenAmount) {
            revert NeedMoreTokens();
        }

        // Retrieve quest key and corresponding quest detail
        QuestDetail memory qd = this.getQuestDetail(questKey);

        // Confirm Quest is not already in progress
        if (qd.active) revert QuestInProgress();

        // Initialize quest detail.
        this.setBool(keccak256(abi.encodePacked(questKey, ".detail.active")), true);
        this.setUint(keccak256(abi.encodePacked(questKey, ".detail.deadline")), deadline);
        this.setBool(
            keccak256(abi.encodePacked(questKey, ".detail.toReview")),
            this.getBool(keccak256(abi.encodePacked("quest.toReview")))
        );

        // Increment number of mission starts.
        this.addUint(keccak256(abi.encodePacked(missions, missionId, ".starts")), 1);

        // Increment number of mission starts per questKey.
        this.addUint(keccak256(abi.encodePacked(questKey, ".stats.starts")), 1);
    }

    /// @notice Internal function using signature to respond to quest tasks.
    /// @param questKey .
    /// @param taskKey .
    /// @param missionId .
    /// @param taskId .
    /// @param response .
    /// @dev
    function _respond(
        bytes32 questKey,
        bytes32 taskKey,
        address missions,
        uint256 missionId,
        uint256 taskId,
        string calldata response,
        uint256 metricValue
    ) internal virtual {
        // Retrieve questKey and QuestDetail.
        QuestDetail memory qd = this.getQuestDetail(questKey);

        // Confirm Quest is active.
        if (!qd.active) revert QuestInactive();

        // Confirm Task is part of Mission.
        if (!IMissions(missions).isTaskInMission(missionId, taskId)) revert InvalidMission();

        // Confirm cooldown has expired.
        uint256 taskCd = this.getUint(keccak256(abi.encodePacked(taskKey, ".review.cd")));
        if (block.timestamp < taskCd) revert Cooldown();

        // Store quest task responses.
        this.setString(keccak256(abi.encodePacked(taskKey, ".review.response")), response);

        // Store metric value.
        IMissions(missions).setTaskMetric(taskId, "", metricValue);

        // Initiate/Reset cooldown.
        uint256 cd = this.getUint(keccak256(abi.encodePacked("quest.cd")));
        this.setUint(keccak256(abi.encodePacked(taskKey, ".review.cd")), cd + block.timestamp);

        // Increment number of responses for the task.
        // Data also applies to public use to signal frequency of interacting with a Task.
        this.addUint(keccak256(abi.encodePacked(taskKey, ".review.responseCount")), 1);

        // If review is not necessary, proceed to distribute reward and update quest detail.
        if (!qd.toReview) {
            updateQuestDetail(questKey, missionId, qd);
        }
    }

    /// @notice Internal function using signature to review quest tasks.
    /// @param tokenAddress .
    /// @param tokenId .
    /// @param missionId .
    /// @param taskId .
    /// @param reviewResult .
    /// @dev
    function _review(
        address tokenAddress,
        uint256 tokenId,
        address missions,
        uint256 missionId,
        uint256 taskId,
        bool reviewResult
    ) internal {
        // Retrieve quest id and corresponding quest detail
        bytes32 questKey = this.encode(tokenAddress, tokenId, missions, missionId, 0);
        bytes32 taskKey = this.encode(tokenAddress, tokenId, missions, missionId, taskId);
        QuestDetail memory qd = this.getQuestDetail(questKey);
        if (!qd.toReview) revert InvalidReview();

        if (!reviewResult) {
            // Store review result
            this.deleteBool(keccak256(abi.encodePacked(taskKey, ".review.result")));
        } else {
            // Store review result
            this.setBool(keccak256(abi.encodePacked(taskKey, ".review.result")), reviewResult);

            // Update quest detail
            updateQuestDetail(questKey, missionId, qd);
        }
    }
}
