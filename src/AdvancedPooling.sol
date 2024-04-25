// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {ILog, Activity, Touchpoint} from "./interface/ILog.sol";
import {IBulletin, List, Item} from "./interface/IBulletin.sol";
import {LibMap} from "solady/utils/LibMap.sol";
import {LibBitmap} from "solady/utils/LibBitmap.sol";
import {LibBytemap} from "solbase/utils/LibBytemap.sol";

/// @title Advanced Pooling
/// @notice The Advanced Pooling contract pools Log data for easy retrieval by tokens.
/// @author audsssy.eth
contract AdvancedPooling {
    using LibBitmap for LibBitmap.Bitmap;
    using LibMap for LibMap.Uint8Map;
    using LibBytemap for LibBytemap.Bytemap;

    LibBitmap.Bitmap bitmap;
    LibMap.Uint8Map uint8Map;
    LibBytemap.Bytemap bytemap;

    mapping(bytes32 => uint256) public counter;

    /// -----------------------------------------------------------------------
    /// Error
    /// -----------------------------------------------------------------------

    error Invalid();

    /// -----------------------------------------------------------------------
    /// Activity Progress
    /// -----------------------------------------------------------------------

    function getActivityProgress(address log, uint256 id) public returns (uint256) {
        bitmap.unsetBatch(0, 255);
        uint256 progress;
        (, address aBulletin, uint256 aListId, uint256 aNonce) = ILog(log).getActivityData(id);
        Touchpoint[] memory tps = new Touchpoint[](aNonce);
        tps = ILog(log).getActivityTouchpoints(id);
        List memory list = IBulletin(aBulletin).getList(aListId);

        uint256 length = list.itemIds.length;

        for (uint256 i; i < aNonce; ++i) {
            /// @dev Calculate percentage of completion.
            for (uint256 j; j < length; ++j) {
                if (tps[i].itemId == list.itemIds[j]) {
                    if (!bitmap.get(list.itemIds[j])) {
                        unchecked {
                            (tps[i].pass) ? ++progress : progress;
                        }
                        bitmap.set(list.itemIds[j]);
                    }
                } else {
                    continue;
                }
            }
        }

        return progress * 100 / length;
    }

    /// @notice Query the number of activities completed in a log by a user.
    function activityRunsByLog(address log) public returns (uint256 runs) {
        uint256 count = ILog(log).activityId();

        uint256 percentage;
        for (uint256 i = 1; i <= count; ++i) {
            percentage = getActivityProgress(log, i);
            (percentage == 100) ? ++runs : runs;
        }
    }

    function activityRunsByLogs(address[] calldata logs) public returns (uint256 runs) {
        uint256 length = logs.length;
        for (uint256 i; i < length; ++i) {
            runs = runs + activityRunsByLog(logs[i]);
        }
    }

    function meanPercentageOfCompletionByLog(address log) public returns (uint256 mean) {
        uint256 percentage;
        uint256 sum;

        uint256 count = ILog(log).activityId();
        for (uint256 i = 1; i <= count; ++i) {
            percentage = getActivityProgress(log, i);

            unchecked {
                sum = sum + percentage;
            }
        }

        unchecked {
            mean = sum / count;
        }
    }

    function meanPercentageOfCompletionByLogs(address[] calldata logs) public returns (uint256 mean) {
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

    /// -----------------------------------------------------------------------
    /// User
    /// -----------------------------------------------------------------------

    /// @notice Query the number of activities completed in a log by a user.
    function activityRunsByLogByUser(address log, address user) public returns (uint256 runs) {
        address aUser;
        uint256 percentage;

        uint256 count = ILog(log).activityId();
        for (uint256 i = 1; i <= count; ++i) {
            (aUser,,,) = ILog(log).getActivityData(i);
            percentage = getActivityProgress(log, i);
            (aUser == user && percentage == 100) ? ++runs : runs;
        }
    }

    function activityRunsByLogsByUser(address[] calldata logs, address user) public returns (uint256 runs) {
        uint256 length = logs.length;

        for (uint256 i; i < length; ++i) {
            runs = runs + activityRunsByLogByUser(logs[i], user);
        }
    }

    function meanPercentageOfCompletionByLogByUser(address log, address user) public returns (uint256 mean) {
        address aUser;
        uint256 percentage;
        uint256 sum;

        uint256 count = ILog(log).activityId();
        for (uint256 i = 1; i <= count; ++i) {
            (aUser,,,) = ILog(log).getActivityData(i);
            if (aUser == user) {
                percentage = getActivityProgress(log, i);

                unchecked {
                    sum = sum + percentage;
                }
            }
        }

        mean = sum / count;
    }

    /// -----------------------------------------------------------------------
    /// Most & Least
    /// -----------------------------------------------------------------------

    function mostFrequentedListByLog(address log) public returns (address, uint256, uint256) {
        uint256 numOfActivities = ILog(log).activityId();

        bytes32 data;
        uint256 runs;
        bytes32 mostFrequentedData;
        address bulletin;
        uint128 listId;
        address aBulletin;
        uint256 aListId;
        for (uint256 i = 1; i <= numOfActivities; ++i) {
            (, aBulletin, aListId,) = ILog(log).getActivityData(i);
            data = bytes32(abi.encodePacked(aBulletin, aListId));
            unchecked {
                ++counter[data];
            }
            if (counter[data] > runs) {
                mostFrequentedData = data;
                runs = counter[data];
            }
        }

        // Decode data via assembly.
        assembly {
            listId := data
            bulletin := shr(128, data)
        }

        cleanup(log, numOfActivities);

        return (bulletin, listId, runs);
    }

    function touchpointRunsByLog(address log, address user) public view returns (uint256 runs) {}

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

    /// -----------------------------------------------------------------------
    /// Internal
    /// -----------------------------------------------------------------------

    function cleanup(address log, uint256 numOfActivities) private {
        address aBulletin;
        uint256 aListId;
        bytes32 data;
        for (uint256 i = 1; i <= numOfActivities; ++i) {
            (, aBulletin, aListId,) = ILog(log).getActivityData(i);
            data = bytes32(abi.encodePacked(aBulletin, aListId));
            delete counter[data];
        }
    }
}
