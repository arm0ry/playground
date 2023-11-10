// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import "kali-markets/Storage.sol";
import {Mission} from "src/Mission.sol";
import {IMission} from "src/interface/IMission.sol";
import {Quest} from "src/Quest.sol";
import {IQuest} from "src/interface/IQuest.sol";

/// -----------------------------------------------------------------------
/// Test Logic
/// -----------------------------------------------------------------------

contract MissionTest is Test {
    Quest quest;
    Mission mission;

    address[] creators;
    address[] newCreators;
    uint256[] deadlines;
    uint256[] newDeadlines;
    string[] detail;
    string[] newDetail;
    uint256[] taskIds;
    uint256[] newTaskIds;

    /// @dev Users.
    address public immutable alice = makeAddr("alice");
    address public immutable bob = makeAddr("bob");
    address public immutable charlie = makeAddr("charlie");
    address public immutable dummy = makeAddr("dummy");
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

    function testReceiveETH() public payable {
        (bool sent,) = address(mission).call{value: 5 ether}("");
        assert(!sent);
    }

    function testInitialized() public payable {
        // Initialize.
        initialize(dao);

        // Validate initialization.
        assertEq(mission.getDao(), dao);
    }

    /// -----------------------------------------------------------------------
    /// DAO Test
    /// ----------------------------------------------------------------------

    function testAuthorizeQuest() public payable {
        // Initialize.
        initialize(dao);

        // Authorize quest contract.
        vm.prank(dao);
        mission.authorizeQuest(address(quest), true);

        // Validate.
        assertEq(mission.isQuestAuthorized(address(quest)), true);
    }

    function testAuthorizeQuest_NotOperator() public payable {
        // Initialize.
        initialize(dao);

        // Authorize quest contract.
        vm.expectRevert(Storage.NotOperator.selector);
        mission.authorizeQuest(address(quest), true);
    }

    /// -----------------------------------------------------------------------
    /// Task Test - Setter
    /// ----------------------------------------------------------------------

    function testSetTask() public payable {
        // Initialize.
        initialize(dao);

        // Set up task.
        setTask(alice, 100000, "Test");
    }

    function testSetTask_NotOperator() public payable {
        // Initialize.
        initialize(dao);

        // Set up task.
        vm.expectRevert(Storage.NotOperator.selector);
        mission.setTasks(creators, deadlines, detail);
    }

    function testSetTask_LengthMismatch() public payable {
        // Initialize.
        initialize(dao);
        creators.push(alice);
        detail.push("Test");

        // Set up task.
        vm.expectRevert(Storage.LengthMismatch.selector);
        vm.prank(dao);
        mission.setTasks(creators, deadlines, detail);
    }

    function testSetTask_InvalidTask() public payable {
        // Initialize.
        initialize(dao);

        // Set up task.
        vm.expectRevert(Mission.InvalidTask.selector);
        vm.prank(dao);
        mission.setTasks(creators, deadlines, detail);
    }

    function testSetTasks() public payable {
        // Initialize.
        initialize(dao);

        // Set up param.
        creators.push(alice);
        creators.push(bob);
        creators.push(charlie);
        deadlines.push(10000);
        deadlines.push(100);
        deadlines.push(1);
        detail.push("TEST");
        detail.push("TEST 2");
        detail.push("TEST 3");

        // Set up task.
        setTasks();
    }

    function testSetTaskCreator() public payable {
        // Set tasks.
        testSetTasks();
        vm.warp(block.timestamp + 1000);

        // Update creator.
        vm.prank(dao);
        mission.setTaskCreator(2, alice);

        // Validate.
        assertEq(mission.getTaskCreator(2), alice);
    }

    function testSetTaskDeadline() public payable {}

    function testSetTaskDetail() public payable {}

    function testIncrementTaskCompletions() public payable {}

    /// -----------------------------------------------------------------------
    /// Mission Test - Setter
    /// ----------------------------------------------------------------------

    function testSetMission() public payable {
        // Prepare to create new Mission
        // taskIds.push(2);
        // taskIds.push(5);

        // // Create new mission
        // vm.prank(dao);
        // mission.setMission(
        //     charlie, "Welcome to New School", "bafkreib5pjrdtrotqdj46bozovqpjrgqzkvpdbt3mevyntdfydmyvfysza", taskIds
        // );

        // Validate Mission setup
        // (mission,) = mission.getMission(1);
        // assertEq(mission.missionId(), 1);
        // assertEq(mission.creator, charlie);
        // assertEq(mission.taskIds.length, 2);
    }

    function testSetMissionCreator() public payable {}

    function testSetMissionDeadline() public payable {}

    function testSetMissionDetail() public payable {}

    function testSetMissionTasks() public payable {}

    function testIncrementMissionStarts() public payable {}

    function testIncrementMissionCompletions() public payable {}

    /// -----------------------------------------------------------------------
    /// Task Test - Getter
    /// ----------------------------------------------------------------------

    function testGetTaskId() public payable {}

    function testGetTaskCreator() public payable {}

    function testGetTaskDeadline() public payable {}

    function testGetTaskDetail() public payable {}

    function testGetTaskCompletions() public payable {}

    function testIsTaskInMission() public payable {
        // bool existTask1 = mission.isTaskInMission(1, 1);
        // bool existTask2 = mission.isTaskInMission(1, 2);
        // bool existTask3 = mission.isTaskInMission(1, 3);
        // bool existTask4 = mission.isTaskInMission(1, 4);
        // bool existTask5 = mission.isTaskInMission(1, 5);

        // assertEq(existTask1, true);
        // assertEq(existTask2, true);
        // assertEq(existTask3, true);
        // assertEq(existTask4, true);
        // assertEq(existTask5, false);
    }

    /// -----------------------------------------------------------------------
    /// Mission Test - Getter
    /// ----------------------------------------------------------------------

    function testGetMissionId() public payable {}

    function testGetMissionCreator() public payable {}

    function testGetMissionDetail() public payable {}

    function testGetMissionTitle() public payable {}

    function testGetMissionTaskCount() public payable {}

    function testGetMissionTaskId() public payable {}

    function testGetMissionTaskIds() public payable {}

    function testGetMissionDeadline() public payable {}

    function testGetMissionStarts() public payable {}

    function testGetMissionCompletions() public payable {}

    /// -----------------------------------------------------------------------
    /// Internal Functions
    /// -----------------------------------------------------------------------

    function initialize(address _dao) internal {
        mission.initialize(_dao);
    }

    function setTask(address creator, uint256 deadline, string memory description) internal {
        // Set up task param.
        creators.push(creator);
        deadlines.push(deadline);
        detail.push(description);

        // Set up task.
        vm.prank(dao);
        mission.setTasks(creators, deadlines, detail);

        // Validate setup.
        assertEq(mission.getTaskId(), ++taskId);
        assertEq(mission.getTaskCreator(taskId), creator);
        assertEq(mission.getTaskDeadline(taskId), deadline);
        assertEq(mission.getTaskDetail(taskId), description);
    }

    function setTasks() internal {
        // Set up task.
        vm.prank(dao);
        mission.setTasks(creators, deadlines, detail);

        // Validate setup.
        for (uint256 i = 0; i < creators.length; i++) {
            ++taskId;
            assertEq(mission.getTaskCreator(taskId), creators[i]);
            assertEq(mission.getTaskDeadline(taskId), deadlines[i]);
            assertEq(mission.getTaskDetail(taskId), detail[i]);
        }
        assertEq(mission.getTaskId(), taskId);
    }

    // function setupTasksAndMission() internal {
    //     // Prepare data to create new Tasks
    //     Task memory task1 = Task({
    //         xp: 1,
    //         duration: 100,
    //         creator: address(dao),
    //         detail: "bafkreib5pjrdtrotqdj46bozovqpjrgqzkvpdbt3mevyntdfydmyvfysza"
    //     });
    //     Task memory task2 = Task({
    //         xp: 2,
    //         duration: 100,
    //         creator: alice,
    //         detail: "bafkreib5pjrdtrotqdj46bozovqpjrgqzkvpdbt3mevyntdfydmyvfysza"
    //     });
    //     Task memory task3 = Task({
    //         xp: 3,
    //         duration: 100,
    //         creator: bob,
    //         detail: "bafkreib5pjrdtrotqdj46bozovqpjrgqzkvpdbt3mevyntdfydmyvfysza"
    //     });
    //     Task memory task4 = Task({
    //         xp: 4,
    //         duration: 100,
    //         creator: charlie,
    //         detail: "bafkreib5pjrdtrotqdj46bozovqpjrgqzkvpdbt3mevyntdfydmyvfysza"
    //     });

    //     tasks.push(task1);
    //     tasks.push(task2);
    //     tasks.push(task3);
    //     tasks.push(task4);

    //     // Create new Tasks
    //     vm.prank(address(dao));
    //     missions.setTasks(taskIds, tasks);

    //     // Validate Task setup
    //     task = missions.getTask(1);
    //     assertEq(task.creator, address(dao));
    //     assertEq(task.xp, 1);

    //     // Prepare to create new Mission
    //     taskIds.push(1);
    //     taskIds.push(2);
    //     taskIds.push(3);
    //     taskIds.push(4);

    //     // Create new mission
    //     vm.prank(address(dao));
    //     missions.setMission(
    //         0,
    //         true,
    //         bob,
    //         "Welcome to New School",
    //         "bafkreib5pjrdtrotqdj46bozovqpjrgqzkvpdbt3mevyntdfydmyvfysza",
    //         taskIds,
    //         1e18 // 1 ETH
    //     );

    //     // Validate Mission setup
    //     (mission,) = missions.getMission(1);
    //     assertEq(missions.missionId(), 1);
    //     assertEq(mission.creator, bob);

    //     // Validate tasks exist in Mission
    //     assertEq(missions.isTaskInMission(1, 1), true);
    //     assertEq(missions.isTaskInMission(1, 2), true);
    //     assertEq(missions.isTaskInMission(1, 3), true);
    //     assertEq(missions.isTaskInMission(1, 4), true);
    //     assertEq(missions.isTaskInMission(1, 5), false);

    //     delete taskIds;
    // }
}
