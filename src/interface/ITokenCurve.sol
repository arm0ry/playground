// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

enum CurveType {
    NA,
    LINEAR,
    QUADRATIC
}

struct Curve {
    address owner;
    address token;
    uint256 id;
    uint256 supply;
    // uint256 maxSupply;
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

struct Collected {
    uint256 amountInCurrency;
    uint256 amountInStablecoin;
    uint256 amountConverted;
}

interface ITokenCurve {
    /// @notice Curve logic.
    function registerCurve(Curve memory curve) external payable;
    function treasuries(uint256) external view returns (uint256);

    /// @notice Patron logic.
    function support(uint256 curveId, address patron, uint256 price) external payable;
    function burn(uint256 curveId, address patron, uint256 tokenId) external payable;

    /// @notice Getter logic.
    function getCurve(uint256 curveId) external view returns (Curve memory);
    function getCurvePrice(bool mint, uint256 curveId, uint256 supply) external view returns (uint256);
}
