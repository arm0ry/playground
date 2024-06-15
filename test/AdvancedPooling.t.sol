// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {Log} from "src/Log.sol";
import {ILog, LogType, Activity, Touchpoint} from "src/interface/ILog.sol";
import {Bulletin} from "src/Bulletin.sol";
import {IBulletin, Item, List} from "src/interface/IBulletin.sol";
import {Pooling} from "src/Pooling.sol";
import {AdvancedPooling} from "src/AdvancedPooling.sol";

import {LogTest} from "./Log.t.sol";

contract AdvancedPoolingTest is LogTest {
    address[] loggers;
    address publicUser;
    AdvancedPooling ap;

    /// -----------------------------------------------------------------------
    /// Setup Tests
    /// -----------------------------------------------------------------------

    /// @notice Set up the testing suite.
    // function setUp() public payable override {
    //     (alice, alicePk) = makeAddrAndKey("alice");
    //     (bob, bobPk) = makeAddrAndKey("bob");
    //     (charlie, charliePk) = makeAddrAndKey("charlie");

    //     deployBulletin(dao);
    //     deployLogger(dao);
    // }

    function deployAdvancedPooling() public payable {
        ap = new AdvancedPooling();
    }

    /// -----------------------------------------------------------------------
    /// Public Users
    /// -----------------------------------------------------------------------

    function test_ActivityRunsByLogByPublic() public {
        test_Log_ReviewNotRequired_LoggerAuthorized();
        deployAdvancedPooling();
        uint256 count = ap.activityRunsByLogByUser(address(logger), publicUser);
        emit log_uint(count);
    }

    function test_ActivityRunsByLogsByPublic() public {
        delete loggers;
        loggers.push(address(logger));
        test_Log_ReviewNotRequired_LoggerAuthorized();
        deployAdvancedPooling();
        uint256 count = ap.activityRunsByLogsByUser(loggers, publicUser);
        emit log_uint(count);
    }

    function test_MeanPercentageOfCompletionByLogByPublic() public {
        test_Log_ReviewNotRequired_LoggerAuthorized();
        deployAdvancedPooling();
        uint256 count = ap.meanPercentageOfCompletionByLogByUser(address(logger), publicUser);
        emit log_uint(count);
    }

    /// -----------------------------------------------------------------------
    /// User
    /// -----------------------------------------------------------------------

    function test_ActivityRunsByLogByUser() public {
        test_Log_ReviewNotRequired_LoggerAuthorized();
        deployAdvancedPooling();
        uint256 count = ap.activityRunsByLogByUser(address(logger), alice);
        emit log_uint(count);
    }

    function test_ActivityRunsByLogsByUser() public {
        delete loggers;
        loggers.push(address(logger));
        test_Log_ReviewNotRequired_LoggerAuthorized();
        deployAdvancedPooling();
        uint256 count = ap.activityRunsByLogsByUser(loggers, alice);
        emit log_uint(count);
    }

    function test_MeanPercentageOfCompletionByLogByUser() public {
        test_Log_ReviewNotRequired_LoggerAuthorized();
        deployAdvancedPooling();
        uint256 mean = ap.meanPercentageOfCompletionByLogByUser(address(logger), alice);
        emit log_uint(mean);
    }
    /// -----------------------------------------------------------------------
    /// Log Activities & Touchpoints
    /// -----------------------------------------------------------------------
}
