// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Script} from "forge-std/Script.sol";
import "forge-std/console.sol";

import {Quest} from "src/Quest.sol";
import {QuestFactory} from "src/QuestFactory.sol";
import {Mission} from "src/Mission.sol";
import {MissionFactory} from "src/MissionFactory.sol";
import {TokenFactory} from "src/TokenFactory.sol";

import {MissionBergerToken} from "src/tokens/MissionBergerToken.sol";
import {MissionSupportToken} from "src/tokens/MissionSupportToken.sol";
import {QuestSupportToken} from "src/tokens/QuestSupportToken.sol";

/// @notice A very simple deployment script
contract Deploy is Script {
    QuestFactory qFactory;
    address mContract;
    MissionFactory mFactory;
    TokenFactory tFactory;

    // Prep for task submission.
    address[] taskCreators;
    uint256[] taskDeadlines;
    string[] taskDetail;

    // Prep for mission submission.
    uint256[] taskIds;

    /// @notice The main script entrypoint.
    function run() external {
        uint256 privateKey = vm.envUint("DEV_PRIVATE_KEY");
        address account = vm.addr(privateKey);

        console.log("Account", account);

        vm.startBroadcast(privateKey);

        // deployQuestFactory();
        deployMissionFactory(account);
        deployTokenFactory();
        mintMissionBergerToken(account);
        // deployMissionSupportTokenFactory();
        // deployQuestSupportTokenFactory();

        vm.stopBroadcast();
    }

    function deployQuestFactory() internal {
        Quest template = new Quest();
        qFactory = new QuestFactory(address(template));
    }

    function deployMissionFactory(address user) internal {
        Mission template = new Mission();
        mFactory = new MissionFactory(address(template));

        // Add first task.
        taskCreators.push(user);
        taskDeadlines.push(100000000);
        taskDetail.push("FIRST TASK");

        // Add second task.
        taskCreators.push(user);
        taskDeadlines.push(100000000000000000);
        taskDetail.push("SECOND TASK");

        // Submit tasks onchain.
        mContract = mFactory.deployMission(user);
        Mission(mContract).initialize(user);
        Mission(mContract).setTasks(taskCreators, taskDeadlines, taskDetail);

        taskIds.push(1);
        taskIds.push(2);

        // Submit mission onchain.
        Mission(mContract).setMission(user, "FIRST MISSION EVER", "IT ALL BEGINS..", taskIds);
    }

    function deployTokenFactory() internal {
        tFactory = new TokenFactory();
    }

    function mintMissionBergerToken(address user) internal {
        MissionBergerToken mbt_template = new MissionBergerToken();
        tFactory.addToken(address(mbt_template), "Mission Harberger Token");
        address token = tFactory.deploy(tFactory.count());
        console.log("Token Address", token);

        MissionBergerToken(token).initialize(user, user);
        MissionBergerToken(token).mint(mContract, 1);
    }

    function deployMissionSupportTokenFactory() internal returns (MissionSupportToken) {}

    function deployQuestSupportTokenFactory() internal returns (QuestSupportToken) {}
}
