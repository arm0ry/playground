// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {IMissions} from "src/interface/IMissions.sol";
import {IQuests} from "src/interface/IQuests.sol";

import {KaliDAO} from "src/kali/KaliDAO.sol";
import {Quests, QuestDetail, Reward, Review} from "src/Quests.sol";
import {Missions, Task, Mission} from "src/Missions.sol";

/// @dev Mocks.
import {MockERC20} from "solbase-test/utils/mocks/MockERC20.sol";
import {MockERC721} from "solbase-test/utils/mocks/MockERC721.sol";

/// -----------------------------------------------------------------------
/// Test Logic
/// -----------------------------------------------------------------------

contract QuestsTest is Test {
    IQuests iQuests;
    IMissions iMissions;
    Quests quests;
    Missions missions;

    MockERC721 erc721;

    Task task;
    Task[] tasks;
    uint256[] taskIds;
    Mission mission;

    KaliDAO arm0ry;
    address[] summoners;
    uint256[] tokenAmounts;
    address[] extensions;
    bytes[] extensionsData;
    uint32[16] govSettings;

    QuestDetail qd;

    /// @dev Users.
    address payable public immutable alice = payable(makeAddr("alice"));
    address public immutable bob = makeAddr("bob");
    address public immutable charlie = makeAddr("charlie");
    address public immutable dummy = makeAddr("dummy");

    /// @dev Helpers.

    string internal constant description = "TEST";

    bytes32 internal constant name1 = 0x5445535400000000000000000000000000000000000000000000000000000000;

    bytes32 internal constant name2 = 0x5445535432000000000000000000000000000000000000000000000000000000;

    /// -----------------------------------------------------------------------
    /// Kali Setup Tests
    /// -----------------------------------------------------------------------

    /// @notice Set up the testing suite.

    function setUp() public payable {
        // Summon KaliDAO
        deployKali();

        // Deploy contracts
        missions = new Missions(address(arm0ry), IQuests(address(quests)));
        quests = new Quests(IMissions(address(missions)), payable(address(arm0ry)), false);

        mintAliceNft();
        setupTasksAndMissions();

        vm.warp(1000);
    }

    function testStart() public payable {
        vm.prank(alice);
        quests.start(address(erc721), 1, 1);

        qd = quests.getQuestDetail(address(erc721), 1, 1);
        assertEq(qd.active, true);
        assertEq(qd.timestamp, 1000);
        assertEq(qd.timeLeft, 400);
    }

    function testStart_Pause() public payable {
        testStart();
        vm.warp(1010);

        vm.prank(alice);
        quests.pause(address(erc721), 1, 1);

        qd = quests.getQuestDetail(address(erc721), 1, 1);
        assertEq(qd.active, false);
        assertEq(qd.timestamp, 0);
        assertEq(qd.timeLeft, 390);
    }

    function testStart_Pause_Start() public payable {
        testStart_Pause();
        vm.warp(1020);

        vm.prank(alice);
        quests.start(address(erc721), 1, 1);

        qd = quests.getQuestDetail(address(erc721), 1, 1);
        assertEq(qd.active, true);
        assertEq(qd.timestamp, 1020);
        assertEq(qd.timeLeft, 390);
    }

    function testRespond_NonReviewable_Task() public payable {
        testStart();
        vm.warp(1010);

        vm.prank(alice);
        quests.respond(address(erc721), 1, 1, 1, "FIRST RESPONSE");
        bytes memory taskKey = quests.encode(address(erc721), 1, 1, 1);
        string memory responses = quests.responses(taskKey, 0);
        // assertEq(responses.length, 1);
        emit log_string(responses);

        qd = quests.getQuestDetail(address(erc721), 1, 1);
        assertEq(qd.completed, 1);
        assertEq(qd.progress, 25);
    }

    function testRespond_Reviewable_Task() public payable {
        testStart();
        vm.prank(address(arm0ry));
        quests.updateQuestReviewStatus(address(erc721), 1, 1, true);
        qd = quests.getQuestDetail(address(erc721), 1, 1);
        assertEq(qd.review, true);

        vm.warp(1010);

        vm.prank(alice);
        quests.respond(address(erc721), 1, 1, 1, "FIRST RESPONSE");
        qd = quests.getQuestDetail(address(erc721), 1, 1);
        assertEq(qd.completed, 0);
        assertEq(qd.progress, 0);
    }

    function testReceiveETH() public payable {
        (bool sent,) = address(quests).call{value: 5 ether}("");
        assert(sent);
        assert(address(quests).balance == 5 ether);
    }

    function testUpdateAdmin() public payable {
        vm.prank(address(arm0ry));
        quests.updateAdmin(alice);

        // Validate admin update
        assertEq(quests.admin(), alice);
    }

    function testUpdateContracts() public payable {
        vm.prank(address(arm0ry));
        iMissions = IMissions(address(charlie));
        quests.updateContracts(iMissions);

        // Validate contract update
        assertEq(address(quests.mission()), address(iMissions));
    }

    /// -----------------------------------------------------------------------
    /// Internal Functions
    /// -----------------------------------------------------------------------

    function deployKali() internal {
        summoners.push(alice);
        tokenAmounts.push(10e18);
        govSettings = [500, 0, 20, 60, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
        arm0ry = new KaliDAO();
        arm0ry.init("Arm0ry", "ARM", "", true, extensions, extensionsData, summoners, tokenAmounts, govSettings);
    }

    function mintAliceNft() internal {
        // Mint Alice an NFT to quest
        erc721 = new MockERC721("TEST", "TEST");
        erc721.mint(alice, 1);
        assertEq(erc721.balanceOf(alice), 1);
    }

    function setupTasks() internal {
        // Prepare data to create new Tasks
        Task memory task1 = Task({
            xp: 1,
            duration: 100,
            creator: address(arm0ry),
            detail: "bafkreib5pjrdtrotqdj46bozovqpjrgqzkvpdbt3mevyntdfydmyvfysza"
        });
        Task memory task2 = Task({
            xp: 2,
            duration: 100,
            creator: alice,
            detail: "bafkreib5pjrdtrotqdj46bozovqpjrgqzkvpdbt3mevyntdfydmyvfysza"
        });
        Task memory task3 = Task({
            xp: 3,
            duration: 100,
            creator: bob,
            detail: "bafkreib5pjrdtrotqdj46bozovqpjrgqzkvpdbt3mevyntdfydmyvfysza"
        });
        Task memory task4 = Task({
            xp: 4,
            duration: 100,
            creator: charlie,
            detail: "bafkreib5pjrdtrotqdj46bozovqpjrgqzkvpdbt3mevyntdfydmyvfysza"
        });

        tasks.push(task1);
        tasks.push(task2);
        tasks.push(task3);
        tasks.push(task4);

        // Create new Tasks
        vm.prank(address(arm0ry));
        missions.setTasks(taskIds, tasks);

        // Validate Task setup
        task = missions.getTask(1);
        assertEq(task.creator, address(arm0ry));
        assertEq(task.xp, 1);
    }

    function setupMissions() internal {
        // Prepare to create new Mission
        taskIds.push(1);
        taskIds.push(2);
        taskIds.push(3);
        taskIds.push(4);

        // Create new mission
        vm.prank(address(arm0ry));
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
    }

    function setupTasksAndMissions() internal {
        setupTasks();
        setupMissions();
        delete taskIds;
    }
}
