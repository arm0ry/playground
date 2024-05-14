// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {IERC20} from "src/interface/IERC20.sol";
import {OwnableRoles} from "src/auth/OwnableRoles.sol";
import {IImpactCurve, CurveType, Curve} from "src/interface/IImpactCurve.sol";
import {ISupportToken} from "src/interface/ISupportToken.sol";

/// @notice .
/// @author audsssy.eth
contract ImpactCurve is OwnableRoles {
    event CurveCreated(Curve curve);

    error TransferFailed();
    error InvalidCurve();
    error InvalidAmount();
    error InsufficientCurrency();

    /// -----------------------------------------------------------------------
    /// Storage
    /// -----------------------------------------------------------------------

    /// @notice Role constants.
    uint256 public constant LIST_OWNERS = 1 << 0;

    /// @notice Curve storage.
    uint256 curveId;
    mapping(uint256 => Curve) public curves;
    mapping(uint256 => uint256) public reserves;
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
    function registerCurve(Curve memory curve) external payable onlyRoles(LIST_OWNERS) {
        // Validate curve conditions.
        if (ISupportToken(curve.token).totalSupply() > 0) revert InvalidCurve();
        if (curve.curveType == CurveType.NA) revert InvalidCurve();
        if (curve.scale == 0) revert InvalidCurve();
        if (curve.burn_a > curve.mint_a || curve.burn_b > curve.mint_b || curve.burn_c > curve.mint_c) {
            revert InvalidCurve();
        }

        if (curve.curveType == CurveType.LINEAR) {
            curve.mint_a = 0;
            curve.burn_a = 0;
        }

        unchecked {
            ++curveId;
        }

        curves[curveId] = curve;
        emit CurveCreated(curve);
    }

    /// -----------------------------------------------------------------------
    /// Patron Logic
    /// -----------------------------------------------------------------------

    /// @notice Pay stablecoin or currency to mint tokens.
    function support(uint256 _curveId, address patron, uint256 price, uint256 amountInCurrency) external payable {
        // Validate mint conditions.
        Curve memory curve = curves[_curveId];
        uint256 _price = getCurvePrice(true, 0, curve, 0);
        uint256 burnPrice = getCurvePrice(false, 0, curve, 0);

        if (price != _price) revert InvalidAmount();
        if (amountInCurrency == 0 && price != msg.value) revert InvalidAmount();

        price = _price - amountInCurrency;
        if (amountInCurrency > 0 && price != msg.value) revert InvalidAmount();

        uint256 floor = calculatePrice(1, curve.scale, 0, 0, curve.mint_c);
        if (floor > amountInCurrency) {
            if (IERC20(curve.currency).balanceOf(address(this)) + amountInCurrency > floor) {
                // Transfer currency.
                IERC20(curve.currency).transferFrom(msg.sender, curve.owner, amountInCurrency);
                IERC20(curve.currency).transferFrom(address(this), curve.owner, floor - amountInCurrency);

                // Transfer stablecoin.
                (bool success,) = msg.sender.call{value: price - burnPrice - amountInCurrency}("");
                if (!success) revert TransferFailed();
            } else {
                revert InsufficientCurrency();
            }
        } else {
            // Transfer currency.
            IERC20(curve.currency).transferFrom(msg.sender, curve.owner, floor);

            // Transfer stablecoin.
            (bool success,) = msg.sender.call{value: price - burnPrice - floor}("");
            if (!success) revert TransferFailed();
        }

        // Mint.
        ISupportToken(curve.token).mint(patron);

        // Allocate burn price to treasury.
        treasuries[_curveId] += burnPrice;
    }

    /// @notice Burn curve token to receive ether.
    function burn(uint256 _curveId, address patron, uint256 tokenId) external payable {
        // Validate mint conditions.
        Curve memory curve = curves[_curveId];
        if (ISupportToken(curve.token).ownerOf(tokenId) != msg.sender) revert Unauthorized();

        // Reduce curve treasury by burn price.
        uint256 burnPrice = getCurvePrice(false, 0, curve, 0);
        treasuries[_curveId] -= burnPrice;

        // Burn SupportToken.
        ISupportToken(curve.token).burn(tokenId);

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
    function getCurvePrice(bool _mint, uint256 _curveId, Curve memory curve, uint256 _supply)
        public
        view
        returns (uint256)
    {
        // Retrieve curve data.
        (_curveId == 0) ? curve : curve = curves[_curveId];

        // Use next available supply when mint, current supply when burn.
        uint256 supply = _supply == 0 ? ISupportToken(curve.token).totalSupply() : _supply;
        supply = _mint ? supply + 1 : supply;

        if (_mint) {
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
        public
        pure
        returns (uint256)
    {
        return constant_a * (supply ** 2) * scale + constant_b * supply * scale + constant_c * scale;
    }

    receive() external payable virtual {}
}
