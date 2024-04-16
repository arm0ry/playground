// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {Item, List} from "./interface/IBulletin.sol";

/// @title List
/// @notice A database management system to store lists of items.
/// @author audsssy.eth
contract Bulletin {
    event ItemUpdated(uint256 id, Item item);
    event ListUpdated(uint256 id, List list);

    error TransferFailed();
    error NotAuthorized();
    error InvalidItem();
    error InvalidList();

    /// -----------------------------------------------------------------------
    /// Storage
    /// -----------------------------------------------------------------------

    address public dao;
    uint256 public fee;
    uint256 public itemId;
    uint256 public listId;
    mapping(uint256 => Item) public items;
    mapping(uint256 => List) public lists;

    // @notice itemId => listId => bool
    mapping(uint256 => mapping(uint256 => bool)) public isItemInList;

    // @notice Log contract => bool
    mapping(address => bool) public isLoggerAuthorized;

    // @notice itemId => number of interactions produced
    mapping(uint256 => uint256) public runsByItem;

    /// -----------------------------------------------------------------------
    /// Modifier
    /// -----------------------------------------------------------------------

    modifier onlyDao() {
        if (dao != msg.sender) revert NotAuthorized();
        _;
    }

    modifier onlyAuthorizedLogger() {
        if (!isLoggerAuthorized[msg.sender]) revert NotAuthorized();
        _;
    }

    modifier payFee() {
        (bool success,) = dao.call{value: fee}("");
        if (!success) revert TransferFailed();
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

    /// -----------------------------------------------------------------------
    /// Item Logic - Setter
    /// -----------------------------------------------------------------------

    function registerItem(Item calldata item) public payable payFee {
        if (item.owner == address(0)) revert InvalidItem();

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
        if (id > 0) {
            if (item.owner == address(0)) {
                removeItem(id);
            } else {
                items[id] = item;
                emit ItemUpdated(itemId, item);
            }
        } else {
            revert InvalidItem();
        }
    }

    function removeItem(uint256 id) private {
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
        if (id > listId) revert InvalidList();
        lists[id] = list;
        emit ListUpdated(listId, list);
    }

    function removeList(uint256 id) external payable onlyDao {
        delete lists[id];
        emit ListUpdated(id, lists[id]);
    }

    /// -----------------------------------------------------------------------
    /// Log Logic - Setter
    /// -----------------------------------------------------------------------

    function authorizeLogger(address logger, bool auth) external onlyDao {
        isLoggerAuthorized[logger] = auth;
    }

    function submit(uint256 _itemId) external onlyAuthorizedLogger {
        if (_itemId > 0) {
            unchecked {
                ++runsByItem[_itemId];
            }
        }
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

    function checkIsItemInList(uint256 _itemId, uint256 _listId) public view returns (bool) {
        return isItemInList[_itemId][_listId];
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

    /// @notice Query the number of times users have completed a list on a bulletin.
    function runsByList(uint256 id) external view returns (uint256 runs) {
        List memory list;
        uint256 itemCount;
        uint256 runsPerItem;

        // @notice Count number of times completed per activity.
        if (id != 0) {
            list = lists[id];
            itemCount = list.itemIds.length;

            for (uint256 i; i < itemCount; ++i) {
                runsPerItem = runsByItem[lists[id].itemIds[i]];

                (runsPerItem > 0)
                    ? ((runs > runsPerItem) ? runs = runsPerItem : (runs == 0) ? runs = runsPerItem : runs)
                    : runs = 0;
            }
        } else {
            revert InvalidList();
        }
    }

    receive() external payable virtual {}
}
