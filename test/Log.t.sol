// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import {Log} from "src/Log.sol";
import {ILog, LogType, Activity, Touchpoint} from "src/interface/ILog.sol";
import {Bulletin} from "src/Bulletin.sol";
import {IBulletin, Item, List} from "src/interface/IBulletin.sol";
import {ITokenMinter} from "src/interface/ITokenMinter.sol";

import {BulletinTest} from "./Bulletin.t.sol";
import {OwnableRoles} from "src/auth/OwnableRoles.sol";
import {Ownable} from "lib/solady/src/auth/Ownable.sol";

contract LogTest is Test {
    Bulletin bulletin;
    Log logger;

    /// @dev Web3 Users.
    address owner = makeAddr("owner");
    address alice;
    uint256 alicePk;
    address bob;
    uint256 bobPk;
    address charlie;
    uint256 charliePk;

    /// @dev Mock Data.
    uint40 constant PAST = 100000;
    uint40 constant FUTURE = 2527482181;
    string TEST = "TEST";
    bytes constant BYTES = bytes(string("BYTES"));

    Item[] items;
    uint256[] itemIds;
    Item item1 =
        Item({review: false, expire: PAST, owner: makeAddr("alice"), title: TEST, detail: TEST, schema: BYTES, drip: 0});
    Item item2 =
        Item({review: false, expire: FUTURE, owner: makeAddr("bob"), title: TEST, detail: TEST, schema: BYTES, drip: 0});
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
        expire: PAST,
        owner: makeAddr("charlie"),
        title: TEST,
        detail: TEST,
        schema: BYTES,
        drip: 0
    });
    Item item5 = Item({
        review: true,
        expire: FUTURE,
        owner: makeAddr("alice"),
        title: TEST,
        detail: TEST,
        schema: BYTES,
        drip: 0
    });
    Item item6 =
        Item({review: true, expire: FUTURE, owner: makeAddr("bob"), title: TEST, detail: TEST, schema: BYTES, drip: 0});

    /// @dev Helpers.
    uint256 taskId;
    uint256 missionId;
    string testString = "TEST";

    /// @dev Bot.
    address buddy = makeAddr("buddy");

    /// @dev Public users.
    string username = "USERNAME";
    string username2 = "USERNAME2";
    string username3 = "USERNAME3";

    bytes32 public constant LOG_TYPEHASH =
        keccak256("Log(address bulletin, uint256 listId, uint256 itemId, string feedback, bytes data)");

    /// -----------------------------------------------------------------------
    /// Setup Tests
    /// -----------------------------------------------------------------------

    /// @notice Set up the testing suite.
    function setUp() public payable virtual {
        (alice, alicePk) = makeAddrAndKey("alice");
        (bob, bobPk) = makeAddrAndKey("bob");
        (charlie, charliePk) = makeAddrAndKey("charlie");

        deployBulletin(owner);
        deployLogger(owner);
    }

    function testReceiveETH() public payable {
        (bool sent,) = address(logger).call{value: 5 ether}("");
        assert(!sent);
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

    function testSetGasBuddy(address user) public payable {
        vm.assume(user != address(0));
        uint256 GASBUDDIES = ILog(address(logger)).GASBUDDIES();
        test_GrantRoles(user, GASBUDDIES);
    }

    function testSetGasBuddy_NotDao(address user) public payable {
        uint256 GASBUDDIES = ILog(address(logger)).GASBUDDIES();
        vm.expectRevert(Ownable.Unauthorized.selector);
        logger.grantRoles(user, GASBUDDIES);
    }

    function testSetMember(address user) public payable {
        vm.assume(user != address(0));
        uint256 MEMBERS = ILog(address(logger)).MEMBERS();
        test_GrantRoles(user, MEMBERS);
    }

    function testSetMember_NotDao(address user) public payable {
        uint256 MEMBERS = ILog(address(logger)).MEMBERS();
        vm.expectRevert(Ownable.Unauthorized.selector);
        logger.grantRoles(user, MEMBERS);
    }

    function test_GrantRoles(address user, uint256 role) public payable {
        vm.assume(user != address(0));
        vm.assume(role > 0);
        vm.prank(owner);
        logger.grantRoles(user, role);

        emit log_uint(bulletin.rolesOf(user));
        assertEq(logger.hasAnyRole(user, role), true);
    }

    function test_GrantRoles_NotOwner(address user, uint256 role) public payable {
        vm.expectRevert(Ownable.Unauthorized.selector);
        logger.grantRoles(user, role);
    }

    /// -----------------------------------------------------------------------
    /// Log
    /// ----------------------------------------------------------------------

    function test_Log_ReviewNotRequired_LoggerAuthorized() public payable {
        uint256 listId = 1;

        registerList_ReviewNotRequired();
        authorizeLogger();

        // logItemByTokenOwnership(user, token, tokenId, _itemId);
        logItem(alice, address(bulletin), listId, 1);
        logItem(alice, address(bulletin), listId, 2);
        logItemBySig(string("alice"), address(bulletin), listId, 3);
        logItemBySponsorship(address(bulletin), listId, 2);
        logItem(alice, address(bulletin), listId, 1);

        assertEq(bulletin.runsByItem(2), 2);
        assertEq(bulletin.runsByItem(3), 1);
        assertEq(bulletin.runsByList(listId), 1);
    }

    function test_Log_ReviewNotRequired_LoggerNotAuthorized() public payable {
        uint256 listId = 1;

        registerList_ReviewNotRequired();

        logItem(alice, address(bulletin), listId, 1);
        logItem(alice, address(bulletin), listId, 2);
        logItemBySig(string("alice"), address(bulletin), listId, 3);
        // logItem(alice, address(bulletin), listId, 3);
        logItem(alice, address(bulletin), listId, 2);
        logItem(alice, address(bulletin), listId, 1);

        assertEq(bulletin.runsByItem(2), 0);
        assertEq(bulletin.runsByItem(3), 0);
        assertEq(bulletin.runsByList(listId), 0);
    }

    function test_Log_ReviewRequired_LoggerAuthorized() public payable {
        uint256 listId = 1;

        registerList_ReviewRequired();
        authorizeLogger();

        logItem(alice, address(bulletin), listId, 4);
        logItem(alice, address(bulletin), listId, 5);
        logItem(alice, address(bulletin), listId, 6);
        logItem(alice, address(bulletin), listId, 5);
        logItem(alice, address(bulletin), listId, 4);

        assertEq(bulletin.runsByItem(5), 0);
        assertEq(bulletin.runsByItem(6), 0);
        assertEq(bulletin.runsByList(listId), 0);
    }

    function test_Log_ReviewRequired_LoggerNotAuthorized() public payable {
        uint256 listId = 1;

        registerList_ReviewRequired();

        logItem(alice, address(bulletin), listId, 4);
        logItem(alice, address(bulletin), listId, 5);
        logItem(alice, address(bulletin), listId, 6);
        logItem(alice, address(bulletin), listId, 5);
        logItem(alice, address(bulletin), listId, 4);

        assertEq(bulletin.runsByItem(5), 0);
        assertEq(bulletin.runsByItem(6), 0);
        assertEq(bulletin.runsByList(listId), 0);
    }

    function test_Log_SomeReviewRequired_LoggerAuthorized() public payable {
        uint256 listId = 1;

        registerList_SomeReviewRequired();
        authorizeLogger();

        logItem(alice, address(bulletin), listId, 1);
        logItem(alice, address(bulletin), listId, 6);
        logItem(alice, address(bulletin), listId, 6);
        logItem(alice, address(bulletin), listId, 1);
        logItem(alice, address(bulletin), listId, 1);

        assertEq(bulletin.runsByItem(1), 3);
        assertEq(bulletin.runsByItem(6), 0);
        assertEq(bulletin.runsByList(listId), 0);
    }

    /// -----------------------------------------------------------------------
    /// Evaluate
    /// ----------------------------------------------------------------------

    function test_Evaluate_ReviewRequired() public payable {
        uint256 listId = 1;
        uint256 logId;

        testSetMember(alice);
        test_Log_ReviewRequired_LoggerAuthorized();
        logId = logger.lookupLogId(alice, keccak256(abi.encodePacked(address(bulletin), listId)));

        vm.prank(alice);
        logger.evaluate(logId, address(bulletin), listId, 0, 4, true);

        vm.prank(alice);
        logger.evaluate(logId, address(bulletin), listId, 1, 5, true);

        vm.prank(alice);
        logger.evaluate(logId, address(bulletin), listId, 2, 6, true);

        assertEq(bulletin.runsByItem(4), 1);
        assertEq(bulletin.runsByItem(5), 1);
        assertEq(bulletin.runsByItem(6), 1);
        assertEq(bulletin.runsByList(listId), 1);
    }

    function test_Evaluate_SomeReviewRequired() public payable {
        uint256 listId = 1;
        uint256 logId;

        testSetMember(alice);
        test_Log_SomeReviewRequired_LoggerAuthorized();
        logId = logger.lookupLogId(alice, keccak256(abi.encodePacked(address(bulletin), listId)));

        vm.prank(alice);
        logger.evaluate(logId, address(bulletin), listId, 1, 6, true);

        vm.prank(alice);
        logger.evaluate(logId, address(bulletin), listId, 2, 6, true);

        assertEq(bulletin.runsByItem(6), 2);
        assertEq(bulletin.runsByList(listId), 2);
    }

    /// -----------------------------------------------------------------------
    /// Helper
    /// ----------------------------------------------------------------------

    function authorizeLogger() internal {
        uint256 LOGGERS = IBulletin(address(bulletin)).LOGGERS();
        vm.prank(owner);
        bulletin.grantRoles(address(logger), LOGGERS);
    }

    function authorizeMember(address user) internal {
        uint256 MEMBERS = ILog(address(logger)).MEMBERS();
        vm.prank(owner);
        bulletin.grantRoles(user, MEMBERS);
    }

    function registerItems() internal {
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

    function registerList_ReviewNotRequired() internal {
        registerItems();

        delete itemIds;
        itemIds.push(1);
        itemIds.push(2);
        itemIds.push(3);
        List memory list = List({owner: alice, title: TEST, detail: TEST, schema: BYTES, itemIds: itemIds, drip: 0});

        uint256 id = bulletin.listId();
        bulletin.registerList(list);

        uint256 _id = bulletin.listId();
        assertEq(id + 1, _id);

        List memory _list = bulletin.getList(_id);
        assertEq(_list.owner, list.owner);
        assertEq(_list.title, list.title);
        assertEq(_list.detail, list.detail);
        assertEq(_list.schema, list.schema);

        uint256 length = itemIds.length;
        for (uint256 i; i < length; i++) {
            assertEq(_list.itemIds[i], itemIds[i]);
        }
    }

    function registerList_ReviewRequired() internal {
        registerItems();

        delete itemIds;
        itemIds.push(4);
        itemIds.push(5);
        itemIds.push(6);
        List memory list = List({owner: bob, title: TEST, detail: TEST, schema: BYTES, itemIds: itemIds, drip: 0});

        uint256 id = bulletin.listId();
        bulletin.registerList(list);

        uint256 _id = bulletin.listId();
        assertEq(id + 1, _id);

        List memory _list = bulletin.getList(_id);
        assertEq(_list.owner, list.owner);
        assertEq(_list.title, list.title);
        assertEq(_list.detail, list.detail);
        assertEq(_list.schema, list.schema);

        uint256 length = itemIds.length;
        for (uint256 i; i < length; i++) {
            assertEq(_list.itemIds[i], itemIds[i]);
        }
    }

    function registerList_SomeReviewRequired() internal {
        registerItems();

        delete itemIds;
        itemIds.push(1);
        itemIds.push(6);
        List memory list = List({owner: charlie, title: TEST, detail: TEST, schema: BYTES, itemIds: itemIds, drip: 0});

        uint256 id = bulletin.listId();
        bulletin.registerList(list);

        uint256 _id = bulletin.listId();
        assertEq(id + 1, _id);

        List memory _list = bulletin.getList(_id);
        assertEq(_list.owner, list.owner);
        assertEq(_list.title, list.title);
        assertEq(_list.detail, list.detail);
        assertEq(_list.schema, list.schema);

        uint256 length = itemIds.length;
        for (uint256 i; i < length; i++) {
            assertEq(_list.itemIds[i], itemIds[i]);
        }
    }

    function logItem(address user, address _bulletin, uint256 _listId, uint256 _itemId) internal {
        uint256 MEMBERS = ILog(address(logger)).MEMBERS();
        uint256 id = logger.lookupLogId(user, keccak256(abi.encodePacked(_bulletin, _listId)));
        (,,, uint256 aNonce) = logger.getLog(id);

        testSetMember(user);

        vm.prank(user);
        logger.log(MEMBERS, _bulletin, _listId, _itemId, TEST, BYTES);
        id = logger.lookupLogId(user, keccak256(abi.encodePacked(_bulletin, _listId)));
        (,,, uint256 _aNonce) = logger.getLog(id);
        assertEq(aNonce + 1, _aNonce);

        uint256 nonceByItemId = logger.getNonceByItemId(_bulletin, _listId, _itemId);
        Touchpoint memory tp = logger.getTouchpointByItemIdByNonce(_bulletin, _listId, _itemId, nonceByItemId);
        assertEq(BYTES, tp.data);
    }

    // TODO: Must grant token a role on the logger contract before logging
    // function logItemByTokenOwnership(address user, address token, uint256 tokenId, uint256 _itemId) internal {
    //     (, address _bulletin, uint256 _listId,) = ITokenMinter(token).getTokenSource(tokenId);

    //     uint256 id = logger.lookupLogId(user, keccak256(abi.encodePacked(_bulletin, _listId)));
    //     (,,, uint256 aNonce) = logger.getLog(id);

    //     testSetMember(user);

    //     vm.prank(user);
    //     logger.logByToken(token, tokenId, _itemId, TEST, BYTES);

    //     id = logger.lookupLogId(user, keccak256(abi.encodePacked(_bulletin, _listId)));
    //     (,,, uint256 _aNonce) = logger.getLog(id);
    //     assertEq(aNonce + 1, _aNonce);
    // }

    function logItemBySig(string memory user, address _bulletin, uint256 _listId, uint256 _itemId) internal {
        uint256 MEMBERS = ILog(address(logger)).MEMBERS();
        (address _user, uint256 _userPk) = makeAddrAndKey(user);

        uint256 id = logger.lookupLogId(_user, keccak256(abi.encodePacked(_bulletin, _listId)));
        (,,, uint256 aNonce) = logger.getLog(id);

        // Prepare message.
        bytes32 message = keccak256(
            abi.encodePacked(
                "\x19\x01",
                logger.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(LOG_TYPEHASH, _user, _bulletin, _listId, _itemId, TEST, BYTES))
            )
        );

        testSetGasBuddy(buddy);

        // User signs message.
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_userPk, message);
        vm.prank(buddy);
        logger.logBySig(MEMBERS, _user, _bulletin, _listId, _itemId, TEST, BYTES, v, r, s);

        id = logger.lookupLogId(_user, keccak256(abi.encodePacked(_bulletin, _listId)));
        (,,, uint256 _aNonce) = logger.getLog(id);
        assertEq(aNonce + 1, _aNonce);
    }

    function logItemBySponsorship(address _bulletin, uint256 _listId, uint256 _itemId) internal {
        uint256 id = logger.lookupLogId(address(0), keccak256(abi.encodePacked(_bulletin, _listId)));
        (,,, uint256 aNonce) = logger.getLog(id);

        testSetGasBuddy(buddy);

        vm.prank(buddy);
        logger.logByPublic(_bulletin, _listId, _itemId, TEST, BYTES);
        id = logger.lookupLogId(address(0), keccak256(abi.encodePacked(_bulletin, _listId)));
        (,,, uint256 _aNonce) = logger.getLog(id);
        assertEq(aNonce + 1, _aNonce);
    }
}
