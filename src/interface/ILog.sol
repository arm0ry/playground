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
    function getActvitiyData(uint256 id)
        external
        view
        returns (address user, address bulletin, uint256 listId, uint256 nonce);

    function getActvitiyTouchpoints(uint256 id, uint256 nonce)
        external
        view
        returns (Touchpoint[] memory touchpoints);
}
