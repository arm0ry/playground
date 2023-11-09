// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {IMission} from "src/interface/IMission.sol";
import {IQuest} from "src/interface/IQuest.sol";

import {Quest} from "src/Quest.sol"; // Community goes on quest
import {Mission} from "src/Mission.sol"; // Put up missions
import {KaliDAO, ProposalType} from "kali-markets/kalidao/KaliDAO.sol"; // Start with a governance framework

/// @dev Mocks.
import {MockERC721} from "../lib/solbase/test/utils/mocks/MockERC721.sol";

/// -----------------------------------------------------------------------
/// Test Logic
/// -----------------------------------------------------------------------

contract QuestTest is Test {
    IQuest iQuest;
    Quest quests_dao;
    Quest quests_erc20;
    Mission missions;

    MockERC721 erc721;

    // Task task;
    // Task[] tasks;
    uint256[] taskIds;
    // Mission mission;

    // Kali proposals.
    address[] accounts;
    uint256[] amounts;
    bytes[] payloads;

    KaliDAO arm0ry;
    address[] summoners;
    uint256[] tokenAmounts;
    address[] extensions;
    bytes[] extensionsData;
    uint32[16] govSettings;

    // QuestDetail qd;

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

        // Initialize Quest that reward DAO tokens
        quests_dao = new Quest();

        // Deploy contracts
        missions = new Mission();
        vm.prank(address(arm0ry));
        missions.initialize((address(arm0ry)));
        // vm.prank(address(arm0ry));
        // quests_dao.initialize(directory);
        // vm.prank(address(arm0ry));
        // directory.setQuestAddress(address(quests_dao), true);

        // Initialize Quest that reward ERC20 tokens
        // quests_erc20 = new Quest();
        // vm.prank(address(arm0ry));
        // quests_erc20.initialize(directory);
        // vm.prank(address(arm0ry));
        // directory.setQuestAddress(address(quests_erc20), true);

        mintNft(alice);
        // setupTasksAndMissions();
        // setupRewards_Dao();
        // setupRewards_Erc20();

        // Let's do the same thing with `getCode`

        vm.warp(1000);
    }

    /// -----------------------------------------------------------------------
    /// DAO Token as Rewards
    /// -----------------------------------------------------------------------

    function testStart() public payable {
        vm.prank(alice);
        // quests_dao.start(address(missions), 1);

        // bytes32 questKey = quests_dao.encode(address(erc721), 1, address(missions), 1, 0);
        // qd = quests_dao.getQuestDetail(questKey);
        // assertEq(qd.active, true);
        // assertEq(qd.timestamp, 1000);
        // assertEq(qd.timeLeft, 400);
    }

    // function testStartBySig() public payable {}

    // function testRespond_NonReviewable_Task() public payable {
    //     testStart();
    //     vm.warp(1010);

    //     vm.prank(alice);
    //     quests_dao.respond(address(erc721), 1, 1, 1, "FIRST RESPONSE");

    //     bytes32 taskKey = quests_dao.encode(address(erc721), 1, 1, 1);
    //     string memory response = directory.getString(keccak256(abi.encodePacked(taskKey, ".review.response")));
    //     assertEq("FIRST RESPONSE", response);

    //     // (, uint256 taskCount) = missions.getMission(1);
    //     // assertEq(taskCount, 4);

    //     // bytes32 questKey = quests_dao.encode(address(erc721), 1, 1, 0);
    //     // qd = quests_dao.getQuestDetail(questKey);
    //     // assertEq(qd.completed, 1);
    //     // assertEq(qd.progress, 25);
    // }

    // function testRespond_Reviewable_Task() public payable {
    //     addReviewer(alice);
    //     addGlobalReviewStatus(true);
    //     // testStart();
    //     // vm.warp(1010);

    //     // vm.prank(alice);
    //     // quests_dao.respond(address(erc721), 1, 1, 1, "FIRST RESPONSE");

    //     // bytes32 taskKey = quests_dao.encode(address(erc721), 1, 1, 1);
    //     // string memory response = directory.getString(keccak256(abi.encodePacked(taskKey, ".review.response")));
    //     // assertEq("FIRST RESPONSE", response);

    //     // (, uint256 taskCount) = missions.getMission(1);
    //     // assertEq(taskCount, 4);

    //     // bytes32 questKey = quests_dao.encode(address(erc721), 1, 1, 0);
    //     // qd = quests_dao.getQuestDetail(questKey);
    //     // assertEq(qd.completed, 1);
    //     // assertEq(qd.progress, 25);
    // }

    // // function testReview() public payable {
    // // testStart();
    // // vm.prank(address(arm0ry));
    // // quests_dao.review(address(erc721), 1, 1, 1, true);

    // // bytes32 taskKey = quests_dao.encode(address(erc721), 1, 1, 1);
    // // bool review = directory.getBool(keccak256(abi.encodePacked(taskKey, ".review.result")));
    // // assertEq(review, true);
    // // }

    // function testClaimRewards() public payable {}

    // function testUpdateAdmin() public payable {
    //     // vm.prank(address(arm0ry));
    //     // quests_dao.updateAdmin(alice);

    //     // Validate admin update
    //     // assertEq(quests_dao.admin(), alice);
    // }

    // function testUpdateContracts() public payable {
    //     // vm.prank(address(arm0ry));
    //     // IMission = IMission(address(dummy));
    //     // quests_dao.updateContracts(IMission);

    //     // Validate contract update
    //     // assertEq(address(quests_dao.mission()), address(IMission));
    // }

    function testReceiveETH() public payable {
        (bool sent,) = address(quests_dao).call{value: 5 ether}("");
        assert(!sent);
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

    function addReviewer(address reviewer) internal {
        bytes memory payload = abi.encodeWithSignature("setReviewer(address,bool)", address(alice), true);
        // bytes memory payload_reviewStatus = abi.encodeWithSignature(
        //     "setReviewStatus(address, uint256, uint256, bool)", tokenAddress, tokenId, missionId, reviewStatus
        // );

        emit log_bytes(payload);

        uint256 proposalId = arm0ry.proposalCount();
        emit log_uint(proposalId);
        emit log_uint(block.timestamp);
        accounts.push(address(quests_dao));
        amounts.push(0);
        payloads.push(payload);
        vm.prank(alice);
        arm0ry.propose(ProposalType.CALL, "Add reviewer", accounts, amounts, payloads);
        emit log_uint(block.timestamp);

        proposalId = arm0ry.proposalCount();
        vm.warp(1100);
        vm.prank(alice);
        emit log_uint(block.timestamp);
        arm0ry.vote(proposalId, true);

        vm.warp(1600);
        vm.prank(alice);
        arm0ry.processProposal(proposalId);

        // bool exists = directory.getBool(keccak256(abi.encodePacked(address(alice), ".exists")));
        // uint256 reviewerId = directory.getUint(keccak256(abi.encodePacked(address(alice), ".reviewerId")));
        // assertEq(exists, true);
        // assertEq(reviewerId, 1);
        // emit log_uint(reviewerId);
    }

    function addGlobalReviewStatus(bool status) internal {
        bytes memory payload = abi.encodeWithSignature("setGlobalReviewStatus(bool)", status);

        emit log_bytes(payload);

        uint256 proposalId = arm0ry.proposalCount();
        emit log_uint(proposalId);
        emit log_uint(block.timestamp);
        accounts.push(address(quests_dao));
        amounts.push(0);
        payloads.push(payload);
        vm.prank(alice);
        arm0ry.propose(ProposalType.CALL, "Toggle review status", accounts, amounts, payloads);
        emit log_uint(block.timestamp);

        proposalId = arm0ry.proposalCount();
        vm.warp(1700);
        vm.prank(alice);
        emit log_uint(block.timestamp);
        arm0ry.vote(proposalId, true);

        vm.warp(2300);
        vm.prank(alice);
        arm0ry.processProposal(proposalId);

        // bool status = directory.getBool(keccak256(abi.encodePacked("quest.reviewStatus")));
        // assertEq(status, true);
        // emit log_uint(reviewerId);
    }

    function mintNft(address account) internal {
        // Mint Alice an NFT to quest
        erc721 = new MockERC721("TEST", "TEST");
        erc721.mint(account, 1);
        assertEq(erc721.balanceOf(account), 1);
    }

    function setupTasks() internal {
        // Prepare data to create new Tasks
        // Task memory task1 = Task({
        //     deadline: 100,
        //     creator: address(arm0ry),
        //     detail: "bafkreib5pjrdtrotqdj46bozovqpjrgqzkvpdbt3mevyntdfydmyvfysza",
        //     completions: 0
        // });
        // Task memory task2 = Task({
        //     deadline: 100,
        //     creator: charlie,
        //     detail: "bafkreib5pjrdtrotqdj46bozovqpjrgqzkvpdbt3mevyntdfydmyvfysza",
        //     completions: 0
        // });
        // Task memory task3 = Task({
        //     deadline: 100,
        //     creator: charlie,
        //     detail: "bafkreib5pjrdtrotqdj46bozovqpjrgqzkvpdbt3mevyntdfydmyvfysza",
        //     completions: 0
        // });
        // Task memory task4 = Task({
        //     deadline: 100,
        //     creator: charlie,
        //     detail: "bafkreib5pjrdtrotqdj46bozovqpjrgqzkvpdbt3mevyntdfydmyvfysza",
        //     completions: 0
        // });

        // tasks.push(task1);
        // tasks.push(task2);
        // tasks.push(task3);
        // tasks.push(task4);

        // Create new Tasks
        vm.prank(address(arm0ry));
        // missions.setTask(0, task1);

        // Validate Task setup
        // task = missions.getTask(1);
        // assertEq(task.creator, address(arm0ry));
        // assertEq(task.deadline, 100);
    }

    function setupMissions() internal {
        // Prepare to create new Mission
        // taskIds.push(1);
        // taskIds.push(2);
        // taskIds.push(3);
        // taskIds.push(4);

        // Create new mission
        // vm.prank(address(arm0ry));
        // missions.setMission(
        //     0,
        //     Mission({
        //         forPurchase: true,
        //         creator: bob,
        //         title: "Welcome to New School",
        //         detail: "bafkreib5pjrdtrotqdj46bozovqpjrgqzkvpdbt3mevyntdfydmyvfysza",
        //         taskIds: taskIds,
        //         completions: 0
        //     })
        // );

        // Validate Mission setup
        // (mission,) = missions.getMission(1);
        // assertEq(missions.getUint(keccak256(abi.encodePacked(address(this), "missionCount"))), 1);
        // assertEq(mission.creator, bob);

        // Validate tasks exist in Mission
        // assertEq(missions.isTaskInMission(1, 1), true);
        // assertEq(missions.isTaskInMission(1, 2), true);
        // assertEq(missions.isTaskInMission(1, 3), true);
        // assertEq(missions.isTaskInMission(1, 4), true);
        // assertEq(missions.isTaskInMission(1, 5), false);
    }

    function setupTasksAndMissions() internal {
        setupTasks();
        setupMissions();
        delete taskIds;
    }
}
