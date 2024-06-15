// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import {TokenCurve} from "src/TokenCurve.sol";
import {CurveType, ITokenCurve} from "src/interface/ITokenCurve.sol";
import {HackathonSupportToken} from "src/tokens/g0v/HackathonSupportToken.sol";
import {MockERC20} from "lib/solbase/test/utils/mocks/MockERC20.sol";

import {Log} from "src/Log.sol";
import {ILog} from "src/interface/ILog.sol";
import {Bulletin} from "src/Bulletin.sol";
import {IBulletin, Item, List} from "src/interface/IBulletin.sol";
import {OwnableRoles} from "src/auth/OwnableRoles.sol";
import {Ownable} from "lib/solady/src/auth/Ownable.sol";

/// -----------------------------------------------------------------------
/// Test Logic
/// -----------------------------------------------------------------------

contract BulletinTest is Test {
    Bulletin bulletin;
    Log logger;
    MockERC20 mock;

    TokenCurve ic;
    HackathonSupportToken hacakathonSupportToken;

    uint256[] itemIds;

    /// @dev Mock Users.
    address immutable alice = makeAddr("alice");
    address immutable bob = makeAddr("bob");
    address immutable charlie = makeAddr("charlie");
    address immutable owner = makeAddr("owner");

    /// @dev Mock Data.
    uint40 constant PAST = 100000;
    uint40 constant FUTURE = 2527482181;
    string TEST = "TEST";
    bytes constant BYTES = bytes(string("BYTES"));
    uint256 defaultBulletinBalance = 10 ether;

    Item[] items;
    Item item1 =
        Item({review: false, expire: PAST, owner: makeAddr("alice"), title: TEST, detail: TEST, schema: BYTES, drip: 0});
    Item item2 =
        Item({review: true, expire: FUTURE, owner: makeAddr("bob"), title: TEST, detail: TEST, schema: BYTES, drip: 0});
    Item item3 = Item({
        review: false,
        expire: FUTURE,
        owner: makeAddr("charlie"),
        title: TEST,
        detail: TEST,
        schema: BYTES,
        drip: 0
    });
    Item item4 = Item({
        review: true,
        expire: FUTURE,
        owner: makeAddr("charlie"),
        title: TEST,
        detail: TEST,
        schema: BYTES,
        drip: 0
    });
    Item item5 = Item({
        review: true,
        expire: FUTURE,
        owner: makeAddr("charlie"),
        title: TEST,
        detail: TEST,
        schema: BYTES,
        drip: 0
    });
    Item item6 = Item({
        review: false,
        expire: FUTURE,
        owner: makeAddr("charlie"),
        title: TEST,
        detail: TEST,
        schema: BYTES,
        drip: 0
    });

    /// -----------------------------------------------------------------------
    /// Setup Tests
    /// -----------------------------------------------------------------------

    /// @notice Set up the testing suite.
    function setUp() public payable {
        deployBulletin(owner);
        deployLogger(owner);

        mock = new MockERC20(TEST, TEST, 18);
        mock.mint(address(bulletin), defaultBulletinBalance);
        vm.prank(address(bulletin));
        mock.approve(address(bulletin), defaultBulletinBalance);
    }

    function testReceiveETH() public payable {
        (bool sent,) = address(bulletin).call{value: 5 ether}("");
        assert(sent);
    }

    function deployBulletin(address user) public payable {
        bulletin = new Bulletin();
        bulletin.initialize(user);
        assertEq(bulletin.owner(), user);
    }

    function deployLogger(address user) public payable {
        logger = new Log();
        logger.initialize(user);
        assertEq(logger.owner(), user);
    }

    /// -----------------------------------------------------------------------
    /// DAO Test
    /// ----------------------------------------------------------------------

    function testAuthorizeLogger(address user) public payable {
        uint256 LOGGERS = IBulletin(address(bulletin)).LOGGERS();
        test_GrantRoles(user, LOGGERS);
    }

    function testAuthorizeLogger_NotOwner() public payable {
        uint256 LOGGERS = IBulletin(address(bulletin)).LOGGERS();
        vm.expectRevert(Ownable.Unauthorized.selector);
        bulletin.grantRoles(address(logger), LOGGERS);
    }

    function testSetFee(uint256 fee) public payable {
        vm.prank(owner);
        bulletin.setFee(fee);
        assertEq(fee, bulletin.fee());
    }

    function testSetFee_NotOwner(uint256 fee) public payable {
        vm.expectRevert(Ownable.Unauthorized.selector);
        bulletin.setFee(fee);
    }

    function testSetFaucet(address currency, uint256 drip) public payable {
        vm.prank(owner);
        bulletin.setFaucet(currency, drip);
        assertEq(currency, bulletin.currency());
        assertEq(drip, bulletin.drip());
    }

    function testSetFaucet_NotOwner(address currency, uint256 drip) public payable {
        vm.expectRevert(Ownable.Unauthorized.selector);
        bulletin.setFaucet(currency, drip);
    }

    function test_GrantRoles(address user, uint256 role) public payable {
        vm.assume(role > 0);
        vm.prank(owner);
        bulletin.grantRoles(user, role);

        emit log_uint(bulletin.rolesOf(user));
        assertEq(bulletin.hasAnyRole(user, role), true);
    }

    function test_GrantRoles_NotOwner(address user, uint256 role) public payable {
        vm.expectRevert(Ownable.Unauthorized.selector);
        bulletin.grantRoles(user, role);
    }

    /// -----------------------------------------------------------------------
    /// Items
    /// ----------------------------------------------------------------------

    function test_ContributeItem(uint256 drip) public payable {
        vm.assume(defaultBulletinBalance >= drip);

        // Set faucet.
        testSetFaucet(address(mock), drip);

        // Grant Alice member role.
        uint256 STAFF = IBulletin(address(bulletin)).STAFF();
        test_GrantRoles(alice, STAFF);

        uint256 id = bulletin.itemId();
        uint256 prevAliceBalance = mock.balanceOf(alice);

        // Alice contributes item.
        vm.prank(alice);
        bulletin.contributeItem(item1);
        uint256 postAliceBalance = mock.balanceOf(alice);
        assertEq(prevAliceBalance + drip, postAliceBalance);

        // Validate setup.
        uint256 _id = bulletin.itemId();
        Item memory _item = bulletin.getItem(_id);
        assertEq(id + 1, _id);
        assertEq(_item.review, item1.review);
        assertEq(_item.expire, item1.expire);
        assertEq(_item.owner, item1.owner);
        assertEq(_item.title, item1.title);
        assertEq(_item.detail, item1.detail);
        assertEq(_item.schema, item1.schema);
        assertEq(_item.drip, item1.drip);
    }

    function test_ContributeItem_FaucetDepleted(uint256 drip) public payable {
        drip = 10 ether;
        test_ContributeItem(drip);

        vm.expectRevert();
        bulletin.contributeItem(item1);
    }

    function testRegisterItem() public payable {
        uint256 id = bulletin.itemId();

        // Set up task.
        bulletin.registerItem(item1);

        // Validate setup.
        uint256 _id = bulletin.itemId();
        Item memory _item = bulletin.getItem(_id);
        assertEq(id + 1, _id);
        assertEq(_item.review, item1.review);
        assertEq(_item.expire, item1.expire);
        assertEq(_item.owner, item1.owner);
        assertEq(_item.title, item1.title);
        assertEq(_item.detail, item1.detail);
        assertEq(_item.schema, item1.schema);
        assertEq(_item.drip, item1.drip);
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
            assertEq(_item.drip, items[i].drip);
        }
    }

    function testRegisterItem_InvalidItem() public payable {
        item1.owner = address(0);

        vm.expectRevert(Bulletin.InvalidItem.selector);
        vm.prank(owner);
        bulletin.registerItem(item1);
    }

    function testUpdateItem() public payable {
        testRegisterItems();

        vm.prank(owner);
        bulletin.updateItem(1, item2);

        Item memory _item = bulletin.getItem(1);
        assertEq(_item.owner, item2.owner);
    }

    function testUpdateItem_InvalidItem() public payable {
        vm.prank(owner);
        vm.expectRevert(Bulletin.InvalidItem.selector);
        bulletin.updateItem(0, item1);
    }

    function testRemoveItem() public payable {
        testRegisterItems();
        item1.owner = address(0);

        vm.prank(owner);
        bulletin.updateItem(1, item1);
        Item memory _item = bulletin.getItem(1);
        assertEq(_item.expire, 0);
    }

    /// -----------------------------------------------------------------------
    /// Lists
    /// ----------------------------------------------------------------------

    function test_ContributeList(uint256 drip) public payable {
        // Setup items.
        testRegisterItems();

        // Prepare list.
        itemIds.push(1);
        itemIds.push(2);
        itemIds.push(3);
        List memory list1 = List({owner: alice, title: TEST, detail: TEST, schema: BYTES, itemIds: itemIds, drip: 0});

        // Set faucet.
        drip = bound(drip, 1 ether, defaultBulletinBalance / 2);
        testSetFaucet(address(mock), drip);

        // Grant Alice member role.
        uint256 STAFF = IBulletin(address(bulletin)).STAFF();
        test_GrantRoles(alice, STAFF);

        uint256 prevAliceBalance = mock.balanceOf(alice);

        // Alice sets up task.
        vm.prank(alice);
        bulletin.contributeList(list1);
        uint256 postAliceBalance = mock.balanceOf(alice);
        assertEq(prevAliceBalance + drip, postAliceBalance);
        emit log_uint(postAliceBalance);

        // Validate setup.
        List memory list = bulletin.getList(1);
        assertEq(list.owner, list1.owner);
        assertEq(list.title, list1.title);
        assertEq(list.detail, list1.detail);
        assertEq(list.schema, list1.schema);
        assertEq(list.drip, list1.drip);
    }

    function test_ContributeList_FaucetDepleted(uint256 drip) public payable {
        drip = 10 ether;
        test_ContributeList(drip);

        // Prepare list.
        itemIds.push(1);
        itemIds.push(2);
        itemIds.push(3);
        List memory list1 = List({owner: alice, title: TEST, detail: TEST, schema: BYTES, itemIds: itemIds, drip: 0});

        vm.expectRevert();
        bulletin.contributeList(list1);
    }

    function testRegisterList() public payable {
        testRegisterItems();

        itemIds.push(1);
        itemIds.push(2);
        itemIds.push(3);
        List memory list1 = List({owner: alice, title: TEST, detail: TEST, schema: BYTES, itemIds: itemIds, drip: 0});

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
        List memory list1 = List({owner: alice, title: TEST, detail: TEST, schema: BYTES, itemIds: itemIds, drip: 0});

        vm.expectRevert(Bulletin.InvalidList.selector);
        bulletin.registerList(list1);
    }

    function testRegisterList_NotAuthorized() public payable {
        itemIds.push(1);
        itemIds.push(2);
        itemIds.push(3);
        List memory list1 =
            List({owner: address(0), title: TEST, detail: TEST, schema: BYTES, itemIds: itemIds, drip: 0});

        vm.expectRevert(Bulletin.NotAuthorized.selector);
        bulletin.registerList(list1);
    }

    function testUpdateList() public payable {
        testRegisterList();

        delete itemIds;
        itemIds.push(4);
        itemIds.push(5);
        itemIds.push(6);
        List memory list1 = List({owner: bob, title: TEST, detail: TEST, schema: BYTES, itemIds: itemIds, drip: 0});

        uint256 id = bulletin.listId();
        List memory list = bulletin.getList(id);

        vm.prank(owner);
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

        vm.prank(owner);
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
    /// Helper
    /// -----------------------------------------------------------------------
}
