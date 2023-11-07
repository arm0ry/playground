// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {LibString} from "../../lib/solbase/src/utils/LibString.sol";
import {IERC721} from "../../lib/forge-std/src/interfaces/IERC721.sol";
import {IERC20} from "../../lib/forge-std/src/interfaces/IERC20.sol";

import {IStorage} from "kali-berger/interface/IStorage.sol";
import {Storage} from "kali-berger/Storage.sol";

import {KaliDAOfactory} from "./KaliDAOfactory.sol";
import {IKaliTokenManager} from "kali-berger/interface/IKaliTokenManager.sol";
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
    error NotInitialized();
    error InvalidAmount();
    error InvalidMint();
    error InvalidBurn();

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    function initialize(address dao, address daoFactory) external {
        if (daoFactory != address(0)) {
            init(dao);
            setKaliDaoFactory(daoFactory);
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
        if (!this.getCurveMintStatus(curveId)) revert NotInitialized();
        _;
    }

    /// -----------------------------------------------------------------------
    /// Creator Logic
    /// -----------------------------------------------------------------------

    /// @notice Configure a curve.
    function curve(
        address owner,
        uint256 curveId,
        CurveType curveType,
        uint256 minSupplyToBurn,
        uint256 constant_a,
        uint256 constant_b,
        uint256 constant_c,
        bool sale,
        string calldata detail
    ) external payable returns (uint256) {
        // Setup new curve.
        if (curveId == 0) {
            // Increment and assign curveId.
            curveId = incrementCurveId();

            // Initialize curve owner.
            setOwner(curveId, owner);

            // Initialize curve type.
            setCurveType(curveId, curveType);

            // Initialize curve type.
            _setMintConstantA(curveId, constant_a);

            // Initialize curve type.
            _setMintConstantB(curveId, constant_b);

            // Initialize curve type.
            _setMintConstantC(curveId, constant_c);

            // Initialize minimum supply required before burn is activated.
            setCurveMinSupplyToBurn(curveId, minSupplyToBurn);
        }

        // Set sale status.
        if (sale != this.getCurveMintStatus(curveId)) _setCurveMintStatus(curveId, sale);

        // Set any detail.
        if (bytes(detail).length > 0) _setCurveDetail(curveId, detail);

        return curveId;
    }

    /// -----------------------------------------------------------------------
    /// ImpactDAO memberships
    /// -----------------------------------------------------------------------

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
                string.concat("ImpactDAO #", LibString.toString(count)),
                string.concat("ID #", LibString.toString(count)),
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
        setImpactDao(curveId, impactDao);
        return impactDao;
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

    /// @notice Mint patron certificate.
    function mint(uint256 curveId, address patron) external payable initialized forSale(curveId) {
        // Retrieve current supply and mint price.

        uint256 supply = incrementCurveSupply(curveId);
        uint256 mintPrice = _getMintPrice(curveId, supply);

        // Validate mint conditions.
        if (msg.value != mintPrice) revert InvalidAmount();
        if (this.getCurveMintStatus(curveId)) revert InvalidMint();

        // Retrieve current burn price.
        uint256 burnPrice = _getBurnPrice(curveId, supply);

        // Retrieve impactDAO.
        address impactDAO = this.getImpactDao(curveId);

        // Send price difference to impactDAO.
        (bool success,) = impactDAO.call{value: mintPrice - burnPrice}("");
        if (success) revert TransferFailed();

        // If impactDAO does not exist, summon one with owner and patron both holding one impactDAO token.
        if (impactDAO == address(0)) {
            impactDAO = summonDao(curveId, patron);
        } else {
            // If impactDAO does exist, mint one impactDAO token to owner and another to patron, only if patron does not already have one.
            if (IKaliTokenManager(impactDAO).balanceOf(patron) == 0) {
                IKaliTokenManager(impactDAO).mintTokens(this.getOwner(curveId), 1);
                IKaliTokenManager(impactDAO).mintTokens(patron, 1);
            }
        }
    }

    /// @notice Burn Patron Certificate.
    function burn(uint256 curveId, address patron) external payable initialized {
        // Retrieve impactDAO and check if patron is eligible.
        address impactDAO = this.getImpactDao(curveId);
        if (IKaliTokenManager(impactDAO).balanceOf(patron) == 0) revert InvalidBurn();

        // Retrieve current burn price.

        uint256 supply = this.getCurveSupply(curveId);
        (supply > 1) ? supply = decrementCurveSupply(curveId) : supply = 0;
        uint256 price = _getBurnPrice(curveId, supply);
        if (price == 0) revert InvalidBurn();

        // Send price to burn to patron.
        (bool success,) = patron.call{value: price}("");
        if (success) addUnclaimed(patron, price);

        // Burn patron certificate.
        IKaliTokenManager(impactDAO).burnTokens(this.getOwner(curveId), 1);
        IKaliTokenManager(impactDAO).burnTokens(patron, 1);
    }

    /// -----------------------------------------------------------------------
    /// Setter Logic
    /// -----------------------------------------------------------------------

    function setKaliDaoFactory(address factory) internal {
        _setAddress(keccak256(abi.encodePacked("dao.factory")), factory);
    }

    function setImpactDao(uint256 curveId, address impactDao) internal {
        _setAddress(keccak256(abi.encode(curveId, ".impactDao")), impactDao);
    }

    function setOwner(uint256 curveId, address owner) internal {
        _setAddress(keccak256(abi.encode(curveId, ".owner")), owner);
    }

    /// -----------------------------------------------------------------------
    /// Curve Setter Logic
    /// -----------------------------------------------------------------------

    function setCurveDetail(uint256 curveId, string calldata detail) external payable onlyOperator {
        _setString(keccak256(abi.encode(curveId, ".detail")), detail);
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

    function setCurveMintStatus(uint256 curveId, bool sale) external payable onlyOwner(curveId) {
        _setBool(keccak256(abi.encode(curveId, ".forSale")), sale);
    }

    function setCurveType(uint256 curveId, CurveType curveType) internal {
        _setUint(keccak256(abi.encode(curveId, ".curveType")), uint256(curveType));
    }

    function _setCurveDetail(uint256 curveId, string calldata detail) internal {
        _setString(keccak256(abi.encode(curveId, ".detail")), detail);
    }

    function setCurveMinSupplyToBurn(uint256 curveId, uint256 minSupplyToBurn) internal {
        _setUint(keccak256(abi.encode(curveId, ".,minSupplyToBurn")), minSupplyToBurn);
    }

    function _setCurveMintStatus(uint256 curveId, bool sale) internal {
        _setBool(keccak256(abi.encode(curveId, ".forSale")), sale);
    }

    function _setMintConstantA(uint256 curveId, uint256 constant_a) internal {
        // To prevent future calculation errors, such as arithmetic overflow/underflow.
        if (constant_a - this.getBurnConstantA(curveId) >= 0) {
            _setUint(keccak256(abi.encode(curveId, ".mint.a")), constant_a);
        }
    }

    function _setMintConstantB(uint256 curveId, uint256 constant_b) internal {
        // To prevent future calculation errors, such as arithmetic overflow/underflow.
        if (constant_b - this.getBurnConstantB(curveId) >= 0) {
            _setUint(keccak256(abi.encode(curveId, ".mint.b")), constant_b);
        }
    }

    function _setMintConstantC(uint256 curveId, uint256 constant_c) internal {
        // To prevent future calculation errors, such as arithmetic overflow/underflow.
        if (constant_c - this.getBurnConstantC(curveId) >= 0) {
            _setUint(keccak256(abi.encode(curveId, ".mint.c")), constant_c);
        }
    }

    function _setBurnConstantA(uint256 curveId, uint256 constant_a) internal {
        // To prevent future calculation errors, such as arithmetic overflow/underflow.
        if (this.getMintConstantA(curveId) - constant_a >= 0) {
            _setUint(keccak256(abi.encode(curveId, ".burn.a")), constant_a);
        }
    }

    function _setBurnConstantB(uint256 curveId, uint256 constant_b) internal {
        // To prevent future calculation errors, such as arithmetic overflow/underflow.
        if (this.getMintConstantB(curveId) - constant_b >= 0) {
            _setUint(keccak256(abi.encode(curveId, ".burn.b")), constant_b);
        }
    }

    function _setBurnConstantC(uint256 curveId, uint256 constant_c) internal {
        // To prevent future calculation errors, such as arithmetic overflow/underflow.
        if (this.getMintConstantC(curveId) - constant_c >= 0) {
            _setUint(keccak256(abi.encode(curveId, ".burn.c")), constant_c);
        }
    }
    /// -----------------------------------------------------------------------
    /// Getter Logic
    /// -----------------------------------------------------------------------

    function getKaliDaoFactory() external view returns (address) {
        return this.getAddress(keccak256(abi.encodePacked("dao.factory")));
    }

    function getCurveCount() external view returns (uint256) {
        return this.getUint(keccak256(abi.encodePacked("curves.count")));
    }

    function getImpactDao(uint256 curveId) external view returns (address) {
        return this.getAddress(keccak256(abi.encode(curveId, ".impactDao")));
    }

    /// -----------------------------------------------------------------------
    /// Curve Getter Logic
    /// -----------------------------------------------------------------------

    function getCurveSupply(uint256 curveId) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(curveId, ".supply")));
    }

    function getCurveMinSupplyToBurn(uint256 curveId) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(curveId, ".minSupplyToBurn")));
    }

    function getCurveMintStatus(uint256 curveId) external view returns (bool) {
        return this.getBool(keccak256(abi.encode(curveId, ".forSale")));
    }

    function getCurveType(uint256 curveId) external view returns (CurveType) {
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
    function getMintPrice(uint256 curveId) external view returns (uint256) {
        uint256 supply = this.getCurveSupply(curveId);
        return _getMintPrice(curveId, supply);
    }

    /// @notice Calculate mint price.
    function _getMintPrice(uint256 curveId, uint256 supply) internal view returns (uint256) {
        CurveType curveType = this.getCurveType(curveId);
        if (curveType == CurveType.NA) return 0;

        // Retrieve constants.
        uint256 constant_a = this.getMintConstantA(curveId);
        uint256 constant_b = this.getMintConstantB(curveId);
        uint256 constant_c = this.getMintConstantC(curveId);

        // Return linear pricing based on, a * b * x + b.
        if (curveType == CurveType.LINEAR) {
            return constant_a * constant_b * supply + constant_b;
        } else {
            // Return curve pricing based on, a * c * x^2 + b * c * x + c.
            return constant_a * constant_c * (supply ** 2) + constant_b * constant_c * supply + constant_c;
        }
    }

    /// @notice Calculate burn price.
    function getBurnPrice(uint256 curveId) external view returns (uint256) {
        uint256 supply = this.getCurveSupply(curveId);
        return _getBurnPrice(curveId, supply);
    }
    /// @notice Calculate burn price.

    function _getBurnPrice(uint256 curveId, uint256 supply) internal view returns (uint256) {
        CurveType curveType = this.getCurveType(curveId);
        if (curveType == CurveType.NA) return 0;

        uint256 minSupplyToBurn = this.getCurveMinSupplyToBurn(curveId);

        if (supply > minSupplyToBurn) {
            // Retrieve constants.
            uint256 constant_a = this.getBurnConstantA(curveId);
            uint256 constant_b = this.getBurnConstantB(curveId);
            uint256 constant_c = this.getBurnConstantC(curveId);

            // Return linear pricing based on, a * b * x + b.
            if (curveType == CurveType.LINEAR) {
                return constant_a * supply + constant_b;
            } else {
                // Return curve pricing based on, a * c * x^2 + b * c * x + c.
                return constant_a * (supply ** 2) + constant_b * supply + constant_c;
            }
        } else {
            return 0;
        }
    }

    function getMintBurnDifference(uint256 curveId) external view returns (uint256) {
        return this.getMintPrice(curveId) - this.getBurnPrice(curveId);
    }

    function getOwner(uint256 curveId) external view returns (address) {
        return this.getAddress(keccak256(abi.encode(curveId, ".owner")));
    }

    // TODO: Consider adding a get function ownerCurves array

    function getCurveDetail(uint256 curveId) external view returns (string memory) {
        return this.getString(keccak256(abi.encode(curveId, ".detail")));
    }

    function getUnclaimed(address user) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(user, ".unclaimed")));
    }

    /// -----------------------------------------------------------------------
    /// Add Logic
    /// -----------------------------------------------------------------------

    function addUnclaimed(address user, uint256 amount) internal returns (uint256) {
        return addUint(keccak256(abi.encode(user, ".unclaimed")), amount);
    }

    function incrementCurveSupply(uint256 curveId) internal returns (uint256) {
        return addUint(keccak256(abi.encodePacked(curveId, ".supply")), 1);
    }

    function decrementCurveSupply(uint256 curveId) internal returns (uint256) {
        return subUint(keccak256(abi.encodePacked(curveId, ".supply")), 1);
    }

    function incrementCurveId() internal returns (uint256) {
        return addUint(keccak256(abi.encodePacked("curves.count")), 1);
    }

    /// -----------------------------------------------------------------------
    /// Delete Logic
    /// -----------------------------------------------------------------------

    function deleteUnclaimed(address user) internal {
        deleteUint(keccak256(abi.encode(user, ".unclaimed")));
    }

    function deleteCurvePurchaseStatus(uint256 curveId) internal {
        deleteBool(keccak256(abi.encode(curveId, ".forSale")));
    }

    /// -----------------------------------------------------------------------
    /// ERC721 Logic
    /// -----------------------------------------------------------------------

    /// @notice Interface for any contract that wants to support safeTransfers from ERC721 asset contracts.
    /// credit: z0r0z.eth https://github.com/kalidao/kali-contracts/blob/main/contracts/utils/NFTreceiver.sol
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4 sig) {
        sig = 0x150b7a02; // 'onERC721Received(address,address,uint256,bytes)'
    }

    receive() external payable virtual {}
}
