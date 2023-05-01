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

    // function isManager(address manager) external returns (bool);

    function getTask(uint8 taskId) external view returns (uint8, uint40, address, string memory, string memory);

    function getMission(uint8 _missionId) external view returns (uint8, uint40, uint8[] memory, string memory, string memory, address, uint8, uint256, uint256);
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

    event QuestStarted(address indexed traveler, uint8 missionId);
    
    event QuestPaused(address indexed traveler, uint8 missionId);

    event QuestResumed(address indexed traveler, uint8 missionId);

    event QuestCompleted(address indexed traveler, uint8 missionId);

    event TaskSubmitted(address indexed traveler, uint8 missionId, uint8 taskId, string indexed homework);

    event TaskReviewed(address indexed reviewer, address indexed traveler, uint8 missionId, uint8 taskId, Review review);

    event TravelerRewardClaimed(address indexed creator, uint256 amount);

    event CreatorRewardClaimed(address indexed creator, uint256 amount);

    event ReviewersUpdated(address[] indexed reviewers);

    event ContractsUpdated(IArm0ryTravelers indexed travelers, IArm0ryMission indexed mission);

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

    error NeedMoreXp();

    /// -----------------------------------------------------------------------
    /// Quest Storage
    /// -----------------------------------------------------------------------
    
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
    mapping(address => mapping(uint256 => Review)) public taskReviews;

    address[] public reviewers;

    // Status indicating if an address is a Manager
    // Account -> True/False 
    mapping(address => bool) public isReviewer;

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
    mapping(uint8 => address[]) public missionStarts;

    // Traveler completions by Mission Id
    // Mission Id => Travelers 
    mapping(uint8 => address[]) public missionCompeletions;

    /// -----------------------------------------------------------------------
    /// Modifier
    /// -----------------------------------------------------------------------

    modifier onlyReviewer() {
        if (isReviewer[msg.sender]) {
            _;
        } else {
            revert InvalidReviewer();
        }
    }

    modifier onlyAdmin() {
        if (admin == msg.sender) {
            _;
        } else {
            revert NotAuthorized();
        }
    }

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

        emit ContractsUpdated(travelers, mission);
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
        (, uint40 _duration, , , , , uint8 requiredXp, , uint256 tasksCount) = mission.getMission(missionId);
        // Confirm Mission is questable 
        if (_duration == 0) revert InvalidMission();

        // Confirm Traveler has sufficient xp to quest Misson
        if (IERC20(admin).balanceOf(msg.sender) < requiredXp * 1e18 ) revert NeedMoreXp();
        
        // Confirm Traveler has recently completed a Mission or finalized an expired Mission
        if (questing[msg.sender] != 0 && quests[msg.sender][questing[msg.sender]].start == 0) {
            // Initialize Quest
            quests[msg.sender][missionId] = Quest({
                start: uint40(block.timestamp),
                duration: _duration,
                completed: 0,
                incomplete: uint8(tasksCount),
                progress: 0,
                xp: 0,
                claimed: 0
            });

            // Add Traveler to list of mission participants
            missionStarts[missionId].push(msg.sender);

            // Mark active quest for Traveler
            questing[msg.sender] = missionId;
            
            emit QuestStarted(msg.sender, missionId);

        } else if (questing[msg.sender] == 0) {
            // Initiatlize new quest or resume previously paused quest

            // Lock Traveler Pass
            travelers.safeTransferFrom(msg.sender, address(this), uint256(uint160(msg.sender)));

            if (quests[msg.sender][missionId].duration == 0) {
                // Initialize Quest
                quests[msg.sender][missionId] = Quest({
                    start: uint40(block.timestamp),
                    duration: _duration,
                    completed: 0,
                    incomplete: uint8(tasksCount),
                    progress: 0,
                    xp: 0,
                    claimed: 0
                });

                // Add Traveler to list of mission participants
                missionStarts[missionId].push(msg.sender);

                // Mark active quest for Traveler
                questing[msg.sender] = missionId;
                
                emit QuestStarted(msg.sender, missionId);
            } else {
                // Resume Quest
                quests[msg.sender][missionId].start = uint40(block.timestamp);

                emit QuestResumed(msg.sender, missionId);
            }
        } else {
            revert InvalidStart();
        }
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

        emit QuestPaused(msg.sender, _missionId);
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
      
        // Confirm Quest has not expired
        (uint40 start, uint40 duration , , , , , ) = this.getQuest(msg.sender, _missionId);
        if (uint40(block.timestamp) > start + duration) revert QuestInactive();

        // Confirm Task is part of Mission
        if (!mission.isTaskInMission(_missionId, uint8(taskId))) revert InvalidMission();

        // Update Homework
        taskHomework[msg.sender][taskId] = homework;

        emit TaskSubmitted(msg.sender, _missionId, uint8(taskId), homework);
    }

    /// -----------------------------------------------------------------------
    /// Review Functions
    /// -----------------------------------------------------------------------

    /// @notice Reviewer to submit review of task completion.
    /// @param traveler Identifier of a Traveler.
    /// @param missionId Identifier of a Quest.
    /// @param taskId Identifier of a Task.
    /// @param review Result of review
    /// @dev 
    function reviewTasks(
        address traveler,
        uint8 missionId,
        uint8 taskId,
        Review review
    ) onlyReviewer external payable {
        // Confirm Reviewer has submitted valid review data
        if (review == Review.NOT_READY) revert InvalidReview();

        // Confirm Traveler has submitted homework
        if (bytes(taskHomework[traveler][taskId]).length == 0) revert TaskNotReadyForReview();

        // Confirm Task has not already been reviewed
        if (taskReviews[traveler][taskId] != Review.NOT_READY) revert AlreadyReviewed();

        // Record review
        taskReviews[traveler][taskId] = review;

        // Update reviewer xp
        reviewerXp[msg.sender]++;

        if (review == Review.PASS) {
            // Mark Task completion
            isMissionTaskCompleted[traveler][missionId][taskId] = true;

            updateQuestDetail(traveler, missionId, taskId);
        } 

        emit TaskReviewed(msg.sender, traveler, missionId, taskId, review);
    }

    function finalizeExpiredQuest(address traveler, uint8 missionId) external payable {
        (uint40 start, uint40 duration , , , uint8 progress, , ) = this.getQuest(traveler, missionId);
        (uint8 missionXp, , , , , , , , ) = mission.getMission(missionId);
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

        emit TravelerRewardClaimed(msg.sender, reward * 1e18);
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

        emit CreatorRewardClaimed(msg.sender, (missionReward + taskReward) * 1e18);
    }

    /// -----------------------------------------------------------------------
    /// Arm0ry Functions
    /// -----------------------------------------------------------------------

    /// @notice Update Arm0ry contracts.
    /// @param _travelers Contract address of Arm0ryTraveler.sol.
    /// @param _mission Contract address of Arm0ryMission.sol.
    /// @dev 
    function updateContracts(IArm0ryTravelers _travelers, IArm0ryMission _mission) 
        onlyAdmin 
        external 
        payable 
    {
        travelers = _travelers;
        mission = _mission;

        emit ContractsUpdated(travelers, mission);
    }

    /// @notice Update reviewers
    /// @param _reviewers The addresses to update managers to
    /// @dev
    function updateReviewers(address[] calldata _reviewers)
        onlyAdmin
        external
        payable
    {
        delete reviewers;

        for (uint8 i = 0 ; i < _reviewers.length;) {

            if (_reviewers[i] != address(0)) {
                reviewers.push(_reviewers[i]);
                isReviewer[_reviewers[i]] = true;
            }

            // cannot possibly overflow
            unchecked {
                ++i;
            }
        }

        emit ReviewersUpdated(reviewers);
    }

    function updateAdmin(address payable _admin) 
        onlyAdmin 
        external 
        payable 
    {
        admin = _admin;
    }

    /// -----------------------------------------------------------------------
    /// Getter Functions
    /// -----------------------------------------------------------------------

    function getQuest(address _traveler, uint8 _missionId) external view returns (uint40, uint40, uint8, uint8, uint8, uint8, uint8) {
        Quest memory quest = quests[_traveler][_missionId];
        return (quest.start, quest.duration, quest.completed, quest.incomplete, quest.progress, quest.xp, quest.claimed);
    }

    function getMissionCompletionsCount(uint8 _missionId) external view returns (uint256) {
        return missionCompeletions[_missionId].length;
    }

    function getMissionStartCount(uint8 _missionId) external view returns (uint256) {
        return missionStarts[_missionId].length;
    }

    function getMissionImpact(uint8 _missionId) external view returns (uint256) {
        uint256 ratio;
        uint256 starts = missionStarts[_missionId].length;
        uint256 completions = missionCompeletions[_missionId].length;

        if (starts != 0) {
            ratio = completions * 100 / starts;
        } else {
            return 0;
        }

        return ratio;
    }

    /// -----------------------------------------------------------------------
    /// Internal Functions
    /// -----------------------------------------------------------------------

    /// @notice Calculate a percentage.
    /// @param numerator The numerator.
    /// @param denominator The denominator.
    /// @dev 
    function calculateProgress(uint numerator, uint denominator) internal pure returns (uint8) {
        return uint8(numerator*(10**2)/denominator); 
    }

    /// @notice Update, and finalize when appropriate, the Quest detail.
     /// @param traveler Identifier of a Traveler.
    /// @param missionId Identifier of a Quest.
    /// @param taskId Identifier of a Task.
    /// @dev 
    function updateQuestDetail(address traveler, uint8 missionId, uint8 taskId) internal {
        // Retrieve to update Task reward
        (uint8 taskXp, , address taskCreator , , ) = mission.getTask(taskId);
        (uint8 missionXp, , , , , address missionCreator, , , uint256 missionTaskCount) = mission.getMission(missionId);
        
        // cannot possibly overflow
        uint progress;
        unchecked { 
            // Update complted Task count
            ++quests[traveler][missionId].completed;

            // Update incomplete Task count
            --quests[traveler][missionId].incomplete;

            // Update Quest progress
            quests[traveler][missionId].progress = calculateProgress(quests[traveler][missionId].completed, missionTaskCount);

            // Update Task reward
            quests[traveler][missionId].xp += taskXp;

            // Reward Task creator
            taskCreatorRewards[taskCreator] += taskXp;
        }

        // Finalize and close out Quest when progress is 100
        if (progress == 100) {
            // Reward Mission creator 
            missionCreatorRewards[missionCreator] += missionXp;

            // Add Traveler to completion array
            missionCompeletions[missionId].push(traveler);

            // Mark Quest complete
            quests[traveler][missionId].start = 0;

            emit QuestCompleted(traveler, missionId);
        }
    }

    receive() external payable {}
}