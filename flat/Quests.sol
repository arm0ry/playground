// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

/// @notice Receiver hook utility for NFT 'safe' transfers
abstract contract NFTreceiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return 0x150b7a02;
    }
}

/// @notice Kali DAO share manager interface
interface IKaliShareManager {
    function mintShares(address to, uint256 amount) external payable;

    function burnShares(address from, uint256 amount) external payable;
}

interface IArm0ryTravelers {
    function ownerOf(uint256 id) external view returns (address);

    function balanceOf(address account) external view returns (uint256);

    function transferFrom(
        address from,
        address to,
        uint256 id
    ) external payable;

    function safeTransferFrom(
        address from,
        address to,
        uint256 id
    ) external payable;
}

// IERC20
interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

interface IArm0ryMission {
    function isTaskInMission(uint8 missionId, uint8 taskId)
        external
        returns (bool);

    function isManager(address manager) external returns (bool);

    function getTask(uint8 taskId) external view returns (uint8, uint40, address, string memory, string memory);

    function getMission(uint8 _missionId) external view returns (uint8, uint40, uint8[] memory, string memory, string memory, address, uint256, uint256);
}

/// @title Arm0ry Quests
/// @notice Quest-to-Earn RPG.
/// @author audsssy.eth

struct Quest {
    uint40 start;
    uint40 duration;
    uint8 completed;
    uint8 incomplete;
    uint8 progress;
    uint8 xp;
    uint8 claimed;
}

enum Review {
    NOT_READY,
    PASS,
    FAIL
}

contract Arm0ryQuests is NFTreceiver {
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    // event QuestStarted(address indexed traveler, uint8 missionId);
    
    // event QuestPaused(address indexed traveler, uint8 missionId);

    // event QuestResumed(address indexed traveler, uint8 missionId);

    // event QuestCompleted(address indexed traveler, uint8 missionId);

    // event TaskSubmitted(address indexed traveler, uint8 missionId, uint8 taskId, string indexed homework);

    // event TaskReviewed(address indexed reviewer, address indexed traveler, uint8 missionId, uint16 taskId, uint8 review);

    // event TravelerRewardClaimed(address indexed creator, uint256 amount);

    // event CreatorRewardClaimed(address indexed creator, uint256 amount);

    // event ReviewerXpUpdated(uint8 xp);

    // event Arm0ryFeeUpdatedXpUpdated(uint8 arm0ryFee);

    // event ContractsUpdated(IArm0ryTravelers indexed travelers, IArm0ryMission indexed mission);

    /// -----------------------------------------------------------------------
    /// Custom Errors
    /// -----------------------------------------------------------------------

    error InvalidStart();

    error InvalidMission();

    error NotAuthorized();

    error InvalidTraveler();

    error NothingToClaim();

    error QuestInactive();

    error QuestActive();

    error InvalidReviewer();

    error InsufficientReviewerXp();

    error InvalidReview();

    error InvalidBonus();

    error AlreadyReviewed();

    error TaskNotReadyForReview();

    error TaskAlreadyCompleted();

    error AlreadyClaimed();

    error LengthMismatch();

    error NeedMoreCoins();

    /// -----------------------------------------------------------------------
    /// Quest Storage
    /// -----------------------------------------------------------------------

    uint256 public immutable THRESHOLD = 10 * 1e18;
    
    address payable public admin;

    IArm0ryTravelers public travelers;

    IArm0ryMission public mission;

    // Traveler's history of quests
    // Traveler => Mission Id => Quest
    mapping(address => mapping(uint256 => Quest)) public quests;

    // Active mission by Traveler 
    // One active mission per Traveler ; 0 signals "no active quest"
    // Traveler => Mission Id
    mapping(address => uint8) public questing;

    // Homework per Task of an active Quest
    // Traveler => Task Id => Homework
    mapping(address => mapping(uint256 => string)) public taskHomework;

    // Review results of a Task of a Quest
    mapping(address => mapping(uint256 => mapping(address => Review))) public taskReviews;

    // Xp per reviewer
    // Reviewer => Xp
    mapping(address => uint8) public reviewerXp;

    // Status indicating if a Task of a Quest is completed
    // Traveler => Mission Id => Task Id => True/False
    mapping(address => mapping(uint8 => mapping(uint256 => bool))) public isMissionTaskCompleted;

    // Rewards per Task creator
    // Task creator => Reward points
    mapping(address => uint16) public taskCreatorRewards;

    // Rewards per Mission creator
    // Mission creator => Reward points
    mapping(address => uint16) public missionCreatorRewards;

    // Travelers per Mission Id
    // Mission Id => Travelers 
    mapping(uint8 => address[]) public missionTravelers;

    // Traveler completions by Mission Id
    // Mission Id => Travelers 
    mapping(uint8 => address[]) public missionCompeletions;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(
        IArm0ryTravelers _travelers,
        IArm0ryMission _mission,
        address payable _admin
    ) {
        travelers = _travelers;
        mission = _mission;
        admin = _admin;

        // emit ContractsUpdated(travelers, mission);
    }

    /// -----------------------------------------------------------------------
    /// Quest Logic
    /// -----------------------------------------------------------------------

    /// @notice Traveler to start a new Quest.
    /// @param missionId Identifier of a Mission.
    /// @dev 
    function startQuest(uint8 missionId)
        external
        payable
    {
        // Confirm if Mission is not 0
        if (missionId == 0) revert InvalidMission();
        
        (, uint40 _duration, , , , , , ) = mission.getMission(missionId);
        if (_duration == 0) revert InvalidMission();

        // Lock Traveler Pass
        travelers.safeTransferFrom(msg.sender, address(this), uint256(uint160(msg.sender)));

        if (quests[msg.sender][missionId].start != 0) revert InvalidStart();

        // If Traveler picked a non-BASIC path, i.e., missionId != 0, 
        if (missionId != 1) {
            if (IERC20(admin).balanceOf(msg.sender) < THRESHOLD) revert NeedMoreCoins();
        }

        // Initialize reviewer xp
        if (quests[msg.sender][missionId].duration == 0) {
            reviewerXp[msg.sender] = 5;
        }

        // Initialize Quest
        quests[msg.sender][missionId] = Quest({
            start: uint40(block.timestamp),
            duration: _duration,
            completed: 0,
            incomplete: 0,
            progress: 0,
            xp: 0,
            claimed: 0
        });

        // Add Traveler to list of mission participants
        missionTravelers[missionId].push(msg.sender);

        // Mark active quest for Traveler
        questing[msg.sender] = missionId;

        // emit QuestStarted(msg.sender, missionId);
    }

    /// @notice Traveler to continue an existing but inactive Quest.
    /// @param _missionId Identifier of a Quest.
    /// @dev 
    function resumeQuest(uint8 _missionId) external payable {
        // Lock Traveler Pass
        travelers.safeTransferFrom(msg.sender, address(this), uint256(uint160(msg.sender)));

        // Confirm no Quest is active 
        if (questing[msg.sender] != 0) revert QuestActive();

        // Confirm Quest to resume has been paused
        if (quests[msg.sender][_missionId].start > 0) revert QuestActive();
        
        // Mark _missionId as active Quest
        questing[msg.sender] = _missionId;

        // Update Quest start time
        quests[msg.sender][_missionId].start = uint40(block.timestamp);

        // emit QuestResumed(msg.sender, missionId);
    }

    /// @notice Traveler to pause an active Quest.
    /// @param _missionId Identifier of a Quest.
    /// @dev 
    function pauseQuest(uint8 _missionId) external payable {
        // Confirm Quest is active
        if (_missionId != questing[msg.sender]) revert QuestInactive();

        // Confirm Quest has not expired
        (uint40 start, uint40 duration , , , , , ) = this.getQuest(msg.sender, _missionId);
        if (uint40(block.timestamp) > start + duration) revert QuestInactive();

        // Use 0 to mark Quest as paused
        questing[msg.sender] = 0;

        // Update Quest start time and duration
        if (_missionId != 1) {
            uint40 diff;
            unchecked { 
                 diff = uint40(block.timestamp) - start;
            }
            quests[msg.sender][_missionId].start = 0;
            quests[msg.sender][_missionId].duration = diff;
        }

        // Return locked NFT when pausing a Quest
        travelers.transferFrom(address(this), msg.sender, uint256(uint160(msg.sender)));

        // emit QuestPaused(msg.sender, missionId);
    }

    /// @notice Traveler to submit Homework for Task completion.
    /// @param _missionId Identifier of a Quest.
    /// @param taskId Identifier of a Task.
    /// @param homework Task homework to turn in.
    /// @dev 
    function submitTasks(
        uint8 _missionId, 
        uint256 taskId, 
        string calldata homework
    ) external payable {
        // Confirm Quest is active
        if (_missionId != questing[msg.sender]) revert QuestInactive();

        // Confirm Task not already completed
        if (isMissionTaskCompleted[msg.sender][_missionId][taskId]) revert TaskAlreadyCompleted();
                
        // Traveler must have at least 1 reviewer xp
        if (reviewerXp[msg.sender] == 0) revert InsufficientReviewerXp();

        // Confirm Quest has not expired
        (uint40 start, uint40 duration , , , , , ) = this.getQuest(msg.sender, _missionId);
        if (uint40(block.timestamp) > start + duration) revert QuestInactive();

        // Update reviewer xp
        reviewerXp[msg.sender]--;

        // Update Homework
        taskHomework[msg.sender][taskId] = homework;

        // emit TaskSubmitted(msg.sender, missionId, taskId, homework);
    }

    /// -----------------------------------------------------------------------
    /// Review Functions
    /// -----------------------------------------------------------------------

    /// @notice Reviewer to submit review of task completion.
    /// @param traveler Identifier of a Traveler.
    /// @param missionId Identifier of a Quest.
    /// @param taskId Identifier of a Task.
    /// @param review Result of review, i.e., 0, 1, or 2.
    /// @dev 
    function reviewTasks(
        address traveler,
        uint8 missionId,
        uint8 taskId,
        Review review,
        uint8 bonusXp
    ) external payable {
        // Reviewer must have completed 2 quests
        bool _isManager = mission.isManager(msg.sender);

        if (admin != msg.sender && !_isManager) {
            if (IERC20(admin).balanceOf(msg.sender) < THRESHOLD) revert NeedMoreCoins();
        }

        // Reviewer cannot review own Task
        if (traveler == msg.sender) revert InvalidReview();

        // Reviewer must provide valid review data
        if (review == Review.NOT_READY) revert InvalidReview();

        // Traveler must have submitted homework
        if (bytes(taskHomework[traveler][taskId]).length == 0) revert TaskNotReadyForReview();

        // Reviewer must not have already reviewed instant Task
        if (taskReviews[traveler][taskId][msg.sender] != Review.NOT_READY) revert AlreadyReviewed();

        // Record review
        taskReviews[traveler][taskId][msg.sender] = review;

        // Update reviewer xp
        reviewerXp[msg.sender]++;

        if (review == Review.PASS) {
            // Mark Task completion
            isMissionTaskCompleted[traveler][missionId][taskId] = true;

            updateQuestDetail(traveler, missionId, taskId, bonusXp);
        } 

        // emit TaskReviewed(msg.sender, traveler, missionId, taskId, review);
    }

    function finalizeExpiredQuest(address traveler, uint8 missionId) external payable {
        (uint40 start, uint40 duration , , , uint8 progress, , ) = this.getQuest(traveler, missionId);
        (uint8 missionXp, , , , , , , ) = mission.getMission(missionId);
        if ((uint40(block.timestamp) < start + duration) && progress != 100) {

            IKaliShareManager(admin).burnShares(traveler, missionXp / 2);

            quests[traveler][missionId].start = 0;
            quests[traveler][missionId].duration = 0;    
        } else {
            revert QuestActive();
        } 
    }

    /// -----------------------------------------------------------------------
    /// Claim Rewards Functions
    /// -----------------------------------------------------------------------

    /// @notice Task creator to claim rewards.
    /// @dev 
    function claimTravelerReward(uint8 missionId) external payable {
        // Retrieve to inspect reward availability
        (, , , , , uint8 xp, uint8 claimed) = this.getQuest(msg.sender, missionId);
        if (xp == 0) revert NothingToClaim();
        if (xp <= claimed) revert NothingToClaim();

        // Calculate reward
        uint8 reward;
        unchecked {
            reward = xp - claimed;
        }

        // Update Quest claim 
        quests[msg.sender][missionId].claimed = xp;

        // Mint rewards
        IKaliShareManager(admin).mintShares(msg.sender, reward * 1e18);

        // emit TravelerRewardClaimed(msg.sender, reward * 1e18);
    }

    /// @notice Task creator to claim rewards.
    /// @dev 
    function claimCreatorReward() external payable {
        if (taskCreatorRewards[msg.sender] == 0 && missionCreatorRewards[msg.sender] == 0) revert NothingToClaim();

        uint16 taskReward = taskCreatorRewards[msg.sender];
        uint16 missionReward = missionCreatorRewards[msg.sender];

        // Update Creator rewards
        taskCreatorRewards[msg.sender] = 0;
        missionCreatorRewards[msg.sender] = 0;

        // Mint rewards
        IKaliShareManager(admin).mintShares(msg.sender, (missionReward + taskReward) * 1e18);

        // emit CreatorRewardClaimed(msg.sender, (missionReward + taskReward) * 1e18);
    }

    /// -----------------------------------------------------------------------
    /// Arm0ry Functions
    /// -----------------------------------------------------------------------

    /// @notice Update Arm0ry contracts.
    /// @param _travelers Contract address of Arm0ryTraveler.sol.
    /// @param _mission Contract address of Arm0ryMission.sol.
    /// @dev 
    function updateContracts(IArm0ryTravelers _travelers, IArm0ryMission _mission) external payable {
        if (msg.sender != admin) revert NotAuthorized();
        travelers = _travelers;
        mission = _mission;

        // emit ContractsUpdated(travelers, mission);
    }

    /// @notice Update Reviewer xp.
    /// @param reviewer Reviewer's address.
    /// @param _xp Xp to assign to Reviewer.
    /// @dev 
    function updateReviewerXp(address reviewer, uint8 _xp) external payable {
        if (msg.sender != admin) revert NotAuthorized();
        reviewerXp[reviewer] = _xp;
    }

    function updateAdmin(address payable _admin) external payable {
        if (msg.sender != admin) revert NotAuthorized();
        admin = _admin;
    }

    /// -----------------------------------------------------------------------
    /// Getter Functions
    /// -----------------------------------------------------------------------

    function getQuest(address _traveler, uint8 _missionId) external view returns (uint40, uint40, uint8, uint8, uint8, uint8, uint8) {
        Quest memory quest = quests[_traveler][_missionId];
        return (quest.start, quest.duration, quest.completed, quest.incomplete, quest.progress, quest.xp, quest.claimed);
    }

    function getMissionCompletionsCount(uint8 _missionId) external view returns (uint8) {
        return uint8(missionCompeletions[_missionId].length);
    }

    function getMissionImpact(uint8 _missionId) external view returns (uint8) {
        uint8 ratio;
        uint8 starts = uint8(missionTravelers[_missionId].length);
        uint8 completions = uint8(missionCompeletions[_missionId].length);


        if (starts != 0) {
            ratio = completions / starts * 100;
        } else {
            return 0;
        }

        return ratio;
    }

    /// -----------------------------------------------------------------------
    /// Internal Functions
    /// -----------------------------------------------------------------------

    /// @notice Calculate Quest progress.
    /// @param _completions The number of completed Tasks.
    /// @param _starts The number of Tasks started.
    /// @dev 
    function calculateProgress(uint _completions, uint _starts) internal pure returns (uint) {
        return _completions*(10**2)/_starts; 
    }

    /// @notice Update, and finalize when appropriate, Quest detail.
    /// @param traveler .
    /// @param missionId .
    /// @param taskId .
    /// @param bonusXp .
    /// @dev 
    function updateQuestDetail(address traveler, uint8 missionId, uint8 taskId, uint8 bonusXp) internal {
        // Retrieve to update Task reward
        (, , uint8 completed, , , , ) = this.getQuest(traveler, missionId);
        (uint8 taskXp, , address taskCreator , , ) = mission.getTask(taskId);
        (uint8 missionXp, , , , , address missionCreator, , uint256 missionTaskCount ) = mission.getMission(missionId);

        taskXp += bonusXp;
        
        // cannot possibly overflow
        uint progress;
        unchecked { 
            ++completed;

            // Update complted Task count
            quests[traveler][missionId].completed = completed;

            // Update incomplete Task count
            quests[traveler][missionId].incomplete = uint8(missionTaskCount) - completed;

            // Update Quest progress
            progress = calculateProgress(completed, missionTaskCount);
            quests[traveler][missionId].progress = uint8(progress);

            // Update Task reward
            quests[traveler][missionId].xp += missionXp;

            // Record task creator rewards
            taskCreatorRewards[taskCreator] += taskXp;
        }

        // Finalize and close out Quest when progress is 100
        if (progress == 100) {

            // Increment Mission creator rewards
            missionCreatorRewards[missionCreator] += missionXp;

            // Clean up Quest
            quests[traveler][missionId].start = 0;

            // Mark Quest as "Inactive" 
            questing[msg.sender] = 0;

            // Add Traveler to completion array
            missionCompeletions[missionId].push(traveler);

            // Return locked NFT when Quest is completed
            travelers.transferFrom(address(this), traveler, uint256(uint160(traveler)));
        }
    }

    receive() external payable {}
}