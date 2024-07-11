// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {ICurrency} from "src/interface/ICurrency.sol";
import {Item, List} from "src/interface/IBulletin.sol";
import {OwnableRoles} from "src/auth/OwnableRoles.sol";

/// @title List
/// @notice A database management system to store lists of items.
/// @author audsssy.eth
contract Bulletin is OwnableRoles {
    event ItemUpdated(uint256 id, Item item);
    event ListUpdated(uint256 id, List list);

    error TransferFailed();
    error NotAuthorized();
    error InvalidItem();
    error InvalidList();

    /// -----------------------------------------------------------------------
    /// Storage
    /// -----------------------------------------------------------------------

    /// @notice Role constants.
    uint256 public constant LOGGERS = 1 << 0;
    uint256 public constant STAFF = 1 << 1;

    /// @notice Bulletin storage.
    uint256 public fee;
    uint256 public itemId;
    uint256 public listId;
    mapping(uint256 => Item) public items;
    mapping(uint256 => List) public lists;

    /// @notice Currency faucet.
    address public currency;
    uint256 public drip;

    /// @dev itemId => listId => bool
    mapping(uint256 => mapping(uint256 => bool)) public isItemInList;

    /// @dev itemId => number of interactions produced
    mapping(uint256 => uint256) public runsByItem;

    /// @dev itemId => number of interactions produced
    mapping(uint256 => uint256) public runsByList;

    /// -----------------------------------------------------------------------
    /// Modifier
    /// -----------------------------------------------------------------------

    modifier payFee(uint256 frequency) {
        (bool success,) = owner().call{value: fee * frequency}("");
        if (!success) revert TransferFailed();
        _;
    }

    modifier drop(uint256 frequency) {
        _;
        ICurrency(currency).transferFrom(address(this), msg.sender, drip * frequency);
    }

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    function initialize(address owner) public {
        _initializeOwner(owner);
    }

    /// -----------------------------------------------------------------------
    /// DAO Logic
    /// ----------------------------------------------------------------------

    function setFee(uint256 _fee) external payable onlyOwner {
        fee = _fee;
    }

    function setFaucet(address _currency, uint256 _drip) external payable onlyOwner {
        currency = _currency;
        drip = _drip;
    }

    /// -----------------------------------------------------------------------
    /// Item Logic - Setter
    /// -----------------------------------------------------------------------

    function contributeItem(Item calldata item) public payable onlyRoles(STAFF) drop(1) {
        _registerItem(item);
    }

    function registerItem(Item calldata item) public payable payFee(1) {
        _registerItem(item);
    }

    function _registerItem(Item calldata item) internal {
        if (item.owner == address(0)) revert InvalidItem();

        unchecked {
            ++itemId;
        }

        items[itemId] = item;
        emit ItemUpdated(itemId, item);
    }

    function contributeItems(Item[] calldata _items) public payable onlyRoles(STAFF) drop(_items.length) {
        uint256 length = _items.length;
        for (uint256 i = 0; i < length; i++) {
            contributeItem(_items[i]);
        }
    }

    function registerItems(Item[] calldata _items) external payable payFee(_items.length) {
        uint256 length = _items.length;
        for (uint256 i = 0; i < length; i++) {
            registerItem(_items[i]);
        }
    }

    function updateItem(uint256 id, Item calldata item) external payable onlyOwner {
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

    function contributeList(List calldata list) public payable onlyRoles(STAFF) drop(1) {
        _registerList(list);
    }

    function registerList(List calldata list) public payable payFee(1) {
        _registerList(list);
    }

    function _registerList(List calldata list) internal {
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

    function updateList(uint256 id, List calldata list) external payable onlyOwner {
        if (id > listId) revert InvalidList();

        // Clear out current list.
        List memory _list = getList(id);
        uint256 length = _list.itemIds.length;
        for (uint256 i; i < length; ++i) {
            delete isItemInList[_list.itemIds[i]][id];
        }
        delete lists[id];

        // Update new list.
        length = list.itemIds.length;
        for (uint256 i; i < length; ++i) {
            isItemInList[list.itemIds[i]][id] = true;
        }
        lists[id] = list;
        emit ListUpdated(listId, list);
    }

    function removeList(uint256 id) external payable onlyOwner {
        List memory _list = getList(id);
        uint256 length = _list.itemIds.length;
        for (uint256 i; i < length; ++i) {
            delete isItemInList[_list.itemIds[i]][id];
        }

        delete lists[id];
        emit ListUpdated(id, lists[id]);
    }

    /// -----------------------------------------------------------------------
    /// Log Logic - Setter
    /// -----------------------------------------------------------------------

    function submit(uint256 _listId, uint256 _itemId) external onlyRoles(LOGGERS) {
        unchecked {
            (_itemId == 0) ? ++runsByList[_listId] : ++runsByItem[_itemId];
        }
    }

    /// -----------------------------------------------------------------------
    /// Item Logic - Getter
    /// -----------------------------------------------------------------------

    function getItem(uint256 id) external view returns (Item memory) {
        return items[id];
    }

    function getItemDrip(uint256 id) external view returns (uint256) {
        return items[id].drip;
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

    function getList(uint256 id) public view returns (List memory) {
        return lists[id];
    }

    function getListDrip(uint256 id) external view returns (uint256) {
        return lists[id].drip;
    }

    function hasListExpired(uint256 id) public view returns (bool) {
        List memory list;
        uint256 itemCount;
        bool expired;

        // @notice Count number of times completed per activity.
        list = lists[id];
        itemCount = list.itemIds.length;

        for (uint256 i; i < itemCount; ++i) {
            hasItemExpired(lists[id].itemIds[i]) ? expired = true : expired;
        }

        return expired;
    }

    receive() external payable virtual {}
}
