// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/// @notice A struct representing the parameters of an item.
/// TODO: Should we add a price parameter?
struct Item {
    bool review; // Whether the item requires review to complete.
    uint40 expire; // The deadline of the item.
    address owner; // The owner of the item.
    string title; // The title of the item.
    string detail; // The detail of the item.
    bytes schema; // Custom data solicited when interacting with this item.
}

/// @notice A struct representing the parameters of a list.
struct List {
    address owner; // The owner of the list.
    string title; // The title of the list.
    string detail; // The detail of the list.
    bytes schema; // Custom data solicited when interacting with this list.
    uint256[] itemIds; // The items in the list.
}

interface IBulletin {
    function dao() external view returns (address);
    function fee() external view returns (uint256);

    function itemId() external view returns (uint256);
    function listId() external view returns (uint256);
    function registerItem(Item calldata item) external payable;
    function registerItems(Item[] calldata _items) external payable;
    function updateItem(uint256 id, Item calldata item) external payable;
    function removeItem(uint256 id) external payable;

    function getItem(uint256 id) external view returns (Item memory);
    function getList(uint256 id) external view returns (List memory);
    function hasListExpired(uint256 id) external view returns (bool);
    function hasItemExpired(uint256 id) external view returns (bool);
    function checkIsItemInList(uint256 itemId, uint256 listId) external view returns (bool);

    function authorizeLogger(address log) external;
    function submit(uint256 itemId) external;
    function isLoggerAuthorized(address log) external view returns (bool);
    function runsByItem(uint256 itemId) external view returns (uint256);
    function runsByList(uint256 itemId) external view returns (uint256);
}
