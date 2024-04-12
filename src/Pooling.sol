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
    /// Contributors
    /// -----------------------------------------------------------------------

    function numOfItemsContributedByContributorByBulletin(address contributor, address bulletin)
        public
        view
        returns (uint256 count)
    {
        Item memory item;
        uint256 itemId = IBulletin(bulletin).itemId();

        for (uint256 i; i < itemId; i++) {
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
    /// Bulletin Lists & Items
    /// -----------------------------------------------------------------------

    function itemRunsByLog(address log) public view returns (uint256 runs) {
        uint256 count = ILog(log).activityId();

        uint256 aNonce;
        for (uint256 i = 1; i <= count; ++i) {
            (,,, aNonce) = ILog(log).getActivityData(i);
            runs = runs + aNonce;
        }
    }

    function averageItemRunsByLog(address log) public view returns (uint256 runs) {
        uint256 count = ILog(log).activityId();

        uint256 aNonce;
        for (uint256 i = 1; i <= count; ++i) {
            (,,, aNonce) = ILog(log).getActivityData(i);
            runs = (runs + aNonce) / count;
        }
    }

    function averageItemRunsyByListByLog(address log, address bulletin, uint256 listId)
        public
        view
        returns (uint256 runs)
    {
        uint256 count = ILog(log).activityId();

        address aBulletin;
        uint256 aListId;
        uint256 aNonce;
        for (uint256 i = 1; i <= count; ++i) {
            (, aBulletin, aListId, aNonce) = ILog(log).getActivityData(i);

            if (bulletin == aBulletin && aListId == listId) {
                runs = (runs + aNonce) / count;
            } else {
                runs;
            }
        }
    }

    function totalItemRunsByListByLog(address log, address bulletin, uint256 listId)
        public
        view
        returns (uint256 runs)
    {
        uint256 count = ILog(log).activityId();

        address aBulletin;
        uint256 aListId;
        uint256 aNonce;
        for (uint256 i = 1; i <= count; ++i) {
            (, aBulletin, aListId, aNonce) = ILog(log).getActivityData(i);

            if (bulletin == aBulletin && aListId == listId) {
                runs = runs + aNonce;
            } else {
                runs;
            }
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

    /// -----------------------------------------------------------------------
    /// User
    /// -----------------------------------------------------------------------

    /// @notice Query the number of activities started in a log by a user.
    function activityStartsByLogByUser(address log, address user) public view returns (uint256 starts) {
        address aUser;
        uint256 count = ILog(log).activityId();

        for (uint256 i = 1; i <= count; ++i) {
            (aUser,,,) = ILog(log).getActivityData(i);
            (aUser == user) ? ++starts : starts;
        }
    }

    /// @notice Query the number of activities completed in a log by a user.
    function activityRunsByLogByUser(address log, address user) public view returns (uint256 runs) {
        address aUser;
        uint256 percentage;

        uint256 count = ILog(log).activityId();
        for (uint256 i = 1; i <= count; ++i) {
            (aUser,,,) = ILog(log).getActivityData(i);
            (, percentage) = ILog(log).getActivityTouchpoints(i);
            (aUser == user && percentage == 100) ? ++runs : runs;
        }
    }

    function activityRunsByLogsByUser(address[] calldata logs, address user) public view returns (uint256 runs) {
        uint256 length = logs.length;

        for (uint256 i; i < length; ++i) {
            runs = runs + activityRunsByLogByUser(logs[i], user);
        }
    }

    /// @notice Query the number of touchpoints in a log by a user.
    function touchpointRunsByLogByUser(address log, address user) public view returns (uint256 runs) {
        address aUser;
        uint256 aNonce;

        uint256 count = ILog(log).activityId();
        for (uint256 i = 1; i <= count; ++i) {
            (aUser,,, aNonce) = ILog(log).getActivityData(i);
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

    function meanPercentageOfCompletionByLogByUser(address log, address user) public view returns (uint256 mean) {
        address aUser;
        uint256 percentage;
        uint256 sum;

        uint256 count = ILog(log).activityId();
        for (uint256 i = 1; i <= count; ++i) {
            (aUser,,,) = ILog(log).getActivityData(i);
            if (aUser == user) {
                (, percentage) = ILog(log).getActivityTouchpoints(i);

                unchecked {
                    sum = sum + percentage;
                }
            }
        }

        mean = sum / count;
    }

    /// -----------------------------------------------------------------------
    /// Log Activities & Touchpoints
    /// -----------------------------------------------------------------------

    function dataByActivity(address log, uint256 activityId) public view returns (bytes[] memory data) {
        (Touchpoint[] memory tp,) = ILog(log).getActivityTouchpoints(activityId);

        uint256 length = tp.length;
        for (uint256 i; i < length; ++i) {
            data[i] = tp[i].data;
        }
    }

    /// @notice Query the number of activities started in a log by a user.
    function activityStartsByLog(address log) public view returns (uint256) {
        return ILog(log).activityId();
    }

    /// @notice Query the number of activities completed in a log by a user.
    function activityRunsByLog(address log) public view returns (uint256 runs) {
        uint256 count = ILog(log).activityId();

        uint256 percentage;
        for (uint256 i = 1; i <= count; ++i) {
            (, percentage) = ILog(log).getActivityTouchpoints(i);
            (percentage == 100) ? ++runs : runs;
        }
    }

    function activityRunsByLogs(address[] calldata logs) public view returns (uint256 runs) {
        uint256 length = logs.length;
        for (uint256 i; i < length; ++i) {
            runs = runs + activityRunsByLog(logs[i]);
        }
    }

    /// @notice Query the number of touchpoints in a log by a user.
    function touchpointRunsByLog(address log) public view returns (uint256 runs) {
        uint256 count = ILog(log).activityId();

        uint256 aNonce;
        for (uint256 i = 1; i <= count; ++i) {
            (,,, aNonce) = ILog(log).getActivityData(i);
            runs = runs + aNonce;
        }
    }

    function touchpointRunsByLogs(address[] calldata logs) public view returns (uint256 runs) {
        uint256 length = logs.length;
        for (uint256 i; i < length; ++i) {
            runs = runs + touchpointRunsByLog(logs[i]);
        }
    }

    function meanPercentageOfCompletionByLog(address log) public view returns (uint256 mean) {
        uint256 percentage;
        uint256 sum;

        uint256 count = ILog(log).activityId();
        for (uint256 i = 1; i <= count; ++i) {
            (, percentage) = ILog(log).getActivityTouchpoints(i);

            unchecked {
                sum = sum + percentage;
            }
        }

        unchecked {
            mean = sum / count;
        }
    }

    function meanPercentageOfCompletionByLogs(address[] calldata logs) public view returns (uint256 mean) {
        uint256 sum;

        uint256 length = logs.length;
        for (uint256 i; i < length; ++i) {
            unchecked {
                sum = sum + meanPercentageOfCompletionByLog(logs[i]);
            }
        }

        unchecked {
            mean = sum / length;
        }
    }
}
