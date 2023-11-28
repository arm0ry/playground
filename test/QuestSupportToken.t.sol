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
import {QuestSupportToken} from "src/tokens/QuestSupportToken.sol";

contract QuestSupportTokenTest is Test {
    Quest quest;
    Mission mission;
    Storage stor;
    QuestSupportToken support;

    IQuest iQuest;
    IStorage iStorage;

    uint256[] taskIds;
    uint256[] newTaskIds;

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
        support = new QuestSupportToken(alice, alice, alice);
    }

    function testReceiveETH() public payable {
        (bool sent,) = address(support).call{value: 5 ether}("");
        assert(!sent);
    }
}
