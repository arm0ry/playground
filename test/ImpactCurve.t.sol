// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {ImpactCurve, CurveType} from "src/ImpactCurve.sol";
import {qSupportToken} from "src/tokens/qSupportToken.sol";
import {mSupportToken} from "src/tokens/mSupportToken.sol";

contract ImpactCurveTest is Test {
    ImpactCurve ic;
    qSupportToken qst;
    mSupportToken mst;

    /// @dev Users.
    address public immutable alice = makeAddr("alice");
    address public immutable bob = makeAddr("bob");
    address public immutable charlie = makeAddr("charlie");
    address public immutable dummy = makeAddr("dummy");
    address payable public immutable user = payable(makeAddr("user"));

    /// @dev Helpers.
    string internal constant testString = "TEST";

    /// -----------------------------------------------------------------------
    /// Setup Test
    /// -----------------------------------------------------------------------

    /// @notice Set up the testing suite.
    function setUp() public payable {
        // Deploy contract.
        ic = new ImpactCurve();
        qst = new qSupportToken();
        qst.init("Support Token", "ST", user, user, user, 1, address(ic), 1);
        mst = new mSupportToken();

        initializeIC(user);
        setupCurve(
            CurveType.LINEAR,
            address(qst),
            alice,
            uint64(0.0001 ether),
            uint32(2),
            uint32(2),
            uint32(2),
            uint32(1),
            uint32(1),
            uint32(1)
        );
    }

    /// -----------------------------------------------------------------------
    /// Setup Test
    /// -----------------------------------------------------------------------

    function testMint() public payable {
        emit log_uint(ic.getPrice(true, 1));

        vm.deal(bob, 10 ether);
        vm.prank(bob);
        ic.support{value: ic.getPrice(true, 1)}(1, bob, ic.getPrice(true, 1));
    }

    function testReceiveETH() public payable {
        (bool sent,) = address(ic).call{value: 5 ether}("");
        assert(sent);
    }

    /// -----------------------------------------------------------------------
    /// Internal Functions
    /// -----------------------------------------------------------------------

    function initializeIC(address _user) internal {
        ic.initialize(_user);
    }

    /// @notice Set up a curve.
    function setupCurve(
        CurveType curveType,
        address supportToken,
        address _user,
        uint64 scale,
        uint32 mint_a,
        uint32 mint_b,
        uint32 mint_c,
        uint32 burn_a,
        uint32 burn_b,
        uint32 burn_c
    ) internal {
        // Set up curve.
        vm.prank(_user);
        ic.curve(curveType, supportToken, _user, scale, mint_a, mint_b, mint_c, mint_a, mint_b, mint_c);
    }
}
