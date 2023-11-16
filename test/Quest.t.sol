// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import "kali-markets/Storage.sol";
import {Mission} from "src/Mission.sol";
import {IMission} from "src/interface/IMission.sol";
import {Quest} from "src/Quest.sol";
import {IQuest} from "src/interface/IQuest.sol";

import {MissionTest} from "test/Mission.t.sol";

/// @dev Mocks.
import {MockERC721} from "../lib/solbase/test/utils/mocks/MockERC721.sol";

/// -----------------------------------------------------------------------
/// Test Logic
/// -----------------------------------------------------------------------

contract QuestTest is Test {
    Quest quest;
    Mission mission;

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

    /// -----------------------------------------------------------------------
    /// Setup Tests
    /// -----------------------------------------------------------------------

    /// @notice Set up the testing suite.
    function setUp() public payable {
        // Deploy contract
        mission = new Mission();
        quest = new Quest();
    }

    /// -----------------------------------------------------------------------
    /// DAO Test
    /// ----------------------------------------------------------------------

    function testSetCooldown(uint40 cd) public payable {
        // Initialize.
        initialize(dao);

        // Authorize quest contract.
        vm.prank(dao);
        quest.setCooldown(cd);

        // Validate.
        assertEq(quest.getCooldown(), cd);
    }

    function testSetCooldown_NotOperator(uint40 cd) public payable {
        // Initialize.
        initialize(dao);

        // Authorize quest contract.
        vm.expectRevert(Storage.NotOperator.selector);
        quest.setCooldown(cd);
    }

    function testSetReviewStatus(bool reviewStatus) public payable {
        // Initialize.
        initialize(dao);

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

    function testSetProfilePicture(string memory url) public payable {
        vm.prank(alice);
        quest.setProfilePicture(url);
        assertEq(quest.getProfilePicture(alice), url);
    }

    function testStart() public payable {}

    function testStartBySig() public payable {}

    function testRespond() public payable {}

    /// -----------------------------------------------------------------------
    /// Review Test
    /// ----------------------------------------------------------------------

    function testSetReviewer() public payable {}

    function testReview() public payable {}

    function testReviewBySig() public payable {}

    /// -----------------------------------------------------------------------
    /// Internal Functions
    /// -----------------------------------------------------------------------

    function initialize(address _dao) internal {
        quest.initialize(_dao);
    }
}
