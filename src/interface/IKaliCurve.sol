// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

enum CurveType {
    NA,
    LINEAR,
    CURVE
}

/// @notice Kali DAO share manager interface
interface IKaliCurve {
    /// @dev DAO logic
    function getKaliDaoFactory() external view returns (address);
    function getImpactDao(uint256 curveId) external view returns (address);

    /// @dev User logic.
    function mint(uint256 curveId, address patron) external payable;
    function burn(uint256 curveId, address patron) external payable;
    function claim() external payable;
    function getUnclaimed(address user) external view returns (uint256);

    /// @dev Curve setter logic
    function curve(
        uint256 curveId,
        CurveType curveType,
        uint256 minSupplyToBurn,
        uint256 constant_a,
        uint256 constant_b,
        uint256 constant_c,
        bool sale,
        string calldata detail
    ) external payable returns (uint256);
    function setCurveDetail(uint256 curveId, string calldata detail) external payable;
    function setCurveMintStatus(uint256 curveId, bool sale) external payable;
    function setMintConstantA(uint256 curveId, uint256 constant_a) external payable;
    function setMintConstantB(uint256 curveId, uint256 constant_b) external payable;
    function setMintConstantC(uint256 curveId, uint256 constant_c) external payable;
    function setBurnConstantA(uint256 curveId, uint256 constant_a) external payable;
    function setBurnConstantB(uint256 curveId, uint256 constant_b) external payable;
    function setBurnConstantC(uint256 curveId, uint256 constant_c) external payable;

    /// @dev Curve getter logic.
    function getOwner(uint256 curveId) external view returns (address);
    function getCurveCount() external view returns (uint256);
    function getCurveDetail(uint256 curveId) external view returns (string memory);
    function getCurveSupply(uint256 curveId) external view returns (uint256);
    function getCurveMinSupplyToBurn(uint256 curveId) external view returns (uint256);
    function getCurveMintStatus(uint256 curveId) external view returns (bool);
    function getCurveType(uint256 curveId) external view returns (CurveType);
    function getMintConstantA(uint256 curveId) external view returns (uint256);
    function getMintConstantB(uint256 curveId) external view returns (uint256);
    function getMintConstantC(uint256 curveId) external view returns (uint256);
    function getBurnConstantA(uint256 curveId) external view returns (uint256);
    function getBurnConstantB(uint256 curveId) external view returns (uint256);
    function getBurnConstantC(uint256 curveId) external view returns (uint256);
    function getMintPrice(uint256 curveId) external returns (uint256);
    function getBurnPrice(uint256 curveId) external returns (uint256);
}
