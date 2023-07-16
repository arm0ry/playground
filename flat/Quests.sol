// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

interface IMissions {
    function isTaskInMission(uint256 missionId, uint256 taskId) external returns (bool);

    function getTask(uint256 taskId) external view returns (uint8, uint40, address, string memory, string memory);

    function getMission(uint256 _missionId)
        external
        view
        returns (uint8, uint40, uint8[] memory, string memory, string memory, address, uint256, uint256, uint256);
}

/// @notice Kali DAO share manager interface
interface IKaliTokenManager {
    function mintShares(address to, uint256 amount) external payable;

    function burnShares(address from, uint256 amount) external payable;

    function balanceOf(address account) external view returns (uint256);

}

interface IERC165 {
    /// @notice Query if a contract implements an interface
    /// @param interfaceID The interface identifier, as specified in ERC-165
    /// @dev Interface identification is specified in ERC-165. This function
    /// uses less than 30,000 gas.
    /// @return `true` if the contract implements `interfaceID` and
    /// `interfaceID` is not 0xffffffff, `false` otherwise
    function supportsInterface(bytes4 interfaceID) external view returns (bool);
}

/// @title ERC-721 Non-Fungible Token Standard
/// @dev See https://eips.ethereum.org/EIPS/eip-721
/// Note: the ERC-165 identifier for this interface is 0x80ac58cd.
interface IERC721 is IERC165 {
    /// @dev This emits when ownership of any NFT changes by any mechanism.
    /// This event emits when NFTs are created (`from` == 0) and destroyed
    /// (`to` == 0). Exception: during contract creation, any number of NFTs
    /// may be created and assigned without emitting Transfer. At the time of
    /// any transfer, the approved address for that NFT (if any) is reset to none.
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);

    /// @dev This emits when the approved address for an NFT is changed or
    /// reaffirmed. The zero address indicates there is no approved address.
    /// When a Transfer event emits, this also indicates that the approved
    /// address for that NFT (if any) is reset to none.
    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);

    /// @dev This emits when an operator is enabled or disabled for an owner.
    /// The operator can manage all NFTs of the owner.
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    /// @notice Count all NFTs assigned to an owner
    /// @dev NFTs assigned to the zero address are considered invalid, and this
    /// function throws for queries about the zero address.
    /// @param _owner An address for whom to query the balance
    /// @return The number of NFTs owned by `_owner`, possibly zero
    function balanceOf(address _owner) external view returns (uint256);

    /// @notice Find the owner of an NFT
    /// @dev NFTs assigned to zero address are considered invalid, and queries
    /// about them do throw.
    /// @param _tokenId The identifier for an NFT
    /// @return The address of the owner of the NFT
    function ownerOf(uint256 _tokenId) external view returns (address);

    /// @notice Transfers the ownership of an NFT from one address to another address
    /// @dev Throws unless `msg.sender` is the current owner, an authorized
    /// operator, or the approved address for this NFT. Throws if `_from` is
    /// not the current owner. Throws if `_to` is the zero address. Throws if
    /// `_tokenId` is not a valid NFT. When transfer is complete, this function
    /// checks if `_to` is a smart contract (code size > 0). If so, it calls
    /// `onERC721Received` on `_to` and throws if the return value is not
    /// `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`.
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    /// @param data Additional data with no specified format, sent in call to `_to`
    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes calldata data) external payable;

    /// @notice Transfers the ownership of an NFT from one address to another address
    /// @dev This works identically to the other function with an extra data parameter,
    /// except this function just sets data to "".
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external payable;

    /// @notice Transfer ownership of an NFT -- THE CALLER IS RESPONSIBLE
    /// TO CONFIRM THAT `_to` IS CAPABLE OF RECEIVING NFTS OR ELSE
    /// THEY MAY BE PERMANENTLY LOST
    /// @dev Throws unless `msg.sender` is the current owner, an authorized
    /// operator, or the approved address for this NFT. Throws if `_from` is
    /// not the current owner. Throws if `_to` is the zero address. Throws if
    /// `_tokenId` is not a valid NFT.
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    function transferFrom(address _from, address _to, uint256 _tokenId) external payable;

    /// @notice Change or reaffirm the approved address for an NFT
    /// @dev The zero address indicates there is no approved address.
    /// Throws unless `msg.sender` is the current NFT owner, or an authorized
    /// operator of the current owner.
    /// @param _approved The new approved NFT controller
    /// @param _tokenId The NFT to approve
    function approve(address _approved, uint256 _tokenId) external payable;

    /// @notice Enable or disable approval for a third party ("operator") to manage
    /// all of `msg.sender`'s assets
    /// @dev Emits the ApprovalForAll event. The contract MUST allow
    /// multiple operators per owner.
    /// @param _operator Address to add to the set of authorized operators
    /// @param _approved True if the operator is approved, false to revoke approval
    function setApprovalForAll(address _operator, bool _approved) external;

    /// @notice Get the approved address for a single NFT
    /// @dev Throws if `_tokenId` is not a valid NFT.
    /// @param _tokenId The NFT to find the approved address for
    /// @return The approved address for this NFT, or the zero address if there is none
    function getApproved(uint256 _tokenId) external view returns (address);

    /// @notice Query if an address is an authorized operator for another address
    /// @param _owner The address that owns the NFTs
    /// @param _operator The address that acts on behalf of the owner
    /// @return True if `_operator` is an approved operator for `_owner`, false otherwise
    function isApprovedForAll(address _owner, address _operator) external view returns (bool);
}

/// @dev Note: the ERC-165 identifier for this interface is 0x150b7a02.
interface IERC721TokenReceiver {
    /// @notice Handle the receipt of an NFT
    /// @dev The ERC721 smart contract calls this function on the recipient
    /// after a `transfer`. This function MAY throw to revert and reject the
    /// transfer. Return of other than the magic value MUST result in the
    /// transaction being reverted.
    /// Note: the contract address is always the message sender.
    /// @param _operator The address which called `safeTransferFrom` function
    /// @param _from The address which previously owned the token
    /// @param _tokenId The NFT identifier which is being transferred
    /// @param _data Additional data with no specified format
    /// @return `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
    ///  unless throwing
    function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes calldata _data)
        external
        returns (bytes4);
}

/// @title ERC-721 Non-Fungible Token Standard, optional metadata extension
/// @dev See https://eips.ethereum.org/EIPS/eip-721
/// Note: the ERC-165 identifier for this interface is 0x5b5e139f.
interface IERC721Metadata is IERC721 {
    /// @notice A descriptive name for a collection of NFTs in this contract
    function name() external view returns (string memory _name);

    /// @notice An abbreviated name for NFTs in this contract
    function symbol() external view returns (string memory _symbol);

    /// @notice A distinct Uniform Resource Identifier (URI) for a given asset.
    /// @dev Throws if `_tokenId` is not a valid NFT. URIs are defined in RFC
    /// 3986. The URI may point to a JSON file that conforms to the "ERC721
    /// Metadata JSON Schema".
    function tokenURI(uint256 _tokenId) external view returns (string memory);
}

/// @title ERC-721 Non-Fungible Token Standard, optional enumeration extension
/// @dev See https://eips.ethereum.org/EIPS/eip-721
/// Note: the ERC-165 identifier for this interface is 0x780e9d63.
interface IERC721Enumerable is IERC721 {
    /// @notice Count NFTs tracked by this contract
    /// @return A count of valid NFTs tracked by this contract, where each one of
    /// them has an assigned and queryable owner not equal to the zero address
    function totalSupply() external view returns (uint256);

    /// @notice Enumerate valid NFTs
    /// @dev Throws if `_index` >= `totalSupply()`.
    /// @param _index A counter less than `totalSupply()`
    /// @return The token identifier for the `_index`th NFT,
    /// (sort order not specified)
    function tokenByIndex(uint256 _index) external view returns (uint256);

    /// @notice Enumerate NFTs assigned to an owner
    /// @dev Throws if `_index` >= `balanceOf(_owner)` or if
    /// `_owner` is the zero address, representing invalid NFTs.
    /// @param _owner An address where we are interested in NFTs owned by them
    /// @param _index A counter less than `balanceOf(_owner)`
    /// @return The token identifier for the `_index`th NFT assigned to `_owner`,
    /// (sort order not specified)
    function tokenOfOwnerByIndex(address _owner, uint256 _index) external view returns (uint256);
}

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
