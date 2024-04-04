// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

struct Activity {
    address user;
    address bulletin;
    uint256 listId;
    uint256 nonce;
    // nonce => Touchpoint
    mapping(uint256 => Touchpoint) touchpoints;
}

struct Touchpoint {
    bool pass;
    uint256 itemId;
    bytes data;
}

interface ILog {
    function activityId() external view returns (uint256);

    function getActivityData(uint256 id)
        external
        view
        returns (address user, address bulletin, uint256 listId, uint256 nonce);

    function getActivityTouchpoints(uint256 id)
        external
        view
        returns (Touchpoint[] memory touchpoints, uint256 percentageOfCompletion);
}
