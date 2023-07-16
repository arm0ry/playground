// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {Quests} from "src/Quests.sol";
import {Missions, Task, Mission} from "src/Missions.sol";

import {IMissions} from "src/interface/IMissions.sol";
import {IQuests} from "src/interface/IQuests.sol";

import {IERC1155} from "forge-std/interfaces/IERC1155.sol";

/// @dev Mocks.
// import {MockERC20} from "solbase-test/utils/mocks/MockERC20.sol";
// import {MockERC721} from "solbase-test/utils/mocks/MockERC721.sol";
// import {MockERC1155} from "solbase-test/utils/mocks/MockERC1155.sol";
// import {MockERC1271Wallet} from "solbase-test/utils/mocks/MockERC1271Wallet.sol";

/// -----------------------------------------------------------------------
/// Errors
/// -----------------------------------------------------------------------

error Initialized();

/// -----------------------------------------------------------------------
/// Test Logic
/// -----------------------------------------------------------------------

contract MissionsTest is Test {
    Quests quests;
    Missions missions;

    IQuests iQuests;
    IMissions iMissions;

    Task[] tasks;
    uint256[] taskIds;
    Mission mission;

    /// @dev Users.

    address public immutable alice = makeAddr("alice");
    address public immutable bob = makeAddr("bob");
    address public immutable charlie = makeAddr("charlie");
    address public immutable dummy = makeAddr("dummy");
    address payable public immutable arm0ry = payable(makeAddr("arm0ry"));

    /// @dev Helpers.

    string internal constant description = "TEST";

    bytes32 internal constant name1 = 0x5445535400000000000000000000000000000000000000000000000000000000;

    bytes32 internal constant name2 = 0x5445535432000000000000000000000000000000000000000000000000000000;

    /// -----------------------------------------------------------------------
    /// Kali Setup Tests
    /// -----------------------------------------------------------------------

    /// @notice Set up the testing suite.

    function setUp() public payable {
        missions = new Missions(arm0ry, IQuests(address(quests)));

        // Prepare to create new Tasks
        Task memory task1 = Task({
            xp: 1,
            duration: 2000000,
            creator: arm0ry,
            detail: "bafkreib5pjrdtrotqdj46bozovqpjrgqzkvpdbt3mevyntdfydmyvfysza"
        });
        Task memory task2 = Task({
            xp: 2,
            duration: 2000000,
            creator: alice,
            detail: "bafkreib5pjrdtrotqdj46bozovqpjrgqzkvpdbt3mevyntdfydmyvfysza"
        });
        Task memory task3 = Task({
            xp: 3,
            duration: 2000000,
            creator: bob,
            detail: "bafkreib5pjrdtrotqdj46bozovqpjrgqzkvpdbt3mevyntdfydmyvfysza"
        });
        Task memory task4 = Task({
            xp: 4,
            duration: 2000000,
            creator: charlie,
            detail: "bafkreib5pjrdtrotqdj46bozovqpjrgqzkvpdbt3mevyntdfydmyvfysza"
        });

        tasks.push(task1);
        tasks.push(task2);
        tasks.push(task3);
        tasks.push(task4);

        // Create new Tasks
        vm.prank(arm0ry);
        missions.setTasks(tasks);

        // Prepare to create new Mission
        taskIds.push(1);
        taskIds.push(2);
        taskIds.push(3);
        taskIds.push(4);

        // Create new mission
        vm.prank(arm0ry);
        missions.setMission(
            true,
            0,
            arm0ry,
            "Welcome to New School",
            "bafkreib5pjrdtrotqdj46bozovqpjrgqzkvpdbt3mevyntdfydmyvfysza",
            taskIds,
            0
        );

        // Validate Mission setup
        (mission,) = missions.getMission(1);
        assertEq(missions.missionId(), 1);
        assertEq(mission.xp, 10);
        assertEq(mission.duration, 8000000);
        assertEq(mission.creator, arm0ry);
        assertEq(mission.requiredXp, 0);
    }

    /// @notice Check deployment.

    function testPurchase() public payable {
        deal(alice, 100e18);
        assertEq(alice.balance, 100e18);

        vm.prank(alice);
        missions.purchase(1);
        assertEq(missions.balanceOf(alice, 1), 1);

        // TEST ROYALTIES DISTRIBUTION
    }

    function testUpdateTask() public payable {}

    function testUpdateMission() public payable {}

    function testUpdateAdmin() public payable {}

    function testUpdateRoyalties() public payable {}
}
