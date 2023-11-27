// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import "kali-markets/Storage.sol";
import {Mission} from "src/Mission.sol";
import {IMission} from "src/interface/IMission.sol";
import {Quest} from "src/Quest.sol";
import {IQuest} from "src/interface/IQuest.sol";

/// @dev Mocks.
import {MockERC721} from "../lib/solbase/test/utils/mocks/MockERC721.sol";

/// -----------------------------------------------------------------------
/// Test Logic
/// -----------------------------------------------------------------------

contract QuestTest is Test {
    Quest quest;
    Mission mission;

    address[] creators;
    uint256[] deadlines;
    string[] detail;
    uint256[] taskIds;

    /// @dev Users.
    address[] reviewers;
    address public immutable alice = makeAddr("alice");
    address public immutable bob = makeAddr("bob");
    address public immutable charlie = makeAddr("charlie");
    address public immutable david = makeAddr("david");
    address public immutable eric = makeAddr("eric");
    address public immutable fred = makeAddr("fred");
    address public immutable dao = makeAddr("dao");

    /// @dev Helpers.
    uint256 taskId;
    uint256 missionId;
    string testString = "TEST";
    bytes32 public constant START_TYPEHASH = keccak256("Start(address signer, address missions, uint256 missionId)");
    bytes32 public constant RESPOND_TYPEHASH =
        keccak256("Respond(address signer, bytes32 taskKey, uint256 response, string feedback)");
    bytes32 public constant REVIEW_TYPEHASH =
        keccak256("Review(address signer, address user, bytes32 taskKey, uint256 response, string feedback)");
    /// -----------------------------------------------------------------------
    /// Setup Tests
    /// -----------------------------------------------------------------------

    /// @notice Set up the testing suite.
    function setUp() public payable {
        // Deploy contract
        mission = new Mission();
        quest = new Quest();

        initialize(dao);
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

    function testSingleTaskMission_Start() public payable {
        setupSingleTaskMission(dao);
        // setupDoubleTaskMission(dao);
        // setupTripleTaskMission(dao);
        // setupQuadTaskMission(dao);

        // Start.
        start(bob, address(mission), 1);

        // Validate.
        assertEq(quest.getQuestCountByUser(bob), 1);
        assertEq(quest.getNumOfMissionsStartedByUser(bob, address(mission), 1), 1);
        assertEq(quest.getNumOfMissionsStarted(), 1);

        (uint256 missionIdCount, uint256 missionsCount) = quest.getNumOfMissionQuested(address(mission), 1);
        assertEq(missionIdCount, 1);
        assertEq(missionsCount, 1);
    }

    function testSingleTaskMission_Respond(uint256 response) public payable {
        testSingleTaskMission_Start();
        vm.warp(block.timestamp + 10);

        // Respond.
        uint256 completedCount = quest.getCompletedTaskCount(bob, address(mission), 1);
        uint256 numOfTaskCompleted = quest.getNumOfTaskCompleted();
        uint256 numOfTaskCompletedByUser = quest.getNumOfTasksCompletedByUser(bob, address(mission), 1, 1);
        uint256 numOfMissionCompleted = quest.getNumOfMissionsCompleted();
        uint256 numOfMissionCompletedByUser = quest.getNumOfMissionsCompletedByUser(bob, address(mission), 1);

        uint256 count = respond(bob, address(mission), 1, 1, response, testString);
        assertEq(count, 1);
        assertEq(quest.getCompletedTaskCount(bob, address(mission), 1), completedCount + 1);
        assertEq(quest.getNumOfTaskCompleted(), numOfTaskCompleted + 1);
        assertEq(quest.getNumOfTasksCompletedByUser(bob, address(mission), 1, 1), numOfTaskCompletedByUser + 1);
        assertEq(quest.getNumOfMissionsCompleted(), numOfMissionCompleted + 1);
        assertEq(quest.getNumOfMissionsCompletedByUser(bob, address(mission), 1), numOfMissionCompletedByUser + 1);
        assertEq(quest.getUserResponse(bob, 0), response);
        assertEq(quest.getUserFeedback(bob, 0), testString);
        assertEq(mission.getMissionCompletions(1), 1);
        assertEq(mission.getTaskCompletions(1), 1);
        emit log_uint(quest.getQuestProgress(bob, address(mission), 1));
    }

    function testStart() public payable {
        setupTasksAndMission(dao);

        // Start.
        start(bob, address(mission), 1);

        // Validate.
        assertEq(quest.getQuestCountByUser(bob), 1);
        assertEq(quest.getNumOfMissionsStartedByUser(bob, address(mission), 1), 1);
        assertEq(quest.getNumOfMissionsStarted(), 1);
        assertEq(mission.getMissionStarts(1), 1);

        (uint256 missionIdCount, uint256 missionsCount) = quest.getNumOfMissionQuested(address(mission), 1);
        assertEq(missionIdCount, 1);
        assertEq(missionsCount, 1);
    }

    function testStart_QuestInProgress() public payable {
        testStart();

        // Start.
        vm.expectRevert(Quest.QuestInProgress.selector);
        vm.prank(bob);
        quest.start(address(mission), 1);
    }

    function testStartBySig() public payable {
        // Initialize George.
        (address george, uint256 georgePK) = makeAddrAndKey("george");

        // Prepare message.
        bytes32 message = keccak256(
            abi.encodePacked(
                "\x19\x01", quest.DOMAIN_SEPARATOR(), keccak256(abi.encode(START_TYPEHASH, george, address(mission), 1))
            )
        );

        // George signs message.
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(georgePK, message);

        setupTasksAndMission(dao);

        // Anyone can take George's signature and start quest on behalf of George.
        quest.startBySig(george, address(mission), 1, v, r, s);

        // Validate.
        assertEq(quest.getQuestCountByUser(george), 1);
        assertEq(quest.getNumOfMissionsStartedByUser(george, address(mission), 1), 1);
        assertEq(quest.getNumOfMissionsStarted(), 1);

        (uint256 missionIdCount, uint256 missionsCount) = quest.getNumOfMissionQuested(address(mission), 1);
        assertEq(missionIdCount, 1);
        assertEq(missionsCount, 1);
    }

    function testStartBySig_InvalidUser() public payable {
        // Initialize George.
        (address george, uint256 georgePK) = makeAddrAndKey("george");

        // Prepare message.
        bytes32 message = keccak256(
            abi.encodePacked(
                "\x19\x01", quest.DOMAIN_SEPARATOR(), keccak256(abi.encode(START_TYPEHASH, george, address(mission), 2))
            )
        );

        // George signs message.
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(georgePK, message);

        setupTasksAndMission(dao);

        // Anyone can take George's signature and start quest on behalf of George.
        vm.expectRevert(Quest.InvalidUser.selector);
        quest.startBySig(george, address(mission), 1, v, r, s);
    }

    function testRespond(uint256 response) public payable {
        testStart();
        vm.warp(block.timestamp + 10);

        // Respond.
        uint256 completedCount = quest.getCompletedTaskCount(bob, address(mission), 1);
        uint256 numOfTaskCompleted = quest.getNumOfTaskCompleted();
        uint256 numOfTaskCompletedByUser = quest.getNumOfTasksCompletedByUser(bob, address(mission), 1, 1);

        uint256 count = respond(bob, address(mission), 1, 1, response, testString);
        assertEq(count, 1);
        assertEq(quest.getCompletedTaskCount(bob, address(mission), 1), completedCount + 1);
        assertEq(quest.getNumOfTaskCompleted(), numOfTaskCompleted + 1);
        assertEq(quest.getNumOfTasksCompletedByUser(bob, address(mission), 1, 1), numOfTaskCompletedByUser + 1);
        emit log_uint(quest.getQuestProgress(bob, address(mission), 1));
    }

    function testRespondBySig(uint256 response) public payable {
        // Initialize George.
        (address george, uint256 georgePK) = makeAddrAndKey("george");

        testStartBySig();
        vm.warp(block.timestamp + 10);

        // Prepare message.
        bytes32 message = keccak256(
            abi.encodePacked(
                "\x19\x01",
                quest.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(RESPOND_TYPEHASH, george, quest.getTaskKey(address(mission), 1, 1), response, testString)
                )
            )
        );

        // George signs message.
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(georgePK, message);

        // Respond.
        uint256 completedCount = quest.getCompletedTaskCount(george, address(mission), 1);

        // Anyone can take George's signature and respond to a task on behalf of George.
        quest.respondBySig(george, address(mission), 1, 1, response, testString, v, r, s);

        // Validate.
        uint256 count = quest.getNumOfResponseByUser(george);
        assertEq(quest.getUserResponse(george, count), response);
        assertEq(quest.getUserFeedback(george, count), testString);

        (address __mission, uint256 __missionId, uint256 __taskId) = quest.getUserTask(george, count);
        assertEq(__mission, address(mission));
        assertEq(__missionId, 1);
        assertEq(__taskId, 1);
        assertEq(quest.getCompletedTaskCount(george, address(mission), 1), completedCount + 1);
    }

    function testRespondBySig_InvalidUser(uint256 response) public payable {
        // Initialize George.
        (address george, uint256 georgePK) = makeAddrAndKey("george");

        testStartBySig();
        vm.warp(block.timestamp + 10);

        // Prepare message.
        bytes32 message = keccak256(
            abi.encodePacked(
                "\x19\x01",
                quest.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(RESPOND_TYPEHASH, george, quest.getTaskKey(address(mission), 1, 2), response, testString)
                )
            )
        );

        // George signs message.
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(georgePK, message);

        // Anyone can take George's signature and respond to a task on behalf of George.
        vm.expectRevert(Quest.InvalidUser.selector);
        quest.respondBySig(george, address(mission), 1, 1, response, testString, v, r, s);
    }

    function testRespond_QuestInactive(uint256 response) public payable {
        testRespond(response);

        // DAO has not started any quest, triggering QusetInactiv().
        vm.expectRevert(Quest.QuestInactive.selector);
        vm.prank(dao);
        quest.respond(address(mission), 1, 1, response, testString);
    }

    function testRespond_InvalidMission(uint256 response) public payable {
        testRespond(response);

        // InvalidMission().
        vm.expectRevert(Quest.InvalidMission.selector);
        vm.prank(bob);
        quest.respond(address(mission), 1, 8, response, testString);
    }

    function testRespond_Cooldown(uint256 response) public payable {
        testRespond(response);

        setCooldown(dao, 100);

        // Respond is not allowed when user is not cooled down.
        vm.warp(block.timestamp + 10);

        vm.expectRevert(Quest.Cooldown.selector);
        vm.prank(bob);
        quest.respond(address(mission), 1, 2, response, testString);

        vm.warp(block.timestamp + 1000);

        // Respond is allowed after user has cooled down.
        uint256 completedCount = quest.getCompletedTaskCount(bob, address(mission), 1);

        uint256 count = respond(bob, address(mission), 1, 1, response, testString);
        assertEq(count, 2);
        assertEq(quest.getCompletedTaskCount(bob, address(mission), 1), completedCount + 1);
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
        setupTasksAndMission(dao);

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
        setupTasksAndMission(dao);

        start(bob, address(mission), 1);
        vm.warp(block.timestamp + 10);
        respond(bob, address(mission), 1, 1, response, testString);

        // Review.
        vm.expectRevert(Quest.InvalidReviewer.selector);
        quest.review(bob, address(mission), 1, 1, reviewResponse, testString);
    }

    function testReview_InvalidReview(uint256 response, uint256 reviewResponse) public payable {
        setupTasksAndMission(dao);
        testSetReviewer(dao, true);

        start(bob, address(mission), 1);
        vm.warp(block.timestamp + 10);
        respond(bob, address(mission), 1, 1, response, testString);

        // Review.
        vm.expectRevert(Quest.InvalidReview.selector);
        vm.prank(dao);
        quest.review(bob, address(mission), 1, 1, reviewResponse, testString);
    }

    // function testReviewBySig(uint256 response) public payable {
    //     testRespond(response);
    //     vm.warp(block.timestamp + 10);

    //     // Initialize George, the reviewer.
    //     (address george, uint256 georgePK) = makeAddrAndKey("george");

    //     // Update review status.
    //     testSetReviewStatus(true);
    //     testSetReviewer(george, true);

    //     // Prepare message.
    //     bytes32 message = keccak256(
    //         abi.encodePacked(
    //             "\x19\x01",
    //             quest.DOMAIN_SEPARATOR(),
    //             keccak256(
    //                 abi.encode(
    //                     REVIEW_TYPEHASH, george, bob, quest.getTaskKey(address(mission), 1, 1), response, testString
    //                 )
    //             )
    //         )
    //     );

    //     // George signs message.
    //     (uint8 v, bytes32 r, bytes32 s) = vm.sign(georgePK, message);

    //     // Anyone can take George's signature and review to a task on behalf of George.
    //     quest.reviewBySig(george, bob, address(mission), 1, 1, response, testString, v, r, s);

    //     // Validate.
    //     uint256 count = quest.getNumOfReviewByReviewer(george);
    //     assertEq(quest.getReviewResponse(george, count), response);
    //     assertEq(quest.getReviewFeedback(george, count), testString);
    // }

    /// -----------------------------------------------------------------------
    /// Internal Functions
    /// -----------------------------------------------------------------------

    function initialize(address _dao) internal {
        quest.initialize(_dao);
        mission.initialize(_dao);

        vm.prank(dao);
        mission.authorizeQuest(address(quest), true);
    }

    function setupTasksAndMission(address _dao) internal {
        creators.push(alice);
        creators.push(bob);
        creators.push(charlie);
        creators.push(david);
        creators.push(eric);
        creators.push(fred);
        deadlines.push(2);
        deadlines.push(10);
        deadlines.push(1000);
        deadlines.push(10000);
        deadlines.push(100000);
        deadlines.push(1000000);
        detail.push("TEST 1");
        detail.push("TEST 2");
        detail.push("TEST 3");
        detail.push("TEST 4");
        detail.push("TEST 5");
        detail.push("TEST 6");

        vm.prank(_dao);
        mission.setTasks(creators, deadlines, detail);

        taskIds.push(1);
        taskIds.push(2);
        taskIds.push(3);
        taskIds.push(4);
        taskIds.push(5);
        taskIds.push(6);
        vm.prank(_dao);
        mission.setMission(alice, "Bunch of Tasks", "So many!", taskIds);
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

    function setCooldown(address user, uint40 cd) public payable {
        // Authorize quest contract.
        vm.prank(user);
        quest.setCooldown(cd);

        // Validate.
        assertEq(quest.getCooldown(), cd);
    }

    function start(address user, address _mission, uint256 _missionId) public payable {
        // Start.
        vm.prank(user);
        quest.start(_mission, _missionId);

        // Validate.
        (address _user, address __mission, uint256 __missionId) = quest.getQuest(quest.getQuestCount());
        assertEq(_user, user);
        assertEq(__mission, _mission);
        assertEq(__missionId, _missionId);
        assertEq(quest.isQuestActive(user, _mission, _missionId), true);
    }

    function respond(
        address user,
        address _mission,
        uint256 _missionId,
        uint256 _taskId,
        uint256 response,
        string memory feedback
    ) internal returns (uint256) {
        // Respond.
        vm.prank(user);
        quest.respond(_mission, _missionId, _taskId, response, feedback);

        // Validate.
        uint256 count = quest.getNumOfResponseByUser(user);
        assertEq(quest.getUserResponse(user, count), response);
        assertEq(quest.getUserFeedback(user, count), feedback);

        (address __mission, uint256 __missionId, uint256 __taskId) = quest.getUserTask(user, count);
        assertEq(__mission, _mission);
        assertEq(__missionId, _missionId);
        assertEq(__taskId, _taskId);

        return count;
    }

    function review(
        address reviewer,
        address user,
        address _mission,
        uint256 _missionId,
        uint256 _taskId,
        uint256 reviewResponse,
        string memory reviewFeedback
    ) internal returns (uint256) {
        // Review.
        vm.prank(reviewer);
        quest.review(user, address(_mission), _missionId, _taskId, reviewResponse, reviewFeedback);

        // Validate.
        uint256 count = quest.getNumOfReviewByReviewer(reviewer);
        assertEq(quest.getReviewResponse(reviewer, count), reviewResponse);
        assertEq(quest.getReviewFeedback(reviewer, count), reviewFeedback);
        assertEq(quest.getReviewResponse(reviewer, 0), reviewResponse);
        assertEq(quest.getReviewFeedback(reviewer, 0), reviewFeedback);
        return count;
    }
}
