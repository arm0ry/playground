// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {ILog, Activity, Touchpoint} from "./interface/ILog.sol";
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
    /// Public Users
    /// -----------------------------------------------------------------------

    /// @notice Query the number of activities in a log by users via sponsoredLog().
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

    /// @notice Query the number of touchpoints in a log by users via sponsoredLog().
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

    function listRunsByLog(address log, address bulletin, uint256 listId) public view returns (uint256 starts) {}
    function averageNonceByListByLog(address log, address bulletin, uint256 listId)
        public
        view
        returns (uint256 starts)
    {}
    function averageNonceByLog(address log) public view returns (uint256 starts) {}
    function mostFrequentedListByLog(address log) public view returns (uint256 starts) {}
    function touchpointRunsByLog(address log, address user) public view returns (uint256 runs) {}

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

    function passingTouchpointsByActivityByUser(address log, uint256 activityId, address user)
        public
        view
        returns (uint256 passingTouchpoints)
    {}

    function itemFrequencyByActivityByUser(address log, uint256 activityId, uint256 itemId, address user)
        public
        view
        returns (uint256 frequency)
    {}

    function mostFrequentedItemByActivityByUser(address log, uint256 activityId, address user)
        public
        view
        returns (uint256 itemId, uint256 frequency)
    {}

    function dataByTouchpointByUser(address log, uint256 activityId, address user) public view returns (bytes memory) {}

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
    /// MultipleRretrieval
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
