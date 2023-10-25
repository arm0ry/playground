// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IKaliBerger {
    /// @notice ERC721 token logic.
    function escrow(address token, uint256 tokenId) external payable;
    function pull(address token, uint256 tokenId) external payable;
    function setTokenDetail(address token, uint256 tokenId, string calldata detail) external payable;

    /// @notice DAO logic.
    function approve(address token, uint256 tokenId, bool sale, string calldata detail) external payable;
    function balanceDao(address token, uint256 tokenId) external payable;
    function setKaliDaoFactory(address factory) external payable;
    function setCertificateMinter(address factory) external payable;
    function setTax(address token, uint256 tokenId, uint256 _tax) external payable;

    /// @notice Claim logic.
    function claim() external payable;
    function getUnclaimed(address user) external view returns (uint256);

    /// @notice Buyer/Owner logic.
    function buy(address token, uint256 tokenId, uint256 newPrice, uint256 currentPrice) external payable;
    function setPrice(address token, uint256 tokenId, uint256 price) external payable;
    function addDeposit(address token, uint256 tokenId, uint256 amount) external payable;
    function exit(address token, uint256 tokenId, uint256 amount) external payable;

    /// @notice DAO getter logic.
    function getKaliDaoFactory() external view returns (address);
    function getCertificateMinter() external view returns (address);
    function getBergerCount() external view returns (uint256);
    function getImpactDao(address token, uint256 tokenId) external view returns (address);
    function getTokenPurchaseStatus(address token, uint256 tokenId) external view returns (bool);
    function getTax(address token, uint256 tokenId) external view returns (uint256 _tax);

    /// @notice ERC721 token getter logic.
    function getPrice(address token, uint256 tokenId) external view returns (uint256);
    function getCreator(address token, uint256 tokenId) external view returns (address);
    function getTokenDetail(address token, uint256 tokenId) external view returns (string memory);
    function getDeposit(address token, uint256 tokenId) external view returns (uint256);
    function getTimeLastCollected(address token, uint256 tokenId) external view returns (uint256);
    function getTimeAcquired(address token, uint256 tokenId) external view returns (uint256);
    function getTimeHeld(address user) external view returns (uint256);
    function getOwner(address token, uint256 tokenId) external view returns (address);

    /// @notice Harberger Tax logic.
    function getTotalCollected(address token, uint256 tokenId) external view returns (uint256);
    function patronageToCollect(address token, uint256 tokenId) external view returns (uint256 amount);

    /// @notice Patron logic.
    function isPatron(address token, uint256 tokenId, address patron) external view returns (bool);
    function getPatron(address token, uint256 tokenId, uint256 patronId) external view returns (address);
    function getPatronId(address token, uint256 tokenId, address patron) external view returns (uint256);
    function getPatronCount(address token, uint256 tokenId) external view returns (uint256);
    function getPatronContribution(address token, uint256 tokenId, address patron) external view returns (uint256);
}
