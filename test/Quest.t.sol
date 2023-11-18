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
    uint256[] newTaskIds;

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

    function testSetProfilePicture(string calldata image) public payable {
        vm.prank(alice);
        quest.setProfilePicture(image);
        assertEq(quest.getProfilePicture(alice), image);
    }

    function testStart() public payable {
        setupTasks();
        vm.prank(dao);
        mission.setTasks(creators, deadlines, detail);

        taskIds.push(1);
        taskIds.push(2);
        taskIds.push(3);
        taskIds.push(4);

        vm.prank(dao);
        mission.setMission(alice, "Welcome to your first mission!", "It's so fun~", taskIds);

        // Start.
        vm.prank(bob);
        quest.start(address(mission), 1);

        // Validate.
        assertEq(quest.getNumOfMissionsStartedByUser(bob, address(mission), 1), 1);
        assertEq(quest.getNumOfMissionsStarted(), 1);
    }

    function testStartBySig() public payable {}

    function testRespond(uint256 response, string calldata feedback) public payable {
        testStart();

        // Respond.
        vm.prank(bob);
        quest.respond(address(mission), 1, 1, response, feedback);

        // Validate.
        (uint256 count,) = quest.getResponseCountByUser(bob, address(mission), 1, 1);
        assertEq(count, 1);
        assertEq(quest.getUserResponse(bob, 0, address(mission), 1, 1), response);
        assertEq(quest.getUserFeedback(bob, 0, address(mission), 1, 1), feedback);
    }

    /// -----------------------------------------------------------------------
    /// Review Test
    /// ----------------------------------------------------------------------

    function testSetReviewer(address reviewer, bool status) public payable {
        // Initialize.
        initialize(dao);

        // Authorize quest contract.
        vm.prank(dao);
        quest.setReviewer(reviewer, status);

        // Validate.
        assertEq(quest.isReviewer(reviewer), status);
    }

    function testSetReviewStatus_NotOperator(address reviewer, bool status) public payable {
        // Initialize.
        initialize(dao);

        // Authorize quest contract.
        vm.expectRevert(Storage.NotOperator.selector);
        quest.setReviewer(reviewer, status);
    }

    function testReview(
        uint256 response,
        string calldata feedback,
        uint256 reviewResponse,
        string calldata reviewFeedback
    ) public payable {
        testSetReviewStatus(true);

        testSetReviewer(dao, true);

        testStart();

        // TODO: Reorg bc testRespond includes testStart
        testRespond(response, feedback);

        // Review.
        vm.prank(dao);
        quest.respond(address(mission), 1, 1, reviewResponse, reviewFeedback);
    }

    function testReviewBySig() public payable {}

    /// -----------------------------------------------------------------------
    /// Internal Functions
    /// -----------------------------------------------------------------------

    function initialize(address _dao) internal {
        quest.initialize(_dao);
        mission.initialize(_dao);
    }

    function setupTasks() internal {
        creators.push(alice);
        creators.push(bob);
        creators.push(charlie);
        creators.push(david);
        creators.push(eric);
        creators.push(fred);
        deadlines.push(2);
        deadlines.push(10);
        deadlines.push(100);
        deadlines.push(1000);
        deadlines.push(10000);
        deadlines.push(100000);
        detail.push("TEST 1");
        detail.push("TEST 2");
        detail.push("TEST 3");
        detail.push("TEST 4");
        detail.push("TEST 5");
        detail.push("TEST 6");
    }
}
