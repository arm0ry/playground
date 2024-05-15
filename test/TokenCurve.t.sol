// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {TokenCurve} from "src/TokenCurve.sol";
import {ITokenCurve, CurveType, Curve} from "src/interface/ITokenCurve.sol";
import {ListToken} from "src/tokens/ListToken.sol";
import {Currency} from "src/tokens/Currency.sol";

import {Bulletin} from "src/Bulletin.sol";
import {IBulletin, Item, List} from "src/interface/IBulletin.sol";

contract TokenCurveTest is Test {
    Bulletin bulletin;
    TokenCurve ic;
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

    Curve curve;
    Curve curve2;
    Curve curve3;

    Currency currency;

    /// -----------------------------------------------------------------------
    /// Setup Test
    /// -----------------------------------------------------------------------

    /// @notice Set up the testing suite.
    function setUp() public payable {
        // Deploy contract.
        ic = new TokenCurve();

        deployBulletin(user);
    }

    function testCurve_InvalidCurve() public payable {
        initializeIC(user);
        deployListToken(user);

        vm.expectRevert(TokenCurve.InvalidCurve.selector);

        ic.registerCurve(curve);
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
        deployCurrency(user);
        vm.warp(block.timestamp + 100);

        uint256 id = setupCurve(
            CurveType.LINEAR,
            address(listToken),
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
        deployCurrency(user);

        vm.warp(block.timestamp + 100);

        vm.expectRevert(TokenCurve.InvalidCurve.selector);
        ic.registerCurve(
            Curve({
                owner: alice,
                token: address(listToken),
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
    //     initializeIC(user);
    //     deployListToken(user);
    //     vm.warp(block.timestamp + 100);

    //             vm.expectRevert(0x82b42900); // `Unauthorized()`

    //     vm.prank(alice);
    //     ic.registerCurve(
    //         Curve({
    //             owner: alice,
    //             token: address(listToken),
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
    //     ic.curve(
    //         CurveType.LINEAR,
    //         address(listToken),
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
        ic.support{value: mintPrice}(1, bob, mintPrice, 0);

        uint256 burnPrice = ic.getCurvePrice(false, 1, 0);

        // Validate.
        assertEq(listToken.balanceOf(bob), 1);
        assertEq(listToken.totalSupply(), 1);

        assertEq(ic.treasuries(1), burnPrice);

        vm.prank(bob);
        listToken.updateInputs(1, 1, 1);
        emit log_string(listToken.generateSvg(1));
    }

    // function testLinearCurve_support_InvalidCurve(
    //     uint64 scale,
    //     uint32 mint_a,
    //     uint32 mint_b,
    //     uint32 mint_c,
    //     uint32 burn_a,
    //     uint32 burn_b,
    //     uint32 burn_c
    // ) public payable {
    //     testLinearCurve_support(scale, mint_a, mint_b, mint_c, burn_a, burn_b, burn_c);

    //     vm.expectRevert(TokenCurve.InvalidCurve.selector);
    //     vm.prank(alice);
    //     ic.curve(
    //         CurveType.LINEAR,
    //         address(listToken),
    //         alice,
    //         uint64(0.0001 ether),
    //         uint32(2),
    //         uint32(2),
    //         uint32(2),
    //         uint32(1),
    //         uint32(1),
    //         uint32(1)
    //     );
    // }

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
        vm.expectRevert(TokenCurve.InvalidAmount.selector);
        vm.prank(bob);
        ic.support{value: 1 ether}(1, bob, mintPrice, 0);
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
        vm.expectRevert(TokenCurve.InvalidAmount.selector);
        vm.prank(bob);
        ic.support{value: mintPrice}(1, bob, 1 ether, 0);
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

        // Burn.
        vm.prank(bob);
        ic.burn(1, bob, 1);

        // Validate.
        assertEq(listToken.balanceOf(bob), 0);
        assertEq(listToken.totalSupply(), 0);
        assertEq(ic.treasuries(1), 0);
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
        vm.expectRevert(0x82b42900); // `Unauthorized()`
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
        ic.support{value: mintPrice}(1, bob, mintPrice, 0);

        emit log_uint(listToken.balanceOf(bob));

        // First burn.
        vm.prank(bob);
        ic.burn(1, bob, 2);

        emit log_uint(listToken.balanceOf(bob));

        // Second burn.
        vm.expectRevert(0x82b42900); // `Unauthorized()`

        vm.prank(bob);
        ic.burn(1, bob, 1);

        emit log_uint(listToken.balanceOf(bob));
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
    //             vm.expectRevert(0x82b42900); // `Unauthorized()`

    //     vm.prank(alice);
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
        vm.expectRevert(0x82b42900); // `Unauthorized()`

        vm.prank(bob);
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

        initializeIC(user);
        deployListToken(user);
        deployCurrency(user);
        vm.warp(block.timestamp + 100);

        uint256 id = setupCurve(
            CurveType.QUADRATIC,
            address(listToken),
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

    function testQuadCurve_InvalidCurve(
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

        vm.expectRevert(TokenCurve.InvalidCurve.selector);
        ic.registerCurve(
            Curve({
                owner: alice,
                token: address(listToken),
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

        uint256 mintPrice = ic.getCurvePrice(true, 1, 0);

        vm.deal(bob, 1000000000000000000 ether);
        vm.prank(bob);
        ic.support{value: mintPrice}(1, bob, mintPrice, 0);

        uint256 burnPrice = ic.getCurvePrice(false, 1, 0);

        assertEq(listToken.balanceOf(bob), 1);
        assertEq(listToken.totalSupply(), 1);
        assertEq(ic.treasuries(1), burnPrice);
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
        uint256 burnPrice = ic.getCurvePrice(false, 1, 0);
        uint256 prevBalance = address(bob).balance;
        emit log_uint(prevBalance);

        // Burn.
        vm.prank(bob);
        ic.burn(1, bob, 1);

        // Validation.
        assertEq(listToken.balanceOf(bob), 0);
        assertEq(listToken.totalSupply(), 0);
        assertEq(ic.treasuries(1), 0);
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

    function deployCurrency(address _user) internal {
        currency = new Currency("User Support Token", "UST", _user);
    }

    /// @notice Set up a curve.
    function setupCurve(
        CurveType curveType,
        address _listToken,
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
        ic.registerCurve(
            Curve({
                owner: _user,
                token: _listToken,
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
        uint256 curveId = ic.curveId();
        Curve memory _c = ic.getCurve(curveId);
        assertEq(uint256(_c.curveType), uint256(curveType));
        assertEq(_c.owner, _user);
        assertEq(_c.token, _listToken);
        assertEq(_c.currency, _currency);
        assertEq(_c.scale, scale);
        assertEq(_c.mint_a, mint_a);
        assertEq(_c.mint_b, mint_b);
        assertEq(_c.mint_c, mint_c);
        assertEq(_c.burn_a, burn_a);
        assertEq(_c.burn_b, burn_b);
        assertEq(_c.burn_c, burn_c);
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
            assertEq(ic.getCurvePrice(true, curveId, supply), calculatePrice(supply + 1, scale, 0, mint_b, mint_c));
            assertEq(ic.getCurvePrice(false, curveId, supply), calculatePrice(supply, scale, 0, burn_b, burn_c));

            // Linear @ supply2.
            assertEq(ic.getCurvePrice(true, curveId, supply2), calculatePrice(supply2 + 1, scale, 0, mint_b, mint_c));
            assertEq(ic.getCurvePrice(false, curveId, supply2), calculatePrice(supply2, scale, 0, burn_b, burn_c));
        } else if (curveType == CurveType.QUADRATIC) {
            // Poly @ supply.
            assertEq(ic.getCurvePrice(true, curveId, supply), calculatePrice(supply + 1, scale, mint_a, mint_b, mint_c));
            assertEq(ic.getCurvePrice(false, curveId, supply), calculatePrice(supply, scale, burn_a, burn_b, burn_c));

            // Poly @ supply2.
            assertEq(
                ic.getCurvePrice(true, curveId, supply2), calculatePrice(supply2 + 1, scale, mint_a, mint_b, mint_c)
            );
            assertEq(ic.getCurvePrice(false, curveId, supply2), calculatePrice(supply2, scale, burn_a, burn_b, burn_c));
        } else {
            assertEq(ic.getCurvePrice(true, curveId, supply), calculatePrice(supply + 1, scale, 0, 0, 0));
            assertEq(ic.getCurvePrice(false, curveId, supply), calculatePrice(supply, scale, 0, 0, 0));

            assertEq(ic.getCurvePrice(true, curveId, supply2), calculatePrice(supply2 + 1, scale, 0, 0, 0));
            assertEq(ic.getCurvePrice(false, curveId, supply2), calculatePrice(supply2, scale, 0, 0, 0));
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
