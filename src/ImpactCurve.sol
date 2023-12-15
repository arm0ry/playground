// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {Storage} from "kali-markets/Storage.sol";

import {IImpactCurve, CurveType} from "./interface/IImpactCurve.sol";
import {ISupportToken} from "./interface/ISupportToken.sol";

/// @notice .
/// @author audsssy.eth
contract ImpactCurve is Storage {
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event CurveCreated(
        uint256 curveId,
        CurveType curveType,
        address token,
        address owner,
        uint96 scale,
        uint16 burnRatio,
        uint48 constant_a,
        uint48 constant_b,
        uint48 constant_c
    );

    /// -----------------------------------------------------------------------
    /// Custom Error
    /// -----------------------------------------------------------------------

    error NotAuthorized();
    error TransferFailed();
    error NotInitialized();
    error InvalidCurve();
    error InvalidAmount();
    error InvalidMint();
    error InvalidBurn();

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    /// @notice .
    function initialize(address dao) external payable {
        init(dao);
    }

    /// -----------------------------------------------------------------------
    /// Modifiers
    /// -----------------------------------------------------------------------

    modifier initialized() {
        if (this.getDao() == address(0)) revert NotInitialized();
        _;
    }

    /// -----------------------------------------------------------------------
    /// Creator Logic
    /// -----------------------------------------------------------------------

    /// @notice Configure a curve.
    function curve(
        CurveType curveType,
        address token,
        address owner,
        uint96 scale,
        uint16 burnRatio, // Relative to mint price.
        uint48 constant_a,
        uint48 constant_b,
        uint48 constant_c
    ) external payable returns (uint256 curveId) {
        if (ISupportToken(token).totalSupply() > 0) revert InvalidCurve();

        // Increment and assign curveId.
        curveId = incrementCurveId();

        // Initialize curve token.
        setCurveToken(curveId, token);

        // Initialize curve owner.
        setCurveOwner(curveId, owner);

        // Initialize curve type.
        setCurveType(curveId, curveType);

        // Initialize curve data.
        setCurveFormula(curveId, this.encodeCurveData(scale, burnRatio, constant_a, constant_b, constant_c));

        emit CurveCreated(curveId, curveType, token, owner, scale, burnRatio, constant_a, constant_b, constant_c);
    }

    /// -----------------------------------------------------------------------
    /// Claimed Logic
    /// -----------------------------------------------------------------------

    /// @notice Claim tax revenue and unsuccessful transfers.
    function claim() external payable {
        uint256 amount = this.getUnclaimed(msg.sender);
        if (amount == 0) revert NotAuthorized();

        deleteUnclaimed(msg.sender);

        (bool success,) = msg.sender.call{value: amount}("");
        if (!success) revert TransferFailed();
    }

    /// -----------------------------------------------------------------------
    /// Patron Logic
    /// -----------------------------------------------------------------------

    /// @notice Pay ether to mint curve token.
    function support(uint256 curveId, uint256 price) external payable initialized {
        // Validate mint conditions.
        if (msg.sender == this.getCurveOwner(curveId)) revert NotAuthorized();
        if (price != this.getPrice(true, curveId) || price != msg.value) {
            revert InvalidAmount();
        }

        // Distribute support to curve owner.
        addUnclaimed(this.getCurveOwner(curveId), price - this.getPrice(false, curveId));

        // Mint.
        address curveToken = this.getCurveToken(curveId);
        if (curveToken != address(0) && !this.getCurveBurned(curveId, msg.sender)) {
            setCurveBurned(curveId, msg.sender, true);
            ISupportToken(curveToken).mint(msg.sender, 0);
        }
    }

    /// @notice Burn curve token to receive ether.
    function burn(uint256 curveId, address patron, uint256 id) external payable initialized {
        // Validate mint conditions.
        if (!this.getCurveBurned(curveId, patron)) revert NotAuthorized();
        deleteCurveBurned(curveId, patron);

        if (ISupportToken(this.getCurveToken(curveId)).ownerOf(id) != msg.sender) revert NotAuthorized();

        // Distribute burn to patron.
        uint256 amount = this.getPrice(false, curveId);
        (bool success,) = patron.call{value: amount}("");
        if (!success) addUnclaimed(patron, amount);

        ISupportToken(this.getCurveToken(curveId)).burn(id);
    }

    /// @notice Internal function to add to unclaimed amount.
    function addUnclaimed(address user, uint256 amount) internal {
        addUint(keccak256(abi.encode(user, ".unclaimed")), amount);
    }

    /// -----------------------------------------------------------------------
    /// Curve Setter Logic
    /// -----------------------------------------------------------------------

    /// @notice .
    function setCurveToken(uint256 curveId, address token) internal {
        _setAddress(keccak256(abi.encode(curveId, ".token")), token);
    }

    /// @notice .
    function setCurveOwner(uint256 curveId, address owner) internal {
        if (owner == address(0)) revert NotAuthorized();
        _setAddress(keccak256(abi.encode(curveId, ".owner")), owner);
    }

    /// @notice .
    function setCurveType(uint256 curveId, CurveType curveType) internal {
        _setUint(keccak256(abi.encode(curveId, ".curveType")), uint256(curveType));
    }

    /// @notice .
    function setCurveFormula(uint256 curveId, uint256 key) internal {
        _setUint(keccak256(abi.encode(curveId, ".data")), key);
    }

    /// @notice .
    function setCurveBurned(uint256 curveId, address patron, bool burned) internal {
        _setBool(keccak256(abi.encode(curveId, ".patrons.", patron, ".burned")), burned);
    }

    /// @notice .
    function deleteCurveBurned(uint256 curveId, address patron) internal {
        deleteBool(keccak256(abi.encode(curveId, ".patrons.", patron, ".burned")));
    }

    /// -----------------------------------------------------------------------
    /// Curve Getter Logic
    /// -----------------------------------------------------------------------

    /// @notice Return owner of a curve.
    function getCurveOwner(uint256 curveId) external view returns (address) {
        return this.getAddress(keccak256(abi.encode(curveId, ".owner")));
    }

    /// @notice Return owner of a curve.
    function getCurveToken(uint256 curveId) external view returns (address) {
        return this.getAddress(keccak256(abi.encode(curveId, ".owner")));
    }

    /// @notice Return current supply of a curve.
    // function getCurveSupply(uint256 curveId) external view returns (uint256) {
    //     return this.getUint(keccak256(abi.encode(curveId, ".supply")));
    // }

    /// @notice Return type of a curve.
    function getCurveType(uint256 curveId) external view returns (CurveType) {
        return CurveType(this.getUint(keccak256(abi.encode(curveId, ".curveType"))));
    }

    /// @notice Return curve data in order - scale, burnRatio, constant_a, constant_b, constant_c.
    function getCurveFormula(uint256 curveId) external view returns (uint256, uint256, uint256, uint256, uint256) {
        return this.decodeCurveData(this.getUint(keccak256(abi.encode(curveId, ".data"))));
    }

    /// @notice .
    function getCurveBurned(uint256 curveId, address patron) external view returns (bool) {
        return this.getBool(keccak256(abi.encode(curveId, ".patrons.", patron, ".burned")));
    }

    /// @notice Calculate mint and burn price.
    function getPrice(bool _mint, uint256 curveId) external view virtual returns (uint256) {
        // Retrieve curve data.
        CurveType curveType = this.getCurveType(curveId);
        uint256 supply = ISupportToken(this.getCurveToken(curveId)).totalSupply();
        (uint256 scale, uint256 burnRatio, uint256 constant_a, uint256 constant_b, uint256 constant_c) =
            this.getCurveFormula(curveId);

        // Update curve data based on request for mint or burn price.
        supply = _mint ? supply + 1 : supply;
        burnRatio = _mint ? 100 : uint256(100) - burnRatio;

        if (curveType == CurveType.LINEAR) {
            // Return linear pricing based on, a * b * x + b.
            return (constant_a * supply * scale + constant_b * scale) * burnRatio / 100;
        } else if (curveType == CurveType.POLY) {
            // Return curve pricing based on, a * c * x^2 + b * c * x + c.
            return (constant_a * (supply ** 2) * scale + constant_b * supply * scale + constant_c * scale) * burnRatio
                / 100;
        } else {
            return 0;
        }
    }

    /// @notice Return mint and burn price difference of a curve.
    function getMintBurnDifference(uint256 curveId) external view returns (uint256) {
        return this.getPrice(true, curveId) - this.getPrice(false, curveId);
    }

    /// @notice Return unclaimed amount by a user.
    function getUnclaimed(address user) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(user, ".unclaimed")));
    }

    /// -----------------------------------------------------------------------
    /// Counter Logic
    /// -----------------------------------------------------------------------

    /// @notice Internal function to increment number of total curves.
    function incrementCurveId() internal returns (uint256) {
        return addUint(keccak256(abi.encode("curves.count")), 1);
    }

    /// @notice Internal function to increment supply of a curve.
    // function incrementCurveSupply(uint256 curveId) internal returns (uint256) {
    //     return addUint(keccak256(abi.encode(curveId, ".supply")), 1);
    // }

    /// @notice Internal function to decrement supply of a curve.
    // function decrementCurveSupply(uint256 curveId) internal returns (uint256) {
    //     return subUint(keccak256(abi.encode(curveId, ".supply")), 1);
    // }

    /// -----------------------------------------------------------------------
    /// Delete Logic
    /// -----------------------------------------------------------------------

    /// @notice Internal function to delete unclaimed amount.
    function deleteUnclaimed(address user) internal {
        deleteUint(keccak256(abi.encode(user, ".unclaimed")));
    }

    /// -----------------------------------------------------------------------
    /// Helper Logic
    /// -----------------------------------------------------------------------

    function encodeCurveData(uint96 scale, uint16 burnRatio, uint48 constant_a, uint48 constant_b, uint48 constant_c)
        external
        pure
        returns (uint256)
    {
        return uint256(bytes32(abi.encodePacked(scale, burnRatio, constant_a, constant_b, constant_c)));
    }

    function decodeCurveData(uint256 key) external pure returns (uint256, uint256, uint256, uint256, uint256) {
        // Convert tokenId from type uint256 to bytes32.
        bytes32 _key = bytes32(key);

        // Declare variables to return later.
        uint48 constant_c;
        uint48 constant_b;
        uint48 constant_a;
        uint16 burnRatio;
        uint96 scale;

        // Parse data via assembly.
        assembly {
            constant_c := _key // 0-47
            constant_b := shr(48, _key) // 48-95
            constant_a := shr(96, _key) // 96-143
            burnRatio := shr(144, _key) // 144-147
            scale := shr(160, _key) // 160-
        }

        return (uint256(scale), uint256(burnRatio), uint256(constant_a), uint256(constant_b), uint256(constant_c));
    }

    receive() external payable virtual {}
}
