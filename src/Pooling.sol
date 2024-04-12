// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {ILog, Activity, Touchpoint} from "./interface/ILog.sol";
import {IBulletin, List, Item} from "./interface/IBulletin.sol";

/// @title Pooling
/// @notice The Pooling library pools Log data for easy retrieval by tokens.
/// @author audsssy.eth
library Pooling {
    /// -----------------------------------------------------------------------
    /// Error
    /// -----------------------------------------------------------------------

    error Invalid();

    /// -----------------------------------------------------------------------
    /// Contributors - List
    /// -----------------------------------------------------------------------

    function numOfItemsContributed(address contributor, address bulletin) public view returns (uint256 count) {
        Item memory item;
        uint256 itemId = IBulletin(bulletin).itemId();

        for (uint256 i; i < itemId; i++) {
            item = IBulletin(bulletin).getItem(i);
            if (item.owner == contributor) ++count;
        }
    }

    function numOfListsContributed(address contributor, address bulletin) public view returns (uint256 count) {
        List memory list;
        uint256 listId = IBulletin(bulletin).listId();

        for (uint256 i; i < listId; i++) {
            list = IBulletin(bulletin).getList(i);
            if (list.owner == contributor) ++count;
        }
    }

    /// -----------------------------------------------------------------------
    /// Public Users
    /// -----------------------------------------------------------------------

    /// @notice Query the num`ber of activities in a log by users via sponsoredLog().
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

    function itemRunsByLog(address log) public view returns (uint256 runs) {
        uint256 count = ILog(log).activityId();

        uint256 aNonce;
        for (uint256 i = 1; i <= count; ++i) {
            (,,, aNonce) = ILog(log).getActivityData(i);
            runs = runs + aNonce;
        }
    }

    function listRunsByLog(address log) public view returns (uint256 runs) {
        uint256 count = ILog(log).activityId();

        address aUser;
        address aBulletin;
        uint256 aListId;
        for (uint256 i = 1; i <= count; ++i) {
            (aUser, aBulletin, aListId,) = ILog(log).getActivityData(i);
            runs = runs + IBulletin(aBulletin).runsByList(aListId);
        }
    }

    function averageNonceByListByLog(address log, address bulletin, uint256 listId)
        public
        view
        returns (uint256 nonce)
    {
        uint256 count = ILog(log).activityId();

        address aBulletin;
        uint256 aListId;
        uint256 aNonce;
        for (uint256 i = 1; i <= count; ++i) {
            (, aBulletin, aListId, aNonce) = ILog(log).getActivityData(i);

            if (bulletin == aBulletin && aListId == listId) {
                nonce = (nonce + aNonce) / count;
            } else {
                nonce;
            }
        }
    }

    function averageNonceByLog(address log) public view returns (uint256 nonce) {
        uint256 count = ILog(log).activityId();

        uint256 aNonce;
        for (uint256 i = 1; i <= count; ++i) {
            (,,, aNonce) = ILog(log).getActivityData(i);
            nonce = (nonce + aNonce) / count;
        }
    }

    function touchpointRunsByLog(address log, address user) public view returns (uint256 runs) {}

    /// @notice Query the number of activities started in a log by a user.
    function activityStartsByLogByUser(address log, address user) public view returns (uint256 starts) {
        address aUser;
        uint256 count = ILog(log).activityId();

        for (uint256 j = 1; j <= count; ++j) {
            (aUser,,,) = ILog(log).getActivityData(j);
            (aUser == user) ? ++starts : starts;
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
