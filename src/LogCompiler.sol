// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {ILog, Touchpoint} from "./interface/ILog.sol";
import {IBulletin, List} from "./interface/IBulletin.sol";

/// @title Compiler
/// @notice The Compiler contract compiles Log data for easy retrieval by SupportToken.
/// @author audsssy.eth
contract LogCompiler {
    // @notice Compile data related to the requested activity.
    function compileNumOfRuns(address log, address user, address bulletin, uint256 listId)
        internal
        view
        returns (uint256 runs)
    {
        uint256 activityCount = ILog(log).activityId();

        List memory list;
        uint256 itemCount;
        uint256 runsPerItem;

        for (uint256 i; i < activityCount; ++i) {
            // @notice Count number of times completed per activity.
            if (bulletin != address(0) && listId != 0) {
                list = IBulletin(bulletin).getList(listId);
                itemCount = list.itemIds.length;

                for (uint256 j; j < itemCount; ++j) {
                    runsPerItem = IBulletin(bulletin).numOfInteractionsByItem(list.itemIds[i]);

                    (runsPerItem > 0)
                        ? ((runs > runsPerItem) ? runs = runsPerItem : (runs == 0) ? runs = runsPerItem : runs)
                        : runs = 0;
                }
            }

            // TODO: Count number of completed activities per bulletin by user.
            if (user != address(0)) {}
        }
    }
}
