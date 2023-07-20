// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {Missions, Task, Mission} from "src/Missions.sol";
import {IMissions} from "src/interface/IMissions.sol";
import {Quests} from "src/Quests.sol";
import {IQuests} from "src/interface/IQuests.sol";

/// -----------------------------------------------------------------------
/// Test Logic
/// -----------------------------------------------------------------------

contract MissionsTest is Test {
    Quests quests;
    Missions missions;

    IQuests iQuests;
    IMissions iMissions;

    Task task;
    Task[] tasks;
    Task[] newTasks;
    uint256[] taskIds;
    uint256[] newTaskIds;

    Mission mission;

    uint256 royalties;
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
        // Deploy the Missions contract
        missions = new Missions(arm0ry, IQuests(address(quests)));

        // Validate global variables
        assertEq(missions.royalties(), 10);
        assertEq(missions.admin(), arm0ry);

        // Prepare data to create new Tasks
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
        missions.setTasks(taskIds, tasks);

        // Validate Task setup
        task = missions.getTask(1);
        assertEq(task.creator, arm0ry);
        assertEq(task.xp, 1);

        // Prepare to create new Mission
        taskIds.push(1);
        taskIds.push(2);
        taskIds.push(3);
        taskIds.push(4);

        // Create new mission
        vm.prank(arm0ry);
        missions.setMission(
            0,
            true,
            0,
            bob,
            "Welcome to New School",
            "bafkreib5pjrdtrotqdj46bozovqpjrgqzkvpdbt3mevyntdfydmyvfysza",
            taskIds,
            1e18 // 1 ETH
        );

        // Validate Mission setup
        (mission,) = missions.getMission(1);
        assertEq(missions.missionId(), 1);
        assertEq(mission.creator, bob);
        assertEq(mission.requiredXp, 0);

        // Validate tasks exist in Mission
        assertEq(missions.isTaskInMission(1, 1), true);
        assertEq(missions.isTaskInMission(1, 2), true);
        assertEq(missions.isTaskInMission(1, 3), true);
        assertEq(missions.isTaskInMission(1, 4), true);
        assertEq(missions.isTaskInMission(1, 5), false);

        delete taskIds;
    }

    function testReceiveETH() public payable {
        (bool sent,) = address(quests).call{value: 5 ether}("");
        assert(sent);
        assert(address(quests).balance == 5 ether);
    }

    function testUpdateAdmin() public payable {
        vm.prank(arm0ry);
        missions.updateAdmin(charlie);

        // Validate admin update
        assertEq(missions.admin(), charlie);
    }

    function testUpdateContracts() public payable {
        vm.prank(arm0ry);
        iQuests = IQuests(address(charlie));
        missions.updateContracts(iQuests);

        // Validate admin update
        assertEq(address(missions.quests()), address(iQuests));
    }

    function testUpdateRoyalties() public payable {
        vm.prank(arm0ry);
        missions.updateRoyalties(12);

        // Validate royalties update
        assertEq(missions.royalties(), 12);
    }

    function testPurchase() public payable {
        // Deal Alice 100 eth
        deal(alice, 100e18);

        // Validate existing balances
        assertEq(alice.balance, 100e18);
        assertEq(bob.balance, 0);
        assertEq(address(arm0ry).balance, 0);

        // Alice makes purchase
        vm.prank(alice);
        missions.purchase{value: 1e18}(1);
        assertEq(missions.balanceOf(alice, 1), 1);

        // Validate royalties distribution
        assertEq(address(bob).balance, 0.1e18);
        assertEq(address(arm0ry).balance, 0.9e18);
    }

    function testUpdateTasks() public payable {
        // Prepare data to create new Tasks
        Task memory task1 = Task({
            xp: 4,
            duration: 2000000,
            creator: arm0ry,
            detail: "bafkreib5pjrdtrotqdj46bozovqpjrgqzkvpdbt3mevyntdfydmyvfysza"
        });
        Task memory task2 = Task({
            xp: 3,
            duration: 2000000,
            creator: alice,
            detail: "bafkreib5pjrdtrotqdj46bozovqpjrgqzkvpdbt3mevyntdfydmyvfysza"
        });
        Task memory task3 = Task({
            xp: 2,
            duration: 2000000,
            creator: bob,
            detail: "bafkreib5pjrdtrotqdj46bozovqpjrgqzkvpdbt3mevyntdfydmyvfysza"
        });
        Task memory task4 = Task({
            xp: 1,
            duration: 2000000,
            creator: charlie,
            detail: "bafkreib5pjrdtrotqdj46bozovqpjrgqzkvpdbt3mevyntdfydmyvfysza"
        });

        newTasks.push(task1);
        newTasks.push(task2);
        newTasks.push(task3);
        newTasks.push(task4);

        newTaskIds.push(1);
        newTaskIds.push(2);
        newTaskIds.push(3);
        newTaskIds.push(4);

        // Update Tasks
        vm.prank(arm0ry);
        missions.setTasks(newTaskIds, newTasks);

        // Validate Task setup
        task = missions.getTask(1);
        assertEq(task.creator, arm0ry);
        assertEq(task.xp, 4);
    }

    function testUpdateMission() public payable {
        // Prepare to create new Mission
        taskIds.push(2);
        taskIds.push(5);

        // Create new mission
        vm.prank(arm0ry);
        missions.setMission(
            1,
            false,
            2e18,
            charlie,
            "Welcome to New School",
            "bafkreib5pjrdtrotqdj46bozovqpjrgqzkvpdbt3mevyntdfydmyvfysza",
            taskIds,
            1e18 // 1 ETH
        );

        // Validate Mission setup
        (mission,) = missions.getMission(1);
        assertEq(missions.missionId(), 1);
        assertEq(mission.creator, charlie);
        assertEq(mission.requiredXp, 2e18);
        assertEq(mission.taskIds.length, 2);
    }

    function testAggregateTasksDate() public payable {}

    function testIsTaskInMission() public payable {}
}
