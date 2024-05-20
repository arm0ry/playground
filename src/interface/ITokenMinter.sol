// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/// @notice Interface to Harberger tax tokens.
interface ITokenMinter {
    function config(
        uint256 id,
        address builder,
        uint256 builderId,
        string calldata name,
        string calldata desc,
        address bulletin,
        uint256 listId,
        address logger,
        address market
    ) external payable;
    function mint(address to, uint256 id) external payable;
    function burn(address from, uint256 id) external payable;
    function balanceOf(address _owner, uint256 _id) external view returns (uint256);
    function uri(uint256 id) external view returns (string memory);
}
