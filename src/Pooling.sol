// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {ILog, Touchpoint} from "./interface/ILog.sol";
import {IBulletin, List} from "./interface/IBulletin.sol";

/// @title Compiler
/// @notice The Compiler contract compiles Log data for easy retrieval by SupportToken.
/// @author audsssy.eth
library Pooling {
    /// -----------------------------------------------------------------------
    /// Error
    /// -----------------------------------------------------------------------

    error Invalid();

    /// -----------------------------------------------------------------------
    /// Sponsored Users
    /// -----------------------------------------------------------------------

    /// @notice Query the number of activities in a log by sponsored users.
    function activityRunsByLogByPublic(address log) external view returns (uint256 runs) {
        address user;
        address aUser;
        uint256 count = ILog(log).activityId();

        for (uint256 i = 1; i <= count; ++i) {
            user = address(uint160(uint256(bytes32(abi.encodePacked(i)))));
            (aUser,,,) = ILog(log).getActivityData(i);
            (user == aUser) ? ++runs : runs;
        }
    }

    /// @notice Query the number of touchpoints in a log by sponsored users.
    function touchpointRunsByLogByPublic(address log) external view returns (uint256 runs) {
        address user;
        address aUser;
        uint256 aNonce;
        uint256 count = ILog(log).activityId();

        for (uint256 i = 1; i <= count; ++i) {
            user = address(uint160(uint256(bytes32(abi.encodePacked(i)))));
            (aUser,,, aNonce) = ILog(log).getActivityData(i);
            (user == aUser) ? runs = runs + aNonce : runs;
        }
    }

    /// -----------------------------------------------------------------------
    /// Mean & Runs
    /// -----------------------------------------------------------------------

    /// @notice Query the number of times users have completed a list on a bulletin.
    function runsByList(address bulletin, uint256 listId) external view returns (uint256 runs) {
        List memory list;
        uint256 itemCount;
        uint256 runsPerItem;

        // @notice Count number of times completed per activity.
        if (bulletin != address(0) && listId != 0) {
            list = IBulletin(bulletin).getList(listId);
            itemCount = list.itemIds.length;

            for (uint256 i; i < itemCount; ++i) {
                runsPerItem = IBulletin(bulletin).runsByItem(list.itemIds[i]);

                (runsPerItem > 0)
                    ? ((runs > runsPerItem) ? runs = runsPerItem : (runs == 0) ? runs = runsPerItem : runs)
                    : runs = 0;
            }
        } else {
            revert Invalid();
        }
    }

    /// @notice Query the number of activities started in a log by a user.
    function activityStartsByLogByUser(address log, address user) public view returns (uint256 starts) {
        address aUser;

        if (log != address(0) && user != address(0)) {
            uint256 count = ILog(log).activityId();
            for (uint256 j = 1; j <= count; ++j) {
                (aUser,,,) = ILog(log).getActivityData(j);
                (aUser == user) ? ++starts : starts;
            }
        } else {
            revert Invalid();
        }
    }

    /// @notice Query the number of activities completed in a log by a user.
    function activityRunsByLogByUser(address log, address user) public view returns (uint256 runs) {
        address aUser;
        uint256 percentage;

        if (log != address(0) && user != address(0)) {
            uint256 count = ILog(log).activityId();
            for (uint256 j = 1; j <= count; ++j) {
                (aUser,,,) = ILog(log).getActivityData(j);
                (, percentage) = ILog(log).getActivityTouchpoints(j);
                (aUser == user && percentage == 100) ? ++runs : runs;
            }
        } else {
            revert Invalid();
        }
    }

    /// @notice Query the number of touchpoints in a log by a user.
    function touchpointRunsByLogByUser(address log, address user) public view returns (uint256 runs) {
        address aUser;
        uint256 aNonce;

        if (log != address(0) && user != address(0)) {
            uint256 count = ILog(log).activityId();
            for (uint256 j = 1; j <= count; ++j) {
                (aUser,,, aNonce) = ILog(log).getActivityData(j);
                if (aUser == user) {
                    runs = runs + aNonce;
                }
            }
        } else {
            revert Invalid();
        }
    }

    function meanPercentageOfCompletionByLogByUser(address log, address user)
        public
        view
        returns (uint256 mean, uint256 runs)
    {
        address aUser;
        uint256 percentage;
        uint256 sum;

        if (log != address(0) && user != address(0)) {
            uint256 count = ILog(log).activityId();
            for (uint256 j = 1; j <= count; ++j) {
                (aUser,,,) = ILog(log).getActivityData(j);
                if (aUser == user) {
                    (, percentage) = ILog(log).getActivityTouchpoints(j);

                    unchecked {
                        ++runs;
                        sum = sum + percentage;
                    }
                }
            }
        } else {
            revert Invalid();
        }

        mean = sum / runs;
    }

    /// -----------------------------------------------------------------------
    ///
    /// -----------------------------------------------------------------------

    function touchpointRunsByLogsByUser(address[] calldata logs, address user) public view returns (uint256 runs) {
        uint256 length = logs.length;

        for (uint256 i; i < length; ++i) {
            runs = runs + touchpointRunsByLogByUser(logs[i], user);
        }
    }

    function activityRunsByLogsByUser(address[] calldata logs, address user) public view returns (uint256 runs) {
        uint256 length = logs.length;

        for (uint256 i; i < length; ++i) {
            runs = runs + activityRunsByLogByUser(logs[i], user);
        }
    }
}
