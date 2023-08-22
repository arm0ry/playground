// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IQuest {
    function getMissionCompletionsCount(uint8 missionId) external view returns (uint256);

    function mission() external view returns (address);

    function encode(address tokenAddress, uint256 tokenId, address missions, uint256 missionId, uint256 taskId)
        external
        pure
        returns (bytes memory);

    function decode(bytes calldata b)
        external
        pure
        returns (address tokenAddress, uint256 tokenId, address missions, uint256 missionId, uint256 taskId);
}
