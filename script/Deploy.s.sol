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
    error Invalid();

    // Constant.
    uint256 constant past = 100000;
    uint256 constant future = 2527482181;

    // Contracts.
    address mContract = address(0x63695B447E02D2D36FB2178b964CA8ce20bBF99B);
    address qContract = address(0);
    address fContract;
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

        deployG0vPlayground(account, user1, user2, gasbot);
        // deployParticipantSupportToken(user1, qContract, icContract);

        // deployFoodList(user2);
        // deployMeditationJourney(user1);

        vm.stopBroadcast();
    }

    function deployG0vPlayground(address patron, address user, address user2, address gasbot) internal {
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
        deployImpactCurve(user);

        // 4. Deploy mission contract, and set bonding curve as pricing model for paying to set tasks and missions.
        deployMission(patron);
        Mission(mContract).setPriceCurve(icContract, 1);

        // 5. Deploy support tokens.
        deployHackathonSupportToken(mContract, qContract, icContract);
        deployOnboardingSupportToken(mContract, 1, qContract, icContract);
        deployParticipantSupportToken(user, qContract, icContract);

        // 6. Set curves.
        ImpactCurve(icContract).curve(CurveType.LINEAR, hackathonContract, user, 0.0001 ether, 0, 10, 0, 0, 5, 0);
        ImpactCurve(icContract).curve(CurveType.LINEAR, onboardingContract, user, 0.0001 ether, 0, 10, 0, 0, 2, 0);
        ImpactCurve(icContract).curve(CurveType.POLY, participantContract, user, 0.0001 ether, 10, 20, 0, 5, 20, 0);

        // 7. Prepare hackathon.
        deployHackath0n(user, user2);
        deployHackath0nLunch(user);

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
        ParticipantSupportToken(participantContract).populate(1, 1);

        // 12. Mint support.
        support(1, patron);
        support(2, patron);
        support(3, patron);
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

    function deployFoodList(address creator) internal {
        // Clear arrarys.
        delete taskCreators;
        delete taskDeadlines;
        delete taskTitles;
        delete taskDetail;
        delete taskIds;

        // Add first task.
        taskCreators.push(creator);
        taskDeadlines.push(future);
        taskTitles.push(unicode"滷肉飯");
        taskDetail.push(unicode"食材...");

        // Add second task.
        taskCreators.push(creator);
        taskDeadlines.push(future);
        taskTitles.push(unicode"瀨尿牛肉丸");
        taskDetail.push(unicode"食材...");

        // Add third task.
        taskCreators.push(creator);
        taskDeadlines.push(future);
        taskTitles.push(unicode"臭豆腐");
        taskDetail.push(unicode"食材...");

        setNewTasksAndMission(
            taskCreators,
            taskDeadlines,
            taskTitles,
            taskDetail,
            creator,
            unicode"臭豆腐大王",
            unicode"好吃，新奇又好玩！ 食神好棒～"
        );
    }

    function deployMeditationJourney(address creator) internal {
        // Clear arrarys.
        delete taskCreators;
        delete taskDeadlines;
        delete taskTitles;
        delete taskDetail;
        delete taskIds;

        // Add first task.
        taskCreators.push(creator);
        taskDeadlines.push(future);
        taskTitles.push("Day 1. Peace flows where mindfulness goes.");
        taskDetail.push("Guided meditation...");

        // Add second task.
        taskCreators.push(creator);
        taskDeadlines.push(future);
        taskDetail.push("Day 2. Silence is the language of the soul.");
        taskDetail.push("Guided meditation...");

        // Add third task.
        taskCreators.push(creator);
        taskDeadlines.push(future);
        taskTitles.push("Day 3. Breathe in calm, breathe out chaos.");
        taskDetail.push("Guided meditation...");

        // Add fourth task.
        taskCreators.push(creator);
        taskDeadlines.push(future);
        taskTitles.push("Day 4. Stillness is the key to understanding.");
        taskDetail.push("Guided meditation...");

        // Add fifth task.
        taskCreators.push(creator);
        taskDeadlines.push(future);
        taskTitles.push("Day 5. In quietude, truth whispers.");
        taskDetail.push("Guided meditation...");

        // Add sixth task.
        taskCreators.push(creator);
        taskDeadlines.push(future);
        taskTitles.push("Day 6. Let go, and let flow in meditation.");
        taskDetail.push("Guided meditation...");

        // Add seventh task.
        taskCreators.push(creator);
        taskDeadlines.push(future);
        taskTitles.push("Day 7. Rooted in silence, blossoming in peace.");
        taskDetail.push("Guided meditation...");

        setNewTasksAndMission(
            taskCreators,
            taskDeadlines,
            taskTitles,
            taskDetail,
            creator,
            "Days of Mindful Living",
            "An onchain journey to infuse daily life with mindfulness practices. Inhale deeply, feeling calmness spread, and exhale slowly, letting all stress melt away. Sink deeper with each breath, letting peace envelop your being."
        );
    }

    function deployHackath0n(address user, address user2) internal {
        // Clear arrarys.
        delete taskCreators;
        delete taskDeadlines;
        delete taskTitles;
        delete taskDetail;
        delete taskIds;

        // Add first task.
        taskCreators.push(user);
        taskDeadlines.push(past);
        taskTitles.push(unicode"第陸拾次記得投票黑客松 － 60th Hackath0n");
        taskDetail.push("https://g0v.hackmd.io/@jothon/B1IwtQNrT");

        // Add second task.
        taskCreators.push(user);
        taskDeadlines.push(future);
        taskTitles.push(unicode"第陸拾壹次龍來 Open Data Day 黑客松 － 61st Hackath0n");
        taskDetail.push("https://g0v.hackmd.io/@jothon/B1DqSeaK6");

        setNewTasksAndMission(
            taskCreators,
            taskDeadlines,
            taskTitles,
            taskDetail,
            user,
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

        // Add first task.
        taskCreators.push(user);
        taskDeadlines.push(future);
        taskTitles.push(unicode"炸雞 － Fried Chicken");
        taskDetail.push(unicode"食材(Ingredients)... 產地(From)...");

        // Add second task.
        taskCreators.push(user);
        taskDeadlines.push(future);
        taskTitles.push(unicode"冰紅茶 - Iced Black Tea");
        taskDetail.push(unicode"食材(Ingredients)... 產地(From)...");

        // Add third task.
        taskCreators.push(user);
        taskDeadlines.push(future);
        taskTitles.push(unicode"熱紅茶 － Hot Black Tea");
        taskDetail.push(unicode"食材(Ingredients)... 產地(From)...");

        // Add fourth task.j
        taskCreators.push(user);
        taskDeadlines.push(future);
        taskTitles.push(unicode"壽司  － Sushi");
        taskDetail.push(unicode"食材(Ingredients)... 產地(From)...");

        // Add fifth task.
        taskCreators.push(user);
        taskDeadlines.push(future);
        taskTitles.push(unicode"炒飯 － Fried Rice");
        taskDetail.push(unicode"食材(Ingredients)... 產地(From)...");

        setNewTasksAndMission(
            taskCreators,
            taskDeadlines,
            taskTitles,
            taskDetail,
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

    function _createNewTasks(
        address[] memory users,
        uint256[] memory expirations,
        string[] memory titles,
        string[] memory detail
    ) internal returns (uint256[] memory) {
        // Retrieve task id.
        uint256 taskId = Mission(mContract).getTaskId();

        if (users.length == expirations.length && expirations.length == detail.length && titles.length == detail.length)
        {
            for (uint256 i; i < users.length; i++) {
                taskCreators.push(users[i]);
                taskDeadlines.push(expirations[i]);
                taskTitles.push(titles[i]);
                taskDetail.push(detail[i]);

                taskIds.push(taskId + i + 1);
            }

            // Submit tasks onchain.
            Mission(mContract).payToSetTasks{value: ImpactCurve(icContract).getCurvePrice(true, 1, 0)}(
                taskCreators, taskDeadlines, taskTitles, taskDetail
            );

            return taskIds;
        } else {
            revert Invalid();
        }
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
        address[] memory _taskCreators,
        uint256[] memory _expirations,
        string[] memory _taskTitles,
        string[] memory _taskDetail,
        address _missionCreator,
        string memory _title,
        string memory _missionDetail
    ) internal {
        taskIds = _createNewTasks(_taskCreators, _expirations, _taskTitles, _taskDetail);
        _createNewMission(_missionCreator, _title, _missionDetail, taskIds);
    }
}
