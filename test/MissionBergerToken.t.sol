// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {Mission} from "src/Mission.sol";
import {IMission} from "src/interface/IMission.sol";
import {Quest} from "src/Quest.sol";
import {IQuest} from "src/interface/IQuest.sol";
import {Storage} from "kali-markets/Storage.sol";
import {IStorage} from "kali-markets/interface/IStorage.sol";
import {MissionBergerToken} from "src/tokens/MissionBergerToken.sol";

contract MissionBergerTokenTest is Test {
    Quest quest;
    Mission mission;
    Storage stor;
    MissionBergerToken mbt;

    IQuest iQuest;
    IStorage iStorage;

    uint256[] taskIds;
    uint256[] newTaskIds;

    // Mission mission;

    uint256 royalties;
    /// @dev Users.

    address public immutable alice = makeAddr("alice");
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
        // Deploy contract
        mbt = new MissionBergerToken(dummy, dummy, "Mission Berger Token", "MBT");
    }

    function testReceiveETH() public payable {
        (bool sent,) = address(mbt).call{value: 5 ether}("");
        assert(!sent);
    }
}
