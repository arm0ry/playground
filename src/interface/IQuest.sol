// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {QuestDetail} from "../Quest.sol";

interface IQuest {
    function getQuestDetail(bytes32 questKey) external view returns (QuestDetail memory);

    function encode(address tokenAddress, uint256 tokenId, address missions, uint256 missionId, uint256 taskId)
        external
        pure
        returns (bytes memory);
}
