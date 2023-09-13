// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {QuestDetail} from "../Quest.sol";

interface IQuest {
    function getQuestDetail(address user, uint256 questStarts)
        external
        view
        returns (bytes32 questKey, QuestDetail memory);

    function encodeKey(address missions, uint48 missionId, uint48 taskId) external pure returns (bytes32);

    function decodeKey(bytes32 key) external pure returns (address, uint256, uint256);

    function encodeNftKey(address tokenAddress, uint256 tokenId) external pure returns (bytes32);

    function decodeNftKey(bytes32 nftKey) external pure returns (address, uint256);
}
