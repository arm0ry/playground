// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IImpactToken {
    function mint(address to, uint256 id) external;
    function getTokenId(address missions, uint256 missionId) external pure returns (uint256);
    function decodeTokenId(uint256 tokenId) external pure returns (address missions, uint256 missionId);
}
