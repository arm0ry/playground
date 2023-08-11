// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {IMissions} from "src/interface/IMissions.sol";
import {IQuests} from "src/interface/IQuests.sol";
import {IQuestsDirectory} from "src/interface/IQuestsDirectory.sol";

import {KaliDAO} from "src/kali/KaliDAO.sol";
import {Quests, QuestConfig, QuestDetail, Reward, RewardType, Review} from "src/Quests.sol";
import {Missions, Task, Mission} from "src/Missions.sol";
import {QuestsDirectory} from "src/QuestsDirectory.sol";

/// @dev Mocks.
import {MockERC20} from "solbase-test/utils/mocks/MockERC20.sol";
import {MockERC721} from "solbase-test/utils/mocks/MockERC721.sol";

/// -----------------------------------------------------------------------
/// Test Logic
/// -----------------------------------------------------------------------

contract QuestsTest is Test {
    IQuests iQuests;
    IMissions iMissions;
    IQuestsDirectory iQuestsDirectory;
    Quests quests_dao;
    Quests quests_erc20;
    Missions missions;
    QuestsDirectory questsDirectory;

    MockERC721 erc721;
    MockERC20 erc20;

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
    QuestConfig qc;

    /// @dev Users.

    // Alice goes on quests
    address payable public immutable alice = payable(makeAddr("alice"));
    // Bob writes missions
    address public immutable bob = makeAddr("bob");
    // Charlie writes tasks and reviews tasks
    address public immutable charlie = makeAddr("charlie");
    // Misc address
    address public immutable dummy = makeAddr("dummy");

    /// @dev Helpers.
    // string internal constant description = "TEST";
    // bytes32 internal constant name1 = 0x5445535400000000000000000000000000000000000000000000000000000000;
    // bytes32 internal constant name2 = 0x5445535432000000000000000000000000000000000000000000000000000000;

    /// @notice Set up the testing suite.
    function setUp() public payable {
        // Summon KaliDAO
        deployKali();

        // Deploy contracts
        missions = new Missions();
        missions.initialize(address(arm0ry));

        questsDirectory = new QuestsDirectory();
        questsDirectory.initialize(IMissions(address(missions)), address(arm0ry));

        // Quest that reward DAO tokens
        quests_dao = new Quests();
        quests_dao.initialize(IMissions(address(missions)), IQuestsDirectory(address(questsDirectory)), address(arm0ry));

        // Quest that reward ERC20 tokens
        quests_erc20 = new Quests();
        quests_erc20.initialize(
            IMissions(address(missions)), IQuestsDirectory(address(questsDirectory)), address(arm0ry)
        );

        mintNft(alice);
        setupTasksAndMissions();
        setupRewards_Dao();
        setupRewards_Erc20();

        vm.warp(1000);
    }

    /// -----------------------------------------------------------------------
    /// DAO Token as Rewards
    /// -----------------------------------------------------------------------

    function testStart() public payable {
        vm.prank(alice);
        quests_dao.start(address(erc721), 1, 1);

        qd = quests_dao.getQuestDetail(address(erc721), 1, 1);
        assertEq(qd.active, true);
        assertEq(qd.timestamp, 1000);
        assertEq(qd.timeLeft, 400);
    }

    function testStartBySig() public payable {}

    function testStart_Pause() public payable {
        testStart();
        vm.warp(1010);

        vm.prank(alice);
        quests_dao.pause(address(erc721), 1, 1);

        qd = quests_dao.getQuestDetail(address(erc721), 1, 1);
        assertEq(qd.active, false);
        assertEq(qd.timestamp, 0);
        assertEq(qd.timeLeft, 390);
    }

    function testStartBySig_PauseBySig() public payable {}

    function testStart_Pause_Start() public payable {
        testStart_Pause();
        vm.warp(1020);

        vm.prank(alice);
        quests_dao.start(address(erc721), 1, 1);

        qd = quests_dao.getQuestDetail(address(erc721), 1, 1);
        assertEq(qd.active, true);
        assertEq(qd.timestamp, 1020);
        assertEq(qd.timeLeft, 390);
    }

    function testStartBySig_PauseBySig_StartBySig() public payable {}

    function testRespond_NonReviewable_Task() public payable {
        testStart();
        vm.warp(1010);

        vm.prank(alice);
        quests_dao.respond(address(erc721), 1, 1, 1, "FIRST RESPONSE");
        bytes memory taskKey = quests_dao.encode(address(erc721), 1, 1, 1);
        string memory responses = quests_dao.responses(taskKey, 0);
        // assertEq(responses.length, 1);
        emit log_string(responses);

        qd = quests_dao.getQuestDetail(address(erc721), 1, 1);
        assertEq(qd.completed, 1);
        assertEq(qd.progress, 25);
    }

    function testRespond_Reviewable_Task() public payable {
        testStart();
        vm.prank(address(arm0ry));
        quests_dao.updateQuestReviewStatus(address(erc721), 1, 1, true);
        qd = quests_dao.getQuestDetail(address(erc721), 1, 1);
        assertEq(qd.review, true);

        vm.warp(1010);

        vm.prank(alice);
        quests_dao.respond(address(erc721), 1, 1, 1, "FIRST RESPONSE");
        qd = quests_dao.getQuestDetail(address(erc721), 1, 1);
        assertEq(qd.completed, 0);
        assertEq(qd.progress, 0);
    }

    function testReview() public payable {
        testRespond_Reviewable_Task();
    }

    function testClaimRewards() public payable {}

    /// -----------------------------------------------------------------------
    /// ERC20 Token as Rewards
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// Admin functions
    /// -----------------------------------------------------------------------

    function testUpdateAdmin() public payable {
        vm.prank(address(arm0ry));
        quests_dao.updateAdmin(alice);

        // Validate admin update
        assertEq(quests_dao.admin(), alice);
    }

    function testUpdateContracts() public payable {
        vm.prank(address(arm0ry));
        iMissions = IMissions(address(dummy));
        quests_dao.updateContracts(iMissions);

        // Validate contract update
        assertEq(address(quests_dao.mission()), address(iMissions));
    }

    function testReceiveETH() public payable {
        (bool sent,) = address(quests_dao).call{value: 5 ether}("");
        assert(sent);
        assert(address(quests_dao).balance == 5 ether);
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

    function addReviewer(address account) internal {
        // cast calldata "updateReviewer(address,bool)" [ADDRESS] [BOOL]
        // bytes32 payloads = ;

        // vm.prank(alice);
        // arm0ry.propose(2, "Add reviewer", [address(quests_dao)], [0], payloads);
    }

    function mintNft(address account) internal {
        // Mint Alice an NFT to quest
        erc721 = new MockERC721("TEST", "TEST");
        erc721.mint(account, 1);
        assertEq(erc721.balanceOf(account), 1);
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
            creator: charlie,
            detail: "bafkreib5pjrdtrotqdj46bozovqpjrgqzkvpdbt3mevyntdfydmyvfysza"
        });
        Task memory task3 = Task({
            xp: 3,
            duration: 100,
            creator: charlie,
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

    function setupRewards_Dao() internal {
        vm.prank(address(arm0ry));
        quests_dao.updateQuestConfigs(
            1,
            QuestConfig({
                multiplier: 2,
                gateToken: address(0),
                gateAmount: 0,
                rewardType: RewardType.DAO_ERC20,
                rewardToken: address(arm0ry)
            })
        );

        // Validate quest configurations
        qc = quests_dao.getQuestConfig(1);
        assertEq(qc.multiplier, 2);
        assertEq(qc.rewardToken, address(arm0ry));
    }

    function setupRewards_Erc20() internal {
        erc20 = new MockERC20("TEST_20", "TEST_20", 18);
        // erc20.mint(address(arm0ry), 1);

        vm.prank(address(arm0ry));

        QuestConfig memory _qc = QuestConfig({
            multiplier: 2,
            gateToken: address(0),
            gateAmount: 0,
            rewardType: RewardType.ERC20,
            rewardToken: address(erc20)
        });

        quests_erc20.updateQuestConfigs(1, _qc);

        qc = quests_dao.getQuestConfig(1);
        assertEq(qc.multiplier, 2);
        assertEq(qc.rewardToken, address(arm0ry));
    }
}
