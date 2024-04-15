// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "kali-markets/Storage.sol";
import {Mission} from "src/Mission.sol";
import {IMission} from "src/interface/IMission.sol";
import {Quest} from "src/Quest.sol";
import {IQuest} from "src/interface/IQuest.sol";

import {Log} from "src/Log.sol";
import {ILog} from "src/interface/ILog.sol";
import {Bulletin} from "src/Bulletin.sol";
import {IBulletin} from "src/interface/IBulletin.sol";

contract QuestTest is Test {
    Bulletin bulletin;
    Log logger;

    Quest quest;
    Mission mission;

    address[] creators;
    uint256[] deadlines;
    string[] titles;
    string[] detail;
    uint256[] taskIds;

    /// @dev Web3 Users.
    address dao = makeAddr("dao");
    address[] reviewers;
    address alice;
    uint256 alicePk;
    address bob;
    uint256 bobPk;
    address charlie;
    uint256 charliePk;
    address david;
    uint256 davidPk;
    address eric;
    uint256 ericPk;

    /// @dev Helpers.
    uint256 taskId;
    uint256 missionId;
    string testString = "TEST";

    /// @dev Bot.
    address bot;
    uint256 botPK;
    string gasbotString = "GASBOT";

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
        // Deploy contract
        bulletin = new Bulletin(dao);
        logger = new Log(dao);

        // Initialize user.
        (alice, alicePk) = makeAddrAndKey("alice");
        (bob, bobPk) = makeAddrAndKey("bob");
        (charlie, charliePk) = makeAddrAndKey("charlie");
        (david, davidPk) = makeAddrAndKey("david");
        (eric, ericPk) = makeAddrAndKey("eric");

        (bot, botPK) = makeAddrAndKey(gasbotString);

        // initialize(dao);
        // authorizeQuest(dao, address(quest));

        // setupSingleTaskMission(dao);
    }

    /// -----------------------------------------------------------------------
    /// DAO Test
    /// ----------------------------------------------------------------------

    function testSetCooldown(uint40 cd) public payable {
        // Authorize quest contract.
        setCooldown(dao, cd);
    }

    function testSetCooldown_NotOperator(uint40 cd) public payable {
        // Authorize quest contract.
        vm.expectRevert(Storage.NotOperator.selector);
        quest.setCooldown(cd);
    }

    function testSetReviewStatus(bool reviewStatus) public payable {
        // Authorize quest contract.
        vm.prank(dao);
        quest.setReviewStatus(reviewStatus);

        // Validate.
        assertEq(quest.getReviewStatus(), reviewStatus);
    }

    function testSetReviewStatus_NotOperator(bool reviewStatus) public payable {
        // Initialize.
        initialize(dao);

        // Authorize quest contract.
        vm.expectRevert(Storage.NotOperator.selector);
        quest.setReviewStatus(reviewStatus);
    }

    /// -----------------------------------------------------------------------
    /// Single-Task Mission Tests
    /// ----------------------------------------------------------------------

    function testSingleTaskMission_Start(address _user) public payable {
        // Start.
        start(_user, address(mission), 1);

        // Validate.
        assertEq(quest.getNumOfTimesQuestedByUser(_user), 1);
        assertEq(quest.getNumOfMissionsStarted(), 1);
        assertEq(mission.getMissionStarts(1), 1);

        (uint256 missionIdCount, uint256 missionsCount) = quest.getNumOfMissionQuested(address(mission), 1);
        assertEq(missionIdCount, 1);
        assertEq(missionsCount, 1);
    }

    function testSingleTaskMission_Start_NoAuthorizedQuest(address _user) public payable {
        vm.prank(dao);
        mission.authorizeQuest(address(quest), false);

        // Start.
        start(_user, address(mission), 1);

        // Validate.
        assertEq(quest.getNumOfTimesQuestedByUser(_user), 1);
        assertEq(quest.getNumOfMissionsStarted(), 1);
        assertEq(mission.getMissionStarts(1), 0);

        (uint256 missionIdCount, uint256 missionsCount) = quest.getNumOfMissionQuested(address(mission), 1);
        assertEq(missionIdCount, 1);
        assertEq(missionsCount, 1);
    }

    function testSingleTaskMission_Respond(address _user, uint256 response) public payable {
        vm.assume(_user != address(0));
        testSingleTaskMission_Start(_user);
        vm.warp(block.timestamp + 10);

        // Retrieve for validation later.
        uint256 completedCount = quest.getNumOfCompletedTasksInMission(_user, address(mission), 1);
        uint256 numOfTaskCompleted = quest.getNumOfTaskCompleted();
        uint256 numOfMissionCompleted = quest.getNumOfMissionsCompleted();

        // Respond.
        uint256 _missionId = 1;
        uint256 _taskId = 1;
        respond(_user, address(mission), _missionId, 1, response, testString);

        // Validate.
        assertEq(quest.getNumOfCompletedTasksInMission(_user, address(mission), _missionId), 1);
        assertEq(quest.getNumOfTaskCompleted(), numOfTaskCompleted + 1);
        assertEq(quest.getNumOfMissionsCompleted(), numOfMissionCompleted + 1);
        assertEq(
            quest.getTaskResponse(quest.getQuestIdByUserAndMission(_user, address(mission), _missionId), _taskId),
            response
        );
        assertEq(
            quest.getTaskFeedback(quest.getQuestIdByUserAndMission(_user, address(mission), _missionId), _taskId),
            testString
        );
        assertEq(mission.getMissionCompletions(1), 1);
        assertEq(mission.getTotalTaskCompletions(1), 1);
        assertEq(mission.getTotalTaskCompletionsByMission(1, 1), 1);
    }

    function testSingleTaskMission_Respond_NoAuthorizedQuest(address _user, uint256 response) public payable {
        vm.assume(_user != address(0));
        testSingleTaskMission_Start_NoAuthorizedQuest(_user);
        vm.warp(block.timestamp + 10);

        // Retrieve for validation later.
        uint256 completedCount = quest.getNumOfCompletedTasksInMission(bob, address(mission), 1);
        uint256 numOfTaskCompleted = quest.getNumOfTaskCompleted();
        uint256 numOfMissionCompleted = quest.getNumOfMissionsCompleted();

        // Respond.
        uint256 _missionId = 1;
        uint256 _taskId = 1;
        respond(_user, address(mission), _missionId, 1, response, testString);

        // Validate.
        assertEq(quest.getNumOfCompletedTasksInMission(_user, address(mission), _missionId), 1);
        assertEq(quest.getNumOfTaskCompleted(), numOfTaskCompleted + 1);
        assertEq(quest.getNumOfMissionsCompleted(), numOfMissionCompleted + 1);
        assertEq(
            quest.getTaskResponse(quest.getQuestIdByUserAndMission(_user, address(mission), _missionId), _taskId),
            response
        );
        assertEq(
            quest.getTaskFeedback(quest.getQuestIdByUserAndMission(_user, address(mission), _missionId), _taskId),
            testString
        );
        assertEq(mission.getMissionCompletions(_missionId), 0);
        assertEq(mission.getTotalTaskCompletions(_missionId), 0);
        assertEq(mission.getTotalTaskCompletionsByMission(_missionId, _taskId), 0);
    }

    function testSingleTaskMission_Respond_InvalidRestart(address _user, uint256 response) public payable {
        testSingleTaskMission_Respond(_user, response);

        // .
        vm.expectRevert(Quest.InvalidMission.selector);
        vm.prank(_user);
        quest.start(address(mission), 1);
    }

    /// -----------------------------------------------------------------------
    /// Quad-Task Mission Tests
    /// ----------------------------------------------------------------------

    function testQuadTaskMission_Start(address _user) public payable {
        vm.assume(_user != address(0));

        // Initialize tasks and mission.
        setupQuadTaskMission(dao);

        // Retrieve for later validation.
        uint256 numOfMissionsStarted = quest.getNumOfMissionsStarted();
        uint256 missionStarts = mission.getMissionStarts(2);
        (uint256 missionIdCount, uint256 missionsCount) = quest.getNumOfMissionQuested(address(mission), 2);

        // Start.
        start(_user, address(mission), 2);

        // Validate.
        assertEq(quest.getNumOfTimesQuestedByUser(_user), 1);
        assertEq(quest.getNumOfMissionsStarted(), numOfMissionsStarted + 1);
        assertEq(mission.getMissionStarts(2), missionStarts + 1);

        (uint256 _missionIdCount, uint256 _missionsCount) = quest.getNumOfMissionQuested(address(mission), 2);
        assertEq(_missionIdCount, missionIdCount + 1);
        assertEq(_missionsCount, missionsCount + 1);
    }

    function testQuadTaskMission_Start_InvalidMission_doubleStart(address _user) public payable {
        vm.assume(_user != address(0));

        // Initialize tasks and mission.
        setupQuadTaskMission(dao);
        vm.warp(block.timestamp + 10);

        // Start.
        vm.prank(_user);
        quest.start(address(mission), 2);

        // Start.
        vm.expectRevert(Quest.InvalidMission.selector);
        vm.prank(_user);
        quest.start(address(mission), 2);
    }

    function testQuadTaskMission_Start_InvalidMission_overtime(address _user) public payable {
        vm.assume(_user != address(0));

        // Initialize tasks and mission.
        setupQuadTaskMission(dao);
        vm.warp(block.timestamp + 100000);

        // Start.
        vm.expectRevert(Quest.InvalidMission.selector);
        vm.prank(_user);
        quest.start(address(mission), 2);
    }

    function testQuadTaskMission_Start_NotInitialized(address _user) public payable {
        vm.assume(_user != address(0));

        // Anyone can take user's signature and start quest on behalf of user.
        vm.expectRevert(Quest.NotInitialized.selector);
        vm.prank(_user);
        quest.start(address(mission), 0);
    }

    function testQuadTaskMission_StartBySig(string memory _username) public payable {
        (address _user, uint256 _userPk) = makeAddrAndKey(_username);

        // Initialize tasks and mission.
        setupQuadTaskMission(dao);

        // Retrieve for later validation.
        uint256 questCountByUser = quest.getNumOfTimesQuestedByUser(_user);
        uint256 numOfMissionsStarted = quest.getNumOfMissionsStarted();
        uint256 missionStarts = mission.getMissionStarts(2);
        (uint256 missionIdCount, uint256 missionsCount) = quest.getNumOfMissionQuested(address(mission), 2);

        // Prepare message.
        bytes32 message = keccak256(
            abi.encodePacked(
                "\x19\x01", quest.DOMAIN_SEPARATOR(), keccak256(abi.encode(START_TYPEHASH, _user, address(mission), 2))
            )
        );

        // George signs message.
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_userPk, message);

        vm.prank(dao);
        quest.setGasbot(bot);

        vm.deal(bot, 0.5 ether);

        vm.prank(bot);
        quest.startBySig(_user, address(mission), 2, v, r, s);

        // Validate.
        assertEq(quest.getNumOfTimesQuestedByUser(_user), questCountByUser + 1);
        assertEq(quest.getNumOfMissionsStarted(), numOfMissionsStarted + 1);
        assertEq(mission.getMissionStarts(2), missionStarts + 1);

        (uint256 _missionIdCount, uint256 _missionsCount) = quest.getNumOfMissionQuested(address(mission), 2);
        assertEq(_missionIdCount, missionIdCount + 1);
        assertEq(_missionsCount, missionsCount + 1);
    }

    function testQuadTaskMission_StartBySig_InvalidUser() public payable {
        (address _user, uint256 _userPk) = makeAddrAndKey("invalidUser");

        // Initialize tasks and mission.
        setupQuadTaskMission(dao);

        // Prepare message.
        bytes32 message = keccak256(
            abi.encodePacked(
                "\x19\x01", quest.DOMAIN_SEPARATOR(), keccak256(abi.encode(START_TYPEHASH, alice, address(mission), 2))
            )
        );

        // User signs message.
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_userPk, message);

        // Set gas bot.
        vm.prank(dao);
        quest.setGasbot(bot);

        // Deal bot ether.
        vm.deal(bot, 0.5 ether);

        vm.expectRevert(Quest.InvalidUser.selector);
        vm.prank(bot);
        quest.startBySig(_user, address(mission), 2, v, r, s);
    }

    function testQuadTaskMission_SponsoredStart(string memory _username) public payable {
        // Initialize tasks and mission.
        setupQuadTaskMission(dao);

        uint256 prevCount = quest.getNumOfPublicUsers();
        uint256 prevStartCount = quest.getNumOfStartsByMissionByPublic(address(mission), 2);

        // Set gas bot.
        vm.prank(dao);
        quest.setGasbot(bot);

        // Deal bot ether.
        vm.deal(bot, 0.5 ether);

        vm.prank(bot);
        quest.sponsoredStart(_username, address(mission), 2);

        assertEq(quest.getNumOfPublicUsers(), prevCount + 1);
        assertEq(quest.isPublicUser(getPublicUserAddress(_username), address(mission), 2), true);
        assertEq(quest.getNumOfStartsByMissionByPublic(address(mission), 2), prevStartCount + 1);
    }

    function testQuadTaskMission_SponsoredStart_InvalidBot(string memory _username) public payable {
        // Initialize tasks and mission.
        setupQuadTaskMission(dao);

        vm.expectRevert(Quest.InvalidBot.selector);
        vm.prank(dao);
        quest.sponsoredStart(_username, address(mission), 2);
    }

    function testQuadTaskMission_SponsoredStart_InvalidUser(string memory _username) public payable {
        testQuadTaskMission_SponsoredStart(_username);

        vm.expectRevert(Quest.InvalidUser.selector);
        vm.prank(bot);
        quest.sponsoredStart(_username, address(mission), 2);
    }

    function testQuadTaskMission_Respond(address _user, uint256 response) public payable {
        testQuadTaskMission_Start(_user);
        vm.warp(block.timestamp + 10);

        // Retrieve for validation later.
        uint256 completedCount = quest.getNumOfCompletedTasksInMission(_user, address(mission), 2);
        uint256 numOfTaskCompleted = quest.getNumOfTaskCompleted();
        uint256 numOfResponseByUser = quest.getNumOfResponseByUser(_user);

        // Respond.
        respond(_user, address(mission), 2, 1, response, testString);

        // Validate.
        assertEq(quest.getNumOfCompletedTasksInMission(_user, address(mission), 2), completedCount + 1);
        assertEq(quest.getNumOfTaskCompleted(), numOfTaskCompleted + 1);
        assertEq(quest.getNumOfResponseByUser(_user), numOfResponseByUser + 1);
        assertEq(mission.getTotalTaskCompletions(1), 1);
        assertEq(mission.getTotalTaskCompletionsByMission(2, 1), 1);
    }

    function testQuadTaskMission_Respond_InvalidMission(address _user, uint256 response) public payable {
        testQuadTaskMission_Start(_user);

        // InvalidMission().
        vm.expectRevert(Quest.InvalidMission.selector);
        vm.prank(_user);
        quest.respond(address(mission), 2, 5, response, testString);
        emit log_uint(mission.getTaskId());
        emit log_uint(mission.getMissionId());
    }

    function testQuadTaskMission_Respond_Cooldown(address _user, uint256 response) public payable {
        testQuadTaskMission_Start(_user);

        setCooldown(dao, 100);

        // Respond is not allowed when user is not cooled down.
        vm.warp(block.timestamp + 10);

        vm.expectRevert(Quest.Cooldown.selector);
        vm.prank(_user);
        quest.respond(address(mission), 2, 1, response, testString);

        vm.warp(block.timestamp + 100);

        // Respond is allowed after user has cooled down.
        uint256 completedCount = quest.getNumOfCompletedTasksInMission(_user, address(mission), 2);

        respond(_user, address(mission), 2, 1, response, testString);
        assertEq(quest.getNumOfCompletedTasksInMission(_user, address(mission), 2), completedCount + 1);
    }

    function testQuadTaskMission_RespondBySig(string memory _username, uint256 response) public payable {
        (address _user, uint256 _userPk) = makeAddrAndKey(_username);
        testQuadTaskMission_StartBySig(_username);
        vm.warp(block.timestamp + 10);

        // Prepare message.
        bytes32 message = keccak256(
            abi.encodePacked(
                "\x19\x01",
                quest.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(RESPOND_TYPEHASH, _user, address(mission), 2, 1, response, testString))
            )
        );

        // User signs message.
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_userPk, message);

        // Retrieve for validation later.
        uint256 completedCount = quest.getNumOfCompletedTasksInMission(_user, address(mission), 2);
        uint256 numOfResponseByUser = quest.getNumOfResponseByUser(_user);

        // Respond by sig.
        vm.prank(bot);
        quest.respondBySig(_user, address(mission), 2, 1, response, testString, v, r, s);

        // Validate.
        assertEq(quest.getTaskResponse(quest.getQuestIdByUserAndMission(_user, address(mission), 2), 1), response);
        assertEq(quest.getTaskFeedback(quest.getQuestIdByUserAndMission(_user, address(mission), 2), 1), testString);
        assertEq(quest.getNumOfCompletedTasksInMission(_user, address(mission), 2), completedCount + 1);
        assertEq(quest.getNumOfResponseByUser(_user), numOfResponseByUser + 1);
        assertEq(mission.getTotalTaskCompletions(1), 1);
        assertEq(mission.getTotalTaskCompletionsByMission(2, 1), 1);
    }

    function testQuadTaskMission_SponsoredRespond(string memory _username, uint256 response) public payable {
        testQuadTaskMission_SponsoredStart(_username);

        // Retrieve for validation later.
        address _user = getPublicUserAddress(_username);
        uint256 completedCount = quest.getNumOfCompletedTasksInMission(_user, address(mission), 2);
        uint256 numOfResponseByUser = quest.getNumOfResponseByUser(_user);

        // Sponsored respond.
        vm.prank(bot);
        quest.sponsoredRespond(_username, address(mission), 2, 1, response, testString);

        // Validate.
        assertEq(quest.getTaskResponse(quest.getQuestIdByUserAndMission(_user, address(mission), 2), 1), response);
        assertEq(quest.getTaskFeedback(quest.getQuestIdByUserAndMission(_user, address(mission), 2), 1), testString);
        assertEq(quest.getNumOfCompletedTasksInMission(_user, address(mission), 2), completedCount + 1);
        assertEq(quest.isTaskAccomplished(_user, address(mission), 2, 1), true);
        assertEq(quest.getNumOfResponseByUser(_user), numOfResponseByUser + 1);
        assertEq(mission.getTotalTaskCompletions(1), 1);
        assertEq(mission.getTotalTaskCompletionsByMission(2, 1), 1);
    }

    function testQuadTaskMission_SponsoredRespond_InvalidBot(string memory _username, uint256 response)
        public
        payable
    {
        // Initialize tasks and mission.
        setupQuadTaskMission(dao);

        vm.expectRevert(Quest.InvalidBot.selector);
        vm.prank(dao);
        quest.sponsoredRespond(_username, address(mission), 2, 1, response, testString);
    }

    function testQuadTaskMission_SponsoredRespond_InvalidUser(string memory _username, uint256 response)
        public
        payable
    {
        testQuadTaskMission_SponsoredStart(_username);

        vm.expectRevert(Quest.InvalidUser.selector);
        vm.prank(bot);
        quest.sponsoredRespond("anotherUser", address(mission), 2, 1, response, testString);
    }

    function testQuadTaskMission_RespondBySig_InvalidUser(uint256 response) public payable {
        (address _user, uint256 _userPk) = makeAddrAndKey("invalidUser");

        testQuadTaskMission_StartBySig("invalidUser");
        vm.warp(block.timestamp + 10);

        // Prepare message.
        bytes32 message = keccak256(
            abi.encodePacked(
                "\x19\x01",
                quest.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(RESPOND_TYPEHASH, alice, address(mission), 2, 1, response, testString))
            )
        );

        // George signs message.
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_userPk, message);

        // A mismatch between user and signature result in InvalidUser().
        vm.expectRevert(Quest.InvalidUser.selector);
        vm.prank(bot);
        quest.respondBySig(_user, address(mission), 2, 1, response, testString, v, r, s);
    }

    /// -----------------------------------------------------------------------
    /// Quad-Task Mission Tests - Multi Starts
    /// ----------------------------------------------------------------------

    function testQuadTaskMission_MultipleStarts() public payable {
        // Start.
        testQuadTaskMission_Start(alice);
        testQuadTaskMission_StartBySig("charlie");

        vm.warp(block.timestamp + 100);
        testQuadTaskMission_Start(bob);
        testQuadTaskMission_StartBySig("david");
        testQuadTaskMission_SponsoredStart(username);

        vm.warp(block.timestamp + 200);
        testQuadTaskMission_StartBySig("eric");
        testQuadTaskMission_SponsoredStart(username2);

        // Validate.
        assertEq(quest.getNumOfStartsByMissionByPublic(address(mission), 2), 2);
        assertEq(quest.getNumOfMissionsStarted(), 7);
    }

    /// -----------------------------------------------------------------------
    /// Review Test
    /// ----------------------------------------------------------------------

    function testSetReviewer(address reviewer, bool status) public payable {
        // Authorize quest contract.
        vm.prank(dao);
        quest.setReviewer(reviewer, status);

        // Validate.
        assertEq(quest.isReviewer(reviewer), status);
    }

    function testReview(uint256 response, uint256 reviewResponse) public payable {
        setupQuadTaskMission(dao);

        testSetReviewStatus(true);
        testSetReviewer(dao, true);

        start(bob, address(mission), 1);
        vm.warp(block.timestamp + 10);
        respond(bob, address(mission), 1, 1, response, testString);

        // Review.
        uint256 count = review(dao, bob, address(mission), 1, 1, reviewResponse, testString);
        assertEq(count, 1);
    }

    function testReview_InvalidReviewer(uint256 response, uint256 reviewResponse) public payable {
        setupQuadTaskMission(dao);

        start(bob, address(mission), 1);
        vm.warp(block.timestamp + 10);
        respond(bob, address(mission), 1, 1, response, testString);

        // Review.
        vm.expectRevert(Quest.InvalidReviewer.selector);
        quest.review(bob, address(mission), 1, 1, reviewResponse, testString);
    }

    function testReview_InvalidReview(uint256 response, uint256 reviewResponse) public payable {
        setupQuadTaskMission(dao);
        testSetReviewer(dao, true);

        start(bob, address(mission), 1);
        vm.warp(block.timestamp + 10);
        respond(bob, address(mission), 1, 1, response, testString);

        // Review.
        vm.expectRevert(Quest.InvalidReview.selector);
        vm.prank(dao);
        quest.review(bob, address(mission), 1, 1, reviewResponse, testString);
    }

    /// -----------------------------------------------------------------------
    /// Internal Functions
    /// -----------------------------------------------------------------------

    function initialize(address _dao) internal {
        quest.initialize(_dao);
        mission.initialize(_dao);
    }

    function authorizeQuest(address _dao, address _quest) internal {
        vm.prank(_dao);
        mission.authorizeQuest(_quest, true);
    }

    function setupSingleTaskMission(address _dao) internal {
        delete creators;
        delete deadlines;
        delete titles;
        delete detail;
        delete taskIds;

        creators.push(alice);
        deadlines.push(10000);
        titles.push("TITLE 1");
        detail.push("TEST 1");

        vm.prank(_dao);
        mission.setTasks(creators, deadlines, titles, detail);

        taskIds.push(1);

        vm.prank(_dao);
        mission.setMission(alice, "Single Task Mission", "One Task Only!", taskIds);
    }

    function setupDoubleTaskMission(address _dao) internal {
        delete creators;
        delete deadlines;
        delete titles;
        delete detail;
        delete taskIds;

        creators.push(alice);
        deadlines.push(2);
        titles.push("TITLE 1");
        detail.push("TEST 1");

        creators.push(bob);
        deadlines.push(10);
        titles.push("TITLE 2");
        detail.push("TEST 2");

        vm.prank(_dao);
        mission.setTasks(creators, deadlines, titles, detail);

        taskIds.push(1);
        taskIds.push(2);

        vm.prank(_dao);
        mission.setMission(alice, "Double Task Mission", "Two Tasks!", taskIds);
    }

    function setupTripleTaskMission(address _dao) internal {
        delete creators;
        delete deadlines;
        delete titles;
        delete detail;
        delete taskIds;

        creators.push(alice);
        deadlines.push(2);
        titles.push("TITLE 1");
        detail.push("TEST 1");

        creators.push(bob);
        deadlines.push(10);
        titles.push("TITLE 2");
        detail.push("TEST 2");

        creators.push(charlie);
        deadlines.push(1000);
        titles.push("TITLE 3");
        detail.push("TEST 3");

        vm.prank(_dao);
        mission.setTasks(creators, deadlines, titles, detail);

        taskIds.push(1);
        taskIds.push(2);
        taskIds.push(3);

        vm.prank(_dao);
        mission.setMission(alice, "Three Task Mission", "Three Tasks!", taskIds);
    }

    function setupQuadTaskMission(address _dao) internal {
        delete creators;
        delete deadlines;
        delete titles;
        delete detail;
        delete taskIds;

        creators.push(alice);
        deadlines.push(2);
        titles.push("TITLE 1");
        detail.push("TEST 1");

        creators.push(bob);
        deadlines.push(10);
        titles.push("TITLE 2");
        detail.push("TEST 2");

        creators.push(charlie);
        deadlines.push(1000);
        titles.push("TITLE 3");
        detail.push("TEST 3");

        creators.push(david);
        deadlines.push(10000);
        titles.push("TITLE 4");
        detail.push("TEST 4");

        vm.prank(_dao);
        mission.setTasks(creators, deadlines, titles, detail);

        taskIds.push(1);
        taskIds.push(2);
        taskIds.push(3);
        taskIds.push(4);

        vm.prank(_dao);
        mission.setMission(alice, "Four Task Mission", "Four Tasks!", taskIds);
    }

    function setCooldown(address _user, uint40 cd) public payable {
        // Authorize quest contract.
        vm.prank(_user);
        quest.setCooldown(cd);

        // Validate.
        assertEq(quest.getCooldown(), cd);
    }

    function start(address _user, address _mission, uint256 _missionId) public payable {
        // Start.
        vm.prank(_user);
        quest.start(_mission, _missionId);

        // Validate.
        (address __user, address __mission, uint256 __missionId) = quest.getQuest(quest.getQuestId());
        assertEq(__user, _user);
        assertEq(__mission, _mission);
        assertEq(__missionId, _missionId);
    }

    function respond(
        address _user,
        address _mission,
        uint256 _missionId,
        uint256 _taskId,
        uint256 response,
        string memory feedback
    ) internal {
        // Respond.
        vm.prank(_user);
        quest.respond(_mission, _missionId, _taskId, response, feedback);

        // Validate.
        assertEq(
            quest.getTaskResponse(quest.getQuestIdByUserAndMission(_user, address(_mission), _missionId), _taskId),
            response
        );
        assertEq(
            quest.getTaskFeedback(quest.getQuestIdByUserAndMission(_user, address(_mission), _missionId), _taskId),
            feedback
        );
    }

    function review(
        address reviewer,
        address _user,
        address _mission,
        uint256 _missionId,
        uint256 _taskId,
        uint256 reviewResponse,
        string memory reviewFeedback
    ) internal returns (uint256) {
        // Review.
        vm.prank(reviewer);
        quest.review(_user, address(_mission), _missionId, _taskId, reviewResponse, reviewFeedback);

        // Validate.
        uint256 count = quest.getNumOfReviewByReviewer(reviewer);
        assertEq(quest.getReviewResponse(reviewer, count), reviewResponse);
        assertEq(quest.getReviewFeedback(reviewer, count), reviewFeedback);
        return count;
    }

    // function testGetPublicUserAddress(uint256 salt, uint256 salt2) public payable {
    //     vm.assume(salt != salt2);
    //     address address1 = getPublicUserAddress(username, salt);
    //     address address2 = getPublicUserAddress(username2, salt2);
    //     address altAddress1 = getPublicUserAddress(username, salt);
    //     address altAddress2 = getPublicUserAddress(username, salt2);
    //     address bltAddress1 = getPublicUserAddress(username, salt);
    //     address bltAddress2 = getPublicUserAddress(username2, salt);

    //     assert(address1 != address2);
    //     assert(altAddress1 != altAddress2);
    //     assert(bltAddress1 != bltAddress2);
    // }

    function getPublicUserAddress(string memory _username) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encode(_username)))));
    }
}
