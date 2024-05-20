// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "lib/forge-std/src/Test.sol";
import "lib/forge-std/src/console2.sol";

import {TokenCurve} from "src/TokenCurve.sol";
import {ITokenCurve, CurveType, Curve} from "src/interface/ITokenCurve.sol";
import {TokenMinter} from "src/tokens/TokenMinter.sol";
import {Currency} from "src/tokens/Currency.sol";
import {ICurrency} from "src/interface/ICurrency.sol";
import {Bulletin} from "src/Bulletin.sol";
import {IBulletin, Item, List} from "src/interface/IBulletin.sol";

contract TokenCurveTest is Test {
    Bulletin bulletin;
    TokenCurve tc;
    TokenMinter tokenMinter;

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

    Curve curve;
    Currency currency;

    /// -----------------------------------------------------------------------
    /// Setup Test
    /// -----------------------------------------------------------------------

    /// @notice Set up the testing suite.
    function setUp() public payable {
        // Deploy contract.
        deployTokenCurve(user);
        deployBulletin(user);

        grantRoles(alice, tc.LIST_OWNERS());
    }

    function deployTokenCurve(address _user) public payable {
        tc = new TokenCurve();
        tc.initialize(_user);
        assertEq(tc.owner(), _user);
    }

    function grantRoles(address account, uint256 role) public payable {
        vm.prank(user);
        tc.grantRoles(alice, role);
        assertEq(tc.rolesOf(account), role);
    }

    function testCurve_InvalidCurve() public payable {
        deployToken(user);

        vm.expectRevert(TokenCurve.InvalidCurve.selector);
        vm.prank(alice);
        tc.registerCurve(curve);
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

        uint256 _id = tc.curveId();

        deployToken(user);
        deployCurrency(user);
        vm.warp(block.timestamp + 100);

        uint256 id = setupCurve(
            CurveType.LINEAR,
            address(tokenMinter),
            address(currency),
            alice,
            scale,
            mint_a,
            mint_b,
            mint_c,
            burn_a,
            burn_b,
            burn_c
        );

        assertEq(_id + 1, id);
    }

    function testLinearCurve_InvalidCurve_TokenZeroAddress(
        uint64 scale,
        uint32 mint_a,
        uint32 mint_b,
        uint32 mint_c,
        uint32 burn_a,
        uint32 burn_b,
        uint32 burn_c
    ) public payable {
        vm.assume(burn_a > mint_a && burn_b > mint_b && burn_c > mint_c);

        deployToken(user);
        deployCurrency(user);

        vm.warp(block.timestamp + 100);

        vm.expectRevert(TokenCurve.InvalidCurve.selector);
        vm.prank(alice);
        tc.registerCurve(
            Curve({
                owner: alice,
                token: address(0),
                curveType: CurveType.LINEAR,
                currency: address(currency),
                scale: scale,
                mint_a: mint_a,
                mint_b: mint_b,
                mint_c: mint_c,
                burn_a: burn_a,
                burn_b: burn_b,
                burn_c: burn_c
            })
        );
    }

    function testLinearCurve_InvalidCurve_ScaleZero(
        uint64 scale,
        uint32 mint_a,
        uint32 mint_b,
        uint32 mint_c,
        uint32 burn_a,
        uint32 burn_b,
        uint32 burn_c
    ) public payable {
        vm.assume(burn_a > mint_a && burn_b > mint_b && burn_c > mint_c);

        deployToken(user);
        deployCurrency(user);

        vm.warp(block.timestamp + 100);

        vm.expectRevert(TokenCurve.InvalidCurve.selector);
        vm.prank(alice);
        tc.registerCurve(
            Curve({
                owner: alice,
                token: address(tokenMinter),
                curveType: CurveType.LINEAR,
                currency: address(currency),
                scale: 0,
                mint_a: mint_a,
                mint_b: mint_b,
                mint_c: mint_c,
                burn_a: burn_a,
                burn_b: burn_b,
                burn_c: burn_c
            })
        );
    }

    function testLinearCurve_InvalidCurve_InvalidCurveType(
        uint64 scale,
        uint32 mint_a,
        uint32 mint_b,
        uint32 mint_c,
        uint32 burn_a,
        uint32 burn_b,
        uint32 burn_c
    ) public payable {
        vm.assume(burn_a < mint_a && burn_b < mint_b && burn_c < mint_c);

        deployToken(user);
        deployCurrency(user);

        vm.warp(block.timestamp + 100);

        vm.expectRevert(TokenCurve.InvalidCurve.selector);
        vm.prank(alice);
        tc.registerCurve(
            Curve({
                owner: alice,
                token: address(tokenMinter),
                curveType: CurveType.NA,
                currency: address(currency),
                scale: scale,
                mint_a: mint_a,
                mint_b: mint_b,
                mint_c: mint_c,
                burn_a: burn_a,
                burn_b: burn_b,
                burn_c: burn_c
            })
        );
    }

    // TODO
    function testLinearCurve_InvalidCurve_TokenSupplyGreaterThanZero(
        uint64 scale,
        uint32 mint_a,
        uint32 mint_b,
        uint32 mint_c,
        uint32 burn_a,
        uint32 burn_b,
        uint32 burn_c
    ) public payable {
        // vm.assume(burn_a > mint_a && burn_b > mint_b && burn_c > mint_c);

        // deployToken(user);
        // deployCurrency(user);

        // vm.warp(block.timestamp + 100);

        // vm.expectRevert(TokenCurve.InvalidCurve.selector);
        // vm.prank(alice);
        // tc.registerCurve(
        //     Curve({
        //         owner: alice,
        //         token: address(tokenMinter),
        //         curveType: CurveType.LINEAR,
        //         currency: address(currency),
        //         scale: scale,
        //         mint_a: mint_a,
        //         mint_b: mint_b,
        //         mint_c: mint_c,
        //         burn_a: burn_a,
        //         burn_b: burn_b,
        //         burn_c: burn_c
        //     })
        // );
    }

    function testLinearCurve_InvalidFormula(
        uint64 scale,
        uint32 mint_a,
        uint32 mint_b,
        uint32 mint_c,
        uint32 burn_a,
        uint32 burn_b,
        uint32 burn_c
    ) public payable {
        vm.assume(burn_a > mint_a && burn_b > mint_b && burn_c > mint_c);
        vm.assume(scale > 0);

        deployToken(user);
        deployCurrency(user);

        vm.warp(block.timestamp + 100);

        vm.expectRevert(TokenCurve.InvalidFormula.selector);
        vm.prank(alice);
        tc.registerCurve(
            Curve({
                owner: alice,
                token: address(tokenMinter),
                curveType: CurveType.LINEAR,
                currency: address(currency),
                scale: scale,
                mint_a: mint_a,
                mint_b: mint_b,
                mint_c: mint_c,
                burn_a: burn_a,
                burn_b: burn_b,
                burn_c: burn_c
            })
        );
    }

    // function testLinearCurve_NotAuthorized() public payable {
    //     deployToken(user);
    //     vm.warp(block.timestamp + 100);

    //     vm.expectRevert(0x82b42900); // `Unauthorized()`

    //     vm.prank(alice);
    //     tc.registerCurve(
    //         Curve({
    //             owner: alice,
    //             token: address(tokenMinter),
    //             curveType: CurveType.LINEAR,
    //             currency: _currency,
    //             scale: scale,
    //             mint_a: mint_a,
    //             mint_b: mint_b,
    //             mint_c: mint_c,
    //             burn_a: burn_a,
    //             burn_b: burn_b,
    //             burn_c: burn_c
    //         })
    //     );
    //     tc.curve(
    //         CurveType.LINEAR,
    //         address(tokenMinter),
    //         address(0),
    //         uint64(0.0001 ether),
    //         uint32(2),
    //         uint32(2),
    //         uint32(2),
    //         uint32(1),
    //         uint32(1),
    //         uint32(1)
    //     );
    // }

    function test_LinearCurve_Support_NoCurrency(
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
        uint256 mintPrice = tc.getCurvePrice(true, 1, 0);

        // Deal.
        vm.deal(bob, 10000000000000 ether);

        // Support.
        vm.prank(bob);
        tc.support{value: mintPrice}(1, bob, mintPrice, 0);

        // Validate.
        assertEq(tokenMinter.balanceOf(bob), 1);
        assertEq(tokenMinter.totalSupply(), 1);

        uint256 burnPrice = tc.getCurvePrice(false, 1, 0);
        assertEq(tc.treasuries(1), burnPrice);

        vm.prank(bob);
        tokenMinter.updateInputs(1, 1, 1);
        emit log_string(tokenMinter.generateSvg(1));
    }

    function test_LinearCurve_Support_SomeCurrency_Subsidized(
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
        uint256 mintPrice = tc.getCurvePrice(true, 1, 0);

        // Deal.
        vm.prank(user);
        currency.mint(address(tc), 10000000000000 ether, address(tc));
        vm.deal(bob, 10000000000000 ether);
        vm.prank(user);
        currency.mint(bob, 10000000000000 ether, address(tc));
        uint256 floor = calculatePrice(tokenMinter.totalSupply() + 1, scale, 0, 0, mint_c);
        uint256 currencyPayment = floor / 2;

        // Support.
        vm.prank(bob);
        tc.support{value: mintPrice - floor}(1, bob, mintPrice, currencyPayment);

        // Validate.
        assertEq(tokenMinter.balanceOf(bob), 1);
        assertEq(tokenMinter.totalSupply(), 1);

        uint256 burnPrice = tc.getCurvePrice(false, 1, 0);
        assertEq(tc.treasuries(1), burnPrice);
        assertEq(address(tc).balance, burnPrice);
        assertEq(currency.balanceOf(alice), floor);
        assertEq(address(alice).balance, mintPrice - burnPrice - floor);
        assertEq(currency.balanceOf(bob), 10000000000000 ether - currencyPayment);

        vm.prank(bob);
        tokenMinter.updateInputs(1, 1, 1);
        emit log_string(tokenMinter.generateSvg(1));
    }

    function test_LinearCurve_Support_SomeCurrency_Unsubsidized(
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
        uint256 mintPrice = tc.getCurvePrice(true, 1, 0);

        // Deal.
        vm.deal(bob, 10000000000000 ether);
        vm.prank(user);
        currency.mint(bob, 10000000000000 ether, address(tc));
        uint256 floor = calculatePrice(tokenMinter.totalSupply() + 1, scale, 0, 0, mint_c);
        uint256 currencyPayment = floor / 2;

        // Support.
        vm.prank(bob);
        tc.support{value: mintPrice - currencyPayment}(1, bob, mintPrice, currencyPayment);

        // Validate.
        assertEq(tokenMinter.balanceOf(bob), 1);
        assertEq(tokenMinter.totalSupply(), 1);

        uint256 burnPrice = tc.getCurvePrice(false, 1, 0);
        assertEq(tc.treasuries(1), burnPrice);
        assertEq(address(tc).balance, burnPrice);
        assertEq(currency.balanceOf(alice), currencyPayment);
        assertEq(address(alice).balance, mintPrice - burnPrice - currencyPayment);
        assertEq(currency.balanceOf(bob), 10000000000000 ether - currencyPayment);

        vm.prank(bob);
        tokenMinter.updateInputs(1, 1, 1);
        emit log_string(tokenMinter.generateSvg(1));
    }

    function test_LinearCurve_Support_Floor(
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
        uint256 mintPrice = tc.getCurvePrice(true, 1, 0);

        // Deal.
        vm.deal(bob, 10000000000000 ether);
        vm.prank(user);
        currency.mint(bob, 10000000000000 ether, address(tc));
        uint256 floor = calculatePrice(tokenMinter.totalSupply() + 1, scale, 0, 0, mint_c);

        // Support.
        vm.prank(bob);
        tc.support{value: mintPrice - floor}(1, bob, mintPrice, floor);

        // Validate.
        assertEq(tokenMinter.balanceOf(bob), 1);
        assertEq(tokenMinter.totalSupply(), 1);

        uint256 burnPrice = tc.getCurvePrice(false, 1, 0);
        assertEq(tc.treasuries(1), burnPrice);
        assertEq(address(tc).balance, burnPrice);
        assertEq(currency.balanceOf(alice), floor);
        assertEq(address(alice).balance, mintPrice - burnPrice - floor);
        assertEq(currency.balanceOf(bob), 10000000000000 ether - floor);

        vm.prank(bob);
        tokenMinter.updateInputs(1, 1, 1);
        emit log_string(tokenMinter.generateSvg(1));
    }

    function test_LinearCurve_Support_InvalidAmount_OverFloor(
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
        uint256 mintPrice = tc.getCurvePrice(true, 1, 0);

        // Deal.
        vm.deal(bob, 10000000000000 ether);
        vm.prank(user);
        currency.mint(bob, 10000000000000 ether, address(tc));
        uint256 floor = calculatePrice(tokenMinter.totalSupply() + 1, scale, 0, 0, mint_c);
        uint256 overFloor = floor + 1 wei;
        // Support.
        vm.expectRevert(TokenCurve.InvalidAmount.selector);
        vm.prank(bob);
        tc.support{value: mintPrice - overFloor}(1, bob, mintPrice, overFloor);
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
        uint256 mintPrice = tc.getCurvePrice(true, 1, 0);

        // Deal.
        vm.deal(bob, 10000000000000 ether);

        // Support.
        vm.expectRevert(TokenCurve.InvalidAmount.selector);
        vm.prank(bob);
        tc.support{value: 1 ether}(1, bob, mintPrice, 0);
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
        uint256 mintPrice = tc.getCurvePrice(true, 1, 0);

        // Deal.
        vm.deal(bob, 10000000000000 ether);

        // Support.
        vm.expectRevert(TokenCurve.InvalidAmount.selector);
        vm.prank(bob);
        tc.support{value: mintPrice}(1, bob, 1 ether, 0);
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
        test_LinearCurve_Support_NoCurrency(scale, mint_a, mint_b, mint_c, burn_a, burn_b, burn_c);

        // Burn.
        vm.prank(bob);
        tc.burn(1, bob, 1);

        // Validate.
        assertEq(tokenMinter.balanceOf(bob), 0);
        assertEq(tokenMinter.totalSupply(), 0);
        assertEq(tc.treasuries(1), 0);
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
        test_LinearCurve_Support_NoCurrency(scale, mint_a, mint_b, mint_c, burn_a, burn_b, burn_c);

        // Burn.
        vm.expectRevert(0x82b42900); // `Unauthorized()`
        vm.prank(charlie);
        tc.burn(1, charlie, 1);
    }

    function testQuadCurve(
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

        deployToken(user);
        deployCurrency(user);
        vm.warp(block.timestamp + 100);

        uint256 id = setupCurve(
            CurveType.QUADRATIC,
            address(tokenMinter),
            address(currency),
            alice,
            scale,
            mint_a,
            mint_b,
            mint_c,
            burn_a,
            burn_b,
            burn_c
        );
    }

    function testQuadCurve_InvalidFormula(
        uint64 scale,
        uint32 mint_a,
        uint32 mint_b,
        uint32 mint_c,
        uint32 burn_a,
        uint32 burn_b,
        uint32 burn_c
    ) public payable {
        vm.assume(burn_a > mint_a || burn_b > mint_b || burn_c > mint_c);
        vm.assume(scale > 0);
        deployToken(user);

        vm.expectRevert(TokenCurve.InvalidFormula.selector);
        vm.prank(alice);
        tc.registerCurve(
            Curve({
                owner: alice,
                token: address(tokenMinter),
                curveType: CurveType.QUADRATIC,
                currency: address(currency),
                scale: scale,
                mint_a: mint_a,
                mint_b: mint_b,
                mint_c: mint_c,
                burn_a: burn_a,
                burn_b: burn_b,
                burn_c: burn_c
            })
        );
    }

    function testQuadCurve_support(
        uint64 scale,
        uint32 mint_a,
        uint32 mint_b,
        uint32 mint_c,
        uint32 burn_a,
        uint32 burn_b,
        uint32 burn_c
    ) public payable {
        vm.assume(scale > 0);
        testQuadCurve(scale, mint_a, mint_b, mint_c, burn_a, burn_b, burn_c);

        uint256 mintPrice = tc.getCurvePrice(true, 1, 0);

        vm.deal(bob, 1000000000000000000 ether);
        vm.prank(bob);
        tc.support{value: mintPrice}(1, bob, mintPrice, 0);

        uint256 burnPrice = tc.getCurvePrice(false, 1, 0);

        assertEq(tokenMinter.balanceOf(bob), 1);
        assertEq(tokenMinter.totalSupply(), 1);
        assertEq(tc.treasuries(1), burnPrice);
        assertEq(address(tc).balance, burnPrice);

        vm.prank(bob);
        tokenMinter.updateInputs(1, 1, 1);
        emit log_string(tokenMinter.generateSvg(1));
    }

    function testQuadCurve_burn(
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
        testQuadCurve_support(scale, mint_a, mint_b, mint_c, burn_a, burn_b, burn_c);

        // Retrieve for validation.
        uint256 burnPrice = tc.getCurvePrice(false, 1, 0);
        uint256 prevBalance = address(bob).balance;
        emit log_uint(prevBalance);

        // Burn.
        vm.prank(bob);
        tc.burn(1, bob, 1);

        // Validation.
        assertEq(tokenMinter.balanceOf(bob), 0);
        assertEq(tokenMinter.totalSupply(), 0);
        assertEq(tc.treasuries(1), 0);
        assertEq(address(bob).balance, prevBalance + burnPrice);
    }

    /// -----------------------------------------------------------------------
    /// Other Functions
    /// -----------------------------------------------------------------------

    function testReceiveETH() public payable {
        (bool sent,) = address((tc)).call{value: 5 ether}("");
        assert(sent);
    }

    /// -----------------------------------------------------------------------
    /// Internal Functions
    /// -----------------------------------------------------------------------

    function deployToken(address _user) internal {
        tokenMinter = new TokenMinter();
    }

    function deployCurrency(address _user) internal {
        currency = new Currency("User Support Token", "UST", _user);
    }

    /// @notice Set up a curve.
    function setupCurve(
        CurveType curveType,
        address _tokenMinter,
        address _currency,
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
        tc.registerCurve(
            Curve({
                owner: _user,
                token: _tokenMinter,
                curveType: curveType,
                currency: _currency,
                scale: scale,
                mint_a: mint_a,
                mint_b: mint_b,
                mint_c: mint_c,
                burn_a: burn_a,
                burn_b: burn_b,
                burn_c: burn_c
            })
        );

        // Validate.
        uint256 curveId = tc.curveId();
        Curve memory _c = tc.getCurve(curveId);
        assertEq(uint256(_c.curveType), uint256(curveType));
        assertEq(_c.owner, _user);
        assertEq(_c.token, _tokenMinter);
        assertEq(_c.currency, _currency);

        if (uint256(_c.curveType) == 1) {
            assertEq(_c.scale, scale);
            assertEq(_c.mint_a, 0);
            assertEq(_c.mint_b, mint_b);
            assertEq(_c.mint_c, mint_c);
            assertEq(_c.burn_a, 0);
            assertEq(_c.burn_b, burn_b);
            assertEq(_c.burn_c, 0);
        } else if (uint256(_c.curveType) == 2) {
            assertEq(_c.scale, scale);
            assertEq(_c.mint_a, mint_a);
            assertEq(_c.mint_b, mint_b);
            assertEq(_c.mint_c, mint_c);
            assertEq(_c.burn_a, burn_a);
            assertEq(_c.burn_b, burn_b);
            assertEq(_c.burn_c, 0);
        } else {
            assertEq(_c.scale, scale);
            assertEq(_c.mint_a, 0);
            assertEq(_c.mint_b, 0);
            assertEq(_c.mint_c, 0);
            assertEq(_c.burn_a, 0);
            assertEq(_c.burn_b, 0);
            assertEq(_c.burn_c, 0);
        }

        return curveId;
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
            assertEq(tc.getCurvePrice(true, curveId, supply), calculatePrice(supply + 1, scale, 0, mint_b, mint_c));
            assertEq(tc.getCurvePrice(false, curveId, supply), calculatePrice(supply, scale, 0, burn_b, burn_c));

            // Linear @ supply2.
            assertEq(tc.getCurvePrice(true, curveId, supply2), calculatePrice(supply2 + 1, scale, 0, mint_b, mint_c));
            assertEq(tc.getCurvePrice(false, curveId, supply2), calculatePrice(supply2, scale, 0, burn_b, burn_c));
        } else if (curveType == CurveType.QUADRATIC) {
            // Poly @ supply.
            assertEq(tc.getCurvePrice(true, curveId, supply), calculatePrice(supply + 1, scale, mint_a, mint_b, mint_c));
            assertEq(tc.getCurvePrice(false, curveId, supply), calculatePrice(supply, scale, burn_a, burn_b, burn_c));

            // Poly @ supply2.
            assertEq(
                tc.getCurvePrice(true, curveId, supply2), calculatePrice(supply2 + 1, scale, mint_a, mint_b, mint_c)
            );
            assertEq(tc.getCurvePrice(false, curveId, supply2), calculatePrice(supply2, scale, burn_a, burn_b, burn_c));
        } else {
            assertEq(tc.getCurvePrice(true, curveId, supply), calculatePrice(supply + 1, scale, 0, 0, 0));
            assertEq(tc.getCurvePrice(false, curveId, supply), calculatePrice(supply, scale, 0, 0, 0));

            assertEq(tc.getCurvePrice(true, curveId, supply2), calculatePrice(supply2 + 1, scale, 0, 0, 0));
            assertEq(tc.getCurvePrice(false, curveId, supply2), calculatePrice(supply2, scale, 0, 0, 0));
        }
    }

    function calculatePrice(uint256 supply, uint256 scale, uint256 constant_a, uint256 constant_b, uint256 constant_c)
        internal
        pure
        returns (uint256)
    {
        return constant_a * (supply ** 2) * scale + constant_b * supply * scale + constant_c * scale;
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
