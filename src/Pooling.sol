// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {ILog, Activity, Touchpoint} from "interface/ILog.sol";
import {IBulletin, List, Item} from "interface/IBulletin.sol";

/// @title Pooling
/// @notice The Pooling library pools Log data for easy retrieval by tokens.
/// @author audsssy.eth
library Pooling {
    /// -----------------------------------------------------------------------
    /// Contributors
    /// -----------------------------------------------------------------------

    function numOfItemsContributedByContributorByBulletin(address contributor, address bulletin)
        public
        view
        returns (uint256 count)
    {
        Item memory item;
        uint256 itemId = IBulletin(bulletin).itemId();

        for (uint256 i = 1; i <= itemId; i++) {
            item = IBulletin(bulletin).getItem(i);
            if (item.owner == contributor) ++count;
        }
    }

    function numOfListsContributedByContributorByBulletin(address contributor, address bulletin)
        public
        view
        returns (uint256 count)
    {
        List memory list;
        uint256 listId = IBulletin(bulletin).listId();

        for (uint256 i = 1; i <= listId; i++) {
            list = IBulletin(bulletin).getList(i);
            if (list.owner == contributor) ++count;
        }
    }

    /// -----------------------------------------------------------------------
    /// Bulletin Lists & Items
    /// -----------------------------------------------------------------------

    function touchpointRunsByLog(address log) public view returns (uint256 runs) {
        uint256 count = ILog(log).logId();

        uint256 aNonce;
        for (uint256 i = 1; i <= count; ++i) {
            (,,, aNonce) = ILog(log).getLog(i);
            runs = runs + aNonce;
        }
    }

    function averageTouchpointRunsByLog(address log) public view returns (uint256 runs) {
        uint256 count = ILog(log).logId();

        uint256 aNonce;
        for (uint256 i = 1; i <= count; ++i) {
            (,,, aNonce) = ILog(log).getLog(i);
            runs = (runs + aNonce) / count;
        }
    }

    function averageTouchpointRunsByListByLog(address log, address bulletin, uint256 listId)
        public
        view
        returns (uint256 runs)
    {
        uint256 count = ILog(log).logId();

        address aBulletin;
        uint256 aListId;
        uint256 aNonce;
        for (uint256 i = 1; i <= count; ++i) {
            (, aBulletin, aListId, aNonce) = ILog(log).getLog(i);

            if (bulletin == aBulletin && aListId == listId) {
                runs = (runs + aNonce) / count;
            } else {
                runs;
            }
        }
    }

    function totalTouchpointRunsByListByLog(address log, address bulletin, uint256 listId)
        public
        view
        returns (uint256 runs)
    {
        uint256 count = ILog(log).logId();

        address aBulletin;
        uint256 aListId;
        uint256 aNonce;
        for (uint256 i = 1; i <= count; ++i) {
            (, aBulletin, aListId, aNonce) = ILog(log).getLog(i);

            if (bulletin == aBulletin && aListId == listId) {
                runs = runs + aNonce;
            } else {
                runs;
            }
        }
    }

    function listRunsByLog(address log) public view returns (uint256 runs) {
        uint256 count = ILog(log).logId();

        address aUser;
        address aBulletin;
        uint256 aListId;
        for (uint256 i = 1; i <= count; ++i) {
            (aUser, aBulletin, aListId,) = ILog(log).getLog(i);
            runs = runs + IBulletin(aBulletin).runsByList(aListId);
        }
    }

    /// -----------------------------------------------------------------------
    /// User
    /// -----------------------------------------------------------------------

    /// @notice Query the number of activities started in a log by a user.
    function activityStartsByLogByUser(address log, address user) public view returns (uint256 starts) {
        address aUser;
        uint256 count = ILog(log).logId();

        for (uint256 i = 1; i <= count; ++i) {
            (aUser,,,) = ILog(log).getLog(i);
            (aUser == user) ? ++starts : starts;
        }
    }

    /// @notice Query the number of touchpoints in a log by a user.
    function touchpointRunsByLogByUser(address log, address user) public view returns (uint256 runs) {
        address aUser;
        uint256 aNonce;

        uint256 count = ILog(log).logId();
        for (uint256 i = 1; i <= count; ++i) {
            (aUser,,, aNonce) = ILog(log).getLog(i);
            if (aUser == user) {
                runs = runs + aNonce;
            }
        }
    }

    function touchpointRunsByLogsByUser(address[] calldata logs, address user) public view returns (uint256 runs) {
        uint256 length = logs.length;

        for (uint256 i; i < length; ++i) {
            runs = runs + touchpointRunsByLogByUser(logs[i], user);
        }
    }

    /// -----------------------------------------------------------------------
    /// Log Activities & Touchpoints
    /// -----------------------------------------------------------------------

    function touchpointDataByLogByLogId(address log, uint256 logId) public view returns (bytes[] memory data) {
        Touchpoint[] memory tp = ILog(log).getLogTouchpoints(logId);
        uint256 length = tp.length;
        for (uint256 i; i < length; ++i) {
            data[i] = tp[i].data;
        }
    }

    /// @notice Query the number of activities started in a log by a user.
    function activityStartsByLog(address log) public view returns (uint256) {
        return ILog(log).logId();
    }

    function touchpointRunsByLogs(address[] calldata logs) public view returns (uint256 runs) {
        uint256 length = logs.length;
        for (uint256 i; i < length; ++i) {
            runs = runs + touchpointRunsByLog(logs[i]);
        }
    }
}
