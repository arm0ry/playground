// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {ImpactCurve, CurveType} from "src/ImpactCurve.sol";
import {ListToken} from "src/tokens/ListToken.sol";

import {Bulletin} from "src/Bulletin.sol";
import {IBulletin, Item, List} from "src/interface/IBulletin.sol";

contract ImpactCurveTest is Test {
    Bulletin bulletin;
    ImpactCurve ic;
    ListToken listToken;

    /// @dev Users.
    address public immutable alice = makeAddr("alice");
    address public immutable bob = makeAddr("bob");
    address public immutable charlie = makeAddr("charlie");
    address public immutable dummy = makeAddr("dummy");
    address payable public immutable user = payable(makeAddr("user"));

    /// @dev Mock Data.
    uint40 constant PAST = 100000;
    uint40 constant FUTURE = 2527482181;
    string TEST = "TEST";
    bytes constant BYTES = bytes(string("BYTES"));

    Item[] items;
    uint256[] itemIds;
    Item item1 = Item({review: false, expire: PAST, owner: makeAddr("alice"), title: TEST, detail: TEST, schema: BYTES});
    Item item2 = Item({review: false, expire: FUTURE, owner: makeAddr("bob"), title: TEST, detail: TEST, schema: BYTES});
    Item item3 =
        Item({review: false, expire: FUTURE, owner: makeAddr("charlie"), title: TEST, detail: TEST, schema: BYTES});
    Item item4 =
        Item({review: true, expire: PAST, owner: makeAddr("charlie"), title: TEST, detail: TEST, schema: BYTES});
    Item item5 =
        Item({review: true, expire: FUTURE, owner: makeAddr("alice"), title: TEST, detail: TEST, schema: BYTES});
    Item item6 = Item({review: true, expire: FUTURE, owner: makeAddr("bob"), title: TEST, detail: TEST, schema: BYTES});

    /// -----------------------------------------------------------------------
    /// Setup Test
    /// -----------------------------------------------------------------------

    /// @notice Set up the testing suite.
    function setUp() public payable {
        // Deploy contract.
        ic = new ImpactCurve();

        deployBulletin(user);
    }

    function testCurve_InvalidCurve() public payable {
        initializeIC(user);
        deployListToken(user);

        vm.expectRevert(ImpactCurve.InvalidCurve.selector);
        uint256 id = ic.curve(
            CurveType.NA,
            address(listToken),
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
    /// Linear Test
    /// -----------------------------------------------------------------------

    function testLinearCurve(
        uint64 scale,
        uint32 mint_a,
        uint32 mint_b,
        uint32 mint_c,
        uint32 burn_a,
        uint32 burn_b,
        uint32 burn_c
    ) public payable {
        vm.assume(burn_a < mint_a && burn_b < mint_b && burn_c < mint_c);
        vm.assume(scale > 0);

        initializeIC(user);
        deployListToken(user);
        vm.warp(block.timestamp + 100);

        uint256 id = setupCurve(
            CurveType.LINEAR, address(listToken), alice, scale, mint_a, mint_b, mint_c, burn_a, burn_b, burn_c
        );
        validateCurve(id, ic.getCurveType(id));
    }

    function testLinearCurve_InvalidCurve(
        uint64 scale,
        uint32 mint_a,
        uint32 mint_b,
        uint32 mint_c,
        uint32 burn_a,
        uint32 burn_b,
        uint32 burn_c
    ) public payable {
        vm.assume(burn_a > mint_a && burn_b > mint_b && burn_c > mint_c);
        initializeIC(user);
        deployListToken(user);
        vm.warp(block.timestamp + 100);

        vm.expectRevert(ImpactCurve.InvalidCurve.selector);
        uint256 id =
            ic.curve(CurveType.LINEAR, address(listToken), alice, scale, mint_a, mint_b, mint_c, burn_a, burn_b, burn_c);
    }

    function testLinearCurve_NotAuthorized() public payable {
        initializeIC(user);
        deployListToken(user);
        vm.warp(block.timestamp + 100);

        vm.expectRevert(ImpactCurve.NotAuthorized.selector);
        vm.prank(alice);
        ic.curve(
            CurveType.LINEAR,
            address(listToken),
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

    function testLinearCurve_support(
        uint64 scale,
        uint32 mint_a,
        uint32 mint_b,
        uint32 mint_c,
        uint32 burn_a,
        uint32 burn_b,
        uint32 burn_c
    ) public payable {
        vm.assume(scale > 0);

        // Set up list.
        registerList_ReviewNotRequired();

        // Set up curve.
        testLinearCurve(scale, mint_a, mint_b, mint_c, burn_a, burn_b, burn_c);
        vm.warp(block.timestamp + 100);

        // Retrieve for validation.
        uint256 mintPrice = ic.getCurvePrice(true, 1, 0);

        // Deal.
        vm.deal(bob, 10000000000000 ether);

        // Support.
        vm.prank(bob);
        ic.support{value: mintPrice}(1, bob, mintPrice);

        uint256 burnPrice = ic.getCurvePrice(false, 1, 0);

        // Validate.
        assertEq(listToken.balanceOf(bob), 1);
        assertEq(listToken.totalSupply(), 1);
        assertEq(ic.getUnclaimed(ic.getCurveOwner(ic.getCurveId())), mintPrice - burnPrice);
        assertEq(ic.getCurveTreasury(1), burnPrice);
        assertEq(ic.getCurvePrice(true, 1, 1000) - ic.getCurvePrice(false, 1, 1000), ic.getMintBurnDifference(1, 1000));

        vm.prank(bob);
        listToken.updateInputs(1, 1, 1);
        emit log_string(listToken.generateSvg(1));
    }

    function testLinearCurve_support_InvalidCurve(
        uint64 scale,
        uint32 mint_a,
        uint32 mint_b,
        uint32 mint_c,
        uint32 burn_a,
        uint32 burn_b,
        uint32 burn_c
    ) public payable {
        testLinearCurve_support(scale, mint_a, mint_b, mint_c, burn_a, burn_b, burn_c);

        vm.expectRevert(ImpactCurve.InvalidCurve.selector);
        vm.prank(alice);
        ic.curve(
            CurveType.LINEAR,
            address(listToken),
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

    function testLinearCurve_support_InvalidAmount_InvalidMsgValue(
        uint64 scale,
        uint32 mint_a,
        uint32 mint_b,
        uint32 mint_c,
        uint32 burn_a,
        uint32 burn_b,
        uint32 burn_c
    ) public payable {
        // Set up.
        testLinearCurve(scale, mint_a, mint_b, mint_c, burn_a, burn_b, burn_c);

        // Retrieve for validation.
        uint256 mintPrice = ic.getCurvePrice(true, 1, 0);

        // Deal.
        vm.deal(bob, 10000000000000 ether);

        // Support.
        vm.expectRevert(ImpactCurve.InvalidAmount.selector);
        vm.prank(bob);
        ic.support{value: 1 ether}(1, bob, mintPrice);
    }

    function testLinearCurve_support_InvalidAmount_InvalidParam(
        uint64 scale,
        uint32 mint_a,
        uint32 mint_b,
        uint32 mint_c,
        uint32 burn_a,
        uint32 burn_b,
        uint32 burn_c
    ) public payable {
        // Set up.
        testLinearCurve(scale, mint_a, mint_b, mint_c, burn_a, burn_b, burn_c);

        // Retrieve for validation.
        uint256 mintPrice = ic.getCurvePrice(true, 1, 0);

        // Deal.
        vm.deal(bob, 10000000000000 ether);

        // Support.
        vm.expectRevert(ImpactCurve.InvalidAmount.selector);
        vm.prank(bob);
        ic.support{value: mintPrice}(1, bob, 1 ether);
    }

    function testLinearCurve_burn(
        uint64 scale,
        uint32 mint_a,
        uint32 mint_b,
        uint32 mint_c,
        uint32 burn_a,
        uint32 burn_b,
        uint32 burn_c
    ) public payable {
        vm.assume(scale > 0);

        // Set up.
        testLinearCurve_support(scale, mint_a, mint_b, mint_c, burn_a, burn_b, burn_c);

        // Retrieve for validation.
        bool burned = ic.getCurveBurned(1, bob);

        // Burn.
        vm.prank(bob);
        ic.burn(1, bob, 1);

        // Validate.
        assertEq(listToken.balanceOf(bob), 0);
        assertEq(listToken.totalSupply(), 0);
        assertEq(ic.getCurveTreasury(1), 0);
        assertEq(ic.getCurveBurned(1, bob), true);
        assertEq(!burned, true);
    }

    function testLinearCurve_burn_NotAuthorized(
        uint64 scale,
        uint32 mint_a,
        uint32 mint_b,
        uint32 mint_c,
        uint32 burn_a,
        uint32 burn_b,
        uint32 burn_c
    ) public payable {
        // Set up.
        testLinearCurve_support(scale, mint_a, mint_b, mint_c, burn_a, burn_b, burn_c);

        // Burn.
        vm.expectRevert(ImpactCurve.NotAuthorized.selector);
        vm.prank(charlie);
        ic.burn(1, charlie, 1);
    }

    function testLinearCurve_burn_AlreadyBurned(
        uint64 scale,
        uint32 mint_a,
        uint32 mint_b,
        uint32 mint_c,
        uint32 burn_a,
        uint32 burn_b,
        uint32 burn_c
    ) public payable {
        // Set up.
        testLinearCurve_support(scale, mint_a, mint_b, mint_c, burn_a, burn_b, burn_c);

        uint256 mintPrice = ic.getCurvePrice(true, 1, 0);

        // Support once more.
        vm.prank(bob);
        ic.support{value: mintPrice}(1, bob, mintPrice);

        emit log_uint(listToken.balanceOf(bob));

        // First burn.
        vm.prank(bob);
        ic.burn(1, bob, 2);

        emit log_uint(listToken.balanceOf(bob));

        // Second burn.
        vm.expectRevert(ImpactCurve.NotAuthorized.selector);
        vm.prank(bob);
        ic.burn(1, bob, 1);

        emit log_uint(listToken.balanceOf(bob));
    }

    function testLinearCurve_claim(
        uint64 scale,
        uint32 mint_a,
        uint32 mint_b,
        uint32 mint_c,
        uint32 burn_a,
        uint32 burn_b,
        uint32 burn_c
    ) public payable {
        vm.assume(scale > 0);

        // Set up.
        testLinearCurve_burn(scale, mint_a, mint_b, mint_c, burn_a, burn_b, burn_c);
        vm.warp(block.timestamp + 100);

        // Retrieve for validation.
        uint256 mintPrice = ic.getCurvePrice(true, 1, 0);

        vm.prank(bob);
        ic.support{value: mintPrice}(1, bob, mintPrice);
        vm.warp(block.timestamp + 100);

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

    // function testLinearCurve_claim_NotAuthorized_nothingToWithdraw(
    //     uint64 scale,
    //     uint32 mint_a,
    //     uint32 mint_b,
    //     uint32 mint_c,
    //     uint32 burn_a,
    //     uint32 burn_b,
    //     uint32 burn_c
    // ) public payable {
    //     // Set up.
    //     testLinearCurve_burn(scale, mint_a, mint_b, mint_c, burn_a, burn_b, burn_c);

    //     // Claim.
    //     vm.expectRevert(ImpactCurve.NotAuthorized.selector);
    //     vm.prank(alice);
    //     ic.claim();
    // }

    function testLinearCurve_claim_NotAuthorized_notOwner(
        uint64 scale,
        uint32 mint_a,
        uint32 mint_b,
        uint32 mint_c,
        uint32 burn_a,
        uint32 burn_b,
        uint32 burn_c
    ) public payable {
        // Set up.
        testLinearCurve_burn(scale, mint_a, mint_b, mint_c, burn_a, burn_b, burn_c);
        vm.warp(block.timestamp + 100);

        // Claim.
        vm.expectRevert(ImpactCurve.NotAuthorized.selector);
        vm.prank(bob);
        ic.claim();
    }

    function testLinearCurve_zeroClaim2(
        uint64 scale,
        uint32 mint_a,
        uint32 mint_b,
        uint32 mint_c,
        uint32 burn_a,
        uint32 burn_b,
        uint32 burn_c
    ) public payable {
        vm.assume(scale > 0);
        vm.assume(burn_a > 0 && burn_b > 0 && burn_c > 0);

        // Set up.
        testLinearCurve_support(scale, mint_a, mint_b, mint_c, burn_a, burn_b, burn_c);
        vm.warp(block.timestamp + 100);

        // Support once more.
        uint256 mintPrice = ic.getCurvePrice(true, 1, 0);
        vm.prank(bob);
        ic.support{value: mintPrice}(1, bob, mintPrice);

        // Support once more.
        mintPrice = ic.getCurvePrice(true, 1, 0);
        vm.prank(bob);
        ic.support{value: mintPrice}(1, bob, mintPrice);

        // Support once more.
        mintPrice = ic.getCurvePrice(true, 1, 0);
        vm.prank(bob);
        ic.support{value: mintPrice}(1, bob, mintPrice);

        // First burn.
        vm.prank(bob);
        ic.burn(1, bob, 4);
        vm.prank(bob);
        listToken.burn(3);
        vm.prank(bob);
        listToken.burn(2);
        vm.prank(bob);
        listToken.burn(1);

        // Retrieve for validation.
        uint256 prevPool = ic.getCurveTreasury(1);
        uint256 prevBalance = address(alice).balance;

        // Claim.
        vm.prank(alice);
        ic.zeroClaim(1);

        // Validate.
        assertEq(prevBalance + prevPool, address(alice).balance);
        emit log_uint(address(alice).balance);
    }

    function testLinearCurve_zeroClaim_zeroBurn(uint64 scale, uint32 mint_a, uint32 mint_b, uint32 mint_c)
        public
        payable
    {
        vm.assume(scale > 0);

        // Set up.
        testLinearCurve_support(scale, mint_a, mint_b, mint_c, 0, 0, 0);
        vm.warp(block.timestamp + 100);

        // Support once more.
        uint256 mintPrice = ic.getCurvePrice(true, 1, 0);
        vm.prank(bob);
        ic.support{value: mintPrice}(1, bob, mintPrice);

        // Impact burn.
        vm.prank(bob);
        ic.burn(1, bob, 2);

        // Token burn.
        vm.prank(bob);
        listToken.burn(1);

        // Claim.
        vm.expectRevert(ImpactCurve.NotAuthorized.selector);
        vm.prank(alice);
        ic.zeroClaim(1);
    }

    function testLinearCurve_zeroClaim_NotAuthorized_nonzeroSupply(
        uint64 scale,
        uint32 mint_a,
        uint32 mint_b,
        uint32 mint_c,
        uint32 burn_a,
        uint32 burn_b,
        uint32 burn_c
    ) public payable {
        vm.assume(scale > 0);

        // Set up.
        testLinearCurve_support(scale, mint_a, mint_b, mint_c, burn_a, burn_b, burn_c);

        // Support once more.
        uint256 mintPrice = ic.getCurvePrice(true, 1, 0);
        vm.prank(bob);
        ic.support{value: mintPrice}(1, bob, mintPrice);

        // Support once more.
        mintPrice = ic.getCurvePrice(true, 1, 0);
        vm.prank(bob);
        ic.support{value: mintPrice}(1, bob, mintPrice);

        // Support once more.
        mintPrice = ic.getCurvePrice(true, 1, 0);
        vm.prank(bob);
        ic.support{value: mintPrice}(1, bob, mintPrice);

        // First burn.
        vm.prank(bob);
        ic.burn(1, bob, 4);
        vm.prank(bob);
        listToken.burn(3);
        vm.prank(bob);
        listToken.burn(2);

        // Retrieve for validation.
        uint256 prevPool = ic.getCurveTreasury(1);
        uint256 prevBalance = address(alice).balance;

        // Claim.
        vm.expectRevert(ImpactCurve.NotAuthorized.selector);
        vm.prank(alice);
        ic.zeroClaim(1);
    }

    function testLinearCurve_zeroClaim_NotAuthorized_notOwner(
        uint64 scale,
        uint32 mint_a,
        uint32 mint_b,
        uint32 mint_c,
        uint32 burn_a,
        uint32 burn_b,
        uint32 burn_c
    ) public payable {
        vm.assume(scale > 0);

        // Set up.
        testLinearCurve_support(scale, mint_a, mint_b, mint_c, burn_a, burn_b, burn_c);

        vm.expectRevert(ImpactCurve.NotAuthorized.selector);
        vm.prank(bob);
        ic.zeroClaim(1);
    }

    /// -----------------------------------------------------------------------
    /// Poly Test
    /// -----------------------------------------------------------------------

    function testPolyCurve(
        uint64 scale,
        uint32 mint_a,
        uint32 mint_b,
        uint32 mint_c,
        uint32 burn_a,
        uint32 burn_b,
        uint32 burn_c
    ) public payable {
        vm.assume(scale > 0);
        vm.assume(burn_a < mint_a && burn_b < mint_b && burn_c < mint_c);

        initializeIC(user);
        deployListToken(user);

        uint256 id = setupCurve(
            CurveType.QUADRATIC, address(listToken), alice, scale, mint_a, mint_b, mint_c, burn_a, burn_b, burn_c
        );
        validateCurve(id, ic.getCurveType(id));
    }

    function testPolyCurve_InvalidCurve(
        uint64 scale,
        uint32 mint_a,
        uint32 mint_b,
        uint32 mint_c,
        uint32 burn_a,
        uint32 burn_b,
        uint32 burn_c
    ) public payable {
        vm.assume(burn_a > mint_a || burn_b > mint_b || burn_c > mint_c);
        initializeIC(user);
        deployListToken(user);

        vm.expectRevert(ImpactCurve.InvalidCurve.selector);
        uint256 id = ic.curve(
            CurveType.QUADRATIC, address(listToken), alice, scale, mint_a, mint_b, mint_c, burn_a, burn_b, burn_c
        );
    }

    function testPolyCurve_support(
        uint64 scale,
        uint32 mint_a,
        uint32 mint_b,
        uint32 mint_c,
        uint32 burn_a,
        uint32 burn_b,
        uint32 burn_c
    ) public payable {
        vm.assume(scale > 0);
        testPolyCurve(scale, mint_a, mint_b, mint_c, burn_a, burn_b, burn_c);

        uint256 mintPrice = ic.getCurvePrice(true, 1, 0);

        vm.deal(bob, 1000000000000000000 ether);
        vm.prank(bob);
        ic.support{value: mintPrice}(1, bob, mintPrice);

        uint256 burnPrice = ic.getCurvePrice(false, 1, 0);

        assertEq(listToken.balanceOf(bob), 1);
        assertEq(listToken.totalSupply(), 1);
        assertEq(ic.getUnclaimed(alice), mintPrice - burnPrice);
        assertEq(ic.getCurveTreasury(1), burnPrice);
    }

    function testPolyCurve_burn(
        uint64 scale,
        uint32 mint_a,
        uint32 mint_b,
        uint32 mint_c,
        uint32 burn_a,
        uint32 burn_b,
        uint32 burn_c
    ) public payable {
        vm.assume(scale > 0);

        // Set up.
        testPolyCurve_support(scale, mint_a, mint_b, mint_c, burn_a, burn_b, burn_c);

        // Retrieve for validation.
        uint256 burnPrice = ic.getCurvePrice(false, 1, 0);
        uint256 prevBalance = address(bob).balance;
        emit log_uint(prevBalance);

        // Burn.
        vm.prank(bob);
        ic.burn(1, bob, 1);

        // Validation.
        assertEq(listToken.balanceOf(bob), 0);
        assertEq(listToken.totalSupply(), 0);
        assertEq(ic.getCurveTreasury(1), 0);
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

    function deployListToken(address _user) internal {
        listToken = new ListToken("User Support Token", "UST", address(bulletin), address(ic));
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
            assertEq(ic.getCurvePrice(true, curveId, supply), ic.calculatePrice(supply + 1, scale, 0, mint_b, mint_c));
            assertEq(ic.getCurvePrice(false, curveId, supply), ic.calculatePrice(supply, scale, 0, burn_b, burn_c));

            // Linear @ supply2.
            assertEq(ic.getCurvePrice(true, curveId, supply2), ic.calculatePrice(supply2 + 1, scale, 0, mint_b, mint_c));
            assertEq(ic.getCurvePrice(false, curveId, supply2), ic.calculatePrice(supply2, scale, 0, burn_b, burn_c));
        } else if (curveType == CurveType.QUADRATIC) {
            // Poly @ supply.
            assertEq(
                ic.getCurvePrice(true, curveId, supply), ic.calculatePrice(supply + 1, scale, mint_a, mint_b, mint_c)
            );
            assertEq(ic.getCurvePrice(false, curveId, supply), ic.calculatePrice(supply, scale, burn_a, burn_b, burn_c));

            // Poly @ supply2.
            assertEq(
                ic.getCurvePrice(true, curveId, supply2), ic.calculatePrice(supply2 + 1, scale, mint_a, mint_b, mint_c)
            );
            assertEq(
                ic.getCurvePrice(false, curveId, supply2), ic.calculatePrice(supply2, scale, burn_a, burn_b, burn_c)
            );
        } else {
            assertEq(ic.getCurvePrice(true, curveId, supply), ic.calculatePrice(supply + 1, scale, 0, 0, 0));
            assertEq(ic.getCurvePrice(false, curveId, supply), ic.calculatePrice(supply, scale, 0, 0, 0));

            assertEq(ic.getCurvePrice(true, curveId, supply2), ic.calculatePrice(supply2 + 1, scale, 0, 0, 0));
            assertEq(ic.getCurvePrice(false, curveId, supply2), ic.calculatePrice(supply2, scale, 0, 0, 0));
        }
    }

    /// -----------------------------------------------------------------------
    /// Bulletin Functions
    /// -----------------------------------------------------------------------

    function deployBulletin(address _user) public payable {
        bulletin = new Bulletin();
        bulletin.initialize(_user);
        assertEq(bulletin.owner(), _user);
    }

    function registerItems() internal {
        Item memory _item;

        items.push(item1);
        items.push(item2);
        items.push(item3);
        items.push(item4);
        items.push(item5);
        items.push(item6);

        bulletin.registerItems(items);

        uint256 _id = bulletin.itemId();
        for (uint256 i; i < _id; ++i) {
            _item = bulletin.getItem(i + 1);
            assertEq(_item.review, items[i].review);
            assertEq(_item.owner, items[i].owner);
            assertEq(_item.expire, items[i].expire);
            assertEq(_item.title, items[i].title);
            assertEq(_item.detail, items[i].detail);
            assertEq(_item.schema, items[i].schema);
        }
    }

    function registerList_ReviewNotRequired() internal {
        registerItems();

        delete itemIds;
        itemIds.push(1);
        itemIds.push(2);
        itemIds.push(3);
        List memory list = List({owner: alice, title: TEST, detail: TEST, schema: BYTES, itemIds: itemIds});

        uint256 id = bulletin.listId();
        bulletin.registerList(list);

        uint256 _id = bulletin.listId();
        assertEq(id + 1, _id);

        List memory _list = bulletin.getList(_id);
        assertEq(_list.owner, list.owner);
        assertEq(_list.title, list.title);
        assertEq(_list.detail, list.detail);
        assertEq(_list.schema, list.schema);

        uint256 length = itemIds.length;
        for (uint256 i; i < length; i++) {
            assertEq(_list.itemIds[i], itemIds[i]);
        }
    }
}
