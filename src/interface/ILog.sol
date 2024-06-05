// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

struct Activity {
    address user;
    address bulletin;
    uint256 listId;
    uint256 nonce;
    // nonce => Touchpoint
    mapping(uint256 => Touchpoint) touchpoints;
}

struct Touchpoint {
    bool pass;
    uint256 itemId;
    string feedback;
    bytes data;
}

interface ILog {
    function GASBUDDIES() external view returns (uint256);
    function REVIEWERS() external view returns (uint256);

    function initialize(address owner) external;
    function owner() external view returns (address);
    function grantRoles(address user, uint256 roles) external;
    function hasAnyRole(address user, uint256 roles) external view returns (bool);
    function rolesOf(address user) external view returns (uint256 roles);

    function log(address bulletin, uint256 listId, uint256 itemId, string calldata feedback, bytes calldata data)
        external
        payable;
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
    ) external payable;
    function sponsoredLog(
        address bulletin,
        uint256 listId,
        uint256 itemId,
        string calldata feedback,
        bytes calldata data
    ) external payable;

    function logId() external view returns (uint256);
    function getLog(uint256 logId)
        external
        view
        returns (address user, address bulletin, uint256 listId, uint256 nonce);
    function lookupLogId(address user, bytes32 encodePackedBulletinListId) external view returns (uint256);
    function getLogTouchpoints(uint256 logId) external view returns (Touchpoint[] memory);
    function getLogTouchpointsByItemId(uint256 _logId, uint256 _itemId) external view returns (Touchpoint[] memory);
    function nonceByItemId(bytes32 encodePackedBulletinListIdItemId) external view returns (uint256);
    function touchpointDataByEncodedItemId(bytes32 encodePackedBulletinListIdItemId, uint256 nonce)
        external
        view
        returns (bytes memory);
}
