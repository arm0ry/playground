// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {Log} from "src/Log.sol";
import {ILog, Activity, Touchpoint} from "src/interface/ILog.sol";
import {Bulletin} from "src/Bulletin.sol";
import {IBulletin, Item, List} from "src/interface/IBulletin.sol";

import {BulletinTest} from "./Bulletin.t.sol";

contract LogTest is Test {
    Bulletin bulletin;
    Log logger;

    /// @dev Web3 Users.
    address dao = makeAddr("dao");
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
    Item item1 = Item({review: false, expire: PAST, owner: makeAddr("alice"), title: TEST, detail: TEST, schema: BYTES});
    Item item2 = Item({review: false, expire: FUTURE, owner: makeAddr("bob"), title: TEST, detail: TEST, schema: BYTES});
    Item item3 =
        Item({review: false, expire: FUTURE, owner: makeAddr("charlie"), title: TEST, detail: TEST, schema: BYTES});
    Item item4 =
        Item({review: true, expire: PAST, owner: makeAddr("charlie"), title: TEST, detail: TEST, schema: BYTES});
    Item item5 =
        Item({review: true, expire: FUTURE, owner: makeAddr("alice"), title: TEST, detail: TEST, schema: BYTES});
    Item item6 = Item({review: true, expire: FUTURE, owner: makeAddr("bob"), title: TEST, detail: TEST, schema: BYTES});

    // Touchpoint[] touchpoints;
    uint256 percentageOfCompletion;

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
        keccak256("Log(address bulletin, uint256 listId ,uint256 itemId, string feedback, bytes data)");

    /// -----------------------------------------------------------------------
    /// Setup Tests
    /// -----------------------------------------------------------------------

    /// @notice Set up the testing suite.
    function setUp() public payable {
        (alice, alicePk) = makeAddrAndKey("alice");
        (bob, bobPk) = makeAddrAndKey("bob");
        (charlie, charliePk) = makeAddrAndKey("charlie");

        deployBulletin(dao);
        deployLogger(dao);
    }

    function testReceiveETH() public payable {
        (bool sent,) = address(logger).call{value: 5 ether}("");
        assert(!sent);
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

    function testSetGasBuddy(address _buddy) public payable {
        vm.prank(dao);
        logger.setGasBuddy(_buddy);
        assertEq(logger.getGasBuddy(), _buddy);
    }

    function testSetGasBuddy_NotDao(address _buddy) public payable {
        vm.expectRevert(Log.NotAuthorized.selector);
        vm.prank(alice);
        logger.setGasBuddy(_buddy);
    }

    function testSetReviewer(address reviewer, address _bulletin, uint256 listId) public payable {
        vm.prank(dao);
        logger.setReviewer(reviewer, _bulletin, listId);
        assertEq(logger.isReviewer(reviewer, keccak256(abi.encodePacked(_bulletin, listId))), true);
    }

    function testSetReviewer_NotDao(address reviewer) public payable {
        vm.expectRevert(Log.NotAuthorized.selector);
        vm.prank(alice);
        logger.setReviewer(reviewer, address(bulletin), 1);
    }

    /// -----------------------------------------------------------------------
    /// Log
    /// ----------------------------------------------------------------------

    function test_Log_ReviewNotRequired_LoggerAuthorized() public payable {
        uint256 listId = 1;

        registerList_ReviewNotRequired();
        authorizeLogger(true);

        logItem(alice, address(bulletin), listId, 1);
        logItem(alice, address(bulletin), listId, 2);
        logItemBySig(string("alice"), address(bulletin), listId, 3);
        logItemBySponsorship(alice, address(bulletin), listId, 2);

        uint256 progress = logItem(alice, address(bulletin), listId, 1);
        emit log_uint(progress);

        assertEq(progress, 100);

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

        uint256 progress = logItem(alice, address(bulletin), listId, 1);
        emit log_uint(progress);

        assertEq(progress, 100);

        assertEq(bulletin.runsByItem(2), 0);
        assertEq(bulletin.runsByItem(3), 0);
        assertEq(bulletin.runsByList(listId), 0);
    }

    function test_Log_ReviewRequired_LoggerAuthorized() public payable {
        uint256 listId = 1;

        registerList_ReviewRequired();
        authorizeLogger(true);

        logItem(alice, address(bulletin), listId, 4);
        logItem(alice, address(bulletin), listId, 5);
        logItem(alice, address(bulletin), listId, 6);
        logItem(alice, address(bulletin), listId, 5);

        uint256 progress = logItem(alice, address(bulletin), listId, 4);
        emit log_uint(progress);
        assertEq(progress, 0);

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

        uint256 progress = logItem(alice, address(bulletin), listId, 4);
        emit log_uint(progress);
        assertEq(progress, 0);

        assertEq(bulletin.runsByItem(5), 0);
        assertEq(bulletin.runsByItem(6), 0);
        assertEq(bulletin.runsByList(listId), 0);
    }

    function test_Log_SomeReviewRequired_LoggerAuthorized() public payable {
        uint256 listId = 1;

        registerList_SomeReviewRequired();
        authorizeLogger(true);

        logItem(alice, address(bulletin), listId, 1);
        logItem(alice, address(bulletin), listId, 6);
        logItem(alice, address(bulletin), listId, 6);
        logItem(alice, address(bulletin), listId, 1);

        uint256 progress = logItem(alice, address(bulletin), listId, 1);
        emit log_uint(progress);
        assertEq(progress, 50);

        assertEq(bulletin.runsByItem(1), 3);
        assertEq(bulletin.runsByItem(6), 0);
        assertEq(bulletin.runsByList(listId), 0);
    }

    /// -----------------------------------------------------------------------
    /// Evaluate
    /// ----------------------------------------------------------------------

    function test_Evaluate_ReviewRequired() public payable {
        uint256 listId = 1;
        uint256 activityId;
        uint256 progress;

        testSetReviewer(alice, address(bulletin), listId);
        test_Log_ReviewRequired_LoggerAuthorized();
        activityId = logger.userActivityLookup(alice, keccak256(abi.encodePacked(address(bulletin), listId)));

        vm.prank(alice);
        logger.evaluate(activityId, address(bulletin), listId, 0, 4, true);
        (, progress) = logger.getActivityTouchpoints(activityId);
        emit log_uint(progress);

        vm.prank(alice);
        logger.evaluate(activityId, address(bulletin), listId, 1, 5, true);
        (, progress) = logger.getActivityTouchpoints(activityId);
        emit log_uint(progress);

        vm.prank(alice);
        logger.evaluate(activityId, address(bulletin), listId, 2, 6, true);
        (, progress) = logger.getActivityTouchpoints(activityId);
        emit log_uint(progress);

        assertEq(bulletin.runsByItem(4), 1);
        assertEq(bulletin.runsByItem(5), 1);
        assertEq(bulletin.runsByItem(6), 1);
        assertEq(bulletin.runsByList(listId), 1);
    }

    function test_Evaluate_SomeReviewRequired() public payable {
        uint256 listId = 1;
        uint256 activityId;
        uint256 progress;

        testSetReviewer(alice, address(bulletin), listId);
        test_Log_SomeReviewRequired_LoggerAuthorized();
        activityId = logger.userActivityLookup(alice, keccak256(abi.encodePacked(address(bulletin), listId)));

        vm.prank(alice);
        logger.evaluate(activityId, address(bulletin), listId, 1, 6, true);
        (, progress) = logger.getActivityTouchpoints(activityId);
        emit log_uint(progress);

        vm.prank(alice);
        logger.evaluate(activityId, address(bulletin), listId, 2, 6, true);
        (, progress) = logger.getActivityTouchpoints(activityId);
        emit log_uint(progress);

        assertEq(bulletin.runsByItem(6), 2);
        assertEq(bulletin.runsByList(listId), 2);
    }

    /// -----------------------------------------------------------------------
    /// Helper
    /// ----------------------------------------------------------------------

    function authorizeLogger(bool auth) internal {
        vm.prank(dao);
        bulletin.authorizeLogger(address(logger), auth);
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
        }
    }

    function registerList_ReviewNotRequired() internal {
        registerItems();

        delete itemIds;
        itemIds.push(1);
        itemIds.push(2);
        itemIds.push(3);
        List memory list = List({owner: alice, title: TEST, detail: TEST, schema: BYTES, itemIds: itemIds});

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
        List memory list = List({owner: bob, title: TEST, detail: TEST, schema: BYTES, itemIds: itemIds});

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
        List memory list = List({owner: charlie, title: TEST, detail: TEST, schema: BYTES, itemIds: itemIds});

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

    function logItem(address user, address _bulletin, uint256 _listId, uint256 _itemId) internal returns (uint256) {
        uint256 id = logger.userActivityLookup(user, keccak256(abi.encodePacked(_bulletin, _listId)));
        (,,, uint256 aNonce) = logger.getActivityData(id);

        vm.prank(user);
        logger.log(_bulletin, _listId, _itemId, TEST, BYTES);
        id = logger.userActivityLookup(user, keccak256(abi.encodePacked(_bulletin, _listId)));
        uint256 _aNonce;
        (,,, _aNonce) = logger.getActivityData(id);
        assertEq(aNonce + 1, _aNonce);

        (, uint256 progress) = logger.getActivityTouchpoints(_listId);

        return progress;
    }

    function logItemBySig(string memory user, address _bulletin, uint256 _listId, uint256 _itemId)
        internal
        returns (uint256)
    {
        (address _user, uint256 _userPk) = makeAddrAndKey(user);

        uint256 id = logger.userActivityLookup(_user, keccak256(abi.encodePacked(_bulletin, _listId)));
        (,,, uint256 aNonce) = logger.getActivityData(id);

        // Prepare message.
        bytes32 message = keccak256(
            abi.encodePacked(
                "\x19\x01",
                logger.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(LOG_TYPEHASH, _user, address(bulletin), _listId, _itemId, TEST, BYTES))
            )
        );

        // George signs message.
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_userPk, message);
        logger.logBySig(_user, address(bulletin), _listId, _itemId, TEST, BYTES, v, r, s);

        id = logger.userActivityLookup(_user, keccak256(abi.encodePacked(_bulletin, _listId)));
        (,,, uint256 _aNonce) = logger.getActivityData(id);
        assertEq(aNonce + 1, _aNonce);

        (, uint256 progress) = logger.getActivityTouchpoints(_listId);

        return progress;
    }

    function logItemBySponsorship(address user, address _bulletin, uint256 _listId, uint256 _itemId)
        internal
        returns (uint256)
    {
        uint256 id = logger.userActivityLookup(user, keccak256(abi.encodePacked(_bulletin, _listId)));
        (,,, uint256 aNonce) = logger.getActivityData(id);

        testSetGasBuddy(buddy);

        vm.prank(buddy);
        logger.sponsoredLog(_bulletin, _listId, _itemId, TEST, BYTES);
        id = logger.userActivityLookup(user, keccak256(abi.encodePacked(_bulletin, _listId)));
        uint256 _aNonce;
        (,,, _aNonce) = logger.getActivityData(id);
        assertEq(aNonce + 1, _aNonce);

        (, uint256 progress) = logger.getActivityTouchpoints(_listId);

        return progress;
    }
}
