// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {Mission} from "src/Mission.sol";
import {MissionFactory} from "src/MissionFactory.sol";

contract MissionFactoryTest is Test {
    Mission mission;
    MissionFactory factory;

    /// @dev Users.
    address payable public dao = payable(makeAddr("dao"));

    /// @notice Set up the testing suite.
    function setUp() public payable {
        // Deploy contract
        mission = new Mission();
        factory = new MissionFactory(dao);
    }

    function testDeploy() public payable {
        address prediction = factory.determineAddress(dao);
        assertEq(prediction, factory.deployMission(dao));
    }

    function testReceiveETH() public payable {
        (bool sent,) = address(factory).call{value: 5 ether}("");
        assert(!sent);
    }
}
