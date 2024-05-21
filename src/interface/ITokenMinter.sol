// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

struct TokenMetadata {
    string name;
    string desc;
    address bulletin;
    uint256 listId;
    address logger;
}

struct TokenBuilder {
    address builder;
    uint48 builderId;
}

struct TokenOwner {
    uint48 lastConfigured;
    address owner;
}

/// @notice .
interface ITokenMinter {
    function tokenId() external returns (uint256);
    function setMinter(TokenMetadata calldata metadata, TokenBuilder calldata builder, address market)
        external
        payable;
    function mintByCurve(address to, uint256 id) external payable;
    function burnByCurve(address from, uint256 id) external payable;
    function balanceOf(address _owner, uint256 _id) external view returns (uint256);
    function uri(uint256 id) external view returns (string memory);
}
