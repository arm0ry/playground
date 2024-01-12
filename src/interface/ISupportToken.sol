// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/// @notice Interface to Harberger tax tokens.
interface ISupportToken {
    /// @notice Initialization logic.
    /// @notice Quest SupportToken.
    function init(
        string memory _name,
        string memory _symbol,
        address _quest,
        address _mission,
        uint256 _missionId,
        address _curve
    ) external payable;
    /// @notice Mission SupportToken.
    function init(string memory _name, string memory _symbol, address _mission, uint256 _missionId, address _curve)
        external
        payable;

    /// @notice Patron logic.
    function mint(address to) external payable;
    function burn(uint256 id) external payable;

    /// @notice Getter logic.
    function totalSupply() external view returns (uint256);
    function ownerOf(uint256 id) external view returns (address);
}
