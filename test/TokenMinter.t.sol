// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {TokenMinter} from "src/tokens/TokenMinter.sol";

contract TokenMinterTest is Test {
    TokenMinter tokenMinter;

    /// @dev Users.
    address public immutable alice = makeAddr("alice");
    address public immutable bob = makeAddr("bob");
    address public immutable charlie = makeAddr("charlie");
    address public immutable dummy = makeAddr("dummy");
    address payable public immutable user = payable(makeAddr("user"));

    /// @dev Helpers.
    string internal constant testString = "TEST";

    /// -----------------------------------------------------------------------
    /// Kali Setup Tests
    /// -----------------------------------------------------------------------

    /// @notice Set up the testing suite.

    function setUp() public payable {
        tokenMinter = new TokenMinter();
    }

    function testMint() public payable {
        // uint256 amount = 2;
        // uint256 price = IKaliCurve(address(kaliCurve)).getMintBurnDifference(1) * amount;

        // vm.deal(bob, 10 ether);
        // vm.prank(bob);
        // tokenMinter.support{value: price}(alice, 1, 1, amount);

        // emit log_uint(tokenMinter.balanceOf(bob, 1));
    }

    function testReceiveETH() public payable {
        (bool sent,) = address(tokenMinter).call{value: 5 ether}("");
        assert(!sent);
    }
}
