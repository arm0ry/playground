// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {ImpactCurve} from "src/ImpactCurve.sol";
import {CurveType, IImpactCurve} from "src/interface/IImpactCurve.sol";
import {HackathonSupportToken} from "src/tokens/g0v/HackathonSupportToken.sol";
import {ISupportToken} from "src/interface/ISupportToken.sol";

import {Log} from "src/Log.sol";
import {ILog} from "src/interface/ILog.sol";
import {Bulletin} from "src/Bulletin.sol";
import {IBulletin, Item, List} from "src/interface/IBulletin.sol";

/// -----------------------------------------------------------------------
/// Test Logic
/// -----------------------------------------------------------------------

contract BulletinTest is Test {
    Bulletin bulletin;
    Log logger;

    ImpactCurve impactCurve;
    HackathonSupportToken hacakathonSupportToken;

    uint256[] itemIds;

    /// @dev Mock Users.
    address immutable alice = makeAddr("alice");
    address immutable bob = makeAddr("bob");
    address immutable charlie = makeAddr("charlie");
    address immutable dao = makeAddr("dao");

    /// @dev Mock Data.
    uint40 constant PAST = 100000;
    uint40 constant FUTURE = 2527482181;
    string TEST = "TEST";
    bytes constant BYTES = bytes(string("BYTES"));

    Item[] items;
    Item item1 = Item({review: false, expire: PAST, owner: makeAddr("alice"), title: TEST, detail: TEST, schema: BYTES});
    Item item2 = Item({review: true, expire: FUTURE, owner: makeAddr("bob"), title: TEST, detail: TEST, schema: BYTES});
    Item item3 =
        Item({review: false, expire: FUTURE, owner: makeAddr("charlie"), title: TEST, detail: TEST, schema: BYTES});
    Item item4 =
        Item({review: true, expire: FUTURE, owner: makeAddr("charlie"), title: TEST, detail: TEST, schema: BYTES});
    Item item5 =
        Item({review: true, expire: FUTURE, owner: makeAddr("charlie"), title: TEST, detail: TEST, schema: BYTES});
    Item item6 =
        Item({review: false, expire: FUTURE, owner: makeAddr("charlie"), title: TEST, detail: TEST, schema: BYTES});

    /// -----------------------------------------------------------------------
    /// Setup Tests
    /// -----------------------------------------------------------------------

    /// @notice Set up the testing suite.
    function setUp() public payable {
        deployBulletin(dao);
        deployLogger(dao);
    }

    function testReceiveETH() public payable {
        (bool sent,) = address(bulletin).call{value: 5 ether}("");
        assert(sent);
    }

    function deployBulletin(address user) public payable {
        bulletin = new Bulletin(user);
        assertEq(bulletin.dao(), user);
    }

    function deployLogger(address user) public payable {
        logger = new Log(user);
        assertEq(logger.dao(), user);
    }

    /// -----------------------------------------------------------------------
    /// DAO Test
    /// ----------------------------------------------------------------------

    function testAuthorizeLogger(bool auth) public payable {
        vm.prank(dao);
        bulletin.authorizeLogger(address(logger), auth);
        assertEq(bulletin.isLoggerAuthorized(address(logger)), auth);
    }

    function testAuthorizeLogger_NotDao(bool auth) public payable {
        vm.expectRevert(Bulletin.NotAuthorized.selector);
        bulletin.authorizeLogger(address(logger), auth);
    }

    function testSetFee(uint256 fee) public payable {
        vm.prank(dao);
        bulletin.setFee(fee);
        assertEq(fee, bulletin.fee());
    }

    function testSetFee_NotDao(uint256 fee) public payable {
        vm.expectRevert(Bulletin.NotAuthorized.selector);
        bulletin.setFee(fee);
    }

    /// -----------------------------------------------------------------------
    /// Items
    /// ----------------------------------------------------------------------

    function testRegisterItem() public payable {
        uint256 id = bulletin.itemId();

        // Set up task.
        bulletin.registerItem(item1);

        // Validate setup.
        uint256 _id = bulletin.itemId();
        assertEq(id + 1, _id);

        Item memory _item = bulletin.getItem(_id);
        assertEq(_item.review, item1.review);
        assertEq(_item.expire, item1.expire);
        assertEq(_item.owner, item1.owner);
        assertEq(_item.title, item1.title);
        assertEq(_item.detail, item1.detail);
        assertEq(_item.schema, item1.schema);
    }

    function testRegisterItem_TransferFailed() public payable {
        testSetFee(1 ether);

        vm.deal(alice, 2 ether);

        vm.prank(alice);
        vm.expectRevert(Bulletin.TransferFailed.selector);
        bulletin.registerItem{value: 0.1 ether}(item1);
    }

    function testRegisterItems() public payable {
        Item memory _item;
        uint256 id = bulletin.itemId();

        items.push(item1);
        items.push(item2);
        items.push(item3);
        items.push(item4);
        items.push(item5);
        items.push(item6);

        bulletin.registerItems(items);

        uint256 _id = bulletin.itemId();

        for (uint256 i; i < _id; ++i) {
            _item = bulletin.getItem(i + 1);
            assertEq(_item.review, items[i].review);
            assertEq(_item.owner, items[i].owner);
            assertEq(_item.expire, items[i].expire);
            assertEq(_item.title, items[i].title);
            assertEq(_item.detail, items[i].detail);
            assertEq(_item.schema, items[i].schema);
        }
    }

    function testRegisterItem_InvalidItem() public payable {
        item1.owner = address(0);

        vm.expectRevert(Bulletin.InvalidItem.selector);
        vm.prank(dao);
        bulletin.registerItem(item1);
    }

    function testUpdateItem() public payable {
        testRegisterItems();

        vm.prank(dao);
        bulletin.updateItem(1, item2);

        Item memory _item = bulletin.getItem(1);
        assertEq(_item.owner, item2.owner);
    }

    function testUpdateItem_InvalidItem() public payable {
        vm.prank(dao);
        vm.expectRevert(Bulletin.InvalidItem.selector);
        bulletin.updateItem(0, item1);
    }

    function testRemoveItem() public payable {
        testRegisterItems();
        item1.owner = address(0);

        vm.prank(dao);
        bulletin.updateItem(1, item1);
        Item memory _item = bulletin.getItem(1);
        assertEq(_item.expire, 0);
    }

    /// -----------------------------------------------------------------------
    /// Lists
    /// ----------------------------------------------------------------------

    function testRegisterList() public payable {
        testRegisterItems();

        itemIds.push(1);
        itemIds.push(2);
        itemIds.push(3);
        List memory list1 = List({owner: alice, title: TEST, detail: TEST, schema: BYTES, itemIds: itemIds});

        uint256 id = bulletin.listId();
        bulletin.registerList(list1);

        uint256 _id = bulletin.listId();
        assertEq(id + 1, _id);

        List memory list = bulletin.getList(1);
        assertEq(list.owner, list1.owner);
        assertEq(list.title, list1.title);
        assertEq(list.detail, list1.detail);
        assertEq(list.schema, list1.schema);

        uint256 length = itemIds.length;
        for (uint256 i; i < length; i++) {
            assertEq(list.itemIds[i], itemIds[i]);
        }
    }

    function testRegisterList_InvalidList() public payable {
        List memory list1 = List({owner: alice, title: TEST, detail: TEST, schema: BYTES, itemIds: itemIds});

        vm.expectRevert(Bulletin.InvalidList.selector);
        bulletin.registerList(list1);
    }

    function testRegisterList_NotAuthorized() public payable {
        itemIds.push(1);
        itemIds.push(2);
        itemIds.push(3);
        List memory list1 = List({owner: address(0), title: TEST, detail: TEST, schema: BYTES, itemIds: itemIds});

        vm.expectRevert(Bulletin.NotAuthorized.selector);
        bulletin.registerList(list1);
    }

    function testUpdateList() public payable {
        testRegisterList();

        delete itemIds;
        itemIds.push(4);
        itemIds.push(5);
        itemIds.push(6);
        List memory list1 = List({owner: bob, title: TEST, detail: TEST, schema: BYTES, itemIds: itemIds});

        uint256 id = bulletin.listId();
        List memory list = bulletin.getList(id);

        vm.prank(dao);
        bulletin.updateList(id, list1);

        uint256 _id = bulletin.listId();
        assertEq(id, _id);

        List memory _list = bulletin.getList(_id);
        assertEq(_list.owner, list1.owner);
        assertEq(_list.title, list1.title);
        assertEq(_list.detail, list1.detail);
        assertEq(_list.schema, list1.schema);

        uint256 length = _list.itemIds.length;
        for (uint256 i; i < length; i++) {
            assertEq(_list.itemIds[i], itemIds[i]);

            assertEq(bulletin.isItemInList(_list.itemIds[i], id), true);
        }

        length = list.itemIds.length;
        for (uint256 i; i < length; i++) {
            assertEq(bulletin.isItemInList(list.itemIds[i], id), false);
        }
    }

    function testRemoveList() public payable {
        testRegisterList();

        vm.prank(dao);
        bulletin.removeList(1);

        List memory _list = bulletin.getList(1);
        assertEq(_list.owner, address(0));
        assertEq(_list.title, "");
        assertEq(_list.detail, "");
        assertEq(_list.schema, "");

        uint256 length = _list.itemIds.length;
        for (uint256 i; i < length; i++) {
            assertEq(bulletin.isItemInList(_list.itemIds[i], 1), false);
        }
    }

    /// -----------------------------------------------------------------------
    /// Internal Functions
    /// -----------------------------------------------------------------------

    // function initializeCurveAndToken(uint256 _listId) internal {
    //     impactCurve = new ImpactCurve();
    //     impactCurve.initialize(dao);

    //     hacakathonSupportToken =
    //         new HackathonSupportToken("Test", "TEST", address(quest), address(mission), address(impactCurve));

    //     impactCurve.curve(CurveType.LINEAR, address(hacakathonSupportToken), alice, 0.001 ether, 0, 2, 0, 0, 1, 0);
    // }
}
