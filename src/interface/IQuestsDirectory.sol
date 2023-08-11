// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

enum ListType {
    MISSION_START,
    MISSION_COMPLETE,
    ACCESS_LIST
}

struct Listing {
    address account;
    bool approval;
}

interface IQuestsDirectory {
    function totalSupply(uint256 id) external view returns (uint256);
    function exists(uint256 id) external view returns (bool);
    function listAccount(ListType listType, uint256 missionId, address account, bool approval) external payable;
    function updateList(ListType listType, uint256 missionId, Listing[] calldata listings) external payable;
}
