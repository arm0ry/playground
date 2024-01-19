// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

enum CurveType {
    NA,
    LINEAR,
    POLY
}

interface IImpactCurve {
    /// @notice DAO logic.
    function initialize(address dao) external payable;

    /// @notice Curve logic.
    function curve(
        CurveType curveType,
        address token,
        address owner,
        uint96 scale,
        uint16 burnRatio, // Relative to mint price.
        uint48 constant_a,
        uint48 constant_b,
        uint48 constant_c
    ) external payable returns (uint256 curveId);

    /// @notice Patron logic.
    function claim() external payable;
    function support(uint256 curveId, uint256 price) external payable;
    function burn(uint256 curveId, address patron, uint256 tokenId) external payable;

    /// @notice Getter logic.
    function getCurveId() external view returns (uint256);
    function getCurveOwner(uint256 curveId) external view returns (address);
    function getCurveToken(uint256 curveId) external view returns (address);
    function getCurveTreasury(uint256 curveId) external view returns (uint256);
    function getCurveType(uint256 curveId) external view returns (CurveType);
    function getCurveFormula(uint256 curveId) external view returns (uint256, uint256, uint256, uint256, uint256);
    function getCurveBurned(uint256 curveId, address patron, bool burned) external view returns (bool);
    function getPrice(bool mint, uint256 curveId, uint256 supply) external view returns (uint256);
    function getMintBurnDifference(uint256 curveId) external view returns (uint256);
    function getUnclaimed(address user) external view returns (uint256);

    /// @notice Helper logic.
    function encodeCurveData(uint96 scale, uint16 burnRatio, uint48 constant_a, uint48 constant_b, uint48 constant_c)
        external
        pure
        returns (uint256);
    function decodeCurveData(uint256 key) external pure returns (uint256, uint256, uint256, uint256, uint256);
}
