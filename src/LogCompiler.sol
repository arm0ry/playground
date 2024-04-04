// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {ILog, Touchpoint} from "./interface/ILog.sol";
import {IBulletin, List} from "./interface/IBulletin.sol";

/// @title Compiler
/// @notice The Compiler contract compiles Log data for easy retrieval by SupportToken.
/// @author audsssy.eth
contract LogCompiler {
    function runs(address bulletin, uint256 listId) public view returns (uint256) {}

    function progress() public view returns (uint256) {}

    // @notice Compile data related to the requested activity.
    function compileNumOfRuns(address log, address user, address bulletin, uint256 listId)
        internal
        view
        returns (uint256 runs)
    {
        uint256 activityCount = ILog(log).activityId();

        address aUser;
        address aBulletin;
        uint256 aListId;
        uint256 aNonce;

        List memory list;
        uint256 itemCount;
        Touchpoint[] memory touchpoints;
        uint256 percentageOfCompletion;
        uint256 touchpointsLength;

        for (uint256 i; i < activityCount; ++i) {
            // TODO: Count number of times completed per activity.
            if (bulletin == aBulletin && listId == aListId) {
                list = IBulletin(bulletin).getList(aListId);
                itemCount = list.itemIds.length;

                // Retrieve review flag from Item to check for completion and then compute number of tasks completed over total number of tasks
                (touchpoints, percentageOfCompletion) = ILog(log).getActivityTouchpoints(i);
                touchpointsLength = touchpoints.length;

                for (uint256 j; j < touchpointsLength; ++j) {
                    for (uint256 k; k < itemCount; ++k) {
                        if (touchpoints[j].itemId == list.itemIds[k]) {
                            ++runs;
                        }
                    }
                }
            }

            // TODO: Count number of completed activities per bulletin by user.
            if (user == aUser) {}
        }
    }
}
