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

    /// -----------------------------------------------------------------------
    /// Setup Tests
    /// -----------------------------------------------------------------------

    /// @notice Set up the testing suite.
    function setUp() public payable {
        // Deploy contract
        mission = new Mission();
        quest = new Quest();

        initialize(dao);
        setupTasks(dao);
        setupMission(dao, alice, testString, testString);
    }

    /// -----------------------------------------------------------------------
    /// DAO Test
    /// ----------------------------------------------------------------------

    function testSetCooldown(uint40 cd) public payable {
        // Authorize quest contract.
        vm.prank(dao);
        quest.setCooldown(cd);

        // Validate.
        assertEq(quest.getCooldown(), cd);
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

    function testStart() public payable {
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

    function testStart_QuestInProgress() public payable {
        testStart();

        // Start.
        vm.expectRevert(Quest.QuestInProgress.selector);
        vm.prank(bob);
        quest.start(address(mission), 1);
    }

    function testStartBySig() public payable {}

    function testRespond(uint256 response) public payable {
        testStart();
        vm.warp(block.timestamp + 10);

        // Respond.
        uint256 completedCount = quest.getCompletedTaskCount(bob, address(mission), 1);

        uint256 count = respond(bob, address(mission), 1, 1, response, testString);
        assertEq(count, 1);
        assertEq(quest.getCompletedTaskCount(bob, address(mission), 1), completedCount + 1);
    }

    // TODO: Review
    function testRespond_QuestInactive(uint256 response) public payable {
        testRespond(response);

        //
        vm.expectRevert(Quest.QuestInactive.selector);
        vm.prank(dao);
        quest.respond(address(mission), 1, 1, response, testString);
    }

    // TODO: Review
    function testRespond_InvalidMission(uint256 response) public payable {
        testRespond(response);

        //
        vm.expectRevert(Quest.QuestInactive.selector);
        vm.prank(dao);
        quest.respond(address(mission), 1, 1, response, testString);
    }

    // TODO: Review
    function testRespond_Cooldown(uint256 response) public payable {
        testRespond(response);

        //
        vm.expectRevert(Quest.QuestInactive.selector);
        vm.prank(dao);
        quest.respond(address(mission), 1, 1, response, testString);
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

    function testSetReviewStatus_NotOperator(address reviewer, bool status) public payable {
        // Authorize quest contract.
        vm.expectRevert(Storage.NotOperator.selector);
        quest.setReviewer(reviewer, status);
    }

    function testReview(uint256 response, uint256 reviewResponse) public payable {
        testSetReviewStatus(true);
        testSetReviewer(dao, true);

        start(bob, address(mission), 1);
        vm.warp(block.timestamp + 10);
        respond(bob, address(mission), 1, 1, response, testString);

        // Review.
        uint256 count = review(dao, address(mission), 1, 1, reviewResponse, testString);
        assertEq(count, 1);
    }

    function testReviewBySig() public payable {}

    /// -----------------------------------------------------------------------
    /// Internal Functions
    /// -----------------------------------------------------------------------

    function initialize(address _dao) internal {
        quest.initialize(_dao);
        mission.initialize(_dao);
    }

    function setupTasks(address _dao) internal {
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
    }

    function setupMission(address _dao, address creator, string memory _title, string memory _description) internal {
        taskIds.push(1);
        taskIds.push(2);
        taskIds.push(3);
        taskIds.push(4);

        vm.prank(_dao);
        mission.setMission(creator, _title, _description, taskIds);
    }

    function start(address user, address mission, uint256 missionId) public payable {
        // Start.
        vm.prank(user);
        quest.start(mission, missionId);

        // Validate.
        (address _user, address _mission, uint256 _missionId) = quest.getQuest(quest.getQuestCount());
        assertEq(_user, user);
        assertEq(_mission, mission);
        assertEq(_missionId, missionId);
        assertEq(quest.isQuestActive(user, mission, missionId), true);
    }

    function respond(
        address user,
        address mission,
        uint256 missionId,
        uint256 taskId,
        uint256 response,
        string memory feedback
    ) internal returns (uint256) {
        // Respond.
        vm.prank(user);
        quest.respond(mission, missionId, taskId, response, feedback);

        // Validate.
        uint256 count = quest.getNumOfResponseByUser(user);
        assertEq(quest.getUserResponse(user, count), response);
        assertEq(quest.getUserFeedback(user, count), feedback);

        (address _mission, uint256 _missionId, uint256 _taskId) = quest.getUserTask(user, count);
        assertEq(_mission, mission);
        assertEq(_missionId, missionId);
        assertEq(_taskId, taskId);

        return count;
    }

    function review(
        address reviewer,
        address mission,
        uint256 missionId,
        uint256 taskId,
        uint256 reviewResponse,
        string memory reviewFeedback
    ) internal returns (uint256) {
        // Review.
        vm.prank(reviewer);
        quest.review(bob, address(mission), 1, 1, reviewResponse, reviewFeedback);

        // Validate.
        uint256 count = quest.getNumOfReviewByReviewer(reviewer);
        assertEq(quest.getReviewResponse(reviewer, count), reviewResponse);
        assertEq(quest.getReviewFeedback(reviewer, count), reviewFeedback);

        return count;
    }
}
