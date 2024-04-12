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
    LibBitmap.Bitmap bitmap;
    LibMap.Uint8Map uint8Map;
    LibBytemap.Bytemap bytemap;

    mapping(bytes32 => uint256) public counter;

    /// -----------------------------------------------------------------------
    /// Error
    /// -----------------------------------------------------------------------

    error Invalid();

    /// -----------------------------------------------------------------------
    /// Contributors - List
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// Public Users
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// Mean & Runs
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
