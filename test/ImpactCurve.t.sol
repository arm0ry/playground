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
    }

    function testNotInitialize_curve() public payable {
        initializeIC(address(0));

        vm.expectRevert(ImpactCurve.NotInitialized.selector);
        vm.prank(bob);
        ic.curve(
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

    function testNotInitialize_support() public payable {
        initializeIC(address(0));

        vm.expectRevert(ImpactCurve.NotInitialized.selector);
        vm.prank(bob);
        ic.support(1, bob, 1 ether);
    }

    function testZeroCurve() public payable {
        initializeIC(user);
        initializeQst(user);

        uint256 id = setupCurve(
            CurveType.NA,
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
        validateCurve(id, ic.getCurveType(id));
    }

    /// -----------------------------------------------------------------------
    /// Linear Test
    /// -----------------------------------------------------------------------

    function testLinearCurve() public payable {
        initializeIC(user);
        initializeQst(user);

        uint256 id = setupCurve(
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
        validateCurve(id, ic.getCurveType(id));
    }

    function testLinearCurve_InvalidCurve(
        uint32 mint_a,
        uint32 mint_b,
        uint32 mint_c,
        uint32 burn_a,
        uint32 burn_b,
        uint32 burn_c
    ) public payable {
        vm.assume(burn_a > mint_a || burn_b > mint_b || burn_c > mint_c);
        // vm.assume(burn_b > mint_b);
        // vm.assume(burn_c > mint_c);
        initializeIC(user);
        initializeQst(user);

        vm.expectRevert(ImpactCurve.InvalidCurve.selector);
        uint256 id = ic.curve(
            CurveType.LINEAR, address(qst), alice, uint64(0.0001 ether), mint_a, mint_b, mint_c, burn_a, burn_b, burn_c
        );
    }

    function testLinearCurve_NotAuthorized() public payable {
        initializeIC(user);
        initializeQst(user);

        vm.expectRevert(ImpactCurve.NotAuthorized.selector);
        vm.prank(alice);
        ic.curve(
            CurveType.LINEAR,
            address(qst),
            address(0),
            uint64(0.0001 ether),
            uint32(2),
            uint32(2),
            uint32(2),
            uint32(1),
            uint32(1),
            uint32(1)
        );
    }

    function testLinearCurve_support() public payable {
        // Set up.
        testLinearCurve();

        // Retrieve for validation.
        uint256 mintPrice = ic.getPrice(true, 1, 0);

        // Deal.
        vm.deal(bob, 10 ether);

        // Support.
        vm.prank(bob);
        ic.support{value: ic.getPrice(true, 1, 0)}(1, bob, ic.getPrice(true, 1, 0));

        uint256 burnPrice = ic.getPrice(false, 1, 0);

        // Validate.
        assertEq(qst.balanceOf(bob), 1);
        assertEq(qst.totalSupply(), 1);
        assertEq(ic.getUnclaimed(ic.getCurveOwner(ic.getCurveId())), mintPrice - burnPrice);
        assertEq(ic.getCurvePool(1), burnPrice);
        assertEq(ic.getPrice(true, 1, 1000) - ic.getPrice(false, 1, 1000), ic.getMintBurnDifference(1, 1000));
    }

    function testLinearCurve_support_NotAuthorized() public payable {
        // Set up.
        testLinearCurve_support();

        // Retrieve for validation.
        uint256 mintPrice = ic.getPrice(true, 1, 0);

        // Deal.
        vm.deal(alice, 10 ether);

        // Support.
        vm.expectRevert(ImpactCurve.NotAuthorized.selector);
        vm.prank(alice);
        ic.support{value: mintPrice}(1, alice, mintPrice);
    }

    function testLinearCurve_support_InvalidCurve() public payable {
        testLinearCurve_support();

        vm.expectRevert(ImpactCurve.InvalidCurve.selector);
        vm.prank(alice);
        ic.curve(
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

    function testLinearCurve_support_InvalidAmount_InvalidMsgValue() public payable {
        // Set up.
        testLinearCurve();

        // Retrieve for validation.
        uint256 mintPrice = ic.getPrice(true, 1, 0);

        // Deal.
        vm.deal(bob, 10 ether);

        // Support.
        vm.expectRevert(ImpactCurve.InvalidAmount.selector);
        vm.prank(bob);
        ic.support{value: 1 ether}(1, bob, mintPrice);
    }

    function testLinearCurve_support_InvalidAmount_InvalidParam() public payable {
        // Set up.
        testLinearCurve();

        // Retrieve for validation.
        uint256 mintPrice = ic.getPrice(true, 1, 0);

        // Deal.
        vm.deal(bob, 10 ether);

        // Support.
        vm.expectRevert(ImpactCurve.InvalidAmount.selector);
        vm.prank(bob);
        ic.support{value: mintPrice}(1, bob, 1 ether);
    }

    function testLinearCurve_burn() public payable {
        // Set up.
        testLinearCurve_support();

        // Retrieve for validation.
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

    function testLinearCurve_burn_NotAuthorized() public payable {
        // Set up.
        testLinearCurve_support();

        // Burn.
        vm.expectRevert(ImpactCurve.NotAuthorized.selector);
        vm.prank(charlie);
        ic.burn(1, charlie, 1);
    }

    function testLinearCurve_burn_AlreadyBurned() public payable {
        // Set up.
        testLinearCurve_support();

        uint256 mintPrice = ic.getPrice(true, 1, 0);

        // Support once more.
        vm.prank(bob);
        ic.support{value: mintPrice}(1, bob, mintPrice);

        emit log_uint(qst.balanceOf(bob));

        // First burn.
        vm.prank(bob);
        ic.burn(1, bob, 2);

        emit log_uint(qst.balanceOf(bob));

        // Second burn.
        vm.expectRevert(ImpactCurve.NotAuthorized.selector);
        vm.prank(bob);
        ic.burn(1, bob, 1);

        emit log_uint(qst.balanceOf(bob));
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
        testLinearCurve_support();

        // Support once more.
        uint256 mintPrice = ic.getPrice(true, 1, 0);
        vm.prank(bob);
        ic.support{value: mintPrice}(1, bob, mintPrice);

        // Support once more.
        mintPrice = ic.getPrice(true, 1, 0);
        vm.prank(bob);
        ic.support{value: mintPrice}(1, bob, mintPrice);

        // Support once more.
        mintPrice = ic.getPrice(true, 1, 0);
        vm.prank(bob);
        ic.support{value: mintPrice}(1, bob, mintPrice);

        emit log_uint(qst.balanceOf(bob));

        // First burn.
        vm.prank(bob);
        ic.burn(1, bob, 4);
        vm.prank(bob);
        qst.burn(3);
        vm.prank(bob);
        qst.burn(2);
        vm.prank(bob);
        qst.burn(1);

        // Retrieve for validation.
        uint256 prevPool = ic.getCurvePool(1);
        uint256 prevBalance = address(alice).balance;

        emit log_uint(prevPool);
        emit log_uint(prevBalance);
        emit log_uint(qst.balanceOf(bob));

        // Claim.
        vm.prank(alice);
        ic.zeroClaim(1);

        // Validate.
        assertEq(prevBalance + prevPool, address(alice).balance);
    }

    function testLinearCurve_zeroClaim_branch() public payable {
        // Set up.
        testLinearCurve_support();

        // Support once more.
        uint256 mintPrice = ic.getPrice(true, 1, 0);
        vm.prank(bob);
        ic.support{value: mintPrice}(1, bob, mintPrice);

        // Support once more.
        mintPrice = ic.getPrice(true, 1, 0);
        vm.prank(bob);
        ic.support{value: mintPrice}(1, bob, mintPrice);

        // Support once more.
        mintPrice = ic.getPrice(true, 1, 0);
        vm.prank(bob);
        ic.support{value: mintPrice}(1, bob, mintPrice);

        emit log_uint(qst.balanceOf(bob));

        // First burn.
        vm.prank(bob);
        ic.burn(1, bob, 4);
        vm.prank(bob);
        qst.burn(3);
        vm.prank(bob);
        qst.burn(2);

        // Retrieve for validation.
        uint256 prevPool = ic.getCurvePool(1);
        uint256 prevBalance = address(alice).balance;

        emit log_uint(prevPool);
        emit log_uint(prevBalance);
        emit log_uint(qst.balanceOf(bob));

        // Claim.
        vm.expectRevert(ImpactCurve.NotAuthorized.selector);
        vm.prank(alice);
        ic.zeroClaim(1);
    }

    function testLinearCurve_zeroClaim_NotAuthorized() public payable {
        // Set up.
        testLinearCurve_support();

        vm.expectRevert(ImpactCurve.NotAuthorized.selector);
        vm.prank(bob);
        ic.zeroClaim(1);
    }

    /// -----------------------------------------------------------------------
    /// Poly Test
    /// -----------------------------------------------------------------------

    function testPolyCurve() public payable {
        initializeIC(user);
        initializeQst(user);

        uint256 id = setupCurve(
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
        validateCurve(id, ic.getCurveType(id));
    }

    function testPolyCurve_support() public payable {
        testPolyCurve();

        uint256 mintPrice = ic.getPrice(true, 1, 0);

        vm.deal(bob, 10 ether);
        vm.prank(bob);
        ic.support{value: mintPrice}(1, bob, mintPrice);

        uint256 burnPrice = ic.getPrice(false, 1, 0);

        assertEq(qst.balanceOf(bob), 1);
        assertEq(qst.totalSupply(), 1);
        assertEq(ic.getUnclaimed(alice), mintPrice - burnPrice);
        assertEq(ic.getCurvePool(1), burnPrice);
    }

    function testPolyCurve_burn() public payable {
        // Set up.
        testPolyCurve_support();

        // Retrieve for validation.
        uint256 burnPrice = ic.getPrice(false, 1, 0);
        uint256 prevBalance = address(bob).balance;
        emit log_uint(prevBalance);

        // Burn.
        vm.prank(bob);
        ic.burn(1, bob, 1);

        // Validation.
        assertEq(qst.balanceOf(bob), 0);
        assertEq(qst.totalSupply(), 0);
        assertEq(ic.getCurvePool(1), 0);
        assertEq(address(bob).balance, prevBalance + burnPrice);
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

    function initializeQst(address _user) internal {
        qst = new qSupportToken();
        qst.init("User Support Token", "UST", _user, _user, _user, 1, address(ic), 1);
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
    ) internal returns (uint256 id) {
        // Set up curve.
        vm.prank(_user);
        id = ic.curve(curveType, supportToken, _user, scale, mint_a, mint_b, mint_c, burn_a, burn_b, burn_c);

        // Validate.
        uint256 curveId = ic.getCurveId();
        assertEq(uint256(ic.getCurveType(curveId)), uint256(curveType));
        assertEq(ic.getCurveOwner(curveId), _user);
        assertEq(ic.getCurveToken(curveId), supportToken);

        // (
        //     uint256 _scale,
        //     uint256 _mint_a,
        //     uint256 _mint_b,
        //     uint256 _mint_c,
        //     uint256 _burn_a,
        //     uint256 _burn_b,
        //     uint256 _burn_c
        // ) = ic.getCurveFormula(curveId);
        // assertEq(scale, _scale);
        // assertEq(mint_a, _mint_a);
        // assertEq(mint_b, _mint_b);
        // assertEq(mint_c, _mint_c);
        // assertEq(burn_a, _burn_a);
        // assertEq(burn_b, _burn_b);
        // assertEq(burn_c, _burn_c);
    }

    function validateCurve(uint256 curveId, CurveType curveType) internal {
        (
            uint256 _scale,
            uint256 _mint_a,
            uint256 _mint_b,
            uint256 _mint_c,
            uint256 _burn_a,
            uint256 _burn_b,
            uint256 _burn_c
        ) = ic.getCurveFormula(curveId);
        checkFormula(curveType, curveId, _scale, _mint_a, _mint_b, _mint_c, _burn_a, _burn_b, _burn_c);
    }

    function checkFormula(
        CurveType curveType,
        uint256 curveId,
        uint256 scale,
        uint256 mint_a,
        uint256 mint_b,
        uint256 mint_c,
        uint256 burn_a,
        uint256 burn_b,
        uint256 burn_c
    ) internal {
        uint256 supply = 500;
        uint256 supply2 = 1000;

        if (curveType == CurveType.LINEAR) {
            // Linear @ supply.
            assertEq(ic.getPrice(true, curveId, supply), ic.calculatePrice(supply + 1, scale, 0, mint_b, mint_c));
            assertEq(ic.getPrice(false, curveId, supply), ic.calculatePrice(supply, scale, 0, burn_b, burn_c));

            // Linear @ supply2.
            assertEq(ic.getPrice(true, curveId, supply2), ic.calculatePrice(supply2 + 1, scale, 0, mint_b, mint_c));
            assertEq(ic.getPrice(false, curveId, supply2), ic.calculatePrice(supply2, scale, 0, burn_b, burn_c));
        } else if (curveType == CurveType.POLY) {
            // Poly @ supply.
            assertEq(ic.getPrice(true, curveId, supply), ic.calculatePrice(supply + 1, scale, mint_a, mint_b, mint_c));
            assertEq(ic.getPrice(false, curveId, supply), ic.calculatePrice(supply, scale, burn_a, burn_b, burn_c));

            // Poly @ supply2.
            assertEq(ic.getPrice(true, curveId, supply2), ic.calculatePrice(supply2 + 1, scale, mint_a, mint_b, mint_c));
            assertEq(ic.getPrice(false, curveId, supply2), ic.calculatePrice(supply2, scale, burn_a, burn_b, burn_c));
        } else {
            assertEq(ic.getPrice(true, curveId, supply), ic.calculatePrice(supply + 1, scale, 0, 0, 0));
            assertEq(ic.getPrice(false, curveId, supply), ic.calculatePrice(supply, scale, 0, 0, 0));

            assertEq(ic.getPrice(true, curveId, supply2), ic.calculatePrice(supply2 + 1, scale, 0, 0, 0));
            assertEq(ic.getPrice(false, curveId, supply2), ic.calculatePrice(supply2, scale, 0, 0, 0));
        }
    }
}
