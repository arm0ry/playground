// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {MissionBergerToken} from "src/tokens/MissionBergerToken.sol";
import {MissionSupportToken} from "src/tokens/MissionSupportToken.sol";
import {QuestSupportToken} from "src/tokens/QuestSupportToken.sol";
import {TokenFactory} from "src/TokenFactory.sol";

contract TokenFactoryTest is Test {
    MissionBergerToken mbt;
    MissionSupportToken mst;
    QuestSupportToken qst;
    TokenFactory factory;

    /// @dev Users.
    address public immutable alice = makeAddr("alice");
    address public immutable bob = makeAddr("bob");
    address public immutable charlie = makeAddr("charlie");
    address public immutable dao = makeAddr("dao");

    /// @dev Helpers.
    string testString = "TOKEN";

    /// @notice Set up the testing suite.
    function setUp() public payable {
        // Deploy contracts
        mbt = new MissionBergerToken();
        mst = new MissionSupportToken(dao);
        qst = new QuestSupportToken(dao, dao, dao);
        factory = new TokenFactory();
    }

    function testAddTokens() public payable {
        // Add tokens.
        addToken(address(mbt));
        addToken(address(mst));
        addToken(address(qst));
    }

    function testDeploy() public payable {
        // Deploy tokens.
        deploy(1);
        deploy(2);
        deploy(3);
    }

    function testReceiveETH() public payable {
        (bool sent,) = address(factory).call{value: 5 ether}("");
        assert(!sent);
    }

    /// -----------------------------------------------------------------------
    /// Helper Logic
    /// -----------------------------------------------------------------------

    function addToken(address token) internal {
        uint256 count = factory.count();
        factory.addToken(token, testString);

        ++count;
        assertEq(factory.tokenTemplates(count), token);
        assertEq(factory.tokenTypes(count), testString);
    }

    function deploy(uint256 order) internal {
        address prediction = factory.determineAddress(order);
        assertEq(prediction, factory.deploy(order));
    }
}
