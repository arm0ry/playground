// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {ILog, Activity, Touchpoint} from "./interface/ILog.sol";
import {IBulletin, List, Item} from "./interface/IBulletin.sol";
import {LibBitmap} from "solady/utils/LibBitmap.sol";

/// @title Log
/// @notice A database management system to log data from interacting with Bulletin.
/// @author audsssy.eth
contract Log {
    event Logged(address user, address bulletin, uint256 listId, uint256 itemId, bytes data);
    event Evaluated(uint256 activityId, address bulletin, uint256 listId, uint256 nonce, bool pass);

    error NotAuthorized();
    error InvalidEvaluation();
    error InvalidReviewer();
    error InvalidBot();
    error InvalidList();
    error InvalidItem();

    /// -----------------------------------------------------------------------
    /// Activity Storage
    /// -----------------------------------------------------------------------

    using LibBitmap for LibBitmap.Bitmap;

    LibBitmap.Bitmap bitmap;

    address public dao;
    address public gasBuddy;
    uint256 public activityId;

    // Mapping of activities by activityId.
    mapping(uint256 => Activity) public activities;

    // Mapping of activities by user.
    mapping(address => mapping(bytes32 => uint256)) public userActivityLookup;

    // Mapping of eligible activities for review by reviewer.
    mapping(address => mapping(bytes32 => bool)) public isReviewer;

    /// -----------------------------------------------------------------------
    /// Sign Storage
    /// -----------------------------------------------------------------------

    uint256 internal INITIAL_CHAIN_ID;
    bytes32 internal INITIAL_DOMAIN_SEPARATOR;
    bytes32 public constant LOG_TYPEHASH =
        keccak256("Log(address bulletin, uint256 listId ,uint256 itemId, bytes data)");

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

    modifier onlyGasBuddy() {
        if (gasBuddy != msg.sender) revert NotAuthorized();
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
    /// Log Logic
    /// -----------------------------------------------------------------------

    function log(address bulletin, uint256 listId, uint256 itemId, bytes calldata data) external payable {
        if (IBulletin(bulletin).hasItemExpired(itemId)) revert InvalidItem();
        if (!IBulletin(bulletin).checkIsItemInList(itemId, listId) || IBulletin(bulletin).hasListExpired(listId)) {
            revert InvalidList();
        }

        _log(msg.sender, bulletin, listId, itemId, data);
    }

    function logBySig(
        address signer,
        address bulletin,
        uint256 listId,
        uint256 itemId,
        bytes calldata data,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable {
        // Validate signed message.
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(abi.encode(LOG_TYPEHASH, signer, bulletin, listId, itemId, data))
            )
        );

        address recoveredAddress = ecrecover(digest, v, r, s);
        if (recoveredAddress == address(0) || recoveredAddress != signer) revert NotAuthorized();

        _log(signer, bulletin, listId, itemId, data);
    }

    function sponsoredLog(address bulletin, uint256 listId, uint256 itemId, bytes calldata data)
        external
        payable
        onlyGasBuddy
    {
        _log(address(0), bulletin, listId, itemId, data);
    }

    function _log(address user, address bulletin, uint256 listId, uint256 itemId, bytes calldata data) internal {
        uint256 id = userActivityLookup[user][keccak256(abi.encodePacked(bulletin, listId))];

        if (id == 0) {
            unchecked {
                ++activityId;
            }

            if (user == address(0)) user = address(uint160(uint256(bytes32(abi.encodePacked(activityId)))));
            activities[activityId].user = user;
            activities[activityId].bulletin = bulletin;
            activities[activityId].listId = listId;

            Item memory item = IBulletin(bulletin).getItem(itemId);

            activities[activityId].touchpoints[activities[activityId].nonce] =
                Touchpoint({pass: (item.review) ? false : true, itemId: itemId, data: data});

            unchecked {
                ++activities[activityId].nonce;
            }
        } else {
            activities[id].touchpoints[activities[id].nonce] = Touchpoint({pass: false, itemId: itemId, data: data});

            unchecked {
                ++activities[id].nonce;
            }
        }

        IBulletin(bulletin).submit(itemId);

        emit Logged(user, bulletin, listId, itemId, data);
    }

    /// -----------------------------------------------------------------------
    /// Evaluate
    /// -----------------------------------------------------------------------

    function evaluate(uint256 id, address bulletin, uint256 listId, uint256 order, uint256 itemId, bool pass)
        external
        payable
        onlyReviewer(msg.sender, bulletin, listId)
    {
        (, address _bulletin, uint256 _listId, uint256 nonce) = getActivityData(id);

        // TODO: require itemId retrieved from order matches supplied itemId
        if (order > nonce || bulletin != _bulletin || listId != _listId) revert InvalidEvaluation();

        if (!IBulletin(bulletin).checkIsItemInList(itemId, listId) || IBulletin(bulletin).hasListExpired(listId)) {
            revert InvalidList();
        }

        if (order == 0) revert InvalidEvaluation();
        activities[id].touchpoints[order].pass = pass;

        emit Evaluated(id, bulletin, listId, order, pass);
    }

    /// -----------------------------------------------------------------------
    /// Activity - Getter
    /// -----------------------------------------------------------------------

    function getActivityData(uint256 id)
        public
        view
        returns (address user, address bulletin, uint256 listId, uint256 nonce)
    {
        user = activities[id].user;
        bulletin = activities[id].bulletin;
        listId = activities[id].listId;
        nonce = activities[id].nonce;
    }

    function getActivityTouchpoints(uint256 id)
        external
        returns (Touchpoint[] memory touchpoints, uint256 percentageOfCompletion)
    {
        uint256 progress;

        (, address bulletin, uint256 listId, uint256 nonce) = getActivityData(id);
        List memory list = IBulletin(bulletin).getList(listId);
        uint256 itemCount = list.itemIds.length;

        for (uint256 i; i <= itemCount; ++i) {
            for (uint256 j; j <= nonce; ++j) {
                /// @dev Calculate percentage of completion.
                if (activities[id].touchpoints[j].itemId == list.itemIds[i]) {
                    if (!bitmap.get(i)) {
                        bitmap.set(i);
                        unchecked {
                            ++progress;
                        }
                    }
                }

                /// @dev Retrieve touchpoints.
                (nonce != touchpoints.length) ? touchpoints[j] = activities[id].touchpoints[j] : touchpoints[j];
            }
        }

        unchecked {
            percentageOfCompletion = progress * 100 / itemCount;
        }
    }
}
