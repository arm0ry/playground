// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Script} from "lib/forge-std/src/Script.sol";
import {console2} from "lib/forge-std/src/console2.sol";

import {Log} from "src/Log.sol";
import {ILog, Activity, Touchpoint} from "src/interface/ILog.sol";
import {Bulletin} from "src/Bulletin.sol";
import {IBulletin, List, Item} from "src/interface/IBulletin.sol";

import {Factory} from "src/Factory.sol";
import {TokenCurve} from "src/TokenCurve.sol";

import {ITokenCurve, Curve, CurveType} from "src/interface/ITokenCurve.sol";
import {TokenMinter} from "src/tokens/TokenMinter.sol";
import {ITokenMinter, TokenTitle, TokenBuilder, TokenSource, TokenMarket} from "src/interface/ITokenMinter.sol";
import {Currency} from "src/tokens/Currency.sol";
import {TokenUriBuilder} from "src/tokens/TokenUriBuilder.sol";

/// @notice A very simple deployment script
contract Deploy is Script {
    // Events.
    event Tasks(
        address[] _taskCreators, uint256[] _taskDeadlines, string[] _taskTitles, string[] taskDetail, uint256[] itemIds
    );
    event TaskArray(address[] _taskCreators, uint256[] _taskDeadlines, string[] _taskTitles, string[] taskDetail);

    // Errors.
    error Invalid();

    // Constant.
    uint256 constant PAST = 100000;
    uint40 constant FUTURE = 2527482181;
    bytes constant BYTES = bytes(string("BYTES"));

    // Contracts.
    address bulletinAddr = payable(address(0));
    address loggerAddr = address(0);
    address factoryAddr = address(0);
    address payable marketAddr = payable(address(0));

    // Tokens.
    address tokenMinterAddr;
    address currencyAddr;
    address currencyAddr2;
    address tokenBuilderAddr;

    // Users.
    address account;
    address user1 = address(0x4744cda32bE7b3e75b9334001da9ED21789d4c0d);
    address user2 = address(0xFB12B6A543d986A1938d2b3C7d05848D8913AcC4);
    address user3 = address(0x85E70769d04Be1C9d7C3c373b98BD9929f61F428);
    address gasbuddy = address(0x7Cf60ec5A5541b7d4073F795a67A75E383F3FFFf);

    // Curves.
    Curve curve1;
    Curve curve2;
    Curve curve3;
    Curve curve4;
    Curve curve5;

    // Prep for item submission.
    Item[] items;

    // Prep for list submission.
    uint256[] itemIds;

    /// @notice The main script entrypoint.
    function run() external {
        uint256 privateKey = vm.envUint("DEV_PRIVATE_KEY");
        account = vm.addr(privateKey);

        console2.log("Account", account);

        vm.startBroadcast(privateKey);

        deployCommons(account, user1, gasbuddy);
        // deployTokenBuilder();

        vm.stopBroadcast();
    }

    function runSupport(address patron) internal {
        marketAddr = payable(address(0xc0Cb59917D6632bDaa04a9223Ff3FD700fD367E0));
        Currency(0x53680ac74673922705a009D5fCd6469A9E67fa88).mint(patron, 1 ether, marketAddr);

        uint256 price;
        TokenCurve(marketAddr).support(1, patron, 0.001 ether);

        price = TokenCurve(marketAddr).getCurvePrice(true, 2, 0);
        TokenCurve(marketAddr).support{value: price - 0.003 ether}(2, patron, 0.003 ether);

        price = TokenCurve(marketAddr).getCurvePrice(true, 3, 0);
        TokenCurve(marketAddr).support{value: price - 0.0001 ether}(3, patron, 0.0001 ether);
    }

    function deployCommons(address patron, address user, address _gasbuddy) internal {
        // Deploy quest contract and set gasbuddy.
        deployLogger(false, patron);
        ILog(loggerAddr).grantRoles(gasbuddy, ILog(loggerAddr).GASBUDDIES());
        ILog(loggerAddr).grantRoles(patron, ILog(loggerAddr).MEMBERS());

        // Deploy bulletin contract and grant roles.
        deployBulletin(false, patron);
        IBulletin(bulletinAddr).grantRoles(loggerAddr, IBulletin(bulletinAddr).LOGGERS());

        // Prepare lists.
        registerCoffee();
        registerDeliverCoffee();

        // Deploy token minter and uri builder.
        deployTokenMinter();
        deployTokenBuilder();

        // Deploy curve.
        deployTokenCurve(patron);

        // Deploy currency.
        deployCurrency("Coffee", "COFFEE", patron);
        Currency(currencyAddr).mint(patron, 1000 ether, marketAddr);
        Currency(currencyAddr).mint(marketAddr, 10 ether, marketAddr);

        deployCurrency2("Croissant", "CROISSANT", patron);
        Currency(currencyAddr2).mint(patron, 1000 ether, marketAddr);
        Currency(currencyAddr2).mint(marketAddr, 10 ether, marketAddr);

        // Configure token
        ITokenMinter(tokenMinterAddr).registerMinter(
            TokenTitle({
                name: "Coffee with $croissant",
                desc: "For the $croissant community, we offer our coffee for 5 $croissant."
            }),
            TokenSource({user: user1, bulletin: bulletinAddr, listId: 1, logger: loggerAddr}),
            TokenBuilder({builder: tokenBuilderAddr, builderId: 1}),
            TokenMarket({market: marketAddr, limit: 100})
        );
        uint256 tokenId = ITokenMinter(tokenMinterAddr).tokenId();

        ITokenMinter(tokenMinterAddr).registerMinter(
            TokenTitle({
                name: "Coffee",
                desc: "Giving back to the $coffee community, we take 3 $coffee for our labor and time ,and the rest in $stablecoins for our continued commitment in sourcing local beans and practicing sustainable waste practices."
            }),
            TokenSource({user: user1, bulletin: bulletinAddr, listId: 1, logger: loggerAddr}),
            TokenBuilder({builder: tokenBuilderAddr, builderId: 2}),
            TokenMarket({market: marketAddr, limit: 300})
        );
        uint256 tokenId2 = ITokenMinter(tokenMinterAddr).tokenId();

        ITokenMinter(tokenMinterAddr).registerMinter(
            TokenTitle({
                name: "[Service] Deliver a Pitcher of Coffee", // Pay for delivery in $COFFEE via drop and receive service payments in $COFFEE via curve
                desc: "We can deliver a pitch of cold brew locally for 10 $coffee to cover labor, and the rest in $stablecoin for our commitment to recycle pitchers and deliver with zero-emission."
            }),
            TokenSource({user: user1, bulletin: bulletinAddr, listId: 2, logger: loggerAddr}),
            TokenBuilder({builder: tokenBuilderAddr, builderId: 3}),
            TokenMarket({market: marketAddr, limit: 20})
        );
        uint256 tokenId3 = ITokenMinter(tokenMinterAddr).tokenId();

        ITokenMinter(tokenMinterAddr).registerMinter(
            TokenTitle({
                name: "[Help Wanted] Deliver a Pitcher of Coffee",
                desc: "Reserve a spot with 0.5 $coffee to help us deliver with zero-emission. Hop into our Discord for more delivery detail~"
            }),
            TokenSource({user: user1, bulletin: bulletinAddr, listId: 2, logger: loggerAddr}),
            TokenBuilder({builder: tokenBuilderAddr, builderId: 4}),
            TokenMarket({market: marketAddr, limit: 10})
        );
        uint256 tokenId4 = ITokenMinter(tokenMinterAddr).tokenId();

        // ITokenMinter(tokenMinterAddr).registerMinter(
        //     TokenTitle({
        //         name: "[Harberger Sponsor] How to Make Espresso for Beginners",
        //         desc: "[WIP] Our espresso-making process is a one-of-a-kind artistic endeavor. If you want to know more, show your support and become a Harberger sponsor!"
        //     }),
        //     TokenSource({bulletin: bulletinAddr, listId: 4, logger: loggerAddr}),
        //     TokenBuilder({builder: tokenBuilderAddr, builderId: 1}),
        //     TokenMarket({market: marketAddr, limit: 1})
        // );
        // uint256 tokenId5 = ITokenMinter(tokenMinterAddr).tokenId();

        // Register curves.
        curve1 = Curve({
            owner: user1,
            token: tokenMinterAddr,
            id: tokenId,
            supply: 0,
            curveType: CurveType.LINEAR,
            currency: currencyAddr2,
            scale: 1 ether,
            mint_a: 0,
            mint_b: 0,
            mint_c: 5,
            burn_a: 0,
            burn_b: 0,
            burn_c: 0
        });
        TokenCurve(marketAddr).registerCurve(curve1);

        curve2 = Curve({
            owner: user2,
            token: tokenMinterAddr,
            id: tokenId2,
            supply: 0,
            curveType: CurveType.LINEAR,
            currency: currencyAddr,
            scale: 0.0001 ether,
            mint_a: 0,
            mint_b: 30,
            mint_c: 30000,
            burn_a: 0,
            burn_b: 1,
            burn_c: 0
        });
        TokenCurve(marketAddr).registerCurve(curve2);

        curve3 = Curve({
            owner: user1,
            token: tokenMinterAddr,
            id: tokenId3,
            supply: 0,
            curveType: CurveType.LINEAR,
            currency: currencyAddr,
            scale: 0.0001 ether,
            mint_a: 0,
            mint_b: 100,
            mint_c: 100000,
            burn_a: 0,
            burn_b: 1,
            burn_c: 0
        });
        TokenCurve(marketAddr).registerCurve(curve3);

        curve4 = Curve({
            owner: user2,
            token: tokenMinterAddr,
            id: tokenId4,
            supply: 0,
            curveType: CurveType.QUADRATIC,
            currency: currencyAddr,
            scale: 0.01 ether,
            mint_a: 0,
            mint_b: 5,
            mint_c: 50,
            burn_a: 0,
            burn_b: 1,
            burn_c: 0
        });
        TokenCurve(marketAddr).registerCurve(curve4);

        // Update admin.
        // Need this only if deployer account is different from account operating the contract
        Bulletin(payable(bulletinAddr)).transferOwnership(user);

        // Submit mock user input.
        ILog(loggerAddr).log(bulletinAddr, 1, 0, "Flavorful!", abi.encode(uint256(3), uint256(7), uint256(9)));
        ILog(loggerAddr).log(bulletinAddr, 2, 0, "Wonderful service!", BYTES);

        // Full stablecoin support.
        uint256 price = TokenCurve(marketAddr).getCurvePrice(true, 1, 0);
        TokenCurve(marketAddr).support(1, patron, price);

        // Floor currency support.
        price = TokenCurve(marketAddr).getCurvePrice(true, 2, 0);
        TokenCurve(marketAddr).support{value: price - 3 ether}(2, patron, 3 ether);

        // Partial-floor stablecoin support.
        price = TokenCurve(marketAddr).getCurvePrice(true, 3, 0);
        TokenCurve(marketAddr).support{value: price - 9.9995 ether}(3, patron, 9.9995 ether);

        // Floor currency support.
        price = TokenCurve(marketAddr).getCurvePrice(true, 4, 0);
        TokenCurve(marketAddr).support{value: price - 0.5 ether}(4, patron, 0.5 ether);
    }

    function deployBulletin(bool factory, address user) internal {
        delete bulletinAddr;

        if (factory) {
            bulletinAddr = Factory(factoryAddr).deployBulletin(user);
        } else {
            bulletinAddr = address(new Bulletin());
        }
        IBulletin(payable(bulletinAddr)).initialize(user);
    }

    function deployLogger(bool factory, address user) internal {
        delete loggerAddr;

        if (factory) {
            loggerAddr = Factory(factoryAddr).deployLogger(user);
        } else {
            loggerAddr = address(new Log());
        }
        ILog(loggerAddr).initialize(user);
    }

    function deployTokenCurve(address user) internal {
        delete marketAddr;
        marketAddr = payable(address(new TokenCurve()));
    }

    function deployTokenMinter() internal {
        delete tokenMinterAddr;
        tokenMinterAddr = address(new TokenMinter());
    }

    function deployTokenBuilder() internal {
        delete tokenBuilderAddr;
        tokenBuilderAddr = address(new TokenUriBuilder());
    }

    function deployCurrency(string memory name, string memory symbol, address owner) internal {
        delete currencyAddr;
        currencyAddr = address(new Currency(name, symbol, owner));
    }

    function deployCurrency2(string memory name, string memory symbol, address owner) internal {
        delete currencyAddr2;
        currencyAddr2 = address(new Currency(name, symbol, owner));
    }

    function support(uint256 curveId, address patron, uint256 amountInCurrency) internal {
        uint256 price = TokenCurve(marketAddr).getCurvePrice(true, curveId, 0);
        TokenCurve(marketAddr).support{value: price}(curveId, patron, amountInCurrency);
    }

    function registerList(
        address user,
        address bulletin,
        Item[] memory _items,
        string memory listTitle,
        string memory listDetail,
        uint256 drip
    ) internal {
        delete itemIds;
        uint256 itemId = IBulletin(bulletinAddr).itemId();

        IBulletin(bulletinAddr).registerItems(_items);

        for (uint256 i = 1; i <= _items.length; ++i) {
            itemIds.push(itemId + i);
        }

        List memory list =
            List({owner: user, title: listTitle, detail: listDetail, schema: BYTES, itemIds: itemIds, drip: drip});
        IBulletin(bulletinAddr).registerList(list);
    }

    /// -----------------------------------------------------------------------
    /// Register Lists
    /// -----------------------------------------------------------------------

    function registerCoffee() public {
        delete items;

        Item memory item1 = Item({
            review: false,
            expire: FUTURE,
            owner: user1,
            title: "ABC Beans",
            detail: "https://hackmd.io/@audsssy/rkHLIFwVC",
            schema: BYTES,
            drip: 0
        });
        Item memory item2 = Item({
            review: false,
            expire: FUTURE,
            owner: user1,
            title: "Filtered Water",
            detail: "",
            schema: BYTES,
            drip: 0
        });
        Item memory item3 = Item({
            review: false,
            expire: FUTURE,
            owner: user1,
            title: "Compost Coffee Beans",
            detail: "",
            schema: BYTES,
            drip: 0
        });

        items.push(item1);
        items.push(item2);
        items.push(item3);

        registerList(
            account,
            bulletinAddr,
            items,
            "Coffee",
            "A smooth and refreshing coffee experience crafted to balance bold flavors and ethical sourcing.",
            0
        );
    }

    function registerDeliverCoffee() public {
        delete items;

        Item memory item1 = Item({
            review: false,
            expire: FUTURE,
            owner: user1,
            title: "Grab a Pitcher",
            detail: "",
            schema: BYTES,
            drip: 0
        });
        Item memory item2 = Item({
            review: false,
            expire: FUTURE,
            owner: user1,
            title: "Deliver to Recipient",
            detail: "",
            schema: BYTES,
            drip: 0
        });
        Item memory item3 = Item({
            review: false,
            expire: FUTURE,
            owner: user1,
            title: "Recycle Pitcher",
            detail: "",
            schema: BYTES,
            drip: 0
        });

        items.push(item1);
        items.push(item2);
        items.push(item3);

        registerList(
            account,
            bulletinAddr,
            items,
            "Deliver a Pitcher of Coffee",
            "Reserve a pitcher of Coffee for delivery next Monday!",
            60 ether
        );
    }

    function registerEspresso() public {
        delete items;

        Item memory item1 = Item({
            review: false,
            expire: FUTURE,
            owner: user1,
            title: "ABC Espresso Beans",
            detail: "https://hackmd.io/@audsssy/rkHLIFwVC",
            schema: BYTES,
            drip: 0
        });
        Item memory item2 = Item({
            review: false,
            expire: FUTURE,
            owner: user1,
            title: "Boiled Water",
            detail: "",
            schema: BYTES,
            drip: 0
        });

        items.push(item1);
        items.push(item2);

        registerList(
            account,
            bulletinAddr,
            items,
            "Espresso",
            "Discover our expertly crafted espresso, delivering bold, rich flavor and a velvety crema, perfect for starting your day with a touch of excellence.",
            0
        );
    }

    function registerMakingEspresso() public {
        delete items;

        Item memory item1 = Item({
            review: false,
            expire: FUTURE,
            owner: user1,
            title: "Preheat Machine",
            detail: "https://hackmd.io/@audsssy/BJHHDtPEA",
            schema: BYTES,
            drip: 0
        });
        Item memory item2 = Item({
            review: false,
            expire: FUTURE,
            owner: user1,
            title: "Grind Beans",
            detail: "https://hackmd.io/@audsssy/SkN9wYv40",
            schema: BYTES,
            drip: 0
        });
        Item memory item3 = Item({
            review: false,
            expire: FUTURE,
            owner: user1,
            title: "Tamp Coffee",
            detail: "https://hackmd.io/@audsssy/rJ__K2vEC",
            schema: BYTES,
            drip: 0
        });
        Item memory item4 = Item({
            review: false,
            expire: FUTURE,
            owner: user1,
            title: "Brew Espresso",
            detail: "https://www.youtube.com/embed/fbHPjiST8Is",
            schema: BYTES,
            drip: 0
        });

        items.push(item1);
        items.push(item2);
        items.push(item3);
        items.push(item4);

        registerList(
            account,
            bulletinAddr,
            items,
            "Making Espresso",
            "Making an espresso is an art. We want to share with you how we do it.",
            0
        );
    }

    function registerChiadoPoloHat() public {
        delete items;

        Item memory item1 = Item({
            review: false,
            expire: FUTURE,
            owner: user1,
            title: "6-panel",
            detail: "https://hackmd.io/@audsssy/HJC9SFvNA",
            schema: BYTES,
            drip: 0
        });

        Item memory item2 = Item({
            review: false,
            expire: FUTURE,
            owner: user1,
            title: "Chino Twill",
            detail: "https://hackmd.io/@audsssy/r1PJocwEC",
            schema: BYTES,
            drip: 0
        });

        items.push(item1);

        registerList(
            account,
            bulletinAddr,
            items,
            "Chiado Polo Hat",
            "Chiado Coffee brings you the best looking outfit that makes you proud.",
            0
        );
    }

    function registerHackath0n() public {
        delete items;

        Item memory item1 = Item({
            review: false,
            expire: FUTURE,
            owner: user1,
            title: unicode"第陸拾次記得投票黑客松 － 60th Hackath0n",
            detail: "https://g0v.hackmd.io/@jothon/B1IwtQNrT",
            schema: BYTES,
            drip: 0
        });
        Item memory item2 = Item({
            review: false,
            expire: FUTURE,
            owner: user1,
            title: unicode"第陸拾壹次龍來 Open Data Day 黑客松 － 61st Hackath0n",
            detail: "https://g0v.hackmd.io/@jothon/B1DqSeaK6",
            schema: BYTES,
            drip: 0
        });

        items.push(item1);
        items.push(item2);

        registerList(
            account,
            bulletinAddr,
            items,
            "g0v bi-monthly Hackath0n",
            "Founded in Taiwan, 'g0v' (gov-zero) is a decentralised civic tech community with information transparency, open results and open cooperation as its core values. g0v engages in public affairs by drawing from the grassroot power of the community.",
            0
        );
    }

    function registerListTutorial() internal {
        delete items;
        Item memory item1 = Item({
            review: false,
            expire: FUTURE,
            owner: user1,
            title: "Navigating the 'Create a Task' page",
            detail: "https://hackmd.io/@audsssy/H1bZW6h66",
            schema: BYTES,
            drip: 0
        });
        Item memory item2 = Item({
            review: false,
            expire: FUTURE,
            owner: user2,
            title: "Navigating the 'Create a List' page",
            detail: "https://hackmd.io/@audsssy/rJrera2TT",
            schema: BYTES,
            drip: 0
        });
        Item memory item3 = Item({
            review: false,
            expire: FUTURE,
            owner: user3,
            title: "Navigating Lists",
            detail: "https://hackmd.io/@audsssy/BkrQSah6p",
            schema: BYTES,
            drip: 0
        });

        items.push(item1);
        items.push(item2);
        items.push(item3);

        registerList(
            account,
            bulletinAddr,
            items,
            "'Create a List' Tutorial",
            "This is a tutorial to create, and interact with, a list onchain.",
            0
        );
    }

    function registerWildernessPark() internal {
        delete items;

        Item memory item1 = Item({
            review: false,
            expire: FUTURE,
            owner: user2,
            title: "Trail Post #45",
            detail: "https://www.indianaoutfitters.com/Maps/knobstone_trail/deam_lake_to_jackson_road.jpg",
            schema: BYTES,
            drip: 0
        });
        Item memory item2 = Item({
            review: false,
            expire: FUTURE,
            owner: user1,
            title: "Trail Post #44",
            detail: "https://www.indianaoutfitters.com/Maps/knobstone_trail/deam_lake_to_jackson_road.jpg",
            schema: BYTES,
            drip: 0
        });
        Item memory item3 = Item({
            review: false,
            expire: FUTURE,
            owner: user3,
            title: "Trail Post #43",
            detail: "https://www.indianaoutfitters.com/Maps/knobstone_trail/deam_lake_to_jackson_road.jpg",
            schema: BYTES,
            drip: 0
        });
        Item memory item4 = Item({
            review: false,
            expire: FUTURE,
            owner: user2,
            title: "Trail Post #28",
            detail: "https://www.indianaoutfitters.com/Maps/knobstone_trail/deam_lake_to_jackson_road.jpg",
            schema: BYTES,
            drip: 0
        });
        Item memory item5 = Item({
            review: false,
            expire: FUTURE,
            owner: user3,
            title: "Trail Post #29",
            detail: "https://www.indianaoutfitters.com/Maps/knobstone_trail/deam_lake_to_jackson_road.jpg",
            schema: BYTES,
            drip: 0
        });
        Item memory item6 = Item({
            review: false,
            expire: FUTURE,
            owner: user3,
            title: "Trail Post #48",
            detail: "https://www.indianaoutfitters.com/Maps/knobstone_trail/deam_lake_to_jackson_road.jpg",
            schema: BYTES,
            drip: 0
        });

        items.push(item1);
        items.push(item2);
        items.push(item3);
        items.push(item4);
        items.push(item5);
        items.push(item6);

        registerList(
            account,
            bulletinAddr,
            items,
            "TESTNET Wilderness Park",
            "Scan QR codes at each trail post to help build a real-time heat map of hiking activities!",
            0
        );
    }

    function registerStoryTime() internal {
        delete items;

        Item memory item1 = Item({
            review: false,
            expire: FUTURE,
            owner: user3,
            title: "Seeing Practice Seeing Clearly by Tara Brach",
            detail: "https://www.youtube.com/embed/aoypkPAB1aA",
            schema: BYTES,
            drip: 0
        });
        Item memory item2 = Item({
            review: false,
            expire: FUTURE,
            owner: user3,
            title: "Feather (feat. Cise Starr &amp; Akin from CYNE)",
            detail: "https://www.youtube.com/embed/hQ5x8pHoIPA",
            schema: BYTES,
            drip: 0
        });
        Item memory item3 = Item({
            review: false,
            expire: FUTURE,
            owner: user3,
            title: "Luv(sic.) pt3 (feat. Shing02)",
            detail: "https://www.youtube.com/embed/Fwv2gnCFDOc",
            schema: BYTES,
            drip: 0
        });
        Item memory item4 = Item({
            review: false,
            expire: FUTURE,
            owner: user3,
            title: "After Hanabi -listen to my beats-",
            detail: "https://www.youtube.com/embed/UkhVp85_BnA",
            schema: BYTES,
            drip: 0
        });
        Item memory item5 = Item({
            review: false,
            expire: FUTURE,
            owner: user3,
            title: "Counting Stars",
            detail: "https://www.youtube.com/embed/IXa0kLOKfwQ",
            schema: BYTES,
            drip: 0
        });

        items.push(item1);
        items.push(item2);
        items.push(item3);
        items.push(item4);
        items.push(item5);

        registerList(account, bulletinAddr, items, unicode"Storytime with Aster // 胖比媽咪說故事", "", 0);
    }

    function registerNujabes() internal {
        delete items;

        Item memory item1 = Item({
            review: false,
            expire: FUTURE,
            owner: user3,
            title: "Aruarian Dance",
            detail: "https://www.youtube.com/embed/HkZ8BitJhvc",
            schema: BYTES,
            drip: 0
        });
        Item memory item2 = Item({
            review: false,
            expire: FUTURE,
            owner: user3,
            title: "Feather (feat. Cise Starr &amp; Akin from CYNE)",
            detail: "https://www.youtube.com/embed/hQ5x8pHoIPA",
            schema: BYTES,
            drip: 0
        });
        Item memory item3 = Item({
            review: false,
            expire: FUTURE,
            owner: user3,
            title: "Luv(sic.) pt3 (feat. Shing02)",
            detail: "https://www.youtube.com/embed/Fwv2gnCFDOc",
            schema: BYTES,
            drip: 0
        });
        Item memory item4 = Item({
            review: false,
            expire: FUTURE,
            owner: user3,
            title: "After Hanabi -listen to my beats-",
            detail: "https://www.youtube.com/embed/UkhVp85_BnA",
            schema: BYTES,
            drip: 0
        });
        Item memory item5 = Item({
            review: false,
            expire: FUTURE,
            owner: user3,
            title: "Counting Stars",
            detail: "https://www.youtube.com/embed/IXa0kLOKfwQ",
            schema: BYTES,
            drip: 0
        });

        items.push(item1);
        items.push(item2);
        items.push(item3);
        items.push(item4);
        items.push(item5);

        registerList(
            account,
            bulletinAddr,
            items,
            "The Nujabes Musical Collection",
            "Just a few tracks from the Japanese legend, the original lo-fi master that inspired the entire chill genre. Enjoy!",
            0
        );
    }
}
