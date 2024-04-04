// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {ILog, Touchpoint} from "./interface/ILog.sol";

/// @title Compiler
/// @notice The Compiler contract compiles Log data for easy retrieval by SupportToken.
/// @author audsssy.eth
contract Compiler {
    function runs(address bulletin, uint256 listId) public view returns (uint256) {}

    function progress() public view returns (uint256) {}

    // @notice Compile data related to the requested activity.
    function compileNumOfRuns(address log, address bulletin, uint256 listId) internal view returns (uint256) {
        uint256 activityCount = ILog(log).activityId();

        address aUser;
        address aBulletin;
        uint256 aListId;
        uint256 aNonce;

        for (uint256 i; i < activityCount; ++i) {
            (aUser, aBulletin, aListId, aNonce) = ILog(log).getActivityData(i);

            if (bulletin == aBulletin && listId == aListId) {} // TODO: Do something.

            // Retrieve review flag from Item to check for completion and then compute number of tasks completed over total number of tasks
            Touchpoint[] memory touchpoints = ILog(log).getActivityTouchpoints(aListId, aNonce);

            uint256 length = touchpoints.length;
            for (uint256 i; i < length; ++i) {
                // if (touchpoints[i].)
            }
        }
    }
}
