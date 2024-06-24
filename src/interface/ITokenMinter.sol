// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

struct TokenTitle {
    string name;
    string desc;
}

struct TokenSource {
    address user;
    address bulletin;
    uint256 listId;
    address logger;
}

struct TokenBuilder {
    address builder;
    uint48 builderId;
}

struct TokenMarket {
    address market;
    uint256 limit;
}

/// @notice .
interface ITokenMinter {
    function tokenId() external returns (uint256);
    function registerMinter(
        TokenTitle calldata title,
        TokenSource calldata source,
        TokenBuilder calldata builder,
        TokenMarket calldata market
    ) external payable;

    function mint(address to, uint256 id) external payable;
    function burn(address from, uint256 id) external payable;
    function mintByMarket(address to, uint256 id) external payable;
    function burnByMarket(address from, uint256 id) external payable;
    function mintByLogger(address to, uint256 id) external payable;
    function burnByLogger(address from, uint256 id) external payable;

    function balanceOf(address _owner, uint256 _id) external view returns (uint256);
    function uri(uint256 id) external view returns (string memory);
    function ownerOf(uint256 id) external view returns (address);

    function getTokenTitle(uint256 id) external payable returns (string memory, string memory);
    function getTokenBuilder(uint256 id) external payable returns (address, uint256);
    function getTokenSource(uint256 id) external payable returns (address, address, uint256, address);
    function getTokenMarket(uint256 id) external payable returns (address, uint256);
}
