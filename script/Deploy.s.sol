// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Script} from "forge-std/Script.sol";
import "forge-std/console.sol";

import {Mission} from "src/Mission.sol";
import {Quest} from "src/Quest.sol";
import {Factory} from "src/Factory.sol";
import {ImpactCurve} from "src/ImpactCurve.sol";

import {IImpactCurve, CurveType} from "../src/interface/IImpactCurve.sol";
import {qSupportToken} from "src/tokens/qSupportToken.sol";
import {mSupportToken} from "src/tokens/mSupportToken.sol";

/// @notice A very simple deployment script
contract Deploy is Script {
    // Contracts.
    address mContract;
    address qContract;
    address fContract;
    address payable icContract;

    // Tokens.
    address mstContract;
    address qstContract;

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
        address user2 = address(0xFB12B6A543d986A1938d2b3C7d05848D8913AcC4);

        vm.startBroadcast(privateKey);

        deployFactory(account, user, user2);
        // deployImpactCurve(user);

        vm.stopBroadcast();
    }

    function deployFactory(address patron, address user, address user2) internal {
        // Templates.
        Quest qTemplate = new Quest();
        Mission mTemplate = new Mission();
        mSupportToken mstTemplate = new mSupportToken();
        qSupportToken qstTemplate = new qSupportToken();

        // Deploy curves.
        deployImpactCurve(user);

        // Deploy factory.
        fContract =
            address(new Factory(address(mTemplate), address(mstTemplate), address(qTemplate), address(qstTemplate)));

        // Set curve.
        ImpactCurve(icContract).curve(
            CurveType.LINEAR,
            Factory(fContract).determineMissionTokenAddress(user),
            user,
            0.0001 ether,
            0,
            10,
            0,
            0,
            1,
            0
        );

        deployMission(user);
        setTasksAndMission(user, user2);

        deployQuest(user);
        Quest(qContract).start(address(mContract), 1);
        Quest(qContract).respond(address(mContract), 1, 1, 1, "First Task Done!");
        Quest(qContract).respond(address(mContract), 1, 1, 2, "Second Task Done!");

        mstContract = Factory(fContract).deploySupportToken(
            "Support Token", "mST", user, address(0), address(mContract), 1, address(icContract), 1
        );

        ImpactCurve(icContract).support(1, patron, ImpactCurve(icContract).getPrice(true, 1, 0));
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

    function setTasksAndMission(address user, address user2) internal {
        // Add first task.
        taskCreators.push(user);
        taskDeadlines.push(100000000);
        taskDetail.push("FIRST TASK");

        // Add second task.
        taskCreators.push(user2);
        taskDeadlines.push(100000000000000000);
        taskDetail.push("SECOND TASK");

        // Submit tasks onchain.
        Mission(mContract).setTasks(taskCreators, taskDeadlines, taskDetail);

        taskIds.push(1);
        taskIds.push(2);

        // Submit mission onchain.
        Mission(mContract).setMission(user, unicode"g0v 60th Hackathon", "IT ALL BEGINS..", taskIds);
    }
}
