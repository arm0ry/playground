// // SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {Missions, Task, Mission} from "src/Missions.sol";
import {Missions} from "src/Missions.sol";
import {IMissions} from "src/interface/IMissions.sol";
import {Quest} from "src/Quest.sol";
import {IQuest} from "src/interface/IQuest.sol";
import {Storage} from "src/Storage.sol";
import {IStorage} from "src/interface/IStorage.sol";
import {Minter} from "src/Minter.sol";
import {SupportCurveToken} from "src/tokens/SupportCurveToken.sol";
// import {IStorage} from "src/interface/IStorage.sol";

contract SupportCurveTokenTest is Test {
    Quest quest;
    Missions missions;
    Storage stor;
    SupportCurveToken support;

    IQuest iQuest;
    IMissions iMissions;
    IStorage iStorage;

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
        // Deploy contract
        support = new SupportCurveToken(alice);
        // missions = new Missions();
        // missions.initialize((address(arm0ry)));

        // Validate global variables
        // assertEq(missions.royalties(), 0);
        // assertEq(missions_v2.dao(), arm0ry);

        // setupTasksAndMissions();
    }

    function testReceiveETH() public payable {
        (bool sent,) = address(support).call{value: 5 ether}("");
        assert(!sent);
    }
}
