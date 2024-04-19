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
    address bot;
    uint256 botPK;

    /// @dev Public users.
    string username = "USERNAME";
    string username2 = "USERNAME2";
    string username3 = "USERNAME3";

    bytes32 public constant START_TYPEHASH = keccak256("Start(address signer,address missions,uint256 missionId)");
    bytes32 public constant RESPOND_TYPEHASH = keccak256(
        "Respond(address signer,address missions,uint256 missionId,uint256 taskId,uint256 response,string feedback)"
    );
    bytes32 public constant REVIEW_TYPEHASH =
        keccak256("Review(address signer,address user,bytes32 taskKey,uint256 response,string feedback)");

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

    function testSetGasBuddy(address buddy) public payable {
        vm.prank(dao);
        logger.setGasBuddy(buddy);
        assertEq(logger.getGasBuddy(), buddy);
    }

    function testAuthorizeLogger_NotDao(address buddy) public payable {
        vm.expectRevert(Log.NotAuthorized.selector);
        vm.prank(alice);
        logger.setGasBuddy(buddy);
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

    function test_Log_ReviewNotRequired() public payable {
        uint256 listId = 1;

        registerList_ReviewNotRequired();

        logItem(alice, address(bulletin), listId, 1);
        logItem(alice, address(bulletin), listId, 2);
        logItem(alice, address(bulletin), listId, 3);
        logItem(alice, address(bulletin), listId, 2);

        uint256 progress = logItem(alice, address(bulletin), listId, 1);
        emit log_uint(progress);

        assertEq(progress, 100);
    }

    function test_Log_ReviewRequired() public payable {
        uint256 listId = 1;

        registerList_ReviewRequired();

        logItem(alice, address(bulletin), listId, 4);
        logItem(alice, address(bulletin), listId, 5);
        logItem(alice, address(bulletin), listId, 6);
        logItem(alice, address(bulletin), listId, 5);

        uint256 progress = logItem(alice, address(bulletin), listId, 4);
        emit log_uint(progress);
        assertEq(progress, 0);
    }

    function test_Log_SomeReviewRequired() public payable {
        uint256 listId = 1;

        registerList_SomeReviewRequired();

        logItem(alice, address(bulletin), listId, 1);
        logItem(alice, address(bulletin), listId, 6);
        logItem(alice, address(bulletin), listId, 6);
        logItem(alice, address(bulletin), listId, 1);

        uint256 progress = logItem(alice, address(bulletin), listId, 1);
        emit log_uint(progress);
        assertEq(progress, 50);
    }

    /// -----------------------------------------------------------------------
    /// Evaluate
    /// ----------------------------------------------------------------------

    function test_Evaluate_ReviewRequired() public payable {
        uint256 listId = 1;
        uint256 activityId;
        uint256 progress;

        testSetReviewer(alice, address(bulletin), listId);
        test_Log_ReviewRequired();
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
    }

    function test_Evaluate_SomeReviewRequired() public payable {
        uint256 listId = 1;
        uint256 activityId;
        uint256 progress;

        testSetReviewer(alice, address(bulletin), listId);
        test_Log_SomeReviewRequired();
        activityId = logger.userActivityLookup(alice, keccak256(abi.encodePacked(address(bulletin), listId)));

        vm.prank(alice);
        logger.evaluate(activityId, address(bulletin), listId, 1, 6, true);
        (, progress) = logger.getActivityTouchpoints(activityId);
        emit log_uint(progress);

        vm.prank(alice);
        logger.evaluate(activityId, address(bulletin), listId, 2, 6, true);
        (, progress) = logger.getActivityTouchpoints(activityId);
        emit log_uint(progress);
    }

    /// -----------------------------------------------------------------------
    /// Helper
    /// ----------------------------------------------------------------------

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
        (address aUser, address aBulletin, uint256 aListId, uint256 aNonce) = logger.getActivityData(id);

        if (id > 0) {
            assertEq(aUser, user);
            assertEq(aBulletin, _bulletin);
            assertEq(aListId, _listId);
        }

        vm.prank(user);
        logger.log(_bulletin, _listId, _itemId, BYTES);
        id = logger.userActivityLookup(user, keccak256(abi.encodePacked(_bulletin, _listId)));
        uint256 _aNonce;
        (,,, _aNonce) = logger.getActivityData(id);
        assertEq(aNonce + 1, _aNonce);

        (, uint256 progress) = logger.getActivityTouchpoints(_listId);

        return progress;
    }

    // /// -----------------------------------------------------------------------
    // /// Quad-Task Mission Tests
    // /// ----------------------------------------------------------------------

    // function testQuadTaskMission_Start(address _user) public payable {
    //     vm.assume(_user != address(0));

    //     // Initialize tasks and mission.
    //     setupQuadTaskMission(dao);

    //     // Retrieve for later validation.
    //     uint256 numOfMissionsStarted = quest.getNumOfMissionsStarted();
    //     uint256 missionStarts = mission.getMissionStarts(2);
    //     (uint256 missionIdCount, uint256 missionsCount) = quest.getNumOfMissionQuested(address(mission), 2);

    //     // Start.
    //     start(_user, address(mission), 2);

    //     // Validate.
    //     assertEq(quest.getNumOfTimesQuestedByUser(_user), 1);
    //     assertEq(quest.getNumOfMissionsStarted(), numOfMissionsStarted + 1);
    //     assertEq(mission.getMissionStarts(2), missionStarts + 1);

    //     (uint256 _missionIdCount, uint256 _missionsCount) = quest.getNumOfMissionQuested(address(mission), 2);
    //     assertEq(_missionIdCount, missionIdCount + 1);
    //     assertEq(_missionsCount, missionsCount + 1);
    // }

    // function testQuadTaskMission_Start_InvalidMission_doubleStart(address _user) public payable {
    //     vm.assume(_user != address(0));

    //     // Initialize tasks and mission.
    //     setupQuadTaskMission(dao);
    //     vm.warp(block.timestamp + 10);

    //     // Start.
    //     vm.prank(_user);
    //     quest.start(address(mission), 2);

    //     // Start.
    //     vm.expectRevert(Quest.InvalidMission.selector);
    //     vm.prank(_user);
    //     quest.start(address(mission), 2);
    // }

    // function testQuadTaskMission_Start_InvalidMission_overtime(address _user) public payable {
    //     vm.assume(_user != address(0));

    //     // Initialize tasks and mission.
    //     setupQuadTaskMission(dao);
    //     vm.warp(block.timestamp + 100000);

    //     // Start.
    //     vm.expectRevert(Quest.InvalidMission.selector);
    //     vm.prank(_user);
    //     quest.start(address(mission), 2);
    // }

    // function testQuadTaskMission_Start_NotInitialized(address _user) public payable {
    //     vm.assume(_user != address(0));

    //     // Anyone can take user's signature and start quest on behalf of user.
    //     vm.expectRevert(Quest.NotInitialized.selector);
    //     vm.prank(_user);
    //     quest.start(address(mission), 0);
    // }

    // function testQuadTaskMission_StartBySig(string memory _username) public payable {
    //     (address _user, uint256 _userPk) = makeAddrAndKey(_username);

    //     // Initialize tasks and mission.
    //     setupQuadTaskMission(dao);

    //     // Retrieve for later validation.
    //     uint256 questCountByUser = quest.getNumOfTimesQuestedByUser(_user);
    //     uint256 numOfMissionsStarted = quest.getNumOfMissionsStarted();
    //     uint256 missionStarts = mission.getMissionStarts(2);
    //     (uint256 missionIdCount, uint256 missionsCount) = quest.getNumOfMissionQuested(address(mission), 2);

    //     // Prepare message.
    //     bytes32 message = keccak256(
    //         abi.encodePacked(
    //             "\x19\x01", quest.DOMAIN_SEPARATOR(), keccak256(abi.encode(START_TYPEHASH, _user, address(mission), 2))
    //         )
    //     );

    //     // George signs message.
    //     (uint8 v, bytes32 r, bytes32 s) = vm.sign(_userPk, message);

    //     vm.prank(dao);
    //     quest.setGasbot(bot);

    //     vm.deal(bot, 0.5 ether);

    //     vm.prank(bot);
    //     quest.startBySig(_user, address(mission), 2, v, r, s);

    //     // Validate.
    //     assertEq(quest.getNumOfTimesQuestedByUser(_user), questCountByUser + 1);
    //     assertEq(quest.getNumOfMissionsStarted(), numOfMissionsStarted + 1);
    //     assertEq(mission.getMissionStarts(2), missionStarts + 1);

    //     (uint256 _missionIdCount, uint256 _missionsCount) = quest.getNumOfMissionQuested(address(mission), 2);
    //     assertEq(_missionIdCount, missionIdCount + 1);
    //     assertEq(_missionsCount, missionsCount + 1);
    // }

    // function testQuadTaskMission_StartBySig_InvalidUser() public payable {
    //     (address _user, uint256 _userPk) = makeAddrAndKey("invalidUser");

    //     // Initialize tasks and mission.
    //     setupQuadTaskMission(dao);

    //     // Prepare message.
    //     bytes32 message = keccak256(
    //         abi.encodePacked(
    //             "\x19\x01", quest.DOMAIN_SEPARATOR(), keccak256(abi.encode(START_TYPEHASH, alice, address(mission), 2))
    //         )
    //     );

    //     // User signs message.
    //     (uint8 v, bytes32 r, bytes32 s) = vm.sign(_userPk, message);

    //     // Set gas bot.
    //     vm.prank(dao);
    //     quest.setGasbot(bot);

    //     // Deal bot ether.
    //     vm.deal(bot, 0.5 ether);

    //     vm.expectRevert(Quest.InvalidUser.selector);
    //     vm.prank(bot);
    //     quest.startBySig(_user, address(mission), 2, v, r, s);
    // }

    // function testQuadTaskMission_SponsoredStart(string memory _username) public payable {
    //     // Initialize tasks and mission.
    //     setupQuadTaskMission(dao);

    //     uint256 prevCount = quest.getNumOfPublicUsers();
    //     uint256 prevStartCount = quest.getNumOfStartsByMissionByPublic(address(mission), 2);

    //     // Set gas bot.
    //     vm.prank(dao);
    //     quest.setGasbot(bot);

    //     // Deal bot ether.
    //     vm.deal(bot, 0.5 ether);

    //     vm.prank(bot);
    //     quest.sponsoredStart(_username, address(mission), 2);

    //     assertEq(quest.getNumOfPublicUsers(), prevCount + 1);
    //     assertEq(quest.isPublicUser(getPublicUserAddress(_username), address(mission), 2), true);
    //     assertEq(quest.getNumOfStartsByMissionByPublic(address(mission), 2), prevStartCount + 1);
    // }

    // function testQuadTaskMission_SponsoredStart_InvalidBot(string memory _username) public payable {
    //     // Initialize tasks and mission.
    //     setupQuadTaskMission(dao);

    //     vm.expectRevert(Quest.InvalidBot.selector);
    //     vm.prank(dao);
    //     quest.sponsoredStart(_username, address(mission), 2);
    // }

    // function testQuadTaskMission_SponsoredStart_InvalidUser(string memory _username) public payable {
    //     testQuadTaskMission_SponsoredStart(_username);

    //     vm.expectRevert(Quest.InvalidUser.selector);
    //     vm.prank(bot);
    //     quest.sponsoredStart(_username, address(mission), 2);
    // }

    // function testQuadTaskMission_Respond(address _user, uint256 response) public payable {
    //     testQuadTaskMission_Start(_user);
    //     vm.warp(block.timestamp + 10);

    //     // Retrieve for validation later.
    //     uint256 completedCount = quest.getNumOfCompletedTasksInMission(_user, address(mission), 2);
    //     uint256 numOfTaskCompleted = quest.getNumOfTaskCompleted();
    //     uint256 numOfResponseByUser = quest.getNumOfResponseByUser(_user);

    //     // Respond.
    //     respond(_user, address(mission), 2, 1, response, testString);

    //     // Validate.
    //     assertEq(quest.getNumOfCompletedTasksInMission(_user, address(mission), 2), completedCount + 1);
    //     assertEq(quest.getNumOfTaskCompleted(), numOfTaskCompleted + 1);
    //     assertEq(quest.getNumOfResponseByUser(_user), numOfResponseByUser + 1);
    //     assertEq(mission.getTotalTaskCompletions(1), 1);
    //     assertEq(mission.getTotalTaskCompletionsByMission(2, 1), 1);
    // }

    // function testQuadTaskMission_Respond_InvalidMission(address _user, uint256 response) public payable {
    //     testQuadTaskMission_Start(_user);

    //     // InvalidMission().
    //     vm.expectRevert(Quest.InvalidMission.selector);
    //     vm.prank(_user);
    //     quest.respond(address(mission), 2, 5, response, testString);
    //     emit log_uint(mission.getTaskId());
    //     emit log_uint(mission.getMissionId());
    // }

    // function testQuadTaskMission_Respond_Cooldown(address _user, uint256 response) public payable {
    //     testQuadTaskMission_Start(_user);

    //     setCooldown(dao, 100);

    //     // Respond is not allowed when user is not cooled down.
    //     vm.warp(block.timestamp + 10);

    //     vm.expectRevert(Quest.Cooldown.selector);
    //     vm.prank(_user);
    //     quest.respond(address(mission), 2, 1, response, testString);

    //     vm.warp(block.timestamp + 100);

    //     // Respond is allowed after user has cooled down.
    //     uint256 completedCount = quest.getNumOfCompletedTasksInMission(_user, address(mission), 2);

    //     respond(_user, address(mission), 2, 1, response, testString);
    //     assertEq(quest.getNumOfCompletedTasksInMission(_user, address(mission), 2), completedCount + 1);
    // }

    // function testQuadTaskMission_RespondBySig(string memory _username, uint256 response) public payable {
    //     (address _user, uint256 _userPk) = makeAddrAndKey(_username);
    //     testQuadTaskMission_StartBySig(_username);
    //     vm.warp(block.timestamp + 10);

    //     // Prepare message.
    //     bytes32 message = keccak256(
    //         abi.encodePacked(
    //             "\x19\x01",
    //             quest.DOMAIN_SEPARATOR(),
    //             keccak256(abi.encode(RESPOND_TYPEHASH, _user, address(mission), 2, 1, response, testString))
    //         )
    //     );

    //     // User signs message.
    //     (uint8 v, bytes32 r, bytes32 s) = vm.sign(_userPk, message);

    //     // Retrieve for validation later.
    //     uint256 completedCount = quest.getNumOfCompletedTasksInMission(_user, address(mission), 2);
    //     uint256 numOfResponseByUser = quest.getNumOfResponseByUser(_user);

    //     // Respond by sig.
    //     vm.prank(bot);
    //     quest.respondBySig(_user, address(mission), 2, 1, response, testString, v, r, s);

    //     // Validate.
    //     assertEq(quest.getTaskResponse(quest.getQuestIdByUserAndMission(_user, address(mission), 2), 1), response);
    //     assertEq(quest.getTaskFeedback(quest.getQuestIdByUserAndMission(_user, address(mission), 2), 1), testString);
    //     assertEq(quest.getNumOfCompletedTasksInMission(_user, address(mission), 2), completedCount + 1);
    //     assertEq(quest.getNumOfResponseByUser(_user), numOfResponseByUser + 1);
    //     assertEq(mission.getTotalTaskCompletions(1), 1);
    //     assertEq(mission.getTotalTaskCompletionsByMission(2, 1), 1);
    // }

    // function testQuadTaskMission_SponsoredRespond(string memory _username, uint256 response) public payable {
    //     testQuadTaskMission_SponsoredStart(_username);

    //     // Retrieve for validation later.
    //     address _user = getPublicUserAddress(_username);
    //     uint256 completedCount = quest.getNumOfCompletedTasksInMission(_user, address(mission), 2);
    //     uint256 numOfResponseByUser = quest.getNumOfResponseByUser(_user);

    //     // Sponsored respond.
    //     vm.prank(bot);
    //     quest.sponsoredRespond(_username, address(mission), 2, 1, response, testString);

    //     // Validate.
    //     assertEq(quest.getTaskResponse(quest.getQuestIdByUserAndMission(_user, address(mission), 2), 1), response);
    //     assertEq(quest.getTaskFeedback(quest.getQuestIdByUserAndMission(_user, address(mission), 2), 1), testString);
    //     assertEq(quest.getNumOfCompletedTasksInMission(_user, address(mission), 2), completedCount + 1);
    //     assertEq(quest.isTaskAccomplished(_user, address(mission), 2, 1), true);
    //     assertEq(quest.getNumOfResponseByUser(_user), numOfResponseByUser + 1);
    //     assertEq(mission.getTotalTaskCompletions(1), 1);
    //     assertEq(mission.getTotalTaskCompletionsByMission(2, 1), 1);
    // }

    // function testQuadTaskMission_SponsoredRespond_InvalidBot(string memory _username, uint256 response)
    //     public
    //     payable
    // {
    //     // Initialize tasks and mission.
    //     setupQuadTaskMission(dao);

    //     vm.expectRevert(Quest.InvalidBot.selector);
    //     vm.prank(dao);
    //     quest.sponsoredRespond(_username, address(mission), 2, 1, response, testString);
    // }

    // function testQuadTaskMission_SponsoredRespond_InvalidUser(string memory _username, uint256 response)
    //     public
    //     payable
    // {
    //     testQuadTaskMission_SponsoredStart(_username);

    //     vm.expectRevert(Quest.InvalidUser.selector);
    //     vm.prank(bot);
    //     quest.sponsoredRespond("anotherUser", address(mission), 2, 1, response, testString);
    // }

    // function testQuadTaskMission_RespondBySig_InvalidUser(uint256 response) public payable {
    //     (address _user, uint256 _userPk) = makeAddrAndKey("invalidUser");

    //     testQuadTaskMission_StartBySig("invalidUser");
    //     vm.warp(block.timestamp + 10);

    //     // Prepare message.
    //     bytes32 message = keccak256(
    //         abi.encodePacked(
    //             "\x19\x01",
    //             quest.DOMAIN_SEPARATOR(),
    //             keccak256(abi.encode(RESPOND_TYPEHASH, alice, address(mission), 2, 1, response, testString))
    //         )
    //     );

    //     // George signs message.
    //     (uint8 v, bytes32 r, bytes32 s) = vm.sign(_userPk, message);

    //     // A mismatch between user and signature result in InvalidUser().
    //     vm.expectRevert(Quest.InvalidUser.selector);
    //     vm.prank(bot);
    //     quest.respondBySig(_user, address(mission), 2, 1, response, testString, v, r, s);
    // }

    // /// -----------------------------------------------------------------------
    // /// Quad-Task Mission Tests - Multi Starts
    // /// ----------------------------------------------------------------------

    // function testQuadTaskMission_MultipleStarts() public payable {
    //     // Start.
    //     testQuadTaskMission_Start(alice);
    //     testQuadTaskMission_StartBySig("charlie");

    //     vm.warp(block.timestamp + 100);
    //     testQuadTaskMission_Start(bob);
    //     testQuadTaskMission_StartBySig("david");
    //     testQuadTaskMission_SponsoredStart(username);

    //     vm.warp(block.timestamp + 200);
    //     testQuadTaskMission_StartBySig("eric");
    //     testQuadTaskMission_SponsoredStart(username2);

    //     // Validate.
    //     assertEq(quest.getNumOfStartsByMissionByPublic(address(mission), 2), 2);
    //     assertEq(quest.getNumOfMissionsStarted(), 7);
    // }

    // /// -----------------------------------------------------------------------
    // /// Review Test
    // /// ----------------------------------------------------------------------

    // function testSetReviewer(address reviewer, bool status) public payable {
    //     // Authorize quest contract.
    //     vm.prank(dao);
    //     quest.setReviewer(reviewer, status);

    //     // Validate.
    //     assertEq(quest.isReviewer(reviewer), status);
    // }

    // function testReview(uint256 response, uint256 reviewResponse) public payable {
    //     setupQuadTaskMission(dao);

    //     testSetReviewStatus(true);
    //     testSetReviewer(dao, true);

    //     start(bob, address(mission), 1);
    //     vm.warp(block.timestamp + 10);
    //     respond(bob, address(mission), 1, 1, response, testString);

    //     // Review.
    //     uint256 count = review(dao, bob, address(mission), 1, 1, reviewResponse, testString);
    //     assertEq(count, 1);
    // }

    // function testReview_InvalidReviewer(uint256 response, uint256 reviewResponse) public payable {
    //     setupQuadTaskMission(dao);

    //     start(bob, address(mission), 1);
    //     vm.warp(block.timestamp + 10);
    //     respond(bob, address(mission), 1, 1, response, testString);

    //     // Review.
    //     vm.expectRevert(Quest.InvalidReviewer.selector);
    //     quest.review(bob, address(mission), 1, 1, reviewResponse, testString);
    // }

    // function testReview_InvalidReview(uint256 response, uint256 reviewResponse) public payable {
    //     setupQuadTaskMission(dao);
    //     testSetReviewer(dao, true);

    //     start(bob, address(mission), 1);
    //     vm.warp(block.timestamp + 10);
    //     respond(bob, address(mission), 1, 1, response, testString);

    //     // Review.
    //     vm.expectRevert(Quest.InvalidReview.selector);
    //     vm.prank(dao);
    //     quest.review(bob, address(mission), 1, 1, reviewResponse, testString);
    // }

    // /// -----------------------------------------------------------------------
    // /// Internal Functions
    // /// -----------------------------------------------------------------------

    // function initialize(address _dao) internal {
    //     quest.initialize(_dao);
    //     mission.initialize(_dao);
    // }

    // function authorizeQuest(address _dao, address _quest) internal {
    //     vm.prank(_dao);
    //     mission.authorizeQuest(_quest, true);
    // }

    // function setupSingleTaskMission(address _dao) internal {
    //     delete creators;
    //     delete deadlines;
    //     delete titles;
    //     delete detail;
    //     delete taskIds;

    //     creators.push(alice);
    //     deadlines.push(10000);
    //     titles.push("TITLE 1");
    //     detail.push("TEST 1");

    //     vm.prank(_dao);
    //     mission.setTasks(creators, deadlines, titles, detail);

    //     taskIds.push(1);

    //     vm.prank(_dao);
    //     mission.setMission(alice, "Single Task Mission", "One Task Only!", taskIds);
    // }

    // function setupDoubleTaskMission(address _dao) internal {
    //     delete creators;
    //     delete deadlines;
    //     delete titles;
    //     delete detail;
    //     delete taskIds;

    //     creators.push(alice);
    //     deadlines.push(2);
    //     titles.push("TITLE 1");
    //     detail.push("TEST 1");

    //     creators.push(bob);
    //     deadlines.push(10);
    //     titles.push("TITLE 2");
    //     detail.push("TEST 2");

    //     vm.prank(_dao);
    //     mission.setTasks(creators, deadlines, titles, detail);

    //     taskIds.push(1);
    //     taskIds.push(2);

    //     vm.prank(_dao);
    //     mission.setMission(alice, "Double Task Mission", "Two Tasks!", taskIds);
    // }

    // function setupTripleTaskMission(address _dao) internal {
    //     delete creators;
    //     delete deadlines;
    //     delete titles;
    //     delete detail;
    //     delete taskIds;

    //     creators.push(alice);
    //     deadlines.push(2);
    //     titles.push("TITLE 1");
    //     detail.push("TEST 1");

    //     creators.push(bob);
    //     deadlines.push(10);
    //     titles.push("TITLE 2");
    //     detail.push("TEST 2");

    //     creators.push(charlie);
    //     deadlines.push(1000);
    //     titles.push("TITLE 3");
    //     detail.push("TEST 3");

    //     vm.prank(_dao);
    //     mission.setTasks(creators, deadlines, titles, detail);

    //     taskIds.push(1);
    //     taskIds.push(2);
    //     taskIds.push(3);

    //     vm.prank(_dao);
    //     mission.setMission(alice, "Three Task Mission", "Three Tasks!", taskIds);
    // }

    // function setupQuadTaskMission(address _dao) internal {
    //     delete creators;
    //     delete deadlines;
    //     delete titles;
    //     delete detail;
    //     delete taskIds;

    //     creators.push(alice);
    //     deadlines.push(2);
    //     titles.push("TITLE 1");
    //     detail.push("TEST 1");

    //     creators.push(bob);
    //     deadlines.push(10);
    //     titles.push("TITLE 2");
    //     detail.push("TEST 2");

    //     creators.push(charlie);
    //     deadlines.push(1000);
    //     titles.push("TITLE 3");
    //     detail.push("TEST 3");

    //     creators.push(david);
    //     deadlines.push(10000);
    //     titles.push("TITLE 4");
    //     detail.push("TEST 4");

    //     vm.prank(_dao);
    //     mission.setTasks(creators, deadlines, titles, detail);

    //     taskIds.push(1);
    //     taskIds.push(2);
    //     taskIds.push(3);
    //     taskIds.push(4);

    //     vm.prank(_dao);
    //     mission.setMission(alice, "Four Task Mission", "Four Tasks!", taskIds);
    // }

    // function setCooldown(address _user, uint40 cd) public payable {
    //     // Authorize quest contract.
    //     vm.prank(_user);
    //     quest.setCooldown(cd);

    //     // Validate.
    //     assertEq(quest.getCooldown(), cd);
    // }

    // function start(address _user, address _mission, uint256 _missionId) public payable {
    //     // Start.
    //     vm.prank(_user);
    //     quest.start(_mission, _missionId);

    //     // Validate.
    //     (address __user, address __mission, uint256 __missionId) = quest.getQuest(quest.getQuestId());
    //     assertEq(__user, _user);
    //     assertEq(__mission, _mission);
    //     assertEq(__missionId, _missionId);
    // }

    // function respond(
    //     address _user,
    //     address _mission,
    //     uint256 _missionId,
    //     uint256 _taskId,
    //     uint256 response,
    //     string memory feedback
    // ) internal {
    //     // Respond.
    //     vm.prank(_user);
    //     quest.respond(_mission, _missionId, _taskId, response, feedback);

    //     // Validate.
    //     assertEq(
    //         quest.getTaskResponse(quest.getQuestIdByUserAndMission(_user, address(_mission), _missionId), _taskId),
    //         response
    //     );
    //     assertEq(
    //         quest.getTaskFeedback(quest.getQuestIdByUserAndMission(_user, address(_mission), _missionId), _taskId),
    //         feedback
    //     );
    // }

    // function review(
    //     address reviewer,
    //     address _user,
    //     address _mission,
    //     uint256 _missionId,
    //     uint256 _taskId,
    //     uint256 reviewResponse,
    //     string memory reviewFeedback
    // ) internal returns (uint256) {
    //     // Review.
    //     vm.prank(reviewer);
    //     quest.review(_user, address(_mission), _missionId, _taskId, reviewResponse, reviewFeedback);

    //     // Validate.
    //     uint256 count = quest.getNumOfReviewByReviewer(reviewer);
    //     assertEq(quest.getReviewResponse(reviewer, count), reviewResponse);
    //     assertEq(quest.getReviewFeedback(reviewer, count), reviewFeedback);
    //     return count;
    // }

    // // function testGetPublicUserAddress(uint256 salt, uint256 salt2) public payable {
    // //     vm.assume(salt != salt2);
    // //     address address1 = getPublicUserAddress(username, salt);
    // //     address address2 = getPublicUserAddress(username2, salt2);
    // //     address altAddress1 = getPublicUserAddress(username, salt);
    // //     address altAddress2 = getPublicUserAddress(username, salt2);
    // //     address bltAddress1 = getPublicUserAddress(username, salt);
    // //     address bltAddress2 = getPublicUserAddress(username2, salt);

    // //     assert(address1 != address2);
    // //     assert(altAddress1 != altAddress2);
    // //     assert(bltAddress1 != bltAddress2);
    // // }

    // function getPublicUserAddress(string memory _username) internal pure returns (address) {
    //     return address(uint160(uint256(keccak256(abi.encode(_username)))));
    // }
}
