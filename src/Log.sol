// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {ILog, Activity, Touchpoint} from "./interface/ILog.sol";
import {IBulletin, List, Item} from "./interface/IBulletin.sol";
import {OwnableRoles} from "src/auth/OwnableRoles.sol";

// import {LibBitmap} from "solady/utils/LibBitmap.sol";

/// @title Log
/// @notice A database management system to log data from interacting with Bulletin.
/// @author audsssy.eth
contract Log is OwnableRoles {
    event Logged(
        address user, address bulletin, uint256 listId, uint256 itemId, uint256 nonce, bool review, bytes data
    );
    event Evaluated(uint256 logId, address bulletin, uint256 listId, uint256 nonce, bool pass);

    error NotAuthorized();
    error InvalidEvaluation();
    error InvalidList();
    error InvalidItem();

    /// -----------------------------------------------------------------------
    /// Storage
    /// -----------------------------------------------------------------------

    /// @notice Role constants.
    uint256 public constant GASBUDDIES = 1 << 0;
    uint256 public constant REVIEWERS = 1 << 1;

    uint256 public logId;

    // Mapping of logs by logId.
    mapping(uint256 => Activity) public logs;

    // Mapping of logs by user.
    // user => (keccak256(abi.encodePacked(bulletin, listId) => logId)
    mapping(address => mapping(bytes32 => uint256)) public lookupLogId;

    /// -----------------------------------------------------------------------
    /// Sign Storage
    /// -----------------------------------------------------------------------

    uint256 internal INITIAL_CHAIN_ID;
    bytes32 internal INITIAL_DOMAIN_SEPARATOR;
    bytes32 public constant LOG_TYPEHASH =
        keccak256("Log(address bulletin, uint256 listId, uint256 itemId, string feedback, bytes data)");

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
    /// Constructor & Modifier
    /// -----------------------------------------------------------------------

    function initialize(address owner) public {
        _initializeOwner(owner);
    }

    modifier checkList(address bulletin, uint256 listId, uint256 itemId) {
        if (!IBulletin(bulletin).checkIsItemInList(itemId, listId)) revert InvalidList();
        if (itemId == 0 && IBulletin(bulletin).hasListExpired(listId)) revert InvalidList();
        _;
    }

    /// -----------------------------------------------------------------------
    /// Log Logic
    /// -----------------------------------------------------------------------

    function log(address bulletin, uint256 listId, uint256 itemId, string calldata feedback, bytes calldata data)
        external
        payable
        checkList(bulletin, listId, itemId)
    {
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
    ) external payable checkList(bulletin, listId, itemId) {
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
    ) external payable onlyRoles(GASBUDDIES) checkList(bulletin, listId, itemId) {
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
        uint256 id = lookupLogId[user][keccak256(abi.encodePacked(bulletin, listId))];
        Item memory item = IBulletin(bulletin).getItem(itemId);
        bool review = (item.review) ? false : true;
        uint256 LOGGERS = IBulletin(bulletin).LOGGERS();

        if (id == 0) {
            unchecked {
                lookupLogId[user][keccak256(abi.encodePacked(bulletin, listId))] = ++logId;
            }

            logs[logId].user = user;
            logs[logId].bulletin = bulletin;
            logs[logId].listId = listId;

            logs[logId].touchpoints[logs[logId].nonce] =
                Touchpoint({pass: review, itemId: itemId, feedback: feedback, data: data});

            unchecked {
                ++logs[logId].nonce;
            }
        } else {
            logs[id].touchpoints[logs[id].nonce] =
                Touchpoint({pass: review, itemId: itemId, feedback: feedback, data: data});
            unchecked {
                ++logs[id].nonce;
            }
        }

        if (IBulletin(bulletin).hasAnyRole(address(this), LOGGERS) && review) {
            IBulletin(bulletin).submit(itemId);
        }

        emit Logged(user, bulletin, listId, itemId, logs[logId].nonce, review, data);
    }

    /// -----------------------------------------------------------------------
    /// Evaluate
    /// -----------------------------------------------------------------------

    function evaluate(uint256 id, address bulletin, uint256 listId, uint256 order, uint256 itemId, bool pass)
        external
        payable
        onlyRoles(REVIEWERS)
    {
        uint256 LOGGERS = IBulletin(bulletin).LOGGERS();
        (, address _bulletin, uint256 _listId, uint256 nonce) = getLog(id);

        if (order > nonce || bulletin != _bulletin || listId != _listId || logs[id].touchpoints[order].itemId != itemId)
        {
            revert InvalidEvaluation();
        }

        if (!IBulletin(bulletin).checkIsItemInList(itemId, listId)) revert InvalidList();

        logs[id].touchpoints[order].pass = pass;
        if (IBulletin(bulletin).hasAnyRole(address(this), LOGGERS) && pass) {
            IBulletin(bulletin).submit(itemId);
        }

        emit Evaluated(id, bulletin, listId, order, pass);
    }

    /// -----------------------------------------------------------------------
    /// Activity - Getter
    /// -----------------------------------------------------------------------

    function getLog(uint256 _logId)
        public
        view
        returns (address user, address bulletin, uint256 listId, uint256 nonce)
    {
        user = logs[_logId].user;
        bulletin = logs[_logId].bulletin;
        listId = logs[_logId].listId;
        nonce = logs[_logId].nonce;
    }

    function getLogTouchpoints(uint256 _logId) external view returns (Touchpoint[] memory) {
        (,,, uint256 aNonce) = getLog(_logId);
        Touchpoint[] memory tps = new Touchpoint[](aNonce);

        for (uint256 i; i < aNonce; ++i) {
            tps[i] = logs[_logId].touchpoints[i];
        }

        return tps;
    }
}
