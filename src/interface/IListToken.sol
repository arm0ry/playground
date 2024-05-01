// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/// @notice Interface to Harberger tax tokens.
interface IListToken {
    function updateInputs(uint256 tokenId, uint128 listId, uint128 curveId) external payable;
}
