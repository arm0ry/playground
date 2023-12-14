// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {KaliDAOfactory, KaliDAO} from "kali-markets/kalidao/KaliDAOfactory.sol";
import {KaliCurve} from "kali-markets/KaliCurve.sol";
import {IKaliCurve, CurveType} from "kali-markets/interface/IKaliCurve.sol";

import {Mission} from "src/Mission.sol";
import {IMission} from "src/interface/IMission.sol";
import {Quest} from "src/Quest.sol";
import {IQuest} from "src/interface/IQuest.sol";
import {Storage} from "kali-markets/Storage.sol";
import {IStorage} from "kali-markets/interface/IStorage.sol";
import {QuestSupportToken} from "src/tokens/QuestSupportToken.sol";

contract QuestSupportTokenTest is Test {
    Quest quest;
    Mission mission;
    Storage stor;
    QuestSupportToken qst;

    KaliCurve kaliCurve;
    KaliDAO daoTemplate;
    KaliDAOfactory daoFactory;

    IQuest iQuest;
    IStorage iStorage;

    // For mission.
    address[] creators;
    uint256[] deadlines;
    string[] detail;
    uint256[] taskIds;
    uint256[] newTaskIds;

    /// @dev Users.
    address public immutable alice = makeAddr("alice");
    address public immutable bob = makeAddr("bob");
    address public immutable charlie = makeAddr("charlie");
    address public immutable dummy = makeAddr("dummy");
    address payable public immutable arm0ry = payable(makeAddr("arm0ry"));

    /// @dev Helpers.
    string internal constant testString = "TEST";

    /// -----------------------------------------------------------------------
    /// Kali Setup Tests
    /// -----------------------------------------------------------------------

    /// @notice Set up the testing suite.

    function setUp() public payable {
        // Deploy contract
        daoFactory = new KaliDAOfactory(payable(daoTemplate));
        kaliCurve = new KaliCurve();
        kaliCurve.initialize(alice, address(daoFactory));
        setupCurve(CurveType.NA, true, true, alice, uint96(0.0001 ether), uint16(10), uint48(2), uint48(2), uint48(2));

        mission = new Mission();
        mission.initialize(alice);
        setTasks();
        setMission(alice, "First", "Description");

        quest = new Quest();
        quest.initialize(alice);
        start(alice, address(mission), 1);

        qst = new QuestSupportToken(address(quest), address(mission), address(kaliCurve));
    }

    function testMint() public payable {
        uint256 amount = 2;
        uint256 price = IKaliCurve(address(kaliCurve)).getMintBurnDifference(1) * amount;

        vm.deal(bob, 10 ether);
        vm.prank(bob);
        qst.support{value: price}(alice, 1, 1, amount);

        emit log_uint(qst.balanceOf(bob, 1));
    }

    function testReceiveETH() public payable {
        (bool sent,) = address(qst).call{value: 5 ether}("");
        assert(!sent);
    }

    function initializeMission(address _dao) internal {
        mission.initialize(_dao);
    }

    function setTasks() public payable {
        // Set up param.
        creators.push(alice);
        creators.push(bob);
        creators.push(charlie);
        deadlines.push(2);
        deadlines.push(10);
        deadlines.push(100);
        detail.push("TEST 1");
        detail.push("TEST 2");
        detail.push("TEST 3");

        // Set up task.
        vm.prank(alice);
        mission.setTasks(creators, deadlines, detail);
    }

    function setMission(address creator, string memory title, string memory _detail) internal {
        // Prepare tasks to add to a a new mission.
        taskIds.push(1);
        taskIds.push(2);

        // Set up task.
        vm.prank(alice);
        mission.setMission(creator, title, _detail, taskIds);
    }

    /// @notice Set up a curve.
    function setupCurve(
        CurveType curveType,
        bool canMint,
        bool daoTreasury,
        address user,
        uint96 scale,
        uint16 burnRatio,
        uint48 constant_a,
        uint48 constant_b,
        uint48 constant_c
    ) internal {
        // Set up curve.
        vm.prank(user);
        kaliCurve.curve(curveType, canMint, daoTreasury, user, scale, burnRatio, constant_a, constant_b, constant_c);
    }

    function start(address user, address _mission, uint256 _missionId) public payable {
        // Start.
        vm.prank(user);
        quest.start(_mission, _missionId);

        // Validate.
        (address _user, address __mission, uint256 __missionId) = quest.getQuest(quest.getQuestCount());
        assertEq(_user, user);
        assertEq(__mission, _mission);
        assertEq(__missionId, _missionId);
        assertEq(quest.isQuestActive(user, _mission, _missionId), true);
    }
}
