// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {Item, List} from "./interface/IBulletin.sol";

/// @title List
/// @notice A database management system to store lists of items.
/// @author audsssy.eth
contract Bulletin {
    event ItemUpdated(uint256 id, Item item);
    event ListUpdated(uint256 id, List list);

    error NotAuthorized();
    error InvalidList();

    /// -----------------------------------------------------------------------
    /// Storage
    /// -----------------------------------------------------------------------

    address dao;
    uint256 fee;
    uint256 public itemId;
    uint256 public listId;
    mapping(uint256 => Item) public items;
    mapping(uint256 => List) public lists;

    mapping(uint256 => mapping(uint256 => bool)) public isItemInList;

    /// -----------------------------------------------------------------------
    /// Modifier
    /// -----------------------------------------------------------------------

    modifier onlyDao() {
        if (dao != msg.sender) revert NotAuthorized();
        _;
    }

    modifier payFee() {
        (bool success,) = dao.call{value: getFee()}("");
        if (!success) revert NotAuthorized();
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
    /// ----------------------------------------------------------------------

    function setFee(uint256 _fee) external payable onlyDao {
        fee = _fee;
    }

    function getFee() public view returns (uint256) {
        return fee;
    }

    function tally(address contributor) public view returns (uint256) {
        uint256 count;
        for (uint256 i; i < itemId; i++) {
            if (items[i].owner == contributor) ++count;
        }

        for (uint256 i; i < listId; i++) {
            if (lists[i].owner == contributor) ++count;
        }

        return count;
    }

    /// -----------------------------------------------------------------------
    /// Item Logic - Setter
    /// -----------------------------------------------------------------------

    function registerItem(Item calldata item) public payable payFee {
        if (item.owner == address(0)) revert NotAuthorized();

        unchecked {
            ++itemId;
        }

        items[itemId] = item;
        emit ItemUpdated(itemId, item);
    }

    function registerItems(Item[] calldata _items) external payable payFee {
        uint256 length = _items.length;
        for (uint256 i = 0; i < length; i++) {
            registerItem(_items[i]);
        }
    }

    function updateItem(uint256 id, Item calldata item) external payable onlyDao {
        if (id > itemId) revert NotAuthorized();
        items[id] = item;
        emit ItemUpdated(itemId, item);
    }

    function removeItem(uint256 id) external payable onlyDao {
        delete items[id];
        emit ItemUpdated(itemId, items[id]);
    }

    /// -----------------------------------------------------------------------
    /// List Logic - Setter
    /// -----------------------------------------------------------------------

    function registerList(List calldata list) public payable payFee {
        uint256 length = list.itemIds.length;
        if (list.owner == address(0)) revert NotAuthorized();
        if (length == 0) revert InvalidList();

        unchecked {
            ++listId;
        }

        for (uint256 i; i < length; ++i) {
            isItemInList[list.itemIds[i]][listId] = true;
        }

        lists[listId] = list;
        emit ListUpdated(listId, list);
    }

    function updateList(uint256 id, List calldata list) external payable onlyDao {
        if (id > listId) revert NotAuthorized();
        lists[id] = list;
        emit ListUpdated(listId, list);
    }

    function removeList(uint256 id) external payable onlyDao {
        delete lists[id];
        emit ListUpdated(id, lists[id]);
    }

    /// -----------------------------------------------------------------------
    /// Item Logic - Getter
    /// -----------------------------------------------------------------------

    function getItem(uint256 id) external view returns (Item memory) {
        return items[id];
    }

    function hasItemExpired(uint256 id) public view returns (bool) {
        if (block.timestamp > items[id].expire) return true;
        else return false;
    }

    /// -----------------------------------------------------------------------
    /// List Logic - Getter
    /// -----------------------------------------------------------------------

    function getList(uint256 id) external view returns (List memory) {
        return lists[id];
    }

    function hasListExpired(uint256 id) external view returns (bool) {
        uint256[] memory itemArray = lists[id].itemIds;
        uint256 length = itemArray.length;

        for (uint256 i; i < length; ++i) {
            if (hasItemExpired(itemArray[i])) return true;
        }
        return false;
    }

    receive() external payable virtual {}
}
