// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {ICurrency} from "src/interface/ICurrency.sol";
import {OwnableRoles} from "src/auth/OwnableRoles.sol";
import {ITokenCurve, CurveType, Curve, Collected} from "src/interface/ITokenCurve.sol";
import {ITokenMinter} from "src/interface/ITokenMinter.sol";

/// @notice .
/// @author audsssy.eth
contract TokenCurve {
    event CurveCreated(uint256 curveId, Curve curve);

    error Unauthorized();
    error TransferFailed();
    error InvalidCurve();
    error InvalidFormula();
    error InvalidAmount();
    error InsufficientCurrency();
    error ExceedLimit();

    /// -----------------------------------------------------------------------
    /// Storage
    /// -----------------------------------------------------------------------

    /// @notice Curve sdtorage.
    uint256 public curveId;
    mapping(uint256 => Curve) public curves;
    mapping(uint256 => uint256) public treasuries;
    mapping(address => mapping(uint256 => uint256)) public patronBalances;
    mapping(uint256 => Collected) public collected;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// Creator Logic
    /// -----------------------------------------------------------------------

    /// @notice Configure a curve.
    function registerCurve(Curve calldata curve) external payable {
        // Validate curve conditions.
        if (ITokenMinter(curve.token).ownerOf(curve.id) != msg.sender) revert Unauthorized();
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
        if (amountInCurrency == 0) revert InsufficientCurrency();

        // Validate mint conditions.
        Curve memory curve = curves[_curveId];
        (, uint256 limit) = ITokenMinter(curve.token).getTokenMarket(curve.id);
        if (curves[_curveId].supply == limit) revert ExceedLimit();

        uint256 _price = getCurvePrice(true, curve, 0);
        uint256 burnPrice = getCurvePrice(false, curve, 0);
        uint256 floor = calculatePrice(1, curve.scale, 0, 0, curve.mint_c);

        if (floor > amountInCurrency) {
            if (curve.currency != address(0)) {
                // Partial Currency Support .
                if (ICurrency(curve.currency).balanceOf(address(this)) >= floor - amountInCurrency) {
                    if (_price - amountInCurrency != msg.value) revert InvalidAmount(); // Assumes 1:1 ratio between base coin and currency.

                    // Transfer currency.
                    ICurrency(curve.currency).transferFrom(patron, curve.owner, amountInCurrency);
                    ICurrency(curve.currency).transferFrom(address(this), curve.owner, floor - amountInCurrency);

                    // Transfer coin.
                    safeTransferETH(curve.owner, _price - burnPrice - floor);

                    collected[_curveId].amountInCurrency += floor;
                    collected[_curveId].amountInStablecoin += _price - burnPrice - floor;
                    collected[_curveId].amountConverted += floor - amountInCurrency;
                } else {
                    revert InsufficientCurrency();
                }
            } else {
                // Full Stablecoin Support.
                // Without subsidy, increase payment based on amount of currency support.
                if (_price != msg.value) revert InvalidAmount(); // Assumes 1:1 ratio between base coin and currency.

                // Transfer coin.
                safeTransferETH(curve.owner, _price - burnPrice);

                collected[_curveId].amountInStablecoin += _price - burnPrice;
            }
        } else {
            // Floor Currency Support.
            if (_price - floor != msg.value) revert InvalidAmount(); // Assumes 1:1 ratio between base coin and currency.

            // Transfer currency.
            ICurrency(curve.currency).transferFrom(patron, curve.owner, floor);

            // Transfer coin.
            safeTransferETH(curve.owner, _price - burnPrice - floor);

            collected[_curveId].amountInCurrency += floor;
            collected[_curveId].amountInStablecoin += _price - burnPrice - floor;
        }

        // Mint.
        ITokenMinter(curve.token).mintByMarket(patron, curve.id);

        unchecked {
            ++curves[_curveId].supply;
            ++patronBalances[msg.sender][_curveId];

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
        --patronBalances[msg.sender][_curveId];

        // Reduce curve treasury by burn price.
        uint256 burnPrice = getCurvePrice(false, curve, 0);
        treasuries[_curveId] -= burnPrice;

        // Burn SupportToken.
        ITokenMinter(curve.token).burnByMarket(msg.sender, tokenId);

        // Distribute burn to patron.
        safeTransferETH(patron, burnPrice);
    }

    /// -----------------------------------------------------------------------
    /// Curve Getter Logic
    /// -----------------------------------------------------------------------

    /// @notice Return owner of a curve.
    function getCurve(uint256 _curveId) external view returns (Curve memory) {
        return curves[_curveId];
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

    /// -----------------------------------------------------------------------
    /// Collection Logic
    /// -----------------------------------------------------------------------

    function getCollection(uint256 _curveId) external view returns (Collected memory) {
        return collected[_curveId];
    }

    function calculatePrice(uint256 supply, uint256 scale, uint256 constant_a, uint256 constant_b, uint256 constant_c)
        internal
        pure
        returns (uint256)
    {
        return constant_a * (supply ** 2) * scale + constant_b * supply * scale + constant_c * scale;
    }

    /// -----------------------------------------------------------------------
    /// Claim
    /// -----------------------------------------------------------------------

    function claim(uint256 _curveId) external {
        address owner = curves[_curveId].owner; // TODO: change to owner of currency not owner of curve
        uint256 amount = collected[_curveId].amountConverted;

        if (amount == 0 || owner == msg.sender) revert Unauthorized();
        safeTransferETH(msg.sender, amount);
    }

    /// -----------------------------------------------------------------------
    /// Internal Logic
    /// -----------------------------------------------------------------------

    /// @notice Calculate mint and burn price.
    function getCurvePrice(bool _mint, Curve memory curve, uint256 _supply) internal view returns (uint256) {
        return _getCurvePrice(_mint, 0, curve, _supply);
    }

    receive() external payable virtual {}
}

/// @dev Solady
function safeTransferETH(address to, uint256 amount) {
    assembly ("memory-safe") {
        if iszero(call(gas(), to, amount, codesize(), 0x00, codesize(), 0x00)) {
            mstore(0x00, 0xb12d13eb)
            revert(0x1c, 0x04)
        }
    }
}
