// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

struct Metadata {
    string name;
    string desc;
    address bulletin;
    uint256 listId;
    address logger;
}

struct Builder {
    address builder;
    uint48 builderId;
}

struct Owner {
    uint48 lastConfigured;
    address owner;
}

/// @notice .
interface ITokenMinter {
    function tokenId() external returns (uint256);
    function setMinter(Metadata calldata metadata, Builder calldata builder, address market) external payable;
    function mint(address to, uint256 id) external payable;
    function burn(address from, uint256 id) external payable;
    function balanceOf(address _owner, uint256 _id) external view returns (uint256);
    function uri(uint256 id) external view returns (string memory);
}
