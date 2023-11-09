// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {Quest} from "src/Quest.sol";
import {QuestFactory} from "src/QuestFactory.sol";

contract QuestFactoryTest is Test {
    Quest quest;
    QuestFactory factory;

    /// @dev Users.
    address payable public dao = payable(makeAddr("dao"));

    /// @notice Set up the testing suite.
    function setUp() public payable {
        // Deploy contracts
        quest = new Quest();
        factory = new QuestFactory(address(quest));
    }

    function testDeploy() public payable {
        address prediction = factory.determineAddress(dao);
        assertEq(prediction, factory.deployQuest(dao));
    }

    function testReceiveETH() public payable {
        (bool sent,) = address(factory).call{value: 5 ether}("");
        assert(!sent);
    }
}
