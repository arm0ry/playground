// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ITravelers {
    function mintTravelerPass() external payable returns (uint256);

    function ownerOf(uint256 id) external view returns (address);

    function balanceOf(address account) external view returns (uint256);

    function transferFrom(address from, address to, uint256 id) external payable;

    function safeTransferFrom(address from, address to, uint256 id) external payable;
}
