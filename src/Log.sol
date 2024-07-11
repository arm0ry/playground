// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {ILog, Activity, Touchpoint} from "src/interface/ILog.sol";
import {IBulletin, List, Item} from "src/interface/IBulletin.sol";
import {ICurrency} from "src/interface/ICurrency.sol";
import {ITokenMinter} from "src/interface/ITokenMinter.sol";
import {OwnableRoles} from "src/auth/OwnableRoles.sol";

/// @title Log
/// @notice A database management system to log data from interacting with Bulletin.
/// @author audsssy.eth
contract Log is OwnableRoles {
    event Logged(
        uint256 role,
        address user,
        address bulletin,
        uint256 listId,
        uint256 itemId,
        uint256 nonce,
        bool review,
        bytes data
    );
    event Evaluated(uint256 logId, address bulletin, uint256 listId, uint256 nonce, bool pass);

    error InvalidEvaluation();
    error InvalidLogger();
    error InvalidList();
    error InvalidItem();

    /// -----------------------------------------------------------------------
    /// Storage
    /// -----------------------------------------------------------------------

    /// @notice Currency faucet.
    address public currency;

    uint256 public logId;

    // Mapping of logs by logId.
    mapping(uint256 => Activity) public logs;

    // Mapping of logs by user.
    // user => (keccak256(abi.encodePacked(bulletin, listId) => logId)
    mapping(address => mapping(bytes32 => uint256)) public lookupLogId;

    // Mapping of touchpoints by encoded itemId data
    // keccak256(abi.encodePacked(bulletin, listId, itemId) => nonce for itemId
    mapping(bytes32 => uint256) nonceByItemId;
    // keccak256(abi.encodePacked(bulletin, listId, itemId) => nonce for itemId => Touchpoint
    mapping(bytes32 => mapping(uint256 => Touchpoint)) public touchpointByItemId;

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
        if (itemId == 0) {
            if (IBulletin(bulletin).hasListExpired(listId)) revert InvalidList();
        } else {
            if (IBulletin(bulletin).hasItemExpired(itemId)) revert InvalidItem();
            if (!IBulletin(bulletin).checkIsItemInList(itemId, listId)) revert InvalidList();
        }

        _;
    }

    /// -----------------------------------------------------------------------
    /// Log Logic
    /// -----------------------------------------------------------------------

    /// @notice Public logging.
    function log(
        uint256 role,
        address bulletin,
        uint256 listId,
        uint256 itemId,
        string calldata feedback,
        bytes calldata data
    ) external payable onlyRoles(role) checkList(bulletin, listId, itemId) {
        _log(role, msg.sender, bulletin, listId, itemId, feedback, data);
    }

    /// @notice Token ownership logging.
    function logByToken(
        uint256 role,
        address token,
        uint256 tokenId,
        uint256 tokenRole,
        uint256 itemId,
        string calldata feedback,
        bytes calldata data
    ) external payable onlyRoles(role) {
        // Check token role.
        if (!hasAnyRole(address(uint160(uint256(keccak256(abi.encode(token, tokenId))))), tokenRole)) {
            revert Unauthorized();
        }

        // Check user token balance.
        if (ITokenMinter(token).balanceOf(msg.sender, tokenId) == 0) revert Unauthorized();

        // Retrieve token source.
        (, address bulletin, uint256 listId, address logger) = ITokenMinter(token).getTokenSource(tokenId);
        if (logger != address(this)) revert InvalidLogger();

        _log(role, msg.sender, bulletin, listId, itemId, feedback, data);

        // TODO: Consider burn by token curve instead.
        ITokenMinter(token).burnByLogger(msg.sender, tokenId);
    }

    /// @notice Permissionless logging by signature.
    function logBySig(
        uint256 role,
        uint256 signerRole,
        address signer,
        address bulletin,
        uint256 listId,
        uint256 itemId,
        string calldata feedback,
        bytes calldata data,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable onlyRoles(role) checkList(bulletin, listId, itemId) {
        if (!hasAnyRole(signer, signerRole)) revert Unauthorized();

        // Validate signed message.
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(abi.encode(LOG_TYPEHASH, signer, bulletin, listId, itemId, feedback, data))
            )
        );

        address recoveredAddress = ecrecover(digest, v, r, s);
        if (recoveredAddress == address(0) || recoveredAddress != signer) revert Unauthorized();

        _log(signerRole, signer, bulletin, listId, itemId, feedback, data);
    }

    function _log(
        uint256 role,
        address user,
        address bulletin,
        uint256 listId,
        uint256 itemId,
        string calldata feedback,
        bytes calldata data
    ) internal {
        uint256 id = lookupLogId[user][keccak256(abi.encodePacked(bulletin, listId))];

        // Check if review by reviewer is required.
        Item memory item = IBulletin(bulletin).getItem(itemId);
        bool review = (item.review) ? false : true;

        // Set up touchpoint.
        Touchpoint memory tp = Touchpoint({role: role, pass: review, itemId: itemId, feedback: feedback, data: data});

        // Store touchpoint by logId.
        if (id == 0) {
            unchecked {
                lookupLogId[user][keccak256(abi.encodePacked(bulletin, listId))] = ++logId;
            }

            logs[logId].user = user;
            logs[logId].bulletin = bulletin;
            logs[logId].listId = listId;

            logs[logId].touchpoints[logs[logId].nonce] = tp;

            unchecked {
                ++logs[logId].nonce;
            }
        } else {
            logs[id].touchpoints[logs[id].nonce] = tp;
            unchecked {
                ++logs[id].nonce;
            }
        }

        // Also store touchpoint by itemId.
        unchecked {
            ++nonceByItemId[keccak256(abi.encodePacked(bulletin, listId, itemId))];
            touchpointByItemId[keccak256(abi.encodePacked(bulletin, listId, itemId))][nonceByItemId[keccak256(
                abi.encodePacked(bulletin, listId, itemId)
            )]] = tp;
        }

        // Finally, log data
        if (IBulletin(bulletin).hasAnyRole(address(this), IBulletin(bulletin).LOGGERS()) && review) {
            IBulletin(bulletin).submit(listId, itemId);
        }

        emit Logged(role, user, bulletin, listId, itemId, logs[logId].nonce, review, data);
    }

    /// -----------------------------------------------------------------------
    /// Evaluate
    /// -----------------------------------------------------------------------

    function evaluate(
        uint256 role,
        uint256 id,
        address bulletin,
        uint256 listId,
        uint256 order,
        uint256 itemId,
        bool pass
    ) external payable onlyRoles(role) checkList(bulletin, listId, itemId) {
        // Already reviewed.
        Item memory item = IBulletin(bulletin).getItem(itemId);
        if (!item.review) revert InvalidItem();

        (address user, address _bulletin, uint256 _listId, uint256 nonce) = getLog(id);
        if (order > nonce || bulletin != _bulletin || listId != _listId || logs[id].touchpoints[order].itemId != itemId)
        {
            revert InvalidEvaluation();
        }

        logs[id].touchpoints[order].pass = pass;

        if (IBulletin(bulletin).hasAnyRole(address(this), IBulletin(bulletin).LOGGERS()) && pass) {
            IBulletin(bulletin).submit(listId, itemId);
        }

        if (currency != address(0)) {
            ICurrency(currency).transferFrom(
                address(this),
                user,
                (itemId == 0) ? IBulletin(bulletin).getListDrip(listId) : IBulletin(bulletin).getItemDrip(itemId)
            );
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

    function getLogId(address user, address bulletin, uint256 listId) external view returns (uint256) {
        return lookupLogId[user][keccak256(abi.encodePacked(bulletin, listId))];
    }

    function getTouchpointsByLog(uint256 _logId) external view returns (Touchpoint[] memory) {
        (,,, uint256 aNonce) = getLog(_logId);
        Touchpoint[] memory tps = new Touchpoint[](aNonce);

        for (uint256 i; i < aNonce; ++i) {
            tps[i] = logs[_logId].touchpoints[i];
        }

        return tps;
    }

    function getTouchpointsByLogByItemId(uint256 _logId, uint256 itemId) external view returns (Touchpoint[] memory) {
        (,,, uint256 aNonce) = getLog(_logId);
        Touchpoint[] memory tps = new Touchpoint[](aNonce);

        for (uint256 i; i < aNonce; ++i) {
            Touchpoint memory tp = logs[_logId].touchpoints[i];
            if (tp.itemId == itemId) {
                tps[i] = tp;
            }
        }

        return tps;
    }

    function getNonceByItemId(address bulletin, uint256 listId, uint256 itemId) public view returns (uint256) {
        return nonceByItemId[keccak256(abi.encodePacked(bulletin, listId, itemId))];
    }

    function getTouchpointByItemIdByNonce(address bulletin, uint256 listId, uint256 itemId, uint256 nonce)
        external
        view
        returns (Touchpoint memory)
    {
        return touchpointByItemId[keccak256(abi.encodePacked(bulletin, listId, itemId))][nonce];
    }
}
