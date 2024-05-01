// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {Log} from "src/Log.sol";
import {ILog, Activity, Touchpoint} from "interface/ILog.sol";
import {Bulletin} from "src/Bulletin.sol";
import {IBulletin, List, Item} from "interface/IBulletin.sol";

import {Factory} from "src/Factory.sol";
import {ImpactCurve} from "src/ImpactCurve.sol";

import {IImpactCurve, CurveType} from "interface/IImpactCurve.sol";
import {OnboardingSupportToken} from "tokens/g0v/OnboardingSupportToken.sol";
import {HackathonSupportToken} from "tokens/g0v/HackathonSupportToken.sol";
import {ParticipantSupportToken} from "tokens/g0v/ParticipantSupportToken.sol";
import {ListToken} from "tokens/ListToken.sol";
import {IListToken} from "interface/IListToken.sol";

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
    address bulletinAddress = payable(address(0));
    address loggerAddress = address(0);
    address factoryAddress = address(0);
    address payable icContract = payable(address(0));

    // Tokens.
    // address hackathonContract;
    // address onboardingContract;
    // address participantContract;
    address listTokenAddress;
    address listToken2Address;
    address listToken3Address;

    // Users.
    address user1 = address(0x4744cda32bE7b3e75b9334001da9ED21789d4c0d);
    address user2 = address(0xFB12B6A543d986A1938d2b3C7d05848D8913AcC4);
    address user3 = address(0x85E70769d04Be1C9d7C3c373b98BD9929f61F428);
    address gasbuddy = address(0x7Cf60ec5A5541b7d4073F795a67A75E383F3FFFf);

    // Prep for item submission.
    Item[] items;

    // Prep for list submission.
    uint256[] itemIds;

    /// @notice The main script entrypoint.
    function run() external {
        uint256 privateKey = vm.envUint("DEV_PRIVATE_KEY");
        address account = vm.addr(privateKey);

        console2.log("Account", account);

        vm.startBroadcast(privateKey);

        // TODO: g0v
        // deployG0vPlayground(account, user1, user2, gasbuddy);
        // deployParticipantSupportToken(user1, loggerAddress, icContract);

        // deployHackath0n(user1);
        // deployHackath0nLunch(user1);
        // deployBoringStation(account);

        // TODO: commons
        deployCommons(account, user1, gasbuddy);

        vm.stopBroadcast();
    }

    //     function deployG0vPlayground(address patron, address user, address user2, address gasbuddy) internal {
    //         // Templates for factory deployment.
    //         Quest qTemplate = new Quest();
    //         Mission mTemplate = new Mission();

    //         // 1. Deploy factory.
    //         // Factory factory = new Factory(address(mTemplate),  address(qTemplate));
    //         // factoryAddress = address(factory);

    //         // 2. Deploy quest contract and set gasbuddy.
    //         deployLogger(patron);
    //         Quest(loggerAddress).setgasbuddy(gasbuddy);
    //         Quest(loggerAddress).setDao(user);

    //         // 3. Deploy curves.
    //         deployImpactCurve(user);

    //         // 4. Deploy mission contract, and set bonding curve as pricing model for paying to set tasks and missions.
    //         deployBulletin(patron);
    //         // Mission(bulletinAddress).setFee(0);

    //         // 5. Deploy support tokens.
    //         deployHackathonSupportToken(bulletinAddress, loggerAddress, icContract);
    //         deployOnboardingSupportToken(bulletinAddress, 1, loggerAddress, icContract);
    //         deployParticipantSupportToken(user, loggerAddress, icContract);

    //         // 6. Set curves.
    //         ImpactCurve(icContract).curve(CurveType.LINEAR, hackathonContract, user, 0.00001 ether, 0, 10, 0, 0, 5, 0);
    //         ImpactCurve(icContract).curve(CurveType.LINEAR, onboardingContract, user, 0.00001 ether, 0, 10, 0, 0, 2, 0);
    //         ImpactCurve(icContract).curve(
    //             CurveType.QUADRATIC, participantContract, user, 0.00001 ether, 10, 20, 0, 5, 20, 0
    //         );

    //         // 7. Prepare hackathon.
    //         // deployHackath0n(user);
    //         // deployHackath0nLunch(user);
    //         // deployBoringStation(user);

    //         // 8. Authorize quest contract to record stats in mission contract.
    //         Mission(bulletinAddress).authorizeQuest(loggerAddress, true);

    //         // 9. Update admin.
    //         // Need this only if deployer account is different from account operating the contract
    //         Mission(bulletinAddress).setDao(user);

    //         // 10. Submit mock user input.
    //         Quest(loggerAddress).start(address(bulletinAddress), 1);
    //         Quest(loggerAddress).respond(address(bulletinAddress), 1, 2, 1100111, unicode"去大松學到好多東西喔！");

    //         // 11. Configure support tokens.
    //         HackathonSupportToken(hackathonContract).setSvgInputs(1, 2);
    //         OnboardingSupportToken(onboardingContract).tally(2);

    //         // 12. Mint support.
    //         support(1, patron);
    //         support(2, patron);
    //         support(3, patron);

    //         // 13. Customize support tokens.
    //         ParticipantSupportToken(participantContract).populate(1, 1);
    //     }

    function deployCommons(address patron, address user, address _gasbuddy) internal {
        // Templates for factory deployment.
        // Log logger = new Log();
        // Bulletin bulletin = new Bulletin();

        // Deploy factory.
        // Factory factory = new Factory(address(mTemplate), address(logger));
        // factoryAddress = address(factory);

        // Deploy quest contract and set gasbuddy.
        deployLogger(false, patron);
        ILog(loggerAddress).grantRoles(gasbuddy, ILog(loggerAddress).GASBUDDIES());

        // Deploy curves.
        deployImpactCurve(patron);

        // Deploy bulletin contract and grant .
        deployBulletin(false, patron);
        IBulletin(bulletinAddress).grantRoles(loggerAddress, IBulletin(bulletinAddress).LOGGERS());

        // Deploy list tokens and set curves.
        listTokenAddress = deployListToken(bulletinAddress, icContract);
        ImpactCurve(icContract).curve(CurveType.QUADRATIC, listTokenAddress, user1, 0.0001 ether, 25, 15, 10, 0, 10, 5);

        listToken2Address = deployListToken(bulletinAddress, icContract);
        ImpactCurve(icContract).curve(CurveType.QUADRATIC, listToken2Address, user2, 0.0001 ether, 5, 15, 10, 0, 10, 5);

        listToken3Address = deployListToken(bulletinAddress, icContract);
        ImpactCurve(icContract).curve(
            CurveType.QUADRATIC, listToken3Address, user3, 0.0001 ether, 8, 88, 888, 4, 44, 444
        );

        // Prepare lists.
        deployListTutorial();
        deployWildernessPark();
        deployNujabes();

        // Update admin.
        // Need this only if deployer account is different from account operating the contract
        Bulletin(payable(bulletinAddress)).transferOwnership(user);

        // Submit mock user input.
        ILog(loggerAddress).log(bulletinAddress, 1, 1, "Alright not too hard to follow!", BYTES);
        ILog(loggerAddress).log(bulletinAddress, 1, 2, "Wow!", BYTES);

        // Mint.
        support(1, patron);
        IListToken(listTokenAddress).updateInputs(1, 1, 1);
        // support(2, patron);
        // support(3, patron);
    }

    function deployBulletin(bool factory, address user) internal {
        delete bulletinAddress;

        if (factory) {
            bulletinAddress = Factory(factoryAddress).deployBulletin(user);
        } else {
            bulletinAddress = address(new Bulletin());
        }
        IBulletin(payable(bulletinAddress)).initialize(user);
    }

    function deployLogger(bool factory, address user) internal {
        delete loggerAddress;

        if (factory) {
            loggerAddress = Factory(factoryAddress).deployLogger(user);
        } else {
            loggerAddress = address(new Log());
        }
        ILog(loggerAddress).initialize(user);
    }

    function deployImpactCurve(address user) internal {
        delete icContract;

        icContract = payable(address(new ImpactCurve()));
        ImpactCurve(icContract).initialize(user);
    }

    //     function deployHackathonSupportToken(address _bulletinContract, address _loggerAddress, address _icContract) internal {
    //         HackathonSupportToken supportToken =
    //             new HackathonSupportToken("g0v Hackathon Support Token", "g0vHST", _loggerAddress, _bulletinContract, _icContract);
    //         hackathonContract = address(supportToken);
    //     }

    //     function deployOnboardingSupportToken(
    //         address _bulletinContract,
    //         uint256 _missionId,
    //         address _loggerAddress,
    //         address payable _icContract
    //     ) internal {
    //         OnboardingSupportToken supportToken = new OnboardingSupportToken(
    //             "g0v Onboarding Support Token", "g0vOST", _loggerAddress, _bulletinContract, _missionId, _icContract
    //         );
    //         onboardingContract = address(supportToken);
    //     }

    //     function deployParticipantSupportToken(address _user, address _loggerAddress, address payable _icContract) internal {
    //         ParticipantSupportToken supportToken =
    //             new ParticipantSupportToken("g0v Participant Support Token", "g0vPST", _loggerAddress, _icContract);
    //         participantContract = address(supportToken);
    //     }

    function deployListToken(address _bulletinContract, address payable _icContract) internal returns (address) {
        ListToken token = new ListToken("List Token", "LT", _bulletinContract, _icContract);
        return address(token);
    }

    function support(uint256 curveId, address patron) internal {
        uint256 price = ImpactCurve(icContract).getCurvePrice(true, curveId, 0);
        ImpactCurve(icContract).support{value: price}(curveId, patron, price);
    }

    function deployListTutorial() internal {
        delete items;
        delete itemIds;

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
        IBulletin(bulletinAddress).registerItems(items);

        itemIds.push(1);
        itemIds.push(2);
        itemIds.push(3);
        List memory list = List({
            owner: user1,
            title: "'Create a List' Tutorial",
            detail: "This is a tutorial to create, and interact with, a list onchain.",
            schema: BYTES,
            itemIds: itemIds
        });
        IBulletin(bulletinAddress).registerList(list);
    }

    function deployWildernessPark() internal {
        delete items;
        delete itemIds;

        Item memory item1 = Item({
            review: false,
            expire: FUTURE,
            owner: user2,
            title: "Trail Post #1",
            detail: "https://www.indianaoutfitters.com/Maps/knobstone_trail/deam_lake_to_jackson_road.jpg",
            schema: BYTES
        });
        Item memory item2 = Item({
            review: false,
            expire: FUTURE,
            owner: user1,
            title: "Trail Post #2",
            detail: "https://www.indianaoutfitters.com/Maps/knobstone_trail/deam_lake_to_jackson_road.jpg",
            schema: BYTES
        });
        Item memory item3 = Item({
            review: false,
            expire: FUTURE,
            owner: user3,
            title: "Trail Post #3",
            detail: "https://www.indianaoutfitters.com/Maps/knobstone_trail/deam_lake_to_jackson_road.jpg",
            schema: BYTES
        });
        Item memory item4 = Item({
            review: false,
            expire: FUTURE,
            owner: user2,
            title: "Trail Post #4",
            detail: "https://www.indianaoutfitters.com/Maps/knobstone_trail/deam_lake_to_jackson_road.jpg",
            schema: BYTES
        });
        Item memory item5 = Item({
            review: false,
            expire: FUTURE,
            owner: user3,
            title: "Trail Post #5",
            detail: "https://www.indianaoutfitters.com/Maps/knobstone_trail/deam_lake_to_jackson_road.jpg",
            schema: BYTES
        });

        items.push(item1);
        items.push(item2);
        items.push(item3);
        items.push(item4);
        items.push(item5);
        IBulletin(bulletinAddress).registerItems(items);

        itemIds.push(1);
        itemIds.push(2);
        itemIds.push(3);
        itemIds.push(4);
        itemIds.push(5);
        List memory list = List({
            owner: user2,
            title: "TESTNET Wilderness Park",
            detail: "Scan QR codes at each trail post to help the trail rangers build a real-time heat map of hiking activities!",
            schema: BYTES,
            itemIds: itemIds
        });
        IBulletin(bulletinAddress).registerList(list);
    }

    function deployNujabes() internal {
        delete items;
        delete itemIds;

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
        IBulletin(bulletinAddress).registerItems(items);

        itemIds.push(1);
        itemIds.push(2);
        itemIds.push(3);
        itemIds.push(4);
        itemIds.push(5);
        List memory list = List({
            owner: user3,
            title: "The Nujabes Musical Collection",
            detail: "Just a few tracks from the Japanese legend, the original lo-fi master that inspired the entire chill genre. Enjoy!",
            schema: BYTES,
            itemIds: itemIds
        });
        IBulletin(bulletinAddress).registerList(list);
    }
}
