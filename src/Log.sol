// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {ILog, Activity, Touchpoint} from "./interface/ILog.sol";
import {IBulletin, List, Item} from "./interface/IBulletin.sol";
import {LibBitmap} from "solady/utils/LibBitmap.sol";

/// @title Log
/// @notice A database management system to log data from interacting with Bulletin.
/// @author audsssy.eth
contract Log {
    using LibBitmap for LibBitmap.Bitmap;

    event Logged(
        address user, address bulletin, uint256 listId, uint256 itemId, uint256 nonce, bool review, bytes data
    );
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
        keccak256("Log(address bulletin, uint256 listId ,uint256 itemId, string feedback, bytes data)");

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

    function log(address bulletin, uint256 listId, uint256 itemId, string calldata feedback, bytes calldata data)
        external
        payable
    {
        if (IBulletin(bulletin).hasItemExpired(itemId)) revert InvalidItem();
        if (!IBulletin(bulletin).checkIsItemInList(itemId, listId) || IBulletin(bulletin).hasListExpired(listId)) {
            revert InvalidList();
        }

        _log(msg.sender, bulletin, listId, itemId, feedback, data);
    }

    function logBySig(
        address signer,
        address bulletin,
        uint256 listId,
        uint256 itemId,
        string calldata feedback,
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
                keccak256(abi.encode(LOG_TYPEHASH, signer, bulletin, listId, itemId, feedback, data))
            )
        );

        address recoveredAddress = ecrecover(digest, v, r, s);
        if (recoveredAddress == address(0) || recoveredAddress != signer) revert NotAuthorized();

        _log(signer, bulletin, listId, itemId, feedback, data);
    }

    /// @notice Sponsor log is used in combination with gas buddy, which provide gas subsidy.
    function sponsoredLog(
        address bulletin,
        uint256 listId,
        uint256 itemId,
        string calldata feedback,
        bytes calldata data
    ) external payable onlyGasBuddy {
        _log(address(0), bulletin, listId, itemId, feedback, data);
    }

    function _log(
        address user,
        address bulletin,
        uint256 listId,
        uint256 itemId,
        string calldata feedback,
        bytes calldata data
    ) internal {
        uint256 id = userActivityLookup[user][keccak256(abi.encodePacked(bulletin, listId))];
        Item memory item = IBulletin(bulletin).getItem(itemId);
        bool review = (item.review) ? false : true;

        if (id == 0) {
            unchecked {
                userActivityLookup[user][keccak256(abi.encodePacked(bulletin, listId))] = ++activityId;
            }

            activities[activityId].user = user;
            activities[activityId].bulletin = bulletin;
            activities[activityId].listId = listId;

            activities[activityId].touchpoints[activities[activityId].nonce] =
                Touchpoint({pass: review, itemId: itemId, feedback: feedback, data: data});

            unchecked {
                ++activities[activityId].nonce;
            }
        } else {
            activities[id].touchpoints[activities[id].nonce] =
                Touchpoint({pass: review, itemId: itemId, feedback: feedback, data: data});
            unchecked {
                ++activities[id].nonce;
            }
        }

        if (IBulletin(bulletin).isLoggerAuthorized(address(this)) && review) IBulletin(bulletin).submit(itemId);

        emit Logged(user, bulletin, listId, itemId, activities[activityId].nonce, review, data);
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

        if (
            order > nonce || bulletin != _bulletin || listId != _listId
                || activities[id].touchpoints[order].itemId != itemId
        ) revert InvalidEvaluation();

        if (!IBulletin(bulletin).checkIsItemInList(itemId, listId) || IBulletin(bulletin).hasListExpired(listId)) {
            revert InvalidList();
        }

        activities[id].touchpoints[order].pass = pass;
        if (IBulletin(bulletin).isLoggerAuthorized(address(this)) && pass) IBulletin(bulletin).submit(itemId);

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

    function getActivityTouchpoints(uint256 id) external returns (Touchpoint[] memory, uint256) {
        bitmap.unsetBatch(0, 256);
        uint256 progress;
        (, address aBulletin, uint256 aListId, uint256 aNonce) = getActivityData(id);
        Touchpoint[] memory tps = new Touchpoint[](aNonce);
        List memory list = IBulletin(aBulletin).getList(aListId);

        uint256 length = list.itemIds.length;

        for (uint256 i; i < aNonce; ++i) {
            tps[i] = activities[id].touchpoints[i];

            /// @dev Calculate percentage of completion.
            for (uint256 j; j < length; ++j) {
                if (activities[id].touchpoints[i].itemId == list.itemIds[j]) {
                    if (!bitmap.get(list.itemIds[j])) {
                        unchecked {
                            (tps[i].pass) ? ++progress : progress;
                        }
                        bitmap.set(list.itemIds[j]);
                    }
                } else {
                    continue;
                }
            }
        }

        return (tps, progress * 100 / length);
    }
}
