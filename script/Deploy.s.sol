// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Script} from "forge-std/Script.sol";
import "forge-std/console.sol";

import {Mission} from "src/Mission.sol";
import {Quest} from "src/Quest.sol";
import {Factory} from "src/Factory.sol";
import {ImpactCurve} from "src/ImpactCurve.sol";

import {IImpactCurve, CurveType} from "../src/interface/IImpactCurve.sol";
import {OnboardingSupportToken} from "src/tokens/g0v/OnboardingSupportToken.sol";
import {HackathonSupportToken} from "src/tokens/g0v/HackathonSupportToken.sol";
import {ParticipantSupportToken} from "src/tokens/g0v/ParticipantSupportToken.sol";

/// @notice A very simple deployment script
contract Deploy is Script {
    event Tasks(
        address[] _taskCreators, uint256[] _taskDeadlines, string[] _taskTitles, string[] taskDetail, uint256[] taskIds
    );
    event TaskArray(address[] _taskCreators, uint256[] _taskDeadlines, string[] _taskTitles, string[] taskDetail);

    error Invalid();

    // Constant.
    uint256 constant past = 100000;
    uint256 constant future = 2527482181;

    // Contracts.
    address mContract = address(0);
    address qContract = address(0);
    address fContract = address(0);
    address payable icContract = payable(address(0));

    // Tokens.
    address hackathonContract;
    address onboardingContract;
    address participantContract;

    // Prep for task submission.
    address[] taskCreators;
    uint256[] taskDeadlines;
    string[] taskTitles;
    string[] taskDetail;

    // Prep for mission submission.
    uint256[] taskIds;

    /// @notice The main script entrypoint.
    function run() external {
        uint256 privateKey = vm.envUint("DEV_PRIVATE_KEY");
        address account = vm.addr(privateKey);

        console.log("Account", account);

        address user1 = address(0x4744cda32bE7b3e75b9334001da9ED21789d4c0d);
        address user2 = address(0xFB12B6A543d986A1938d2b3C7d05848D8913AcC4);
        address gasbot = address(0x7Cf60ec5A5541b7d4073F795a67A75E383F3FFFf);

        vm.startBroadcast(privateKey);

        // TODO: g0v
        // deployG0vPlayground(account, user1, user2, gasbot);
        // deployParticipantSupportToken(user1, qContract, icContract);

        // deployHackath0n(user1);
        // deployHackath0nLunch(user1);
        // deployBoringStation(account);

        // TODO: commons
        deployCommons(account, user1, gasbot);

        vm.stopBroadcast();
    }

    function deployG0vPlayground(address patron, address user, address user2, address gasbot) internal {
        // Templates for factory deployment.
        Quest qTemplate = new Quest();
        Mission mTemplate = new Mission();

        // 1. Deploy factory.
        // Factory factory = new Factory(address(mTemplate),  address(qTemplate));
        // fContract = address(factory);

        // 2. Deploy quest contract and set gasbot.
        deployQuest(patron);
        Quest(qContract).setGasbot(gasbot);
        Quest(qContract).setDao(user);

        // 3. Deploy curves.
        deployImpactCurve(user);

        // 4. Deploy mission contract, and set bonding curve as pricing model for paying to set tasks and missions.
        deployMission(patron);
        // Mission(mContract).setFee(0);

        // 5. Deploy support tokens.
        deployHackathonSupportToken(mContract, qContract, icContract);
        deployOnboardingSupportToken(mContract, 1, qContract, icContract);
        deployParticipantSupportToken(user, qContract, icContract);

        // 6. Set curves.
        ImpactCurve(icContract).curve(CurveType.LINEAR, hackathonContract, user, 0.00001 ether, 0, 10, 0, 0, 5, 0);
        ImpactCurve(icContract).curve(CurveType.LINEAR, onboardingContract, user, 0.00001 ether, 0, 10, 0, 0, 2, 0);
        ImpactCurve(icContract).curve(CurveType.POLY, participantContract, user, 0.00001 ether, 10, 20, 0, 5, 20, 0);

        // 7. Prepare hackathon.
        deployHackath0n(user);
        deployHackath0nLunch(user);
        deployBoringStation(user);

        // 8. Authorize quest contract to record stats in mission contract.
        Mission(mContract).authorizeQuest(qContract, true);

        // 9. Update admin.
        // Need this only if deployer account is different from account operating the contract
        Mission(mContract).setDao(user);

        // 10. Submit mock user input.
        Quest(qContract).start(address(mContract), 1);
        Quest(qContract).respond(address(mContract), 1, 2, 1100111, "I went to 61st hackathon! It was so fun~");

        // 11. Configure support tokens.
        HackathonSupportToken(hackathonContract).setSvgInputs(1, 2);
        OnboardingSupportToken(onboardingContract).tally(2);

        // 12. Mint support.
        support(1, patron);
        support(2, patron);
        support(3, patron);

        // 13. Customize support tokens.
        ParticipantSupportToken(participantContract).populate(1, 1);
    }

    function deployCommons(address patron, address user, address gasbot) internal {
        // Templates for factory deployment.
        Quest qTemplate = new Quest();
        Mission mTemplate = new Mission();

        // 1. Deploy factory.
        Factory factory = new Factory(address(mTemplate),  address(qTemplate));
        fContract = address(factory);

        // 2. Deploy quest contract and set gasbot.
        deployQuest(patron);
        Quest(qContract).setGasbot(gasbot);
        Quest(qContract).setDao(user);

        // 3. Deploy curves.
        // deployImpactCurve(user);

        // 4. Deploy mission contract, and set bonding curve as pricing model for paying to set tasks and missions.
        deployMission(patron);
        // Mission(mContract).setFee(0);

        // 5. Deploy support tokens.
        // deployHackathonSupportToken(mContract, qContract, icContract);
        // deployOnboardingSupportToken(mContract, 1, qContract, icContract);
        // deployParticipantSupportToken(user, qContract, icContract);

        // 6. Set curves.
        // ImpactCurve(icContract).curve(CurveType.LINEAR, hackathonContract, user, 0.00001 ether, 0, 10, 0, 0, 5, 0);
        // ImpactCurve(icContract).curve(CurveType.LINEAR, onboardingContract, user, 0.00001 ether, 0, 10, 0, 0, 2, 0);
        // ImpactCurve(icContract).curve(CurveType.POLY, participantContract, user, 0.00001 ether, 10, 20, 0, 5, 20, 0);

        // 7. Prepare hackathon.
        // deployHackath0n(user);
        // deployHackath0nLunch(user);
        // deployBoringStation(user);

        // 8. Authorize quest contract to record stats in mission contract.
        Mission(mContract).authorizeQuest(qContract, true);

        // 9. Update admin.
        // Need this only if deployer account is different from account operating the contract
        Mission(mContract).setDao(user);

        // 10. Submit mock user input.
        // Quest(qContract).start(address(mContract), 1);
        // Quest(qContract).respond(address(mContract), 1, 2, 1100111, "I went to 61st hackathon! It was so fun~");

        // 11. Configure support tokens.
        // HackathonSupportToken(hackathonContract).setSvgInputs(1, 2);
        // OnboardingSupportToken(onboardingContract).tally(2);

        // 12. Mint support.
        // support(1, patron);
        // support(2, patron);
        // support(3, patron);

        // 13. Customize support tokens.
        // ParticipantSupportToken(participantContract).populate(1, 1);
    }

    function deployMission(address user) internal {
        mContract = Factory(fContract).deployMission(user);
        Mission(mContract).initialize(user);
    }

    function deployQuest(address user) internal {
        qContract = Factory(fContract).deployQuest(user);
        Quest(qContract).initialize(user);
    }

    function deployImpactCurve(address user) internal {
        icContract = payable(address(new ImpactCurve()));
        ImpactCurve(icContract).initialize(user);
    }

    function deployHackathonSupportToken(address _mContract, address _qContract, address _icContract) internal {
        HackathonSupportToken supportToken =
            new HackathonSupportToken("g0v Hackathon Support Token", "g0vHST", _qContract, _mContract, _icContract);
        hackathonContract = address(supportToken);
    }

    function deployOnboardingSupportToken(
        address _mContract,
        uint256 _missionId,
        address _qContract,
        address payable _icContract
    ) internal {
        OnboardingSupportToken supportToken =
        new OnboardingSupportToken("g0v Onboarding Support Token", "g0vOST", _qContract, _mContract, _missionId, _icContract);
        onboardingContract = address(supportToken);
    }

    function deployParticipantSupportToken(address _user, address _qContract, address payable _icContract) internal {
        ParticipantSupportToken supportToken =
            new ParticipantSupportToken("g0v Participant Support Token", "g0vPST", _qContract, _icContract);
        participantContract = address(supportToken);
    }

    function support(uint256 curveId, address patron) internal {
        uint256 price = ImpactCurve(icContract).getCurvePrice(true, curveId, 0);
        ImpactCurve(icContract).support{value: price}(curveId, patron, price);
    }

    function deployBoringStation(address creator) internal {
        // Clear arrarys.
        delete taskCreators;
        delete taskDeadlines;
        delete taskTitles;
        delete taskDetail;
        delete taskIds;

        // Add first task.
        taskCreators.push(creator);
        taskDeadlines.push(future);
        taskTitles.push(unicode"冥想三分鐘 | 3 min meditation");
        taskDetail.push("Guided meditation...");

        // Add second task.
        taskCreators.push(creator);
        taskDeadlines.push(future);
        taskTitles.push(unicode"冥想五分鐘 | 5 min meditation");
        taskDetail.push("Guided meditation...");

        // Add third task.
        taskCreators.push(creator);
        taskDeadlines.push(future);
        taskTitles.push(unicode"冥想十五分鐘 | 15 min meditation");
        taskDetail.push("Guided meditation...");

        // Add fourth task.
        taskCreators.push(creator);
        taskDeadlines.push(future);
        taskTitles.push(unicode"自由伸展 | stretch");
        taskDetail.push("Ways to stretch for max relaxation");

        // Add fifth task.
        taskCreators.push(creator);
        taskDeadlines.push(future);
        taskTitles.push(unicode"拼拼圖 | help with jigsaw puzzle");
        taskDetail.push(unicode"找 Zoey");

        setNewTasksAndMission(
            taskCreators.length,
            creator,
            unicode"無聊小站 | Bored Station",
            unicode"休息一下，站起來走一走，等等回來再繼續！ Move around, take a break, and touch some grass!"
        );
    }

    function deployHackath0n(address _user) internal {
        // Clear arrarys.
        delete taskCreators;
        delete taskDeadlines;
        delete taskTitles;
        delete taskDetail;
        delete taskIds;

        taskCreators.push(_user);
        taskDeadlines.push(past);
        taskTitles.push(unicode"第陸拾次記得投票黑客松 － 60th Hackath0n");
        taskDetail.push("https://g0v.hackmd.io/@jothon/B1IwtQNrT");

        taskCreators.push(_user);
        taskDeadlines.push(future);
        taskTitles.push(unicode"第陸拾壹次龍來 Open Data Day 黑客松 － 61st Hackath0n");
        taskDetail.push("https://g0v.hackmd.io/@jothon/B1DqSeaK6");

        setNewTasksAndMission(
            taskCreators.length,
            _user,
            unicode"台灣零時政府黑客松",
            unicode"自台灣發起、多中心化的公民科技社群「零時政府」，以資訊透明、開放成果、開放協作為核心，透過群眾草根的力量來關心公共事務。 Founded in Taiwan, 'g0v' (gov-zero) is a decentralised civic tech community with information transparency, open results and open cooperation as its core values. g0v engages in public affairs by drawing from the grassroot power of the community."
        );
    }

    function deployHackath0nLunch(address user) internal {
        // Clear arrarys.
        delete taskCreators;
        delete taskDeadlines;
        delete taskTitles;
        delete taskDetail;
        delete taskIds;

        taskCreators.push(user);
        taskDeadlines.push(future);
        taskTitles.push(unicode"🍲 素 - 什錦炒飯 ｜ Vegetarian - Mixed Vegetable Fried Rice");
        taskDetail.push(unicode"食材(Ingredients)... 產地(From)...");

        taskCreators.push(user);
        taskDeadlines.push(future);
        taskTitles.push(
            unicode"🍲 素 - 時蔬炒米粉 ｜ Vegetarian - Stir-Fried Rice Vermicelli with Seasonal Vegetables"
        );
        taskDetail.push(unicode"食材(Ingredients)... 產地(From)...");

        taskCreators.push(user);
        taskDeadlines.push(future);
        taskTitles.push(unicode"🍲 素 - 青江燴菇 ｜ Vegetarian - Braised Mushrooms with Choy Sum ");
        taskDetail.push(unicode"食材(Ingredients)... 產地(From)...");

        taskCreators.push(user);
        taskDeadlines.push(future);
        taskTitles.push(unicode"🥘 XO醬彩椒雞柳 ｜ XO Sauce Bell Pepper Chicken Fillet ");
        taskDetail.push(unicode"食材(Ingredients)... 產地(From)...");

        taskCreators.push(user);
        taskDeadlines.push(future);
        taskTitles.push(unicode"🥘 奶油檸檬魚排 ｜ Creamy Lemon Fish Fillet ");
        taskDetail.push(unicode"食材(Ingredients)... 產地(From)...");

        taskCreators.push(user);
        taskDeadlines.push(future);
        taskTitles.push(unicode"🫕 熱 - 芋頭西米露 ｜ Hot - Taro Sago Dessert");
        taskDetail.push(unicode"食材(Ingredients)... 產地(From)...");

        taskCreators.push(user);
        taskDeadlines.push(future);
        taskTitles.push(unicode"🍖 炸雞 ｜ Fried Chicken ");
        taskDetail.push(unicode"食材(Ingredients)... 產地(From)...");

        taskCreators.push(user);
        taskDeadlines.push(future);
        taskTitles.push(unicode"🍕 Pizza");
        taskDetail.push(unicode"請 also 在心得欄分享你 pizza 的選擇！");

        taskCreators.push(user);
        taskDeadlines.push(future);
        taskTitles.push(unicode"🥤 飲料 ｜ Beverage ");
        taskDetail.push(unicode"請 also 在心得欄分享你喝了哪些飲料！");

        setNewTasksAndMission(
            taskCreators.length,
            user,
            unicode"台灣零時政府當次黑客松之午餐",
            unicode"自台灣發起、多中心化的公民科技社群「零時政府」，以資訊透明、開放成果、開放協作為核心，透過群眾草根的力量來關心公共事務。 Founded in Taiwan, 'g0v' (gov-zero) is a decentralised civic tech community with information transparency, open results and open cooperation as its core values. g0v engages in public affairs by drawing from the grassroot power of the community."
        );
    }

    function _createNewTask(address user, uint256 expiration, string calldata title, string calldata detail) internal {
        // Add one task.
        taskCreators.push(user);
        taskDeadlines.push(expiration);
        taskTitles.push(title);
        taskDetail.push(detail);

        // Submit tasks onchain.
        Mission(mContract).payToSetTasks{value: ImpactCurve(icContract).getCurvePrice(true, 1, 0)}(
            taskCreators, taskDeadlines, taskTitles, taskDetail
        );
    }

    function _createNewTasks(uint256 taskCount) internal returns (uint256[] memory) {
        // Retrieve task id.
        uint256 taskId = Mission(mContract).getTaskId();

        // Build task id array.
        for (uint256 i; i < taskCount; i++) {
            taskIds.push(taskId + i + 1);
        }

        // Submit tasks onchain.
        Mission(mContract).payToSetTasks{value: ImpactCurve(icContract).getCurvePrice(true, 1, 0)}(
            taskCreators, taskDeadlines, taskTitles, taskDetail
        );

        emit TaskArray(taskCreators, taskDeadlines, taskTitles, taskDetail);

        return taskIds;
    }

    function _createNewMission(address creator, string memory title, string memory detail, uint256[] memory _taskIds)
        internal
    {
        // Submit mission onchain.
        Mission(mContract).payToSetMission{value: ImpactCurve(icContract).getCurvePrice(true, 1, 0)}(
            creator, title, detail, _taskIds
        );
    }

    function setNewTasksAndMission(
        uint256 taskCount,
        address _missionCreator,
        string memory _title,
        string memory _missionDetail
    ) internal {
        taskIds = _createNewTasks(taskCount);
        _createNewMission(_missionCreator, _title, _missionDetail, taskIds);
    }
}
