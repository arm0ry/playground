// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {Log} from "src/Log.sol";
import {ILog, Activity, Touchpoint} from "src/interface/ILog.sol";
import {Bulletin} from "src/Bulletin.sol";
import {IBulletin, Item, List} from "src/interface/IBulletin.sol";
import {Pooling} from "src/Pooling.sol";

import {LogTest} from "./Log.t.sol";

contract PoolingTest is LogTest {
    address[] loggers;
    address publicUser;

    /// -----------------------------------------------------------------------
    /// Setup Tests
    /// -----------------------------------------------------------------------

    /// @notice Set up the testing suite.
    // function setUp() public  {
    //     (alice, alicePk) = makeAddrAndKey("alice");
    //     (bob, bobPk) = makeAddrAndKey("bob");
    //     (charlie, charliePk) = makeAddrAndKey("charlie");

    //     deployBulletin(dao);
    //     deployLogger(dao);
    // }

    /// -----------------------------------------------------------------------
    /// Contributors
    /// -----------------------------------------------------------------------

    function test_NumOfItemsContributed() public {
        registerItems();
        uint256 count = Pooling.numOfItemsContributedByContributorByBulletin(alice, address(bulletin));
        emit log_uint(count);

        // assertEq(logger.getGasBuddy(), _buddy);
    }

    function test_NumOfListsContributed() public {
        registerList_ReviewNotRequired();
        uint256 count = Pooling.numOfListsContributedByContributorByBulletin(alice, address(bulletin));
        emit log_uint(count);

        // assertEq(logger.getGasBuddy(), _buddy);
    }

    /// -----------------------------------------------------------------------
    /// Public Users
    /// -----------------------------------------------------------------------

    function test_ActivityStartsByLogByPublic() public {
        test_Log_ReviewNotRequired_LoggerAuthorized();
        uint256 count = Pooling.activityStartsByLogByUser(address(logger), publicUser);
        emit log_uint(count);
    }

    function test_TouchpointRunsByLogByPublic() public {
        test_Log_ReviewNotRequired_LoggerAuthorized();
        uint256 count = Pooling.touchpointRunsByLogByUser(address(logger), publicUser);
        emit log_uint(count);
    }

    function test_TouchpointRunsByLogsByPublic() public {
        delete loggers;
        loggers.push(address(logger));
        test_Log_ReviewNotRequired_LoggerAuthorized();
        uint256 count = Pooling.touchpointRunsByLogsByUser(loggers, publicUser);
        emit log_uint(count);
    }

    /// -----------------------------------------------------------------------
    /// Bulletin Lists & Items
    /// -----------------------------------------------------------------------

    function test_ItemRunsByLog() public {
        test_Log_ReviewNotRequired_LoggerAuthorized();
        uint256 count = Pooling.touchpointRunsByLog(address(logger));
        emit log_uint(count);
    }

    function test_AverageItemRunsByLog() public {
        test_Log_ReviewNotRequired_LoggerAuthorized();
        uint256 count = Pooling.averageTouchpointRunsByLog(address(logger));
        emit log_uint(count);
    }

    function test_AverageItemRunsByListByLog() public {
        test_Log_ReviewNotRequired_LoggerAuthorized();
        uint256 count = Pooling.averageTouchpointRunsByListByLog(address(logger), address(bulletin), 1);
        emit log_uint(count);
    }

    function test_TotalItemRunsByListByLog() public {
        test_Log_ReviewNotRequired_LoggerAuthorized();
        uint256 count = Pooling.totalTouchpointRunsByListByLog(address(logger), address(bulletin), 1);
        emit log_uint(count);
    }

    function test_ListRunsByLog() public {
        test_Log_ReviewNotRequired_LoggerAuthorized();
        uint256 count = Pooling.listRunsByLog(address(logger));
        emit log_uint(count);
    }

    /// -----------------------------------------------------------------------
    /// User
    /// -----------------------------------------------------------------------

    function test_ActivityStartsByLogByUser() public {
        test_Log_ReviewNotRequired_LoggerAuthorized();
        uint256 count = Pooling.activityStartsByLogByUser(address(logger), alice);
        emit log_uint(count);
    }

    function test_TouchpointRunsByLogByUser() public {
        test_Log_ReviewNotRequired_LoggerAuthorized();
        uint256 count = Pooling.touchpointRunsByLogByUser(address(logger), alice);
        emit log_uint(count);
    }

    function test_TouchpointRunsByLogsByUser() public {
        delete loggers;
        loggers.push(address(logger));
        test_Log_ReviewNotRequired_LoggerAuthorized();
        uint256 count = Pooling.touchpointRunsByLogsByUser(loggers, alice);
        emit log_uint(count);
    }

    /// -----------------------------------------------------------------------
    /// Log Activities & Touchpoints
    /// -----------------------------------------------------------------------
}
