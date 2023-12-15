// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Script} from "forge-std/Script.sol";
import "forge-std/console.sol";

import {Mission} from "src/Mission.sol";
import {Quest} from "src/Quest.sol";
import {Factory} from "src/Factory.sol";
import {ImpactCurve} from "src/ImpactCurve.sol";

import {IImpactCurve, CurveType} from "../src/interface/IImpactCurve.sol";
import {MissionBergerToken} from "src/tokens/MissionBergerToken.sol";
import {MissionSupportToken} from "src/tokens/MissionSupportToken.sol";
import {qSupportToken} from "src/tokens/qSupportToken.sol";
import {mSupportToken} from "src/tokens/mSupportToken.sol";

/// @notice A very simple deployment script
contract Deploy is Script {
    // Contracts.
    Mission mContract;
    Quest qContract;
    Factory fContract;
    ImpactCurve icContract;

    // Tokens.
    mSupportToken mstContract;
    qSupportToken qstContract;

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

        address user = address(0x4744cda32bE7b3e75b9334001da9ED21789d4c0d);

        vm.startBroadcast(privateKey);

        deployFactory(user);
        deployImpactCurve(user);

        vm.stopBroadcast();
    }

    function deployFactory(address user) internal {
        // Templates.
        Quest qTemplate = new Quest();
        Mission mTemplate = new Mission();
        mSupportToken mstTemplate = new mSupportToken();
        qSupportToken qstTemplate = new qSupportToken();

        fContract = new Factory(address(mTemplate), address(mstTemplate), address(qTemplate), address(qstTemplate));
    }

    function deployImpactCurve(address user) internal {
        icContract = new ImpactCurve();
    }

    // function deployMissionFactory(address user) internal {
    //     Mission template = new Mission();

    //     // Add first task.
    //     taskCreators.push(user);
    //     taskDeadlines.push(100000000);
    //     taskDetail.push("FIRST TASK");

    //     // Add second task.
    //     taskCreators.push(user);
    //     taskDeadlines.push(100000000000000000);
    //     taskDetail.push("SECOND TASK");

    //     // Deploy mission contract.
    //     mContract = mFactory.deployMission(user);
    //     Mission(mContract).initialize(user);

    //     // Submit tasks onchain.
    //     Mission(mContract).setTasks(taskCreators, taskDeadlines, taskDetail);

    //     taskIds.push(1);
    //     taskIds.push(2);

    //     // Submit mission onchain.
    //     Mission(mContract).setMission(
    //         user, unicode"g0v 第伍拾玖次輪班寫 code 救台灣黑客松", "IT ALL BEGINS..", taskIds
    //     );
    // }
}
