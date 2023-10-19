// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {LibString} from "../../lib/solbase/src/utils/LibString.sol";
import {IERC721} from "../../lib/forge-std/src/interfaces/IERC721.sol";
import {IERC20} from "../../lib/forge-std/src/interfaces/IERC20.sol";

import {IStorage} from "../interface/IStorage.sol";
import {Storage} from "../Storage.sol";

import {KaliDAOfactory} from "./KaliDAOfactory.sol";
import {IKaliTokenManager} from "../interface/IKaliTokenManager.sol";
import {IKaliCurve, CurveType} from "../interface/IKaliCurve.sol";

/// @notice When DAOs use math equations as basis for selling goods and services and
///         automagically form subDAOs, good things happen!
/// @author audsssy.eth
contract KaliCurve is Storage {
    /// -----------------------------------------------------------------------
    /// Custom Error
    /// -----------------------------------------------------------------------

    error NotAuthorized();
    error TransferFailed();
    error InvalidExit();
    error NotInitialized();
    error InvalidAmount();

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    function initialize(address dao, address daoFactory) external {
        if (daoFactory != address(0)) {
            init(dao, address(0));
            this.setKaliDaoFactory(daoFactory);
        }
    }

    /// -----------------------------------------------------------------------
    /// Modifiers
    /// -----------------------------------------------------------------------

    modifier initialized() {
        if (this.getKaliDaoFactory() == address(0) || this.getDao() == address(0)) revert NotInitialized();
        _;
    }

    modifier onlyOwner(uint256 curveId) {
        if (this.getOwner(curveId) != msg.sender) revert NotAuthorized();
        _;
    }

    modifier forSale(uint256 curveId) {
        if (!this.getTokenPurchaseStatus(curveId)) revert NotInitialized();
        _;
    }

    /// -----------------------------------------------------------------------
    /// Creator Logic
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// DAO Logic
    /// -----------------------------------------------------------------------

    /// @notice Seed a curve.
    function configureCurve(
        uint256 curveId,
        CurveType curveType,
        uint256 constant_a,
        uint256 constant_b,
        uint256 constant_c,
        uint256 maxSupply,
        uint256 maxPrice,
        bool sale,
        string calldata detail
    ) external payable {
        if (curveId == 0) {
            // Start number of curves at 1.
            curveId = incrementCurveCount();

            // Initialize curve owner.
            setOwner(curveId, msg.sender);

            // TODO: Make sure burn() only starts at total supply of 2
            // Increment total supply for curve.
            incrementCurveSupply(curveId);
        }

        // Set max supply.
        if (maxSupply > 0) _setCurveMaxSupply(curveId, maxSupply);

        // Set max price.
        if (maxPrice > 0) _setCurveMaxPrice(curveId, maxPrice);

        // Set sale status.
        if (sale) _setCurvePurchaseStatus(curveId, sale);

        // Set any detail.
        if (bytes(detail).length > 0) _setCurveDetail(curveId, detail);
    }

    /// -----------------------------------------------------------------------
    /// ImpactDAO memberships
    /// -----------------------------------------------------------------------

    /// @notice Public function to rebalance any Impact DAO.
    /// @param token ERC721 token address.
    /// @param tokenId ERC721 tokenId.
    function balanceDao(address token, uint256 tokenId) external payable {
        _balance(token, tokenId, this.getImpactDao(token, tokenId));
    }

    /// @notice Update Impact DAO balance when ERC721 is purchased.
    /// @param token ERC721 token address.
    /// @param tokenId ERC721 tokenId.
    /// @param patron Patron of ERC721.
    function updateBalances(address token, uint256 tokenId, address impactDao, address patron) internal {
        if (impactDao == address(0)) {
            // Summon DAO with 50/50 ownership between creator and patron(s).
            this.setImpactDao(token, tokenId, summonDao(token, tokenId, this.getCreator(token, tokenId), patron));
        } else {
            // Update DAO balance.
            _balance(token, tokenId, impactDao);
        }
    }

    /// @notice Summon an Impact DAO.
    function summonDao(uint256 curveId, address owner) private returns (address) {
        // Provide creator and patron to summon DAO.
        address[] memory voters = new address[](1);
        voters[0] = owner;

        // Provide respective token amount.
        uint256[] memory tokens = new uint256[](1);
        tokens[0] = 1;

        // Have ImpactDAO hooked up to KaliCurve at start so that KaliCurve may mint/burn tokens on behalf of ImpactDAO.
        address[] memory extensions = new address[](1);
        extensions[0] = address(this);
        bytes[] memory extensionsData = new bytes[](1);
        extensionsData[0] = "0x0";

        // Provide KaliDAO governance settings.
        uint32[16] memory govSettings;
        govSettings = [uint32(300), 0, 20, 52, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1];

        // Summon a KaliDAO
        uint256 count = this.getCurveCount();
        address payable impactDao = payable(
            KaliDAOfactory(this.getKaliDaoFactory()).deployKaliDAO(
                string.concat("BergerTime #", LibString.toString(count)),
                string.concat("BT #", LibString.toString(count)),
                " ",
                true,
                extensions,
                extensionsData,
                voters,
                tokens,
                govSettings
            )
        );

        // Store dao address for future.
        this.setImpactDao(curveId, impactDao);
        return impactDao;
    }

    /// @notice Rebalance Impact DAO.
    /// @param token ERC721 token address.
    /// @param tokenId ERC721 tokenId.
    /// @param dao ImpactDAO summoned for ERC721.
    function _balance(address token, uint256 tokenId, address dao) private {
        uint256 count = this.getPatronCount(token, tokenId);
        for (uint256 i = 1; i <= count;) {
            // Retrieve patron and patron contribution.
            address _patron = this.getPatron(token, tokenId, i);
            uint256 contribution = this.getPatronContribution(token, tokenId, _patron);

            // Retrieve KaliDAO balance data.
            uint256 _contribution = IERC20(dao).balanceOf(_patron);

            // Retrieve creator.
            address creator = this.getCreator(token, tokenId);

            // Determine to mint or burn.
            if (contribution > _contribution) {
                IKaliTokenManager(dao).mintTokens(creator, contribution - _contribution);
                IKaliTokenManager(dao).mintTokens(_patron, contribution - _contribution);
            } else {
                IKaliTokenManager(dao).burnTokens(creator, _contribution - contribution);
                IKaliTokenManager(dao).burnTokens(_patron, _contribution - contribution);
            }

            unchecked {
                ++i;
            }
        }
    }

    /// -----------------------------------------------------------------------
    /// Unclaimed Logic
    /// -----------------------------------------------------------------------

    /// @notice Claim tax revenue and unsuccessful transfers.
    function claim() external payable {
        uint256 amount = this.getUnclaimed(msg.sender);
        if (amount == 0) revert InvalidAmount();

        deleteUnclaimed(msg.sender);

        (bool success,) = msg.sender.call{value: amount}("");
        if (!success) revert TransferFailed();
    }

    /// -----------------------------------------------------------------------
    /// Patron Logic
    /// -----------------------------------------------------------------------

    /// @notice Buy Patron Certificate.
    /// @param token ERC721 token address.
    /// @param tokenId ERC721 tokenId.
    /// @param newPrice New purchase price for ERC721.
    /// @param currentPrice Current purchase price for ERC721.
    function buy(address token, uint256 tokenId, uint256 newPrice, uint256 currentPrice)
        external
        payable
        initialized
        forSale(token, tokenId)
    {
        address owner = this.getOwner(token, tokenId);

        // Pay currentPrice + deposit to current owner.
        processPayment(token, tokenId, owner, newPrice, currentPrice);

        // Balance DAO according to updated contribution.
        updateBalances(token, tokenId, this.getImpactDao(token, tokenId), msg.sender);

        // TODO: check (1) if already summoned, (2) if initial owner token to jumpstart impactDao is burned
        // Summon ImpactDAO
        summonDao(curveId, msg.sender);
    }

    /// -----------------------------------------------------------------------
    /// Setter Logic
    /// -----------------------------------------------------------------------

    function setKaliDaoFactory(address factory) external payable onlyOperator {
        this.setAddress(keccak256(abi.encodePacked("dao.factory")), factory);
    }

    function setImpactDao(uint256 curveId, address impactDao) external payable onlyOperator {
        this.setAddress(keccak256(abi.encode(curveId, ".impactDao")), impactDao);
    }

    function setOwner(uint256 curveId, address owner) internal {
        this.setAddress(keccak256(abi.encode(curveId, ".owner")), owner);
    }

    function setCurveDetail(uint256 curveId, string calldata detail) external payable onlyOperator {
        this.setString(keccak256(abi.encode(curveId, ".detail")), detail);
    }

    function _setCurveDetail(uint256 curveId, string calldata detail) internal {
        this.setString(keccak256(abi.encode(curveId, ".detail")), detail);
    }

    function setCurvePurchaseStatus(uint256 curveId, bool sale) external payable onlyOwner(curveId) {
        this.setBool(keccak256(abi.encode(curveId, ".forSale")), sale);
    }

    function _setCurvePurchaseStatus(uint256 curveId, bool sale) internal {
        this.setBool(keccak256(abi.encode(curveId, ".forSale")), sale);
    }

    function setPatron(uint256 curveId, address patron) internal {
        incrementPatronId(curveId);
        this.setAddress(keccak256(abi.encode(curveId, this.getPatronCount(curveId))), patron);
    }

    function setPatronStatus(uint256 curveId, address patron, bool status) internal {
        this.setBool(keccak256(abi.encode(curveId, patron, ".isPatron")), status);
    }

    /// -----------------------------------------------------------------------
    /// Curve Setter Logic
    /// -----------------------------------------------------------------------

    function setCurveMaxSupply(uint256 curveId, uint256 maxSupply) external payable onlyOwner(curveId) {
        _setCurveMaxSupply(curveId, maxSupply);
    }

    function setCurveMaxPrice(uint256 curveId, uint256 maxPrice) external payable onlyOwner(curveId) {
        _setCurveMaxPrice(curveId, maxPrice);
    }

    function setMintConstantA(uint256 curveId, uint256 constant_a) external payable onlyOwner(curveId) {
        _setMintConstantA(curveId, constant_a);
    }

    function setMintConstantB(uint256 curveId, uint256 constant_b) external payable onlyOwner(curveId) {
        _setMintConstantB(curveId, constant_b);
    }

    function setMintConstantC(uint256 curveId, uint256 constant_c) external payable onlyOwner(curveId) {
        _setMintConstantC(curveId, constant_c);
    }

    function setBurnConstantA(uint256 curveId, uint256 constant_a) external payable onlyOwner(curveId) {
        _setBurnConstantA(curveId, constant_a);
    }

    function setBurnConstantB(uint256 curveId, uint256 constant_b) external payable onlyOwner(curveId) {
        _setBurnConstantB(curveId, constant_b);
    }

    function setBurnConstantC(uint256 curveId, uint256 constant_c) external payable onlyOwner(curveId) {
        _setBurnConstantC(curveId, constant_c);
    }

    function setCurveType(uint256 curveId, CurveType curveType) internal {
        this.setUint(keccak256(abi.encode(curveId, ".curveType")), uint256(curveType));
    }

    function incrementCurveSupply(uint256 curveId) internal {
        addUint(keccak256(abi.encode(curveId, ".supply")), 1);
    }

    function _setCurveMaxSupply(uint256 curveId, uint256 maxSupply) internal {
        if (this.getCurveMaxSupply(curveId) >= maxSupply) revert InvalidAmount();
        this.setUint(keccak256(abi.encode(curveId, ".maxSupply")), uint256(maxSupply));
    }

    function _setCurveMaxPrice(uint256 curveId, uint256 maxPrice) internal {
        if (this.getCurveMaxPrice(curveId) >= maxPrice) revert InvalidAmount();
        this.setUint(keccak256(abi.encode(curveId, ".maxPrice")), uint256(maxPrice));
    }

    function _setMintConstantA(uint256 curveId, uint256 constant_a) internal {
        // To prevent future calculation errors, such as arithmetic overflow/underflow.
        if (constant_a - this.getBurnConstantA(curveId) >= 0) {
            this.setUint(keccak256(abi.encode(curveId, ".mint.a")), constant_a);
        }
    }

    function _setMintConstantB(uint256 curveId, uint256 constant_b) internal {
        // To prevent future calculation errors, such as arithmetic overflow/underflow.
        if (constant_b - this.getBurnConstantB(curveId) >= 0) {
            this.setUint(keccak256(abi.encode(curveId, ".mint.b")), constant_b);
        }
    }

    function _setMintConstantC(uint256 curveId, uint256 constant_c) internal {
        // To prevent future calculation errors, such as arithmetic overflow/underflow.
        if (constant_c - this.getBurnConstantC(curveId) >= 0) {
            this.setUint(keccak256(abi.encode(curveId, ".mint.c")), constant_c);
        }
    }

    function _setBurnConstantA(uint256 curveId, uint256 constant_a) internal {
        // To prevent future calculation errors, such as arithmetic overflow/underflow.
        if (this.getMintConstantA(curveId) - constant_a >= 0) {
            this.setUint(keccak256(abi.encode(curveId, ".burn.a")), constant_a);
        }
    }

    function _setBurnConstantB(uint256 curveId, uint256 constant_b) internal {
        // To prevent future calculation errors, such as arithmetic overflow/underflow.
        if (this.getMintConstantB(curveId) - constant_b >= 0) {
            this.setUint(keccak256(abi.encode(curveId, ".burn.b")), constant_b);
        }
    }

    function _setBurnConstantC(uint256 curveId, uint256 constant_c) internal {
        // To prevent future calculation errors, such as arithmetic overflow/underflow.
        if (this.getMintConstantC(curveId) - constant_c >= 0) {
            this.setUint(keccak256(abi.encode(curveId, ".burn.c")), constant_c);
        }
    }
    /// -----------------------------------------------------------------------
    /// Getter Logic
    /// -----------------------------------------------------------------------

    function getKaliDaoFactory() external view returns (address) {
        return this.getAddress(keccak256(abi.encodePacked("dao.factory")));
    }

    function getCurveCount() external view returns (uint256) {
        return this.getUint(keccak256(abi.encodePacked("bergerTimes.count")));
    }

    function getImpactDao(uint256 curveId) external view returns (address) {
        return this.getAddress(keccak256(abi.encode(curveId, ".impactDao")));
    }

    function getTokenPurchaseStatus(uint256 curveId) external view returns (bool) {
        return this.getBool(keccak256(abi.encode(curveId, ".forSale")));
    }

    /// -----------------------------------------------------------------------
    /// Curve Getter Logic
    /// -----------------------------------------------------------------------

    function getCurveType(uint256 curveId, CurveType curveType) external view returns (CurveType) {
        return CurveType(this.getUint(keccak256(abi.encode(curveId, ".curveType"))));
    }

    function getMintConstantA(uint256 curveId) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(curveId, ".mint.a")));
    }

    function getMintConstantB(uint256 curveId) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(curveId, ".mint.b")));
    }

    function getMintConstantC(uint256 curveId) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(curveId, ".mint.c")));
    }

    function getBurnConstantA(uint256 curveId) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(curveId, ".burn.a")));
    }

    function getBurnConstantB(uint256 curveId) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(curveId, ".burn.b")));
    }

    function getBurnConstantC(uint256 curveId) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(curveId, ".burn.c")));
    }

    // mint formula - initMintPrice + supply * initMintPrice / 50 + (supply ** 2) * initMintPrice / 100;
    // burn formula - initMintPrice + supply * initMintPrice / 50 + (supply ** 2) * initMintPrice / 200;

    /// @notice Calculate mint price.
    function getMintPrice(uint256 curveId, CurveType curveType) external view returns (uint256) {
        uint256 supply;

        // Retrieve constants.
        uint256 constant_a = this.getConsantA(curveId);
        uint256 constant_b = this.getConsantB(curveId);
        uint256 constant_c = this.getConsantC(curveId);

        // Return linear pricing based on, a * b * x + b.
        if (curveType == CurveType.LINEAR) {
            return constant_a * constant_b * supply + constant_b;
        } else {
            // Return curve pricing based on, a * c * x^2 + b * c * x + c.
            return constant_a * constant_c * (supply ** 2) + constant_b * constant_c * supply + constant_c;
        }
    }

    /// @notice Calculate burn price.
    function getBurnPrice(uint256 curveId, CurveType curveType) external view returns (uint256) {
        uint256 supply;

        // Retrieve constants.
        uint256 constant_a = this.getConsantA(curveId);
        uint256 constant_b = this.getConsantB(curveId);
        uint256 constant_c = this.getConsantC(curveId);

        // Return linear pricing based on, a * b * x + b.
        if (curveType == CurveType.LINEAR) {
            return constant_a * supply + constant_b;
        } else {
            // Return curve pricing based on, a * c * x^2 + b * c * x + c.
            return constant_a * (supply ** 2) + constant_b * supply + constant_c;
        }
    }

    function getBurnPrice(uint256 curveId, uint256 curveType) external view returns (uint256) {
        uint256 initMintPrice = 100000000000000; // at 0
        uint256 supply;
    }

    function getOwner(uint256 curveId) external view returns (address) {
        return this.getAddress(keccak256(abi.encode(curveId, ".owner")));
    }

    function getCurveDetail(uint256 curveId) external view returns (string memory) {
        return this.getString(keccak256(abi.encode(curveId, ".detail")));
    }

    function getUnclaimed(address user) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(user, ".unclaimed")));
    }

    function getTotalCollected(uint256 curveId) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(curveId, ".totalCollected")));
    }

    function getPatronCount(uint256 curveId) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(curveId, ".patronCount")));
    }

    // /// @notice There is a chance of exceeding tx size if there are too many patrons in a curve.
    // function getPatronId(uint256 curveId, address patron) external view returns (uint256) {
    //     uint256 count = this.getPatronCount(curveId);

    //     for (uint256 i = 0; i < count;) {
    //         if (patron == this.getPatron(curveId, i)) return i;
    //         unchecked {
    //             ++i;
    //         }
    //     }

    //     return 0;
    // }

    function isPatron(uint256 curveId, address patron) external view returns (bool) {
        return this.getBool(keccak256(abi.encode(curveId, patron, ".isPatron")));
    }

    function getPatron(uint256 curveId, uint256 patronId) external view returns (address) {
        return this.getAddress(keccak256(abi.encode(curveId, patronId)));
    }

    function getPatronContribution(uint256 curveId, address patron) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(curveId, patron, ".contribution")));
    }

    /// -----------------------------------------------------------------------
    /// Add Logic
    /// -----------------------------------------------------------------------

    function _addDeposit(address token, uint256 tokenId, uint256 amount) internal {
        addUint(keccak256(abi.encode(token, tokenId, ".deposit")), amount);
    }

    function subDeposit(address token, uint256 tokenId, uint256 amount) internal {
        subUint(keccak256(abi.encode(token, tokenId, ".deposit")), amount);
    }

    function addUnclaimed(address user, uint256 amount) internal {
        addUint(keccak256(abi.encode(user, ".unclaimed")), amount);
    }

    function addTotalCollected(address token, uint256 tokenId, uint256 collected) internal {
        addUint(keccak256(abi.encode(token, tokenId, ".totalCollected")), collected);
    }

    function addPatronContribution(address token, uint256 tokenId, address patron, uint256 amount) internal {
        addUint(keccak256(abi.encode(token, tokenId, patron, ".contribution")), amount);
    }

    function incrementCurveCount() internal {
        addUint(keccak256(abi.encodePacked("bergerTimes.count")), 1);
    }

    function incrementPatronId(address token, uint256 tokenId) internal {
        addUint(keccak256(abi.encode(token, tokenId, ".patronCount")), 1);
    }

    /// -----------------------------------------------------------------------
    /// Delete Logic
    /// -----------------------------------------------------------------------

    function deleteUnclaimed(address user) internal {
        deleteUint(keccak256(abi.encode(user, ".unclaimed")));
    }

    function deleteTokenPurchaseStatus(address token, uint256 tokenId) internal {
        return deleteBool(keccak256(abi.encode(token, tokenId, ".forSale")));
    }

    /// @notice Process purchase payment.
    /// @param token ERC721 token address.
    /// @param tokenId ERC721 tokenId.
    /// @param currentOwner Current owner of ERC721.
    /// @param newPrice New price of ERC721.
    /// @param currentPrice Current price of ERC721.
    /// credit: simondlr  https://github.com/simondlr/thisartworkisalwaysonsale/blob/master/packages/hardhat/contracts/v1/ArtStewardV2.sol
    function processPayment(
        address token,
        uint256 tokenId,
        address currentOwner,
        uint256 newPrice,
        uint256 currentPrice
    ) internal {
        // Confirm price.
        uint256 price = this.getPrice(token, tokenId);
        if (price != currentPrice || newPrice == 0 || currentPrice > msg.value) revert InvalidAmount();

        // Add purchase price to patron contribution.
        addPatronContribution(token, tokenId, msg.sender, price);

        // Retrieve deposit, if any.
        uint256 deposit = this.getDeposit(token, tokenId);

        if (price + deposit > 0) {
            // this won't execute if KaliBerger owns it. price = 0. deposit = 0.
            // pay previous owner their price + deposit back.
            (bool success,) = currentOwner.call{value: price + deposit}("");
            if (!success) addUnclaimed(currentOwner, price + deposit);
        }

        // Make deposit, if any.
        _addDeposit(token, tokenId, msg.value - price);
    }

    /// @notice Interface for any contract that wants to support safeTransfers from ERC721 asset contracts.
    /// credit: z0r0z.eth https://github.com/kalidao/kali-contracts/blob/main/contracts/utils/NFTreceiver.sol
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4 sig) {
        sig = 0x150b7a02; // 'onERC721Received(address,address,uint256,bytes)'
    }

    receive() external payable virtual {}
}
