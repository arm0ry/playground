// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;


/// @notice Safe ETH and ERC-20 transfer library that gracefully handles missing return values
/// @author Modified from Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/utils/SafeTransferLib.sol)
/// License-Identifier: AGPL-3.0-only
library SafeTransferLib {
    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error ETHtransferFailed();
    error TransferFailed();
    error TransferFromFailed();

    /// -----------------------------------------------------------------------
    /// ETH Logic
    /// -----------------------------------------------------------------------

    function _safeTransferETH(address to, uint256 amount) internal {
        bool success;

        assembly {
            // transfer the ETH and store if it succeeded or not
            success := call(gas(), to, amount, 0, 0, 0, 0)
        }
        if (!success) revert ETHtransferFailed();
    }

    /// -----------------------------------------------------------------------
    /// ERC-20 Logic
    /// -----------------------------------------------------------------------

    function _safeTransfer(
        address token,
        address to,
        uint256 amount
    ) internal {
        bool success;

        assembly {
            // we'll write our calldata to this slot below, but restore it later
            let memPointer := mload(0x40)
            // write the abi-encoded calldata into memory, beginning with the function selector
            mstore(
                0,
                0xa9059cbb00000000000000000000000000000000000000000000000000000000
            )
            mstore(4, to) // append the 'to' argument
            mstore(36, amount) // append the 'amount' argument

            success := and(
                // set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data
                or(
                    and(eq(mload(0), 1), gt(returndatasize(), 31)),
                    iszero(returndatasize())
                ),
                // we use 68 because that's the total length of our calldata (4 + 32 * 2)
                // - counterintuitively, this call() must be positioned after the or() in the
                // surrounding and() because and() evaluates its arguments from right to left
                call(gas(), token, 0, 0, 68, 0, 32)
            )

            mstore(0x60, 0) // restore the zero slot to zero
            mstore(0x40, memPointer) // restore the memPointer
        }
        if (!success) revert TransferFailed();
    }

    function _safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 amount
    ) internal {
        bool success;

        assembly {
            // we'll write our calldata to this slot below, but restore it later
            let memPointer := mload(0x40)
            // write the abi-encoded calldata into memory, beginning with the function selector
            mstore(
                0,
                0x23b872dd00000000000000000000000000000000000000000000000000000000
            )
            mstore(4, from) // append the 'from' argument
            mstore(36, to) // append the 'to' argument
            mstore(68, amount) // append the 'amount' argument

            success := and(
                // set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data
                or(
                    and(eq(mload(0), 1), gt(returndatasize(), 31)),
                    iszero(returndatasize())
                ),
                // we use 100 because that's the total length of our calldata (4 + 32 * 3)
                // - counterintuitively, this call() must be positioned after the or() in the
                // surrounding and() because and() evaluates its arguments from right to left
                call(gas(), token, 0, 0, 100, 0, 32)
            )

            mstore(0x60, 0) // restore the zero slot to zero
            mstore(0x40, memPointer) // restore the memPointer
        }
        if (!success) revert TransferFromFailed();
    }
}

/// @notice Kali DAO share manager interface
interface IKaliShareManager {
    function mintShares(address to, uint256 amount) external payable;
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

enum TripType {
    TASK,
    MISSION
}

struct Trip {
    TripType tripType; // The type of a Trip
    uint8 xp; // The xp of a Trip
    uint40 duration; // The expected duration of a Trip
    uint256[] ids; // A list of related Trips; Mission - Task Ids, Task - Mission Ids
    string detail; // The detail of a Trip
    string title; // The title of a Trip
    address pathfinder; // The creator of a Trip
    uint256 ask; // The ask of a Trip
    uint256 condition; // The condition required for taking on a Trip
}

interface IArm0ryTrips {
    function trips(uint256 _tripId) external view returns (Trip memory);

    function getTripXp(uint256 _tripId) external view returns (uint8);

    function getTripType(uint256 _tripId) external view returns (TripType);

    function getTripDuration(uint256 _tripId) external view returns (uint40);

    function getTripPathfinder(uint256 _tripId) external view returns (address);

    function getTripTitle(uint256 _tripId) external view returns (string memory);

    function getTripIds(uint256 _tripId) external view returns (uint256[] memory);

    function getTripIdsCount(uint256 _tripId) external view returns (uint256);

    function getTripAsk(uint256 _tripId) external view returns (uint256);

    function getTripCondition(uint256 _tripId) external view returns (uint256);
}

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

// IERC20
interface IERC20 {
    function balanceOf(address account) external view returns (uint256);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IArm0ryQuests {
    function questId(address traveler) external view returns (uint8);

    function activeQuests(address traveler) external view returns (uint8);

    function reviewerXp(address traveler) external view returns (uint8);

    function getQuestMissionId(address traveler, uint8 questId) external view returns (uint8);

    function getQuestXp(address traveler, uint8 questId) external view returns (uint8);

    function getQuestStartTime(address traveler, uint8 questId) external view returns (uint40);

    function getQuestProgress(address traveler, uint8 questId) external view returns (uint8);

    function getQuestIncompleteCount(address traveler, uint8 questId) external view returns (uint8);
}

/// @title Arm0ry Quests
/// @notice Quest-to-Earn RPG.
/// @author audsssy.eth

struct Quest {
    uint256 tripId;
    uint40 start;
    uint40 duration;
    uint8 completed;
    uint8 progress;
    uint8 xp;
    uint8 claimed;
}

contract Arm0ryQuests is NFTreceiver {
    using SafeTransferLib for address;

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event QuestStarted(address traveler, uint8 questId, uint256 tripId);
    
    event QuestPaused(address traveler, uint8 questId);

    event QuestResumed(address traveler, uint8 questId);

    event QuestCompleted(address traveler, uint8 questId);

    event TaskSubmitted(address traveler, uint8 questId, uint8 taskId, string homework);

    event TaskReviewed(address reviewer, address traveler, uint8 questId, uint16 taskId, uint8 review);

    event TravelerRewardClaimed(address creator, uint256 amount);

    event CreatorRewardClaimed(address creator, uint256 amount);

    event ReviewerXpUpdated(uint8 xp);

    event Arm0ryFeeUpdatedXpUpdated(uint8 arm0ryFee);

    event ContractsUpdated(IArm0ryTravelers travelers, IArm0ryTrips mission);

    /// -----------------------------------------------------------------------
    /// Custom Errors
    /// -----------------------------------------------------------------------

    error NotAuthorized();

    error InvalidTraveler();

    error NothingToClaim();

    error QuestInactive();

    error CannotResumeQuest();

    error QuestExpired();

    error InvalidReviewer();

    error InsufficientReviewerXp();

    error InvalidReview();

    error InvalidBonus();

    error InvalidArm0ryFee();

    error AlreadyReviewed();

    error TaskNotReadyForReview();

    error TripAlreadyCompleted();

    error AlreadyClaimed();

    error LengthMismatch();

    error NeedMoreCoins();

    /// -----------------------------------------------------------------------
    /// Quest Storage
    /// -----------------------------------------------------------------------
    
    address payable public admin;

    IArm0ryTravelers public travelers;

    IArm0ryTrips public trips;

    // Traveler's history of quests
    mapping(address /* Traveler */ => mapping(uint8 /* questId */ => Quest)) public quests;

    // Counter indicating Quest count per Traveler
    mapping(address /* Traveler */ => uint8 /* questId */) public questId;

    // Homework per Task of an active Quest
    mapping(address /* Traveler */ => mapping(uint256 /* tripId */ => string /* Homework */)) public tripReports;

    // Status indicating if a Trip of an active Quest is ready for review
    mapping(address /* Traveler */ => mapping(uint256 /* tripId */ => bool)) public tripReportReadyForReview;

    // Review results of a Task of a Quest
    mapping(address /* Traveler */ => mapping(uint256 /* tripId */ => mapping(address /* Reviewer */ => bool /* Pass */))) public tripReportReviews;

    // Xp per reviewer
    mapping(address /* Reivewer */ => uint8 /* Review points */) public reviewerXp;

    // Status indicating if a Task of a Quest is completed
    mapping(address /* Traveler */ => mapping(uint256 /* tripId */ => bool /* Completed */)) public isTripCompleted;

    // Rewards per Pathfinder
    mapping(address /* Pathfinder */ => uint16 /* Reward */) public pathfinderRewards;

    // Active quest per Traveler 
    // One active quest per Traveler; max uint8 signals "no active quest"
    mapping(address /* Traveler */ => uint8 /* questId */) public activeQuests;

    // Travelers per Mission Id
    mapping(uint256 /* tripId */ => address[] /* travelers */) public tripping;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(
        IArm0ryTravelers _travelers,
        IArm0ryTrips _trips,
        address payable _admin
    ) {
        travelers = _travelers;
        trips = _trips;
        admin = _admin;

        emit ContractsUpdated(travelers, trips);
    }

    /// -----------------------------------------------------------------------
    /// Quest Logic
    /// -----------------------------------------------------------------------

    /// @notice Traveler to start a new Quest.
    /// @param tripId Identifier of a Mission.
    /// @dev 
    function startQuest(uint256 tripId)
        external
        payable
    {
        uint256 tripCondition = trips.getTripCondition(tripId);
        if (IERC20(admin).balanceOf(msg.sender) < tripCondition) revert NeedMoreCoins();
        if (travelers.balanceOf(msg.sender) == 0) revert InvalidTraveler();

        // Initialize reviewer xp
        uint8 _questId = questId[msg.sender];
        if (_questId == 0) {
            reviewerXp[msg.sender] = 5;
        }

        // Record Quest
        quests[msg.sender][_questId] = Quest({
            tripId: tripId,
            start: uint40(block.timestamp),
            duration: trips.getTripDuration(tripId),
            completed: 0,
            progress: 0,
            xp: 0,
            claimed: 0
        });

        // Add Traveler to list of mission participants
        tripping[tripId].push(msg.sender);

        // Mark active quest for Traveler
        activeQuests[msg.sender] = _questId;
        
        // Update nonce
        unchecked {
            ++_questId;
        }
        questId[msg.sender] = _questId;

        emit QuestStarted(msg.sender, --_questId, tripId);
    }

  /// @notice Traveler to continue an existing but inactive Quest.
    /// @param _questId Identifier of a Quest.
    /// @dev 
    function resumeQuest(uint8 _questId) external payable {
        // Confirm Quest has been paused
        if (quests[msg.sender][_questId].start > 0) revert CannotResumeQuest();

        // Confirm Traveler owns Traveler's Pass to prevent double-questing
        if (travelers.balanceOf(msg.sender) == 0) revert InvalidTraveler();
        
        // Mark Quest as active
        activeQuests[msg.sender] = _questId;

        // Update Quest start time
        quests[msg.sender][_questId].start = uint40(block.timestamp);

        emit QuestResumed(msg.sender, _questId);
    }

    /// @notice Traveler to pause an active Quest.
    /// @param _questId Identifier of a Quest.
    /// @dev 
    function pauseQuest(uint8 _questId) external payable {
        // Confirm Quest is active
        if (_questId != activeQuests[msg.sender]) revert QuestInactive();

        if (travelers.balanceOf(msg.sender) == 0) revert InvalidTraveler();

        // Confirm Quest has not expired
        uint40 questStart = quests[msg.sender][_questId].start;
        uint40 questDuration = quests[msg.sender][_questId].duration;
        if (uint40(block.timestamp) > questStart + questDuration) revert QuestExpired();

        // Use max value to mark Quest as paused
        activeQuests[msg.sender] = type(uint8).max;

        // Update Quest start time and duration
        uint40 diff;
        unchecked { 
            diff = questStart + questDuration - uint40(block.timestamp);
        }
        quests[msg.sender][_questId].start = 0;
        quests[msg.sender][_questId].duration = diff;

        emit QuestPaused(msg.sender, _questId);
    }
    
    /// @notice Traveler to submit Report for Task completion.
    /// @param _questId Identifier of a Quest.
    /// @param tripId Identifier of a Task.
    /// @param report Task report to turn in.
    /// @dev 
    function turnIn(
        uint8 _questId,
        uint8 tripId,
        string calldata report
    ) external payable {
        // Confirm Quest is active
        if (_questId != activeQuests[msg.sender]) revert QuestInactive();

        // Confirm Trip not already completed
        if (isTripCompleted[msg.sender][tripId]) revert TripAlreadyCompleted();
        
        // Traveler must have at least 1 reviewer xp
        if (reviewerXp[msg.sender] == 0) revert InsufficientReviewerXp();

        // Confirm Quest has not expired
        uint40 questStart = quests[msg.sender][_questId].start;
        uint40 questDuration = quests[msg.sender][_questId].duration;
        if (uint40(block.timestamp) > questStart + questDuration) revert QuestExpired();

        // Update Report
        tripReports[msg.sender][tripId] = report;

        // Mark Task ready for review
        tripReportReadyForReview[msg.sender][tripId] = true;

        emit TaskSubmitted(msg.sender, _questId, tripId, report);
    }

    /// -----------------------------------------------------------------------
    /// Review Functions
    /// -----------------------------------------------------------------------

    /// @notice Reviewer to submit review of task completion.
    /// @param traveler Identifier of a Traveler.
    /// @param _questId Identifier of a Quest.
    /// @param review Result of review, i.e., 0, 1, or 2.
    /// @dev 
    function reviewTripReport(
        address traveler,
        uint8 _questId,
        // uint16 tripId,
        bool review
    ) external payable {
        uint256 _tripId = quests[traveler][_questId].tripId;
        Trip memory _trip = trips.trips(_tripId);

        // Reviewer must have completed 2 quests
        if (questId[msg.sender] < 2) revert InvalidReviewer();

        // Traveler must mark Trip for review ahead of time
        if (!tripReportReadyForReview[traveler][_tripId]) revert TaskNotReadyForReview();

        // Reviewer must not have already reviewed instant Task
        if (tripReportReviews[traveler][_tripId][msg.sender]) revert AlreadyReviewed();

        // Record review
        tripReportReviews[traveler][_tripId][msg.sender] = review;

        // Update reviewer xp
        reviewerXp[traveler]--;
        reviewerXp[msg.sender]++;

        if (review) {
            // Mark Task completion
            isTripCompleted[traveler][_tripId] = true;
            tripReportReadyForReview[traveler][_tripId] = false;

            // Retrieve to update Task reward
            uint8 xp = trips.getTripXp(_tripId);
            
            if (_trip.tripType == TripType.TASK) {

            } else {
                
            }



            // Retrieve to update Task completion and progress
            uint8 _completed = quests[traveler][_questId].completed;
            uint8 tripCount = uint8(_trip.ids.length);
            
            // cannot possibly overflow
            uint8 progress;
            unchecked { 
                ++_completed;

                // Update complted Task count
                quests[traveler][_questId].completed = _completed;

                // Update Quest progress
                progress = (_completed / tripCount) * 100;
                quests[traveler][_questId].progress = progress;

                // Update Task reward
                quests[traveler][_questId].xp += xp;

                // Record task creator rewards
                address _pathfinder = _trip.pathfinder;
                pathfinderRewards[_pathfinder] += xp;
            }

            // Update Quest progress
            if (progress == 100) {
                // uint8 missionXp = mission.getMissionXp(missionId);
                // address missionCreator = mission.getMissionCreator(missionId);
                // missionCreatorRewards[missionCreator] += missionXp;
                finalizeQuest(traveler, _questId);
            }
        } 

        // emit TaskReviewed(msg.sender, traveler, _questId, taskId, review);
    }

    /// -----------------------------------------------------------------------
    /// Claim Rewards Functions
    /// -----------------------------------------------------------------------

    /// @notice Travelers may claim rewards.
    /// @dev 
    function claimTravelerReward(uint8 _questId) external payable {
        // Retrieve to inspect reward availability
        uint8 earned = quests[msg.sender][_questId].xp;
        uint8 claimed = quests[msg.sender][_questId].claimed;
        if (earned == 0) revert NothingToClaim();
        if (earned <= claimed) revert NothingToClaim();

        // Calculate reward
        uint8 reward;
        unchecked {
            reward = earned - claimed;
        }

        // Update Quest claim 
        quests[msg.sender][_questId].claimed = earned;

        // Mint rewards
        IKaliShareManager(admin).mintShares(msg.sender, reward * 1e18);

        emit TravelerRewardClaimed(msg.sender, reward * 1e18);
    }

    /// @notice Pathfinders may claim rewards.
    /// @dev 
    function claimCreatorReward() external payable {
        if (pathfinderRewards[msg.sender] == 0) revert NothingToClaim();

        uint16 reward = pathfinderRewards[msg.sender];

        // Update Creator rewards
        pathfinderRewards[msg.sender] = 0;

        // Mint rewards
        IKaliShareManager(admin).mintShares(msg.sender, reward * 1e18);

        emit CreatorRewardClaimed(msg.sender, reward * 1e18);
    }

    /// -----------------------------------------------------------------------
    /// Arm0ry Functions
    /// -----------------------------------------------------------------------

    /// @notice Update Arm0ry contracts.
    /// @param _travelers Contract address of Arm0ryTraveler.sol.
    /// @param _trips Contract address of Arm0ryMission.sol.
    /// @dev 
    function updateContracts(IArm0ryTravelers _travelers, IArm0ryTrips _trips) external payable {
        if (msg.sender != admin) revert NotAuthorized();
        travelers = _travelers;
        trips = _trips;

        emit ContractsUpdated(travelers, trips);
    }

    /// @notice Update Reviewer xp.
    /// @param reviewer Reviewer's address.
    /// @param _xp Xp to assign to Reviewer.
    /// @dev 
    function updateReviewerXp(address reviewer, uint8 _xp) external payable {
        if (msg.sender != admin) revert NotAuthorized();
        reviewerXp[reviewer] = _xp;

        emit ReviewerXpUpdated(_xp);
    }

    /// @notice Withdraw funds to Arm0ry.
    /// @dev 
    function withdraw() external payable {
        if (msg.sender != admin) revert NotAuthorized();
        admin.transfer(address(this).balance);
    }

    /// -----------------------------------------------------------------------
    /// Getter Functions
    /// -----------------------------------------------------------------------

    function getQuestTripId(address _traveler, uint8 _questId) external view returns (uint256) {
        return quests[_traveler][_questId].tripId;
    }

    function getQuestXp(address _traveler, uint8 _questId) external view returns (uint8) {
        return quests[_traveler][_questId].xp;
    }

    function getQuestStartTime(address _traveler, uint8 _questId) external view returns (uint40) {
        return quests[_traveler][_questId].start;
    }
    
    function getQuestProgress(address _traveler, uint8 _questId) external view returns (uint8) {
        return quests[_traveler][_questId].progress;
    }

    /// -----------------------------------------------------------------------
    /// Internal Functions
    /// -----------------------------------------------------------------------

    /// @notice Return locked NFT & staked arm0ry token.
    /// @param traveler .
    /// @param _questId .
    /// @dev 
    function finalizeQuest(address traveler, uint8 _questId) internal {
  
        // Clean up Quest
        quests[traveler][_questId].start = type(uint40).max;

        // Mark Quest as "Inactive" 
        activeQuests[msg.sender] = type(uint8).max;

        emit QuestCompleted(traveler, _questId);
    }

    receive() external payable {}
}