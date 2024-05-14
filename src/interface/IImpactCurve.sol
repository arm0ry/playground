// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

enum CurveType {
    NA,
    LINEAR,
    QUADRATIC
}

struct Curve {
    uint256 id;
    address owner;
    address token;
    CurveType curveType;
    address currency;
    uint64 scale;
    uint32 mint_a;
    uint32 mint_b;
    uint32 mint_c;
    uint32 burn_a;
    uint32 burn_b;
    uint32 burn_c;
}

interface IImpactCurve {
    function initialize(address owner) external payable;

    /// @notice Curve logic.
    function registerCurve(Curve memory curve) external payable;

    /// @notice Owner logic.
    function claim(uint256 curveId, uint256 amountInCurrencyToClaim) external payable;

    /// @notice Patron logic.
    function support(uint256 curveId, address patron, uint256 price) external payable;
    function burn(uint256 curveId, address patron, uint256 tokenId) external payable;

    /// @notice Getter logic.
    function getCurve(uint256 curveId) external view returns (Curve memory);
    function getCurvePrice(bool mint, uint256 curveId, Curve memory curve, uint256 supply)
        external
        view
        returns (uint256);
    function calculatePrice(uint256 supply, uint256 scale, uint256 constant_a, uint256 constant_b, uint256 constant_c)
        external
        pure
        returns (uint256);
}
