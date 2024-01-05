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
    uint256[] deadlines;
    string[] detail;
    uint256[] taskIds;
    uint256[] newTaskIds;

    /// @dev Users.
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

    function testAuthorizeQuest(bool authorization) public payable {
        // Initialize.
        initialize(dao);

        // Authorize quest contract.
        vm.prank(dao);
        mission.authorizeQuest(address(quest), authorization);

        // Validate.
        assertEq(mission.isQuestAuthorized(address(quest)), authorization);
    }

    function testAuthorizeQuest_NotOperator(bool authorization) public payable {
        // Initialize.
        initialize(dao);

        // Authorize quest contract.
        vm.expectRevert(Storage.NotOperator.selector);
        mission.authorizeQuest(address(quest), authorization);
    }

    function testSetFee(uint256 _fee) public payable {
        // Initialize.
        initialize(dao);

        // Authorize quest contract.
        vm.prank(dao);
        mission.setFee(_fee);

        // Validate.
        assertEq(mission.getFee(), _fee);
    }

    function testSetFee_NotOperator(uint256 _fee) public payable {
        // Initialize.
        initialize(dao);

        // Authorize quest contract.
        vm.expectRevert(Storage.NotOperator.selector);
        mission.setFee(_fee);
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

        // Set up task.
        setTasks();
    }

    function testPayToSetTasks(uint256 _fee) public payable {
        vm.assume(9 ether > _fee);

        // Initialize.
        testSetFee(_fee);

        // Set up param.
        delete creators;
        delete deadlines;
        delete detail;

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

        vm.deal(alice, 10 ether);

        // Set up task.
        payToSetTasks(alice, _fee);
    }

    function testPayToSetTasks_InvalidFee() public payable {
        // Initialize.
        testSetFee(0.001 ether);

        // Set up param.
        delete creators;
        delete deadlines;
        delete detail;

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

        vm.deal(alice, 10 ether);

        // Set up task.
        vm.expectRevert(Mission.InvalidFee.selector);
        vm.prank(alice);
        mission.payToSetTasks{value: 0.002 ether}(creators, deadlines, detail);
    }

    function testSetTaskCreator(address newCreator) public payable {
        // Set tasks.
        testSetTasks();
        vm.warp(block.timestamp + 1000);
        vm.assume(newCreator != address(0));

        // Update creator.
        vm.prank(dao);
        mission.setTaskCreator(2, newCreator);

        // Validate.
        assertEq(mission.getTaskCreator(2), newCreator);
    }

    function testSetTaskCreator_InvalidTask(address newCreator) public payable {
        delete newCreator;

        // Set mission.
        testSetTask();

        // Update creator.
        vm.expectRevert(Mission.InvalidTask.selector);
        vm.prank(dao);
        mission.setTaskCreator(taskId, newCreator);
    }

    function testSetTaskDeadline(uint256 newDeadline) public payable {
        // Set tasks.
        testSetTasks();
        vm.warp(block.timestamp + 1000);
        vm.assume(newDeadline > block.timestamp + 1000);

        // Update deadline.
        vm.prank(dao);
        mission.setTaskDeadline(taskId, newDeadline);

        // Validate.
        assertEq(mission.getTaskDeadline(taskId), newDeadline);
    }

    function testSetTaskDeadline_InvalidTask(uint256 newDeadline) public payable {
        delete newDeadline;

        // Set tasks.
        testSetTasks();
        vm.warp(block.timestamp + 1000);

        // Update deadline.
        vm.expectRevert(Mission.InvalidTask.selector);
        vm.prank(dao);
        mission.setTaskDeadline(taskId, newDeadline);
    }

    function testSetTaskDetail(string calldata newDetail) public payable {
        // Set tasks.
        testSetTasks();
        vm.warp(block.timestamp + 1000);

        // Update creator.
        vm.prank(dao);
        mission.setTaskDetail(taskId, newDetail);

        // Validate.
        assertEq(mission.getTaskDetail(taskId), newDetail);
    }

    function testIncrementTaskCompletions() public payable {}

    /// -----------------------------------------------------------------------
    /// Mission Test - Setter
    /// ----------------------------------------------------------------------

    function testSetMission() public payable {
        // Set tasks.
        testSetTasks();
        vm.warp(block.timestamp + 1000);

        // Prepare tasks to add to a a new mission.
        taskIds.push(1);
        taskIds.push(2);

        // Create new mission
        setMission(alice, "Welcome to your first mission!", "For more, check here.");
    }

    function testSetMission_InvalidMission() public payable {
        // Set tasks.
        testSetTasks();
        vm.warp(block.timestamp + 1000);

        // Create new mission
        vm.expectRevert(Mission.InvalidMission.selector);
        vm.prank(dao);
        mission.setMission(alice, "Welcome to your first mission!", "For more, check here.", taskIds);
    }

    function testPayToSetMission(uint256 _fee) public payable {
        vm.assume(9 ether > _fee);

        // Initialize.
        testSetFee(_fee);

        // Set tasks.
        testPayToSetTasks(_fee);
        vm.warp(block.timestamp + 1000);

        // Prepare tasks to add to a a new mission.
        taskIds.push(1);
        taskIds.push(2);
        taskIds.push(3);
        taskIds.push(4);

        vm.deal(alice, 10 ether);

        // Set up task.
        payToSetMission(alice, "Welcome to your first mission!", "For more, check here.", _fee);
    }

    function testPayToSetMission_InvalidFee() public payable {
        // Initialize.
        testSetFee(0.001 ether);

        // Set tasks.
        testSetTasks();
        vm.warp(block.timestamp + 1000);

        // Prepare tasks to add to a a new mission.
        taskIds.push(1);
        taskIds.push(2);

        vm.deal(alice, 10 ether);

        // Set up task.
        vm.expectRevert(Mission.InvalidFee.selector);
        vm.prank(alice);
        mission.payToSetMission{value: 0.002 ether}(
            alice, "Welcome to your first mission!", "For more, check here.", taskIds
        );
    }

    function testSetMissionCreator(address newCreator) public payable {
        // Set mission.
        testSetMission();
        vm.assume(newCreator != address(0));

        // Update creator.
        vm.prank(dao);
        mission.setMissionCreator(missionId, newCreator);

        // Validate.
        assertEq(mission.getMissionCreator(missionId), newCreator);
    }

    function testSetMissionCreator_InvalidMission(address newCreator) public payable {
        delete newCreator;

        // Set mission.
        testSetMission();

        // Update creator.
        vm.expectRevert(Mission.InvalidMission.selector);
        vm.prank(dao);
        mission.setMissionCreator(missionId, newCreator);
    }

    function testSetMissionTitle(string calldata newTitle) public payable {
        vm.assume(bytes(newTitle).length > 0);

        // Set mission.
        testSetMission();

        // Update creator.
        vm.prank(dao);
        mission.setMissionTitle(missionId, newTitle);

        // Validate.
        assertEq(mission.getMissionTitle(missionId), newTitle);
    }

    function testSetMissionTitle_InvalidMission(string memory newTitle) public payable {
        // Empty title.
        delete newTitle;

        // Set mission.
        testSetMission();

        // Update creator.
        vm.expectRevert(Mission.InvalidMission.selector);
        vm.prank(dao);
        mission.setMissionTitle(missionId, newTitle);
    }

    function testSetMissionDetail(string calldata newDetail) public payable {
        // Set mission.
        testSetMission();

        // Update creator.
        vm.prank(dao);
        mission.setMissionDetail(missionId, newDetail);

        // Validate.
        assertEq(mission.getMissionDetail(missionId), newDetail);
    }

    function testAddMissionTasks() public payable {
        // Set mission.
        testSetMission();

        // Reset and update taskIds to add to mission.
        delete taskIds;
        taskIds.push(3);
        taskIds.push(4);

        // Add taskIds.
        vm.prank(dao);
        mission.addMissionTasks(missionId, taskIds);

        // Reset and update taskIds to validate.
        delete taskIds;
        taskIds.push(1);
        taskIds.push(2);
        taskIds.push(3);
        taskIds.push(4);

        // Validate.
        assertEq(mission.getMissionTaskIds(missionId), taskIds);
    }

    function testSetMissionTaskId() public payable {
        // Set mission.
        testSetMission();

        uint256 order = 2;
        uint256 newTaskId = 3;

        // Add taskIds.
        vm.prank(dao);
        mission.setMissionTaskId(missionId, order, newTaskId);

        // Reset and update taskIds to validate.
        delete taskIds;
        taskIds.push(1);
        taskIds.push(3);

        // Validate.
        assertEq(mission.getMissionTaskIds(missionId), taskIds);
        assertEq(mission.getMissionDeadline(missionId), mission.getTaskDeadline(3));
    }

    function testSetMissionTaskId_InvalidTask() public payable {
        // Set mission.
        testSetMission();

        uint256 order = 2;
        uint256 newTaskId = 8;

        // Add taskIds.
        vm.expectRevert(Mission.InvalidTask.selector);
        vm.prank(dao);
        mission.setMissionTaskId(missionId, order, newTaskId);
    }

    function testSetMission_setTaskDeadline(uint256 newDeadline) public payable {
        // Set mission.
        testSetMission();
        vm.warp(block.timestamp + 1000);
        vm.assume(newDeadline > block.timestamp + 1000);

        uint256 _taskId = 1;
        uint256 _missionId = 1;

        // Update task deadline.
        vm.prank(dao);
        mission.setTaskDeadline(_taskId, newDeadline);

        // Validate.
        assertEq(mission.getTaskDeadline(_taskId), newDeadline);
        assertEq(mission.getMissionDeadline(_missionId), newDeadline);
    }

    /// -----------------------------------------------------------------------
    /// Task Test - Getter
    /// ----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// Mission Test - Getter
    /// ----------------------------------------------------------------------

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

    function payToSetTasks(address user, uint256 amount) internal {
        // Retrieve for validation alter.
        uint256 prevBalance = address(dao).balance;

        // Set up task.
        vm.prank(user);
        mission.payToSetTasks{value: amount}(creators, deadlines, detail);

        // Validate task creation.
        for (uint256 i = 0; i < creators.length; i++) {
            ++taskId;
            assertEq(mission.getTaskCreator(taskId), creators[i]);
            assertEq(mission.getTaskDeadline(taskId), deadlines[i]);
            assertEq(mission.getTaskDetail(taskId), detail[i]);
        }
        assertEq(mission.getTaskId(), taskId);

        // Validate balance.
        assertEq(address(dao).balance, prevBalance + amount);
        assertEq(address(mission).balance, 0);
    }

    function setMission(address creator, string memory title, string memory _detail) internal {
        // Set up task.
        vm.prank(dao);
        mission.setMission(creator, title, _detail, taskIds);

        // Retrieve deadlines from tasks identified by taskIds
        uint256 length = taskIds.length;
        uint256 _deadline;
        uint256 temp;
        for (uint256 i = 0; i < length; i++) {
            temp = mission.getTaskDeadline(taskIds[i]);
            (temp > _deadline) ? _deadline = temp : _deadline;
        }

        // Validate setup.
        ++missionId;
        newTaskIds.push(missionId);
        assertEq(mission.getMissionId(), missionId);
        assertEq(mission.getMissionCreator(missionId), creator);
        assertEq(mission.getMissionTitle(missionId), title);
        assertEq(mission.getMissionDetail(missionId), _detail);
        assertEq(mission.getMissionDeadline(missionId), _deadline);
        assertEq(mission.getMissionTaskCount(missionId), length);
        for (uint256 i = 0; i < length; i++) {
            assertEq(taskIds[i], mission.getMissionTaskId(missionId, i + 1));
            assertEq(mission.getTaskMissionIds(taskIds[i]), newTaskIds);
        }
        assertEq(taskIds, mission.getMissionTaskIds(missionId));
    }

    function payToSetMission(address creator, string memory title, string memory _detail, uint256 amount) internal {
        // Set up task.
        vm.prank(creator);
        mission.payToSetMission{value: amount}(creator, title, _detail, taskIds);

        // Retrieve deadlines from tasks identified by taskIds
        uint256 length = taskIds.length;
        uint256 _deadline;
        uint256 temp;
        for (uint256 i = 0; i < length; i++) {
            temp = mission.getTaskDeadline(taskIds[i]);
            (temp > _deadline) ? _deadline = temp : _deadline;
        }

        // Validate setup.
        ++missionId;
        newTaskIds.push(missionId);
        assertEq(mission.getMissionId(), missionId);
        assertEq(mission.getMissionCreator(missionId), creator);
        assertEq(mission.getMissionTitle(missionId), title);
        assertEq(mission.getMissionDetail(missionId), _detail);
        assertEq(mission.getMissionDeadline(missionId), _deadline);
        assertEq(mission.getMissionTaskCount(missionId), length);
        for (uint256 i = 0; i < length; i++) {
            assertEq(taskIds[i], mission.getMissionTaskId(missionId, i + 1));
            assertEq(mission.getTaskMissionIds(taskIds[i]), newTaskIds);
        }
        assertEq(taskIds, mission.getMissionTaskIds(missionId));
    }
}
