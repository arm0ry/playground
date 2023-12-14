// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {ImpactCurve, CurveType} from "src/ImpactCurve.sol";
import {MockERC721} from "lib/solbase/test/utils/mocks/MockERC721.sol";

contract QuestSupportTokenTest is Test {
    ImpactCurve ic;
    MockERC721 token;

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
        ic = new ImpactCurve();
        token = new MockERC721(testString, testString);

        setupCurve(
            CurveType.NA, address(token), alice, uint96(0.0001 ether), uint16(10), uint48(2), uint48(2), uint48(2)
        );
    }

    function testMint() public payable {}

    function testReceiveETH() public payable {
        (bool sent,) = address(ic).call{value: 5 ether}("");
        assert(!sent);
    }

    function initializeIC(address _dao) internal {
        ic.initialize(_dao);
    }

    /// @notice Set up a curve.
    function setupCurve(
        CurveType curveType,
        address nft,
        address user,
        uint96 scale,
        uint16 burnRatio,
        uint48 constant_a,
        uint48 constant_b,
        uint48 constant_c
    ) internal {
        // Set up curve.
        vm.prank(user);
        ic.curve(curveType, nft, user, scale, burnRatio, constant_a, constant_b, constant_c);
    }
}
