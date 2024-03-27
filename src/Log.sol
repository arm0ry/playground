// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

struct Activity {
    address user;
    address bulletin;
    uint256 listId;
    uint256 nonce;
    mapping(uint256 => Interaction) interactions;
}
// mapping(uint256 => bool[]) evaluations;

struct Interaction {
    bool pass;
    uint256 itemId;
    bytes data;
}

contract Log {
    event Responded();
    event Reviewed();

    error NotAuthorized();
    error InvalidEvaluation();
    error InvalidReviewer();

    error InvalidBot();
    error InvalidMission();
    error InvalidTask();

    /// -----------------------------------------------------------------------
    /// Activity Storage
    /// -----------------------------------------------------------------------

    address public dao;
    address public gasBuddy;
    uint256 public activityId;

    // Mapping of activities by activityId.
    mapping(uint256 => Activity) public activities;

    // Mapping of activities by user.
    mapping(address => mapping(bytes32 => uint256)) public userActivityLookup;

    // Mapping of eligible activities by reviewer.
    mapping(address => mapping(bytes32 => bool)) public isReviewer;

    /// -----------------------------------------------------------------------
    /// Sign Storage
    /// -----------------------------------------------------------------------

    uint256 internal INITIAL_CHAIN_ID;
    bytes32 internal INITIAL_DOMAIN_SEPARATOR;
    bytes32 public constant INTERACT_TYPEHASH =
        keccak256("Interact(uint256 activityId,address bulletin, uint256 listId ,uint256 itemId, bytes data)");

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
                keccak256(bytes("Log")),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

    /// -----------------------------------------------------------------------
    /// Modifier
    /// -----------------------------------------------------------------------

    modifier onlyDao() {
        if (dao != msg.sender) revert NotAuthorized();
        _;
    }

    modifier onlyReviewer(address reviewer, address bulletin, uint256 listId) {
        if (!isReviewer[reviewer][keccak256(abi.encodePacked(bulletin, listId))]) revert InvalidReviewer();
        _;
    }

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(address _dao) {
        dao = _dao;
    }

    /// -----------------------------------------------------------------------
    /// DAO Logic
    /// -----------------------------------------------------------------------

    function setGasBuddy(address buddy) external payable onlyDao {
        gasBuddy = buddy;
    }

    function getGasBuddy() public view returns (address) {
        return gasBuddy;
    }

    function setReviewer(address reviewer, address bulletin, uint256 listId) external payable onlyDao {
        isReviewer[reviewer][keccak256(abi.encodePacked(bulletin, listId))] = true;
    }

    /// -----------------------------------------------------------------------
    /// Interact with an activity
    /// -----------------------------------------------------------------------

    function interact(address bulletin, uint256 listId, uint256 itemId, bytes calldata data) external payable {
        if (IBulletin(bulletin).hasItemExpired(itemId)) revert InvalidItem();
        if (!IBulletin(bulletin).isItemInList(itemId, listId) || IBulletin(bulletin).hasListExpired(listId)) {
            revert InvalidList();
        }

        uint256 nonce;
        uint256 id = userActivityLookup[msg.sender][keccak256(abi.encodePacked(bulletin, listId))];

        if (id == 0) {
            unchecked {
                ++activityId;

                nonce = ++activities[activityId].nonce;
            }

            activities[activityId].user = msg.sender;
            activities[activityId].bulletin = bulletin;
            activities[activityId].listId = listId;

            activities[activityId].interactions[nonce] = Interaction({pass: false, itemId: itemId, data: data});
        } else {
            nonce = ++activities[id].nonce;
            activities[id].interactions[nonce] = Interaction({pass: false, itemId: itemId, data: data});
        }
    }

    function interactBySig() external payable {}

    function sponsoredInteract() external payable {}

    /// -----------------------------------------------------------------------
    /// Evaluate
    /// -----------------------------------------------------------------------

    function evaluate(uint256 id, address bulletin, uint256 listId, uint256 nonce, bool pass)
        external
        payable
        onlyReviewer(msg.sender, bulletin, listId)
    {
        if (!IBulletin(bulletin).isItemInList(itemId, listId) || IBulletin(bulletin).hasListExpired(listId)) {
            revert InvalidList();
        }

        if (nonce == 0) revert InvalidEvaluation();
        if (pass) activities[id].interactions[nonce].pass = pass;
    }

    /// -----------------------------------------------------------------------
    /// Activity - Getter
    /// -----------------------------------------------------------------------

    function getActvitiyData(uint256 id) external view {}

    function getActvitiyInteractions(uint256 id) external view {}

    function getActvitiyEvaluations(uint256 id) external view {}
}
