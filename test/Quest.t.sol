// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "kali-markets/Storage.sol";
import {Mission} from "src/Mission.sol";
import {IMission} from "src/interface/IMission.sol";
import {Quest} from "src/Quest.sol";
import {IQuest} from "src/interface/IQuest.sol";

contract QuestTest is Test {
    Quest quest;
    Mission mission;

    address[] creators;
    uint256[] deadlines;
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
        mission = new Mission();
        quest = new Quest();

        // Initialize user.
        (alice, alicePk) = makeAddrAndKey("alice");
        (bob, bobPk) = makeAddrAndKey("bob");
        (charlie, charliePk) = makeAddrAndKey("charlie");
        (david, davidPk) = makeAddrAndKey("david");
        (eric, ericPk) = makeAddrAndKey("eric");

        (bot, botPK) = makeAddrAndKey(gasbotString);

        initialize(dao);
        authorizeQuest(dao, address(quest));

        setupSingleTaskMission(dao);
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
    /// User Test
    /// ----------------------------------------------------------------------

    // TODO: Test scenarios with multiple users and reviewers starting, responding, and reviewing tasks

    function testSetProfilePicture(string memory image) public payable {
        vm.prank(alice);
        quest.setProfilePicture(image);
        assertEq(quest.getProfilePicture(alice), image);
    }

    /// -----------------------------------------------------------------------
    /// Single-Task Mission Tests
    /// ----------------------------------------------------------------------

    function testSingleTaskMission_Start(address _user) public payable {
        // Start.
        start(_user, address(mission), 1);

        // Validate.
        assertEq(quest.getQuestCountByUser(_user), 1);
        assertEq(quest.getNumOfMissionsStartedByUser(_user, address(mission), 1), 1);
        assertEq(quest.getNumOfMissionsStarted(), 1);
        assertEq(mission.getMissionStarts(1), 1);

        (uint256 missionIdCount, uint256 missionsCount) = quest.getNumOfMissionQuested(address(mission), 1);
        assertEq(missionIdCount, 1);
        assertEq(missionsCount, 1);
    }

    function testSingleTaskMission_Start_UnauthorizedQuest(address _user) public payable {
        vm.prank(dao);
        mission.authorizeQuest(address(quest), false);

        // Start.
        start(_user, address(mission), 1);

        // Validate.
        assertEq(quest.getQuestCountByUser(_user), 1);
        assertEq(quest.getNumOfMissionsStartedByUser(_user, address(mission), 1), 1);
        assertEq(quest.getNumOfMissionsStarted(), 1);
        assertEq(mission.getMissionStarts(1), 0);

        (uint256 missionIdCount, uint256 missionsCount) = quest.getNumOfMissionQuested(address(mission), 1);
        assertEq(missionIdCount, 1);
        assertEq(missionsCount, 1);
    }

    function testSingleTaskMission_Respond(address _user, uint256 response) public payable {
        testSingleTaskMission_Start(_user);
        vm.warp(block.timestamp + 10);

        // Respond.
        uint256 completedCount = quest.getCompletedTaskCount(_user, address(mission), 1);
        uint256 numOfTaskCompleted = quest.getNumOfTaskCompleted();
        uint256 numOfTaskCompletedByUser = quest.getNumOfTasksCompletedByUser(_user, address(mission), 1, 1);
        uint256 numOfMissionCompleted = quest.getNumOfMissionsCompleted();
        uint256 numOfMissionCompletedByUser = quest.getNumOfMissionsCompletedByUser(_user, address(mission), 1);

        respond(_user, address(mission), 1, 1, response, testString);
        assertEq(quest.getCompletedTaskCount(_user, address(mission), 1), completedCount + 1);
        assertEq(quest.getNumOfTaskCompleted(), numOfTaskCompleted + 1);
        assertEq(quest.getNumOfTasksCompletedByUser(_user, address(mission), 1, 1), numOfTaskCompletedByUser + 1);
        assertEq(quest.getNumOfMissionsCompleted(), numOfMissionCompleted + 1);
        assertEq(quest.getNumOfMissionsCompletedByUser(_user, address(mission), 1), numOfMissionCompletedByUser + 1);
        assertEq(quest.getUserResponse(_user, 0), response);
        assertEq(quest.getUserFeedback(_user, 0), testString);
        assertEq(mission.getMissionCompletions(1), 1);
        assertEq(mission.getTotalTaskCompletions(1), 1);
        assertEq(mission.getTotalTaskCompletionsByMission(1, 1), 1);
        emit log_uint(quest.getQuestProgress(_user, address(mission), 1));
    }

    function testSingleTaskMission_Respond_UnauthorizedQuest(address _user, uint256 response) public payable {
        testSingleTaskMission_Start_UnauthorizedQuest(_user);
        vm.warp(block.timestamp + 10);

        // Respond.
        uint256 completedCount = quest.getCompletedTaskCount(bob, address(mission), 1);
        uint256 numOfTaskCompleted = quest.getNumOfTaskCompleted();
        uint256 numOfTaskCompletedByUser = quest.getNumOfTasksCompletedByUser(_user, address(mission), 1, 1);
        uint256 numOfMissionCompleted = quest.getNumOfMissionsCompleted();
        uint256 numOfMissionCompletedByUser = quest.getNumOfMissionsCompletedByUser(_user, address(mission), 1);

        respond(_user, address(mission), 1, 1, response, testString);
        assertEq(quest.getCompletedTaskCount(_user, address(mission), 1), completedCount + 1);
        assertEq(quest.getNumOfTaskCompleted(), numOfTaskCompleted + 1);
        assertEq(quest.getNumOfTasksCompletedByUser(_user, address(mission), 1, 1), numOfTaskCompletedByUser + 1);
        assertEq(quest.getNumOfMissionsCompleted(), numOfMissionCompleted + 1);
        assertEq(quest.getNumOfMissionsCompletedByUser(_user, address(mission), 1), numOfMissionCompletedByUser + 1);
        assertEq(quest.getUserResponse(_user, 0), response);
        assertEq(quest.getUserFeedback(_user, 0), testString);
        assertEq(mission.getMissionCompletions(1), 0);
        assertEq(mission.getTotalTaskCompletions(1), 0);
        assertEq(mission.getTotalTaskCompletionsByMission(1, 1), 0);
        emit log_uint(quest.getQuestProgress(_user, address(mission), 1));
    }

    /// -----------------------------------------------------------------------
    /// Quad-Task Mission Tests
    /// ----------------------------------------------------------------------

    function testQuadTaskMission_Start(address _user) public payable {
        // Initialize tasks and mission.
        setupQuadTaskMission(dao);

        // Retrieve for later validation.
        uint256 numOfMissionsStartedByUser = quest.getNumOfMissionsStartedByUser(_user, address(mission), 1);
        uint256 numOfMissionsStarted = quest.getNumOfMissionsStarted();
        uint256 missionStarts = mission.getMissionStarts(1);
        (uint256 missionIdCount, uint256 missionsCount) = quest.getNumOfMissionQuested(address(mission), 1);

        // Start.
        start(_user, address(mission), 1);

        // Validate.fo
        assertEq(quest.getQuestCountByUser(_user), 1);
        assertEq(quest.getNumOfMissionsStartedByUser(_user, address(mission), 1), numOfMissionsStartedByUser + 1);
        assertEq(quest.getNumOfMissionsStarted(), numOfMissionsStarted + 1);
        assertEq(mission.getMissionStarts(1), missionStarts + 1);

        (uint256 _missionIdCount, uint256 _missionsCount) = quest.getNumOfMissionQuested(address(mission), 1);
        assertEq(_missionIdCount, missionIdCount + 1);
        assertEq(_missionsCount, missionsCount + 1);
    }

    function testQuadTaskMission_Start_InvalidMission(address _user) public payable {
        vm.warp(block.timestamp + 100000);

        // Anyone can take user's signature and start quest on behalf of user.
        vm.expectRevert(Quest.InvalidMission.selector);
        vm.prank(_user);
        quest.start(address(mission), 1);
    }

    function testQuadTaskMission_Start_NotInitialized(address _user) public payable {
        // Anyone can take user's signature and start quest on behalf of user.
        vm.expectRevert(Quest.NotInitialized.selector);
        vm.prank(_user);
        quest.start(address(mission), 0);
    }

    function testQuadTaskMission_Start_QuestInProgress(address _user) public payable {
        testQuadTaskMission_Start(_user);

        // Start.
        vm.expectRevert(Quest.QuestInProgress.selector);
        vm.prank(_user);
        quest.start(address(mission), 1);
    }

    function testQuadTaskMission_StartBySig(string memory _username) public payable {
        (address _user, uint256 _userPk) = makeAddrAndKey(_username);

        // Initialize tasks and mission.
        setupQuadTaskMission(dao);

        // Retrieve for later validation.
        uint256 questCountByUser = quest.getQuestCountByUser(_user);
        uint256 numOfMissionsStartedByUser = quest.getNumOfMissionsStartedByUser(_user, address(mission), 1);
        uint256 numOfMissionsStarted = quest.getNumOfMissionsStarted();
        uint256 missionStarts = mission.getMissionStarts(1);
        (uint256 missionIdCount, uint256 missionsCount) = quest.getNumOfMissionQuested(address(mission), 1);

        // Prepare message.
        bytes32 message = keccak256(
            abi.encodePacked(
                "\x19\x01", quest.DOMAIN_SEPARATOR(), keccak256(abi.encode(START_TYPEHASH, _user, address(mission), 1))
            )
        );

        // George signs message.
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_userPk, message);

        vm.prank(dao);
        quest.setGasbot(bot);

        vm.deal(bot, 0.5 ether);

        vm.prank(bot);
        quest.startBySig(_user, address(mission), 1, v, r, s);

        // Validate.
        assertEq(quest.getQuestCountByUser(_user), questCountByUser + 1);
        assertEq(quest.getNumOfMissionsStartedByUser(_user, address(mission), 1), numOfMissionsStartedByUser + 1);
        assertEq(quest.getNumOfMissionsStarted(), numOfMissionsStarted + 1);
        assertEq(mission.getMissionStarts(1), missionStarts + 1);

        (uint256 _missionIdCount, uint256 _missionsCount) = quest.getNumOfMissionQuested(address(mission), 1);
        assertEq(_missionIdCount, missionIdCount + 1);
        assertEq(_missionsCount, missionsCount + 1);
    }

    function testQuadTaskMission_StartBySig_InvalidUser() public payable {
        (address _user, uint256 _userPk) = makeAddrAndKey("invalidUser");

        // Prepare message.
        bytes32 message = keccak256(
            abi.encodePacked(
                "\x19\x01", quest.DOMAIN_SEPARATOR(), keccak256(abi.encode(START_TYPEHASH, alice, address(mission), 1))
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
        quest.startBySig(_user, address(mission), 1, v, r, s);
    }

    function testQuadTaskMission_SponsoredStart(string memory _username) public payable {
        uint256 prevCount = quest.getPublicCount();

        // Set gas bot.
        vm.prank(dao);
        quest.setGasbot(bot);

        // Deal bot ether.
        vm.deal(bot, 0.5 ether);

        vm.prank(bot);
        quest.sponsoredStart(_username, 123, address(mission), 1);

        assertEq(quest.getPublicCount(), prevCount + 1);
        assertEq(quest.isPublicUser(_username, 123), true);
        assertEq(quest.getPublicUser(prevCount + 1), getPublicUserAddress(_username, 123));
    }

    function testQuadTaskMission_SponsoredStart_InvalidBot(string memory _username) public payable {
        vm.expectRevert(Quest.InvalidBot.selector);
        vm.prank(dao);
        quest.sponsoredStart(_username, 123, address(mission), 1);
    }

    function testQuadTaskMission_Respond(address _user, uint256 response) public payable {
        testQuadTaskMission_Start(_user);
        vm.warp(block.timestamp + 10);

        // Respond.
        uint256 completedCount = quest.getCompletedTaskCount(_user, address(mission), 1);
        uint256 numOfTaskCompleted = quest.getNumOfTaskCompleted();
        uint256 numOfTaskCompletedByUser = quest.getNumOfTasksCompletedByUser(_user, address(mission), 1, 1);

        respond(_user, address(mission), 1, 1, response, testString);
        assertEq(quest.getCompletedTaskCount(_user, address(mission), 1), completedCount + 1);
        assertEq(quest.getNumOfTaskCompleted(), numOfTaskCompleted + 1);
        assertEq(quest.getNumOfTasksCompletedByUser(_user, address(mission), 1, 1), numOfTaskCompletedByUser + 1);
        emit log_uint(quest.getQuestProgress(_user, address(mission), 1));
    }

    function testQuadTaskMission_Respond_QuestInactive(address _user, uint256 response) public payable {
        testQuadTaskMission_Start(_user);

        // DAO has not started any quest, triggering QusetInactive().
        vm.expectRevert(Quest.QuestInactive.selector);
        vm.prank(dao);
        quest.respond(address(mission), 1, 1, response, testString);
    }

    function testQuadTaskMission_Respond_InvalidMission(address _user, uint256 response) public payable {
        testQuadTaskMission_Start(_user);

        // InvalidMission().
        vm.expectRevert(Quest.InvalidMission.selector);
        vm.prank(_user);
        quest.respond(address(mission), 1, 8, response, testString);
    }

    function testQuadTaskMission_Respond_Cooldown(address _user, uint256 response) public payable {
        testQuadTaskMission_Start(_user);

        setCooldown(dao, 100);

        // Respond is not allowed when user is not cooled down.
        vm.warp(block.timestamp + 10);

        vm.expectRevert(Quest.Cooldown.selector);
        vm.prank(_user);
        quest.respond(address(mission), 1, 1, response, testString);

        vm.warp(block.timestamp + 100);

        // Respond is allowed after user has cooled down.
        uint256 completedCount = quest.getCompletedTaskCount(_user, address(mission), 1);

        respond(_user, address(mission), 1, 1, response, testString);
        assertEq(quest.getCompletedTaskCount(_user, address(mission), 1), completedCount + 1);
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
                keccak256(abi.encode(RESPOND_TYPEHASH, _user, address(mission), 1, 1, response, testString))
            )
        );

        // User signs message.
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_userPk, message);

        // Retrieve for validation later.
        uint256 completedCount = quest.getCompletedTaskCount(_user, address(mission), 1);

        // Respond by sig.
        vm.prank(bot);
        quest.respondBySig(_user, address(mission), 1, 1, response, testString, v, r, s);

        // Validate.
        uint256 count = quest.getNumOfResponseByUser(_user);
        assertEq(quest.getUserResponse(_user, count), response);
        assertEq(quest.getUserFeedback(_user, count), testString);

        (address __mission, uint256 __missionId, uint256 __taskId) = quest.getUserTask(_user, count);
        assertEq(__mission, address(mission));
        assertEq(__missionId, 1);
        assertEq(__taskId, 1);
        assertEq(quest.getCompletedTaskCount(_user, address(mission), 1), completedCount + 1);
    }

    function testQuadTaskMission_SponsoredRespond(string memory _username, uint256 response) public payable {
        testQuadTaskMission_SponsoredStart(_username);

        // Retrieve for validation later.
        address _user = getPublicUserAddress(_username, 123);
        uint256 completedCount = quest.getCompletedTaskCount(_user, address(mission), 1);

        // Sponsored respond.
        vm.prank(bot);
        quest.sponsoredRespond(_username, 123, address(mission), 1, 1, response, testString);

        // Validate.
        uint256 count = quest.getNumOfResponseByUser(_user);
        assertEq(quest.getUserResponse(_user, count), response);
        assertEq(quest.getUserFeedback(_user, count), testString);

        (address __mission, uint256 __missionId, uint256 __taskId) = quest.getUserTask(_user, count);
        assertEq(__mission, address(mission));
        assertEq(__missionId, 1);
        assertEq(__taskId, 1);
        assertEq(quest.getCompletedTaskCount(_user, address(mission), 1), completedCount + 1);
    }

    function testQuadTaskMission_SponsoredStart_InvalidBot(string memory _username, uint256 response) public payable {
        vm.expectRevert(Quest.InvalidBot.selector);
        vm.prank(dao);
        quest.sponsoredRespond(_username, 123, address(mission), 1, 1, response, testString);
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
                keccak256(abi.encode(RESPOND_TYPEHASH, alice, address(mission), 1, 1, response, testString))
            )
        );

        // George signs message.
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_userPk, message);

        // A mismatch between user and signature result in InvalidUser().
        vm.expectRevert(Quest.InvalidUser.selector);
        vm.prank(bot);
        quest.respondBySig(_user, address(mission), 1, 1, response, testString, v, r, s);
    }

    /// -----------------------------------------------------------------------
    /// Quad-Task Mission Tests - Story Mode
    /// ----------------------------------------------------------------------

    function testQuadTaskMission_MultipleStarts() public payable {
        testQuadTaskMission_Start(alice);
        testQuadTaskMission_StartBySig("charlie");

        vm.warp(block.timestamp + 100);
        testQuadTaskMission_Start(bob);
        testQuadTaskMission_StartBySig("david");
        testQuadTaskMission_SponsoredStart(username);

        vm.warp(block.timestamp + 200);
        testQuadTaskMission_StartBySig("eric");
        testQuadTaskMission_SponsoredStart(username2);
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
        delete detail;
        delete taskIds;

        creators.push(alice);
        deadlines.push(10000);
        detail.push("TEST 1");

        vm.prank(_dao);
        mission.setTasks(creators, deadlines, detail);

        taskIds.push(1);

        vm.prank(_dao);
        mission.setMission(alice, "Single Task Mission", "One Task Only!", taskIds);
    }

    function setupDoubleTaskMission(address _dao) internal {
        delete creators;
        delete deadlines;
        delete detail;
        delete taskIds;

        creators.push(alice);
        deadlines.push(2);
        detail.push("TEST 1");

        creators.push(bob);
        deadlines.push(10);
        detail.push("TEST 2");

        vm.prank(_dao);
        mission.setTasks(creators, deadlines, detail);

        taskIds.push(1);
        taskIds.push(2);

        vm.prank(_dao);
        mission.setMission(alice, "Double Task Mission", "Two Tasks!", taskIds);
    }

    function setupTripleTaskMission(address _dao) internal {
        delete creators;
        delete deadlines;
        delete detail;
        delete taskIds;

        creators.push(alice);
        deadlines.push(2);
        detail.push("TEST 1");

        creators.push(bob);
        deadlines.push(10);
        detail.push("TEST 2");

        creators.push(charlie);
        deadlines.push(1000);
        detail.push("TEST 3");

        vm.prank(_dao);
        mission.setTasks(creators, deadlines, detail);

        taskIds.push(1);
        taskIds.push(2);
        taskIds.push(3);

        vm.prank(_dao);
        mission.setMission(alice, "Three Task Mission", "Three Tasks!", taskIds);
    }

    function setupQuadTaskMission(address _dao) internal {
        delete creators;
        delete deadlines;
        delete detail;
        delete taskIds;

        creators.push(alice);
        deadlines.push(2);
        detail.push("TEST 1");

        creators.push(bob);
        deadlines.push(10);
        detail.push("TEST 2");

        creators.push(charlie);
        deadlines.push(1000);
        detail.push("TEST 3");

        creators.push(david);
        deadlines.push(10000);
        detail.push("TEST 4");

        vm.prank(_dao);
        mission.setTasks(creators, deadlines, detail);

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
        (address __user, address __mission, uint256 __missionId) = quest.getQuest(quest.getQuestCount());
        assertEq(__user, _user);
        assertEq(__mission, _mission);
        assertEq(__missionId, _missionId);
        assertEq(quest.isQuestActive(_user, _mission, _missionId), true);
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
        uint256 count = quest.getNumOfResponseByUser(_user);
        assertEq(quest.getUserResponse(_user, count), response);
        assertEq(quest.getUserFeedback(_user, count), feedback);

        (address __mission, uint256 __missionId, uint256 __taskId) = quest.getUserTask(_user, count);
        assertEq(__mission, _mission);
        assertEq(__missionId, _missionId);
        assertEq(__taskId, _taskId);
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
        assertEq(quest.getReviewResponse(reviewer, 0), reviewResponse);
        assertEq(quest.getReviewFeedback(reviewer, 0), reviewFeedback);
        return count;
    }

    function getPublicUserAddress(string memory _username, uint256 salt) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encode(_username, salt)))));
    }
}
