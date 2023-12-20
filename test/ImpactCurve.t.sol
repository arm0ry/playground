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
        mst = new mSupportToken();

        initializeIC(user);
    }

    /// -----------------------------------------------------------------------
    /// Linear Test
    /// -----------------------------------------------------------------------

    function testLinearCurve() public payable {
        initializeQst();

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

    function testLinearCurve_mint() public payable {
        // Set up.
        testLinearCurve();

        // Retrieve for validation.
        uint256 mintPrice = ic.getPrice(true, 1, 0);
        uint256 burnPrice = ic.getPrice(false, 1, 0);

        // Deal.
        vm.deal(bob, 10 ether);

        // Support.
        vm.prank(bob);
        ic.support{value: ic.getPrice(true, 1, 0)}(1, bob, ic.getPrice(true, 1, 0));

        // Validate.
        assertEq(qst.balanceOf(bob), 1);
        assertEq(qst.totalSupply(), 1);
        assertEq(ic.getUnclaimed(ic.getCurveOwner(ic.getCurveId())), mintPrice - burnPrice);
        assertEq(ic.getCurvePool(1), burnPrice);
        assertEq(ic.getPrice(true, 1, 1000) - ic.getPrice(false, 1, 1000), ic.getMintBurnDifference(1, 1000));
    }

    function testLinearCurve_burn() public payable {
        // Set up.
        testLinearCurve_mint();

        // Retrieve for validation.
        uint256 burnPrice = ic.getPrice(false, 1, 0);
        bool burned = ic.getCurveBurned(1, bob);

        // Burn.
        vm.prank(bob);
        ic.burn(1, bob, 1);

        // Validate.
        assertEq(qst.balanceOf(bob), 0);
        assertEq(qst.totalSupply(), 0);
        assertEq(ic.getCurvePool(1), 0);
        assertEq(ic.getCurveBurned(1, bob), true);
        assertEq(!burned, true);
    }

    function testLinearCurve_claim() public payable {
        // Set up.
        testLinearCurve_burn();

        // Retrieve for validation.
        uint256 prevUnclaimed = ic.getUnclaimed(alice);
        uint256 prevBalance = address(alice).balance;

        // Claim.
        vm.prank(alice);
        ic.claim();

        // Validate.
        assertEq(ic.getUnclaimed(alice), 0);
        assertEq(prevBalance + prevUnclaimed, address(alice).balance);
    }

    function testLinearCurve_claim_NotAuthorized() public payable {
        // Set up.
        testLinearCurve_burn();

        // Claim.
        vm.expectRevert(ImpactCurve.NotAuthorized.selector);
        vm.prank(bob);
        ic.claim();
    }

    function testLinearCurve_zeroClaim() public payable {
        // Set up.
        testLinearCurve_burn();

        // Retrieve for validation.
        uint256 prevPool = ic.getCurvePool(1);
        uint256 prevBalance = address(alice).balance;

        // Claim.
        vm.prank(alice);
        ic.zeroClaim(1);

        // Validate.
        // assertEq(ic.getUnclaimed(alice), 0);
        assertEq(prevBalance + prevPool, address(alice).balance);
    }

    function testLinearCurve_testClaim_NotAuthorized() public payable {
        // Set up.
        testLinearCurve_burn();

        // Claim.
        vm.expectRevert(ImpactCurve.NotAuthorized.selector);
        vm.prank(bob);
        ic.zeroClaim(1);
    }

    /// -----------------------------------------------------------------------
    /// Poly Test
    /// -----------------------------------------------------------------------

    function testPolyCurve() public payable {
        initializeQst();

        setupCurve(
            CurveType.POLY,
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

    function testPolyCurve_mint() public payable {
        testPolyCurve();

        uint256 mintPrice = ic.getPrice(true, 1, 0);
        uint256 burnPrice = ic.getPrice(false, 1, 0);

        vm.deal(bob, 10 ether);
        vm.prank(bob);
        ic.support{value: mintPrice}(1, bob, mintPrice);
        uint256 postBalance = address(bob).balance;

        assertEq(qst.balanceOf(bob), 1);
        assertEq(qst.totalSupply(), 1);
        assertEq(ic.getUnclaimed(alice), mintPrice - burnPrice);
        assertEq(ic.getCurvePool(1), burnPrice);
    }

    function testPolyCurve_burn() public payable {
        // Set up.
        testPolyCurve_mint();

        // Retrieve for validation.
        uint256 burnPrice = ic.getPrice(false, 1, 0);

        // Burn.
        vm.prank(bob);
        ic.burn(1, bob, 1);

        // Validation.
        assertEq(qst.balanceOf(bob), 0);
        assertEq(qst.totalSupply(), 0);
        assertEq(ic.getCurvePool(1), 0);
    }

    /// -----------------------------------------------------------------------
    /// Other Functions
    /// -----------------------------------------------------------------------

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

    function initializeQst() internal {
        qst = new qSupportToken();
        qst.init("User Support Token", "UST", user, user, user, 1, address(ic), 1);
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
        ic.curve(curveType, supportToken, _user, scale, mint_a, mint_b, mint_c, burn_a, burn_b, burn_c);

        // Validate.
        uint256 curveId = ic.getCurveId();
        assertEq(uint256(ic.getCurveType(curveId)), uint256(curveType));
        assertEq(ic.getCurveOwner(curveId), _user);
        assertEq(ic.getCurveToken(curveId), supportToken);
        (
            uint256 _scale,
            uint256 _mint_a,
            uint256 _mint_b,
            uint256 _mint_c,
            uint256 _burn_a,
            uint256 _burn_b,
            uint256 _burn_c
        ) = ic.getCurveFormula(curveId);
        assertEq(scale, _scale);
        assertEq(mint_a, _mint_a);
        assertEq(mint_b, _mint_b);
        assertEq(mint_c, _mint_c);
        assertEq(burn_a, _burn_a);
        assertEq(burn_b, _burn_b);
        assertEq(burn_c, _burn_c);

        assertEq(ic.getPrice(true, 1, 500) - ic.getPrice(false, 1, 500), ic.getMintBurnDifference(1, 500));
        assertEq(ic.getPrice(true, 1, 1000) - ic.getPrice(false, 1, 1000), ic.getMintBurnDifference(1, 1000));

        // TODO: Below stack too deep
        // if (curveType == CurveType.LINEAR) {
        //     assertEq(ic.getPrice(true, 1, 500), ic.calculatePrice(501, _scale, 0, mint_b, mint_c));
        //     assertEq(ic.getPrice(false, 1, 500), ic.calculatePrice(500, _scale, 0, burn_b, burn_c));
        // } else {
        //     assertEq(ic.getPrice(true, 1, 500), ic.calculatePrice(501, _scale, mint_a, mint_b, mint_c));
        //     assertEq(ic.getPrice(false, 1, 500), ic.calculatePrice(500, _scale, burn_a, burn_b, burn_c));
        // }
    }
}
