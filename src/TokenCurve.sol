// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {ICurrency} from "src/interface/ICurrency.sol";
import {OwnableRoles} from "src/auth/OwnableRoles.sol";
import {ITokenCurve, CurveType, Curve} from "src/interface/ITokenCurve.sol";
import {ITokenMinter} from "src/interface/ITokenMinter.sol";

/// @notice .
/// @author audsssy.eth
contract TokenCurve is OwnableRoles {
    event CurveCreated(uint256 curveId, Curve curve);

    error TransferFailed();
    error InvalidCurve();
    error InvalidFormula();
    error InvalidAmount();
    error InsufficientCurrency();

    /// -----------------------------------------------------------------------
    /// Storage
    /// -----------------------------------------------------------------------

    /// @notice Role constants.
    uint256 public constant LIST_OWNERS = 1 << 0;

    /// @notice Curve sdtorage.
    uint256 public curveId;
    mapping(uint256 => Curve) public curves;
    mapping(uint256 => uint256) public treasuries;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    /// @notice .
    function initialize(address owner) external payable {
        _initializeOwner(owner);
    }

    /// -----------------------------------------------------------------------
    /// Creator Logic
    /// -----------------------------------------------------------------------

    /// @notice Configure a curve.
    function registerCurve(Curve calldata curve) external payable onlyRoles(LIST_OWNERS) {
        // Validate curve conditions.
        if (curve.token == address(0) || curve.scale == 0) revert InvalidCurve();
        if (curve.burn_a > curve.mint_a || curve.burn_b > curve.mint_b || curve.burn_c > curve.mint_c) {
            revert InvalidFormula();
        }

        unchecked {
            ++curveId;
        }

        if (curve.curveType == CurveType.LINEAR) {
            curves[curveId] = Curve({
                owner: msg.sender,
                token: curve.token,
                id: curve.id,
                supply: 0,
                curveType: CurveType.LINEAR,
                currency: curve.currency,
                scale: curve.scale,
                mint_a: 0,
                mint_b: curve.mint_b,
                mint_c: curve.mint_c,
                burn_a: 0,
                burn_b: curve.burn_b,
                burn_c: 0
            });
        } else if (curve.curveType == CurveType.QUADRATIC) {
            curves[curveId] = Curve({
                owner: msg.sender,
                token: curve.token,
                id: curve.id,
                supply: 0,
                curveType: CurveType.QUADRATIC,
                currency: curve.currency,
                scale: curve.scale,
                mint_a: curve.mint_a,
                mint_b: curve.mint_b,
                mint_c: curve.mint_c,
                burn_a: curve.burn_a,
                burn_b: curve.burn_b,
                burn_c: 0
            });
        } else {
            revert InvalidCurve();
        }

        emit CurveCreated(curveId, curve);
    }

    /// -----------------------------------------------------------------------
    /// Patron Logic
    /// -----------------------------------------------------------------------

    /// @notice Pay coin or currency to mint tokens.
    function support(uint256 _curveId, address patron, uint256 amountInCurrency) external payable virtual {
        // Validate mint conditions.
        Curve memory curve = curves[_curveId];
        uint256 _price = getCurvePrice(true, curve, 0);
        uint256 burnPrice = getCurvePrice(false, curve, 0);
        uint256 floor = calculatePrice(1, curve.scale, 0, 0, curve.mint_c);

        if (floor > amountInCurrency) {
            // Subsidized Currency Support.
            if (ICurrency(curve.currency).balanceOf(address(this)) + amountInCurrency > floor) {
                // With subsidy, payment is reduced up to floor amount.
                if (_price - floor != msg.value) revert InvalidAmount(); // Assumes 1:1 ratio between base coin and currency.

                // Transfer currency.
                ICurrency(curve.currency).transferFrom(msg.sender, curve.owner, amountInCurrency);
                ICurrency(curve.currency).transferFrom(address(this), curve.owner, floor - amountInCurrency);

                // Transfer coin.
                (bool success,) = curve.owner.call{value: _price - burnPrice - floor}("");
                if (!success) revert TransferFailed();
            } else {
                // Unsubsidized Currency Support.
                // Without subsidy, increase payment based on amount of currency support.
                if (_price - amountInCurrency != msg.value) revert InvalidAmount(); // Assumes 1:1 ratio between base coin and currency.

                // Transfer currency.
                ICurrency(curve.currency).transferFrom(msg.sender, curve.owner, amountInCurrency);

                // Transfer coin.
                (bool success,) = curve.owner.call{value: _price - burnPrice - amountInCurrency}("");
                if (!success) revert TransferFailed();
            }
        } else {
            // Full Currency Support by Patron.
            if (_price - floor != msg.value) revert InvalidAmount(); // Assumes 1:1 ratio between base coin and currency.

            // Transfer currency.
            ICurrency(curve.currency).transferFrom(msg.sender, curve.owner, floor);

            // Transfer coin.
            (bool success,) = curve.owner.call{value: _price - burnPrice - floor}("");
            if (!success) revert TransferFailed();
        }

        // Mint.
        ITokenMinter(curve.token).mint(patron, curve.id);

        unchecked {
            ++curves[_curveId].supply;

            // Allocate burn price to treasury.
            treasuries[_curveId] += burnPrice;
        }
    }

    /// @notice Burn curve token to receive ether.
    function burn(uint256 _curveId, address patron, uint256 tokenId) external payable {
        // Validate mint conditions.
        Curve memory curve = curves[_curveId];
        if (ITokenMinter(curve.token).balanceOf(msg.sender, tokenId) == 0) revert Unauthorized();

        --curves[_curveId].supply;

        // Reduce curve treasury by burn price.
        uint256 burnPrice = getCurvePrice(false, curve, 0);
        treasuries[_curveId] -= burnPrice;

        // Burn SupportToken.
        ITokenMinter(curve.token).burn(msg.sender, tokenId);

        // Distribute burn to patron.
        (bool success,) = patron.call{value: burnPrice}("");
        if (!success) revert TransferFailed();
    }

    /// -----------------------------------------------------------------------
    /// Curve Getter Logic
    /// -----------------------------------------------------------------------

    /// @notice Return owner of a curve.
    function getCurve(uint256 _curveId) external view returns (Curve memory) {
        return curves[_curveId];
    }

    /// @notice Calculate mint and burn price.
    function getCurvePrice(bool _mint, Curve memory curve, uint256 _supply) public view returns (uint256) {
        return _getCurvePrice(_mint, 0, curve, _supply);
    }

    /// @notice Calculate mint and burn price.
    function getCurvePrice(bool _mint, uint256 _curveId, uint256 _supply) public view returns (uint256) {
        Curve memory curve;
        return _getCurvePrice(_mint, _curveId, curve, _supply);
    }

    function _getCurvePrice(bool _mint, uint256 _curveId, Curve memory curve, uint256 _supply)
        internal
        view
        returns (uint256)
    {
        // Retrieve curve data.
        (_curveId == 0) ? curve : curve = curves[_curveId];

        // Use next available supply when mint, current supply when burn.
        uint256 supply = _supply == 0 ? curve.supply : _supply;

        if (_mint) {
            unchecked {
                ++supply;
            }

            // Calculate mint price.
            if (curve.curveType == CurveType.LINEAR) {
                // Return linear pricing based on, a * b * x + b.
                return calculatePrice(supply, curve.scale, 0, curve.mint_b, curve.mint_c);
            } else if (curve.curveType == CurveType.QUADRATIC) {
                // Return curve pricing based on, a * c * x^2 + b * c * x + c.
                return calculatePrice(supply, curve.scale, curve.mint_a, curve.mint_b, curve.mint_c);
            } else {
                return 0;
            }
        } else {
            unchecked {
                (supply == 0) ? ++supply : supply;
            }

            // Calculate burn price.
            if (curve.curveType == CurveType.LINEAR) {
                // Return linear pricing based on, a * b * x + b.
                return calculatePrice(supply, curve.scale, 0, curve.burn_b, curve.burn_c);
            } else if (curve.curveType == CurveType.QUADRATIC) {
                // Return curve pricing based on, a * c * x^2 + b * c * x + c.
                return calculatePrice(supply, curve.scale, curve.burn_a, curve.burn_b, curve.burn_c);
            } else {
                return 0;
            }
        }
    }

    function calculatePrice(uint256 supply, uint256 scale, uint256 constant_a, uint256 constant_b, uint256 constant_c)
        internal
        pure
        returns (uint256)
    {
        return constant_a * (supply ** 2) * scale + constant_b * supply * scale + constant_c * scale;
    }

    receive() external payable virtual {}
}
