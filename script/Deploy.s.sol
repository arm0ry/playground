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
import {OnboardingSupportToken} from "src/tokens/g0v/OnboardingSupportToken.sol";
import {HackathonSupportToken} from "src/tokens/g0v/HackathonSupportToken.sol";
import {ParticipantSupportToken} from "src/tokens/g0v/ParticipantSupportToken.sol";
import {TokenMinter} from "src/tokens/TokenMinter.sol";
import {ITokenMinter, TokenBuilder, TokenOwner, TokenMetadata} from "src/interface/ITokenMinter.sol";
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
    address currency;
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

        vm.stopBroadcast();
    }

    function deployCommons(address patron, address user, address _gasbuddy) internal {
        // Templates for factory deployment.
        // Log logger = new Log();
        // Bulletin bulletin = new Bulletin();

        // Deploy factory.
        // Factory factory = new Factory(address(mTemplate), address(logger));
        // factoryAddr = address(factory);

        // Deploy quest contract and set gasbuddy.
        deployLogger(false, patron);
        ILog(loggerAddr).grantRoles(gasbuddy, ILog(loggerAddr).GASBUDDIES());

        // Deploy curve.
        deployTokenCurve(patron);
        ITokenCurve(marketAddr).grantRoles(patron, ITokenCurve(marketAddr).LIST_OWNERS());

        // Deploy currency.
        deployCurrency(patron);

        // Deploy bulletin contract and grant .
        deployBulletin(false, patron);
        IBulletin(bulletinAddr).grantRoles(loggerAddr, IBulletin(bulletinAddr).LOGGERS());

        // Prepare lists.
        registerListTutorial();
        registerWildernessPark();
        registerNujabes();
        registerHackath0n();

        // Deploy token minter and uri builder.
        tokenMinterAddr = deployTokenMinter();
        tokenBuilderAddr = deployTokenBuilder();

        // Configure token
        ITokenMinter(tokenMinterAddr).setMinter(
            TokenMetadata({
                name: "Flat Collection Token: Community Onboarding",
                desc: "Flat Collection is a way of collecting donations in local $Currency. The amount of $Currency to collect might reflect personal time involved and any local community values produced as a result of socializing the community service/talent/items from the List.",
                bulletin: bulletinAddr,
                listId: 1,
                logger: loggerAddr
            }),
            TokenBuilder({builder: tokenBuilderAddr, builderId: 1}),
            marketAddr
        );
        uint256 tokenId = ITokenMinter(tokenMinterAddr).tokenId();

        ITokenMinter(tokenMinterAddr).setMinter(
            TokenMetadata({
                name: "Curved Support Token: Wildnerness Park (IRL activities)",
                desc: "Curved Support adds a layer on top of Flat Collection and offers opportunities for supporters to exit. The Flat Collection portion of Curved Support collects donations in $Currency just like above, and it might further include any external values in stablecoins that may enter the local economy as a result of socializing the List.",
                bulletin: bulletinAddr,
                listId: 2,
                logger: loggerAddr
            }),
            TokenBuilder({builder: tokenBuilderAddr, builderId: 1}),
            marketAddr
        );
        uint256 tokenId2 = ITokenMinter(tokenMinterAddr).tokenId();

        ITokenMinter(tokenMinterAddr).setMinter(
            TokenMetadata({
                name: "Curved Support Token 2: Music (IP)",
                desc: "Curved Support is an elegant and efficient way to openly capture and distribute values from positive externalities. Local communities that manage $Currency might decide to subsidize the curve to jumpstart the $Currency economy or as means to provide ongoing support for local commerce.",
                bulletin: bulletinAddr,
                listId: 3,
                logger: loggerAddr
            }),
            TokenBuilder({builder: tokenBuilderAddr, builderId: 1}),
            marketAddr
        );
        uint256 tokenId3 = ITokenMinter(tokenMinterAddr).tokenId();

        ITokenMinter(tokenMinterAddr).setMinter(
            TokenMetadata({
                name: "Harberger Sponsor: g0v Hackath0n [WIP]",
                desc: "In addition to using bonding curve as the pricing and ownership mechanism for a List, we can also use Harberger Tax to maintain (serial) ownership of the Lists. This mechanism might be appropriate for supporters looking for more exclusive ownership and relationship with the owner of the List.",
                bulletin: bulletinAddr,
                listId: 4,
                logger: loggerAddr
            }),
            TokenBuilder({builder: tokenBuilderAddr, builderId: 1}),
            marketAddr
        );
        uint256 tokenId4 = ITokenMinter(tokenMinterAddr).tokenId();

        // Register curves.
        curve1 = Curve({
            owner: patron,
            token: tokenMinterAddr,
            id: tokenId,
            supply: 0,
            curveType: CurveType.LINEAR,
            currency: currency,
            scale: 0.0001 ether,
            mint_a: 0,
            mint_b: 0,
            mint_c: 10,
            burn_a: 0,
            burn_b: 0,
            burn_c: 0
        });
        TokenCurve(marketAddr).registerCurve(curve1);

        curve2 = Curve({
            owner: patron,
            token: tokenMinterAddr,
            id: tokenId2,
            supply: 0,
            curveType: CurveType.LINEAR,
            currency: currency,
            scale: 0.0001 ether,
            mint_a: 0,
            mint_b: 5,
            mint_c: 30,
            burn_a: 0,
            burn_b: 2,
            burn_c: 0
        });
        TokenCurve(marketAddr).registerCurve(curve2);

        curve3 = Curve({
            owner: patron,
            token: tokenMinterAddr,
            id: tokenId3,
            supply: 0,
            curveType: CurveType.QUADRATIC,
            currency: currency,
            scale: 0.0001 ether,
            mint_a: 10,
            mint_b: 10,
            mint_c: 1,
            burn_a: 5,
            burn_b: 5,
            burn_c: 0
        });
        TokenCurve(marketAddr).registerCurve(curve3);

        curve4 = Curve({
            owner: patron,
            token: tokenMinterAddr,
            id: tokenId4,
            supply: 0,
            curveType: CurveType.QUADRATIC,
            currency: currency,
            scale: 0.0001 ether,
            mint_a: 10,
            mint_b: 10,
            mint_c: 1,
            burn_a: 5,
            burn_b: 5,
            burn_c: 0
        });
        TokenCurve(marketAddr).registerCurve(curve4);

        // Update admin.
        // Need this only if deployer account is different from account operating the contract
        Bulletin(payable(bulletinAddr)).transferOwnership(user);

        // Submit mock user input.
        ILog(loggerAddr).log(bulletinAddr, 1, 1, "Alright not too hard to follow!", BYTES);
        ILog(loggerAddr).log(bulletinAddr, 1, 2, "Wow!", BYTES);

        // Mint.
        support(1, patron, 0);
        // (tokenMinterAddr).updateInputs(1, 1, 1);
        // support(2, patron);
        // support(3, patron);
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
        TokenCurve(marketAddr).initialize(user);
    }

    //     function deployHackathonSupportToken(address _bulletinContract, address _loggerAddress, address _marketAddr) internal {
    //         HackathonSupportToken supportToken =
    //             new HackathonSupportToken("g0v Hackathon Support Token", "g0vHST", _loggerAddress, _bulletinContract, _marketAddr);
    //         hackathonContract = address(supportToken);
    //     }

    //     function deployOnboardingSupportToken(
    //         address _bulletinContract,
    //         uint256 _missionId,
    //         address _loggerAddress,
    //         address payable _marketAddr
    //     ) internal {
    //         OnboardingSupportToken supportToken = new OnboardingSupportToken(
    //             "g0v Onboarding Support Token", "g0vOST", _loggerAddress, _bulletinContract, _missionId, _marketAddr
    //         );
    //         onboardingContract = address(supportToken);
    //     }

    //     function deployParticipantSupportToken(address _user, address _loggerAddress, address payable _marketAddr) internal {
    //         ParticipantSupportToken supportToken =
    //             new ParticipantSupportToken("g0v Participant Support Token", "g0vPST", _loggerAddress, _marketAddr);
    //         participantContract = address(supportToken);
    //     }

    function deployTokenMinter() internal returns (address) {
        TokenMinter tokenMinter = new TokenMinter();
        return address(tokenMinter);
    }

    function deployTokenBuilder() internal returns (address) {
        TokenUriBuilder builder = new TokenUriBuilder();
        return address(builder);
    }

    function deployCurrency(address owner) internal returns (address) {
        Currency token = new Currency("Currency", "CURRENCY", owner);
        return address(token);
    }

    function support(uint256 curveId, address patron, uint256 amountInCurrency) internal {
        uint256 price = TokenCurve(marketAddr).getCurvePrice(true, curveId, 0);
        TokenCurve(marketAddr).support{value: price}(curveId, patron, amountInCurrency);
    }

    function registerHackath0n() public {
        delete items;

        Item memory item1 = Item({
            review: false,
            expire: FUTURE,
            owner: user1,
            title: unicode"第陸拾次記得投票黑客松 － 60th Hackath0n",
            detail: "https://g0v.hackmd.io/@jothon/B1IwtQNrT",
            schema: BYTES
        });
        Item memory item2 = Item({
            review: false,
            expire: FUTURE,
            owner: user1,
            title: unicode"第陸拾壹次龍來 Open Data Day 黑客松 － 61st Hackath0n",
            detail: "https://g0v.hackmd.io/@jothon/B1DqSeaK6",
            schema: BYTES
        });

        items.push(item1);
        items.push(item2);

        registerList(
            account,
            bulletinAddr,
            items,
            "g0v bi-monthly Hackath0n",
            "Founded in Taiwan, 'g0v' (gov-zero) is a decentralised civic tech community with information transparency, open results and open cooperation as its core values. g0v engages in public affairs by drawing from the grassroot power of the community."
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
            schema: BYTES
        });
        Item memory item2 = Item({
            review: false,
            expire: FUTURE,
            owner: user2,
            title: "Navigating the 'Create a List' page",
            detail: "https://hackmd.io/@audsssy/rJrera2TT",
            schema: BYTES
        });
        Item memory item3 = Item({
            review: false,
            expire: FUTURE,
            owner: user3,
            title: "Navigating Lists",
            detail: "https://hackmd.io/@audsssy/BkrQSah6p",
            schema: BYTES
        });

        items.push(item1);
        items.push(item2);
        items.push(item3);

        registerList(
            account,
            bulletinAddr,
            items,
            "'Create a List' Tutorial",
            "This is a tutorial to create, and interact with, a list onchain."
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
            schema: BYTES
        });
        Item memory item2 = Item({
            review: false,
            expire: FUTURE,
            owner: user1,
            title: "Trail Post #44",
            detail: "https://www.indianaoutfitters.com/Maps/knobstone_trail/deam_lake_to_jackson_road.jpg",
            schema: BYTES
        });
        Item memory item3 = Item({
            review: false,
            expire: FUTURE,
            owner: user3,
            title: "Trail Post #43",
            detail: "https://www.indianaoutfitters.com/Maps/knobstone_trail/deam_lake_to_jackson_road.jpg",
            schema: BYTES
        });
        Item memory item4 = Item({
            review: false,
            expire: FUTURE,
            owner: user2,
            title: "Trail Post #28",
            detail: "https://www.indianaoutfitters.com/Maps/knobstone_trail/deam_lake_to_jackson_road.jpg",
            schema: BYTES
        });
        Item memory item5 = Item({
            review: false,
            expire: FUTURE,
            owner: user3,
            title: "Trail Post #29",
            detail: "https://www.indianaoutfitters.com/Maps/knobstone_trail/deam_lake_to_jackson_road.jpg",
            schema: BYTES
        });
        Item memory item6 = Item({
            review: false,
            expire: FUTURE,
            owner: user3,
            title: "Trail Post #48",
            detail: "https://www.indianaoutfitters.com/Maps/knobstone_trail/deam_lake_to_jackson_road.jpg",
            schema: BYTES
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
            "Scan QR codes at each trail post to help build a real-time heat map of hiking activities!"
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
            schema: BYTES
        });
        Item memory item2 = Item({
            review: false,
            expire: FUTURE,
            owner: user3,
            title: "Feather (feat. Cise Starr & Akin from CYNE)",
            detail: "https://www.youtube.com/embed/hQ5x8pHoIPA",
            schema: BYTES
        });
        Item memory item3 = Item({
            review: false,
            expire: FUTURE,
            owner: user3,
            title: "Luv(sic.) pt3 (feat. Shing02)",
            detail: "https://www.youtube.com/embed/Fwv2gnCFDOc",
            schema: BYTES
        });
        Item memory item4 = Item({
            review: false,
            expire: FUTURE,
            owner: user3,
            title: "After Hanabi -listen to my beats-",
            detail: "https://www.youtube.com/embed/UkhVp85_BnA",
            schema: BYTES
        });
        Item memory item5 = Item({
            review: false,
            expire: FUTURE,
            owner: user3,
            title: "Counting Stars",
            detail: "https://www.youtube.com/embed/IXa0kLOKfwQ",
            schema: BYTES
        });

        items.push(item1);
        items.push(item2);
        items.push(item3);
        items.push(item4);
        items.push(item5);

        registerList(account, bulletinAddr, items, unicode"Storytime with Aster // 胖比媽咪說故事", "");
    }

    function registerNujabes() internal {
        delete items;

        Item memory item1 = Item({
            review: false,
            expire: FUTURE,
            owner: user3,
            title: "Aruarian Dance",
            detail: "https://www.youtube.com/embed/HkZ8BitJhvc",
            schema: BYTES
        });
        Item memory item2 = Item({
            review: false,
            expire: FUTURE,
            owner: user3,
            title: "Feather (feat. Cise Starr & Akin from CYNE)",
            detail: "https://www.youtube.com/embed/hQ5x8pHoIPA",
            schema: BYTES
        });
        Item memory item3 = Item({
            review: false,
            expire: FUTURE,
            owner: user3,
            title: "Luv(sic.) pt3 (feat. Shing02)",
            detail: "https://www.youtube.com/embed/Fwv2gnCFDOc",
            schema: BYTES
        });
        Item memory item4 = Item({
            review: false,
            expire: FUTURE,
            owner: user3,
            title: "After Hanabi -listen to my beats-",
            detail: "https://www.youtube.com/embed/UkhVp85_BnA",
            schema: BYTES
        });
        Item memory item5 = Item({
            review: false,
            expire: FUTURE,
            owner: user3,
            title: "Counting Stars",
            detail: "https://www.youtube.com/embed/IXa0kLOKfwQ",
            schema: BYTES
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
            "Just a few tracks from the Japanese legend, the original lo-fi master that inspired the entire chill genre. Enjoy!"
        );
    }

    function registerList(
        address user,
        address bulletin,
        Item[] memory _items,
        string memory listTitle,
        string memory listDetail
    ) internal {
        delete itemIds;
        uint256 itemId = IBulletin(bulletinAddr).itemId();

        IBulletin(bulletinAddr).registerItems(_items);

        for (uint256 i = 1; i <= _items.length; ++i) {
            itemIds.push(itemId + i);
        }

        List memory list = List({owner: user, title: listTitle, detail: listDetail, schema: BYTES, itemIds: itemIds});
        IBulletin(bulletinAddr).registerList(list);
    }
}
