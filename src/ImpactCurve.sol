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
        uint64 scale,
        uint32 mint_a,
        uint32 mint_b,
        uint32 mint_c,
        uint32 burn_a,
        uint32 burn_b,
        uint32 burn_c
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
        uint64 scale,
        uint32 mint_a,
        uint32 mint_b,
        uint32 mint_c,
        uint32 burn_a,
        uint32 burn_b,
        uint32 burn_c
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
        setCurveFormula(curveId, scale, mint_a, mint_b, mint_c, burn_a, burn_b, burn_c);

        emit CurveCreated(curveId, curveType, token, owner, scale, mint_a, mint_b, mint_c, burn_a, burn_b, burn_c);
    }

    /// -----------------------------------------------------------------------
    /// Claim Logic
    /// -----------------------------------------------------------------------

    /// @notice Claim tax revenue and unsuccessful transfers.
    function claim() external payable {
        uint256 amount = this.getUnclaimed(msg.sender);
        if (amount == 0) revert NotAuthorized();

        deleteUnclaimed(msg.sender);

        (bool success,) = msg.sender.call{value: amount}("");
        if (!success) revert TransferFailed();
    }

    function zeroClaim(uint256 curveId) external payable virtual {
        if (this.getCurveOwner(curveId) != msg.sender) revert NotAuthorized();
        if (ISupportToken(this.getCurveToken(curveId)).totalSupply() == 0 && this.getCurvePool(curveId) > 0) {
            (bool success,) = msg.sender.call{value: this.getCurvePool(curveId)}("");
            if (!success) revert TransferFailed();
        }
    }

    /// -----------------------------------------------------------------------
    /// Patron Logic
    /// -----------------------------------------------------------------------

    /// @notice Pay ether to mint curve token.
    function support(uint256 curveId, address patron, uint256 price) external payable initialized {
        // Validate mint conditions.
        if (patron == this.getCurveOwner(curveId)) revert NotAuthorized();
        if (price != this.getPrice(true, curveId, 0) || price != msg.value) {
            revert InvalidAmount();
        }

        // Distribute support to curve owner.
        uint256 burnPrice = this.getPrice(false, curveId, 0);
        addUnclaimed(this.getCurveOwner(curveId), price - burnPrice);
        addCurvePool(curveId, burnPrice);

        // Mint.
        address curveToken = this.getCurveToken(curveId);
        ISupportToken(curveToken).mint(patron, 0);
    }

    /// @notice Burn curve token to receive ether.
    function burn(uint256 curveId, address patron, uint256 id) external payable initialized {
        // Validate mint conditions.
        address curveToken = this.getCurveToken(curveId);
        if (ISupportToken(curveToken).ownerOf(id) != msg.sender) revert NotAuthorized();
        if (this.getCurveBurned(curveId, patron)) revert NotAuthorized();
        setCurveBurned(curveId, patron, true);

        // Burn SupportToken.
        ISupportToken(curveToken).burn(id);

        // Reduce curve pool by burn price.
        uint256 burnPrice = this.getPrice(false, curveId, 0);
        subCurvePool(curveId, burnPrice);

        // Distribute burn to patron.
        (bool success,) = patron.call{value: burnPrice}("");
        if (!success) addUnclaimed(patron, burnPrice);
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
        _setAddress(keccak256(abi.encode(address(this), ".curves", curveId, ".token")), token);
    }

    /// @notice .
    function setCurveOwner(uint256 curveId, address owner) internal {
        if (owner == address(0)) revert NotAuthorized();
        _setAddress(keccak256(abi.encode(address(this), ".curves", curveId, ".owner")), owner);
    }

    /// @notice .
    function setCurveType(uint256 curveId, CurveType curveType) internal {
        _setUint(keccak256(abi.encode(address(this), ".curves", curveId, ".curveType")), uint256(curveType));
    }

    /// @notice .
    function setCurveFormula(
        uint256 curveId,
        uint64 scale,
        uint32 mint_a,
        uint32 mint_b,
        uint32 mint_c,
        uint32 burn_a,
        uint32 burn_b,
        uint32 burn_c
    ) internal {
        // To prevent future calculation errors, such as arithmetic overflow/underflow.
        if (burn_a >= mint_a || burn_b >= mint_b || burn_c >= mint_c) revert InvalidCurve();

        uint256 key = this.encodeCurveData(scale, mint_a, mint_b, mint_c, burn_a, burn_b, burn_c);
        _setUint(keccak256(abi.encode(address(this), ".curves", curveId, ".formula")), key);
    }
    /// @notice .

    function addCurvePool(uint256 curveId, uint256 amount) internal {
        addUint(keccak256(abi.encode(address(this), ".curves", curveId, ".pool")), amount);
    }

    /// @notice .
    function subCurvePool(uint256 curveId, uint256 amount) internal {
        subUint(keccak256(abi.encode(address(this), ".curves", curveId, ".pool")), amount);
    }

    /// @notice .
    function setCurveBurned(uint256 curveId, address patron, bool burned) internal {
        _setBool(keccak256(abi.encode(address(this), ".curves", curveId, ".patrons.", patron, ".burned")), burned);
    }

    /// -----------------------------------------------------------------------
    /// Curve Getter Logic
    /// -----------------------------------------------------------------------

    /// @notice Return owner of a curve.
    function getCurveOwner(uint256 curveId) external view returns (address) {
        return this.getAddress(keccak256(abi.encode(address(this), ".curves", curveId, ".owner")));
    }

    /// @notice Return owner of a curve.
    function getCurveToken(uint256 curveId) external view returns (address) {
        return this.getAddress(keccak256(abi.encode(address(this), ".curves", curveId, ".token")));
    }

    /// @notice Return type of a curve.
    function getCurveType(uint256 curveId) external view returns (CurveType) {
        return CurveType(this.getUint(keccak256(abi.encode(address(this), ".curves", curveId, ".curveType"))));
    }

    /// @notice Return curve data in order - scale, burnRatio, mint_a, mint_b, mint_c.
    function getCurveFormula(uint256 curveId)
        external
        view
        returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256)
    {
        return this.decodeCurveData(this.getUint(keccak256(abi.encode(address(this), ".curves", curveId, ".formula"))));
    }

    /// @notice .
    function getCurvePool(uint256 curveId) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), ".curves", curveId, ".pool")));
    }

    /// @notice .
    function getCurveBurned(uint256 curveId, address patron) external view returns (bool) {
        return this.getBool(keccak256(abi.encode(address(this), ".curves", curveId, ".patrons.", patron, ".burned")));
    }

    /// @notice Calculate mint and burn price.
    function getPrice(bool _mint, uint256 curveId, uint256 _supply) external view virtual returns (uint256) {
        // Retrieve curve data.
        CurveType curveType = this.getCurveType(curveId);
        uint256 supply = _supply == 0 ? ISupportToken(this.getCurveToken(curveId)).totalSupply() : _supply;
        (uint256 scale, uint256 mint_a, uint256 mint_b, uint256 mint_c, uint256 burn_a, uint256 burn_b, uint256 burn_c)
        = this.getCurveFormula(curveId);

        // Use next available supply when mint, current supply when burn.
        supply = _mint ? supply + 1 : supply;

        if (_mint) {
            // Calculate mint price.
            if (curveType == CurveType.LINEAR) {
                // Return linear pricing based on, a * b * x + b.
                return this.calculatePrice(supply, scale, 0, mint_b, mint_c);
            } else if (curveType == CurveType.POLY) {
                // Return curve pricing based on, a * c * x^2 + b * c * x + c.
                return this.calculatePrice(supply, scale, mint_a, mint_b, mint_c);
            } else {
                return 0;
            }
        } else {
            // Calculate burn price.
            if (curveType == CurveType.LINEAR) {
                // Return linear pricing based on, a * b * x + b.
                return this.calculatePrice(supply, scale, 0, burn_b, burn_c);
            } else if (curveType == CurveType.POLY) {
                // Return curve pricing based on, a * c * x^2 + b * c * x + c.
                return this.calculatePrice(supply, scale, burn_a, burn_b, burn_c);
            } else {
                return 0;
            }
        }
    }

    function calculatePrice(uint256 supply, uint256 scale, uint256 constant_a, uint256 constant_b, uint256 constant_c)
        external
        pure
        returns (uint256)
    {
        return constant_a * (supply ** 2) * scale + constant_b * supply * scale + constant_c * scale;
    }

    /// @notice Return mint and burn price difference of a curve.
    function getMintBurnDifference(uint256 curveId) external view returns (uint256) {
        return this.getPrice(true, curveId, 0) - this.getPrice(false, curveId, 0);
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

    /// @notice Internal function to increment number of total curves.
    function getCurveId() external view returns (uint256) {
        return this.getUint(keccak256(abi.encode("curves.count")));
    }

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

    function encodeCurveData(
        uint64 scale,
        uint32 mint_a,
        uint32 mint_b,
        uint32 mint_c,
        uint32 burn_a,
        uint32 burn_b,
        uint32 burn_c
    ) external pure returns (uint256) {
        return uint256(bytes32(abi.encodePacked(scale, mint_a, mint_b, mint_c, burn_a, burn_b, burn_c)));
    }

    function decodeCurveData(uint256 key)
        external
        pure
        returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256)
    {
        // Convert tokenId from type uint256 to bytes32.
        bytes32 _key = bytes32(key);

        // Declare variables to return later.
        uint32 burn_c;
        uint32 burn_b;
        uint32 burn_a;
        uint32 mint_c;
        uint32 mint_b;
        uint32 mint_a;
        uint64 scale;

        // Parse data via assembly.
        assembly {
            burn_c := _key // 0-32
            burn_b := shr(32, _key) // 33-64
            burn_a := shr(64, _key) // 65-96
            mint_c := shr(96, _key) // 97-128
            mint_b := shr(128, _key) // 129-160
            mint_a := shr(160, _key) // 161-192
            scale := shr(192, _key) // 192-
        }

        return (
            uint256(scale),
            uint256(mint_a),
            uint256(mint_b),
            uint256(mint_c),
            uint256(burn_a),
            uint256(burn_b),
            uint256(burn_c)
        );
    }

    receive() external payable virtual {}
}
