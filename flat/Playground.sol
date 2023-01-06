// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

/// @notice Safe ETH and ERC-20 transfer library that gracefully handles missing return values
/// @author Modified from Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/utils/SafeTransferLib.sol)
/// License-Identifier: AGPL-3.0-only
library SafeTransferLib {
    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error ETHtransferFailed();
    error TransferFailed();
    error TransferFromFailed();

    /// -----------------------------------------------------------------------
    /// ETH Logic
    /// -----------------------------------------------------------------------

    function _safeTransferETH(address to, uint256 amount) internal {
        bool success;

        assembly {
            // transfer the ETH and store if it succeeded or not
            success := call(gas(), to, amount, 0, 0, 0, 0)
        }
        if (!success) revert ETHtransferFailed();
    }

    /// -----------------------------------------------------------------------
    /// ERC-20 Logic
    /// -----------------------------------------------------------------------

    function _safeTransfer(
        address token,
        address to,
        uint256 amount
    ) internal {
        bool success;

        assembly {
            // we'll write our calldata to this slot below, but restore it later
            let memPointer := mload(0x40)
            // write the abi-encoded calldata into memory, beginning with the function selector
            mstore(0, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
            mstore(4, to) // append the 'to' argument
            mstore(36, amount) // append the 'amount' argument

            success := and(
                // set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                // we use 68 because that's the total length of our calldata (4 + 32 * 2)
                // - counterintuitively, this call() must be positioned after the or() in the
                // surrounding and() because and() evaluates its arguments from right to left
                call(gas(), token, 0, 0, 68, 0, 32)
            )

            mstore(0x60, 0) // restore the zero slot to zero
            mstore(0x40, memPointer) // restore the memPointer
        }
        if (!success) revert TransferFailed();
    }

    function _safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 amount
    ) internal {
        bool success;

        assembly {
            // we'll write our calldata to this slot below, but restore it later
            let memPointer := mload(0x40)
            // write the abi-encoded calldata into memory, beginning with the function selector
            mstore(0, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
            mstore(4, from) // append the 'from' argument
            mstore(36, to) // append the 'to' argument
            mstore(68, amount) // append the 'amount' argument

            success := and(
                // set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                // we use 100 because that's the total length of our calldata (4 + 32 * 3)
                // - counterintuitively, this call() must be positioned after the or() in the
                // surrounding and() because and() evaluates its arguments from right to left
                call(gas(), token, 0, 0, 100, 0, 32)
            )

            mstore(0x60, 0) // restore the zero slot to zero
            mstore(0x40, memPointer) // restore the memPointer
        }
        if (!success) revert TransferFromFailed();
    }
}

/// @notice Modern, minimalist, and gas efficient ERC-721 implementation.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC721.sol)
/// @dev Note that balanceOf does not revert if passed the zero address, in defiance of the ERC.
abstract contract ERC721 {
    /*///////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    event Approval(address indexed owner, address indexed spender, uint256 indexed id);

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /*///////////////////////////////////////////////////////////////
                          METADATA STORAGE/LOGIC
    //////////////////////////////////////////////////////////////*/

    string public name;

    string public symbol;

    function tokenURI(uint256 id) public view virtual returns (string memory);

    /*///////////////////////////////////////////////////////////////
                            ERC721 STORAGE                        
    //////////////////////////////////////////////////////////////*/

    mapping(address => uint256) public balanceOf;

    mapping(uint256 => address) public ownerOf;

    mapping(uint256 => address) public getApproved;

    mapping(address => mapping(address => bool)) public isApprovedForAll;

    /*///////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    /*///////////////////////////////////////////////////////////////
                              ERC721 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 id) public virtual {
        address owner = ownerOf[id];

        require(msg.sender == owner || isApprovedForAll[owner][msg.sender], "NOT_AUTHORIZED");

        getApproved[id] = spender;

        emit Approval(owner, spender, id);
    }

    function setApprovalForAll(address operator, bool approved) public virtual {
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual {
        require(from == ownerOf[id], "WRONG_FROM");

        require(to != address(0), "INVALID_RECIPIENT");

        require(
            msg.sender == from || msg.sender == getApproved[id] || isApprovedForAll[from][msg.sender],
            "NOT_AUTHORIZED"
        );

        // Underflow of the sender's balance is impossible because we check for
        // ownership above and the recipient's balance can't realistically overflow.
        unchecked {
            balanceOf[from]--;

            balanceOf[to]++;
        }

        ownerOf[id] = to;

        delete getApproved[id];

        emit Transfer(from, to, id);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual {
        transferFrom(from, to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, "") ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        bytes memory data
    ) public virtual {
        transferFrom(from, to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, data) ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    /*///////////////////////////////////////////////////////////////
                              ERC165 LOGIC
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(bytes4 interfaceId) public pure virtual returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == 0x80ac58cd || // ERC165 Interface ID for ERC721
            interfaceId == 0x5b5e139f; // ERC165 Interface ID for ERC721Metadata
    }

    /*///////////////////////////////////////////////////////////////
                       INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 id) internal virtual {
        require(to != address(0), "INVALID_RECIPIENT");

        require(ownerOf[id] == address(0), "ALREADY_MINTED");

        // Counter overflow is incredibly unrealistic.
        unchecked {
            balanceOf[to]++;
        }

        ownerOf[id] = to;

        emit Transfer(address(0), to, id);
    }

    function _burn(uint256 id) internal virtual {
        address owner = ownerOf[id];

        require(ownerOf[id] != address(0), "NOT_MINTED");

        // Ownership check above ensures no underflow.
        unchecked {
            balanceOf[owner]--;
        }

        delete ownerOf[id];

        delete getApproved[id];

        emit Transfer(owner, address(0), id);
    }

    /*///////////////////////////////////////////////////////////////
                       INTERNAL SAFE MINT LOGIC
    //////////////////////////////////////////////////////////////*/

    function _safeMint(address to, uint256 id) internal virtual {
        _mint(to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(msg.sender, address(0), id, "") ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function _safeMint(
        address to,
        uint256 id,
        bytes memory data
    ) internal virtual {
        _mint(to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(msg.sender, address(0), id, data) ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }
}

/// @notice A generic interface for a contract which properly accepts ERC721 tokens.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC721.sol)
interface ERC721TokenReceiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 id,
        bytes calldata data
    ) external returns (bytes4);
}

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = Math.log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(value, 10), _SYMBOLS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, Math.log256(value) + 1);
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
}

/// @notice Provides a function for encoding some bytes in base64.
/// @author Modified from Brecht Devos (https://github.com/Brechtpd/base64/blob/main/base64.sol)
/// License-Identifier: MIT
library Base64 {
    bytes internal constant TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    /// @dev encodes some bytes to the base64 representation
    function _encode(bytes memory data) internal pure returns (string memory) {
        uint256 len = data.length;
        if (len == 0) return "";

        // multiply by 4/3 rounded up
        uint256 encodedLen = 4 * ((len + 2) / 3);

        // Add some extra buffer at the end
        bytes memory result = new bytes(encodedLen + 32);

        bytes memory table = TABLE;

        assembly {
            let tablePtr := add(table, 1)
            let resultPtr := add(result, 32)

            for {
                let i := 0
            } lt(i, len) {

            } {
                i := add(i, 3)
                let input := and(mload(add(data, i)), 0xffffff)

                let out := mload(add(tablePtr, and(shr(18, input), 0x3F)))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(shr(12, input), 0x3F))), 0xFF))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(shr(6, input), 0x3F))), 0xFF))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(input, 0x3F))), 0xFF))
                out := shl(224, out)

                mstore(resultPtr, out)

                resultPtr := add(resultPtr, 4)
            }

            switch mod(len, 3)
            case 1 {
                mstore(sub(resultPtr, 2), shl(240, 0x3d3d))
            }
            case 2 {
                mstore(sub(resultPtr, 1), shl(248, 0x3d))
            }

            mstore(result, encodedLen)
        }

        return string(result);
    }
}

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    enum Rounding {
        Down, // Toward negative infinity
        Up, // Toward infinity
        Zero // Toward zero
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv)
     * with further edits by Uniswap Labs also under MIT license.
     */
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod0 := mul(x, y)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            require(denominator > prod1, "Math: mulDiv overflow");

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator. Always >= 1.
            // See https://cs.stackexchange.com/q/138556/92363.

            // Does not overflow because the denominator cannot be zero at this stage in the function.
            uint256 twos = denominator & (~denominator + 1);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also works
            // in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator,
        Rounding rounding
    ) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (rounding == Rounding.Up && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded down.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        //
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
        //
        // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
        // → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
        // → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
        //
        // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1 << (log2(a) >> 1);

        // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
        // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
        // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
        // into the expected uint128 result.
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }

    /**
     * @notice Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + (rounding == Rounding.Up && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (rounding == Rounding.Up && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10**64) {
                value /= 10**64;
                result += 64;
            }
            if (value >= 10**32) {
                value /= 10**32;
                result += 32;
            }
            if (value >= 10**16) {
                value /= 10**16;
                result += 16;
            }
            if (value >= 10**8) {
                value /= 10**8;
                result += 8;
            }
            if (value >= 10**4) {
                value /= 10**4;
                result += 4;
            }
            if (value >= 10**2) {
                value /= 10**2;
                result += 2;
            }
            if (value >= 10**1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + (rounding == Rounding.Up && 10**result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256, rounded down, of a positive value.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (rounding == Rounding.Up && 1 << (result << 3) < value ? 1 : 0);
        }
    }
}

/// @notice Kali DAO share manager interface
interface IKaliShareManager {
    function mintShares(address to, uint256 amount) external payable;
    function burnShares(address from, uint256 amount) external payable;
}

interface IArm0ryTravellers {
    function ownerOf(uint256 id) external view returns (address);

    function balanceOf(address account) external view returns (uint);

    function transferFrom(address from, address to, uint256 id) external payable;

    function safeTransferFrom(address from, address to, uint256 id) external payable;
}

/// @title Arm0ry Travellers
/// @notice Traveller NFTs for Arm0ry participants.
/// credit: z0r0z.eth https://gist.github.com/z0r0z/6ca37df326302b0ec8635b8796a4fdbb
contract Arm0ryTravellers is ERC721("Arm0ry Travellers", "ArT") {
    /// -----------------------------------------------------------------------
    /// Soul Logic
    /// -----------------------------------------------------------------------

    function bindSoul() public {
        _mint(msg.sender, uint256(uint160(msg.sender)));
    }

    function unbindSoul(uint256 id) public {
        require(ownerOf[id] == msg.sender, "NOT_SOUL_BINDER");

        _burn(id);
    }

    /// -----------------------------------------------------------------------
    /// Metadata Logic
    /// -----------------------------------------------------------------------

    function tokenURI(uint256 id) public view override returns (string memory) {
        return _buildTokenURI(id);
    }

    function _buildTokenURI(uint256 id) internal view returns (string memory) {
        address soul = address(uint160(id));

        string memory metaSVG = string(
            abi.encodePacked(
                '<text class="h1" dominant-baseline="middle" text-anchor="middle" fill="white" x="50%" y="10%">',
                "Arm0ry MiniGrants Season 1",
                "</text>"
                '<text dominant-baseline="middle" text-anchor="middle" fill="white" x="50%" y="20%">',
                "0x",
                addressToString(soul),
                "</text>",
                '<text dominant-baseline="middle" text-anchor="middle" fill="white" x="50%" y="30%">',
                "Wallet Balance: ",
                weiToEtherString(soul.balance),
                "</text>",
                '<text dominant-baseline="middle" text-anchor="middle" fill="white" x="50%" y="90%">',
                "I commit to completing arm0ry grants program",
                "</text>"
            )
        );
        bytes memory svg = abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400" preserveAspectRatio="xMidYMid meet" style="font:14px serif"><rect width="400" height="400" fill="black" />',
            '<style type="text/css"><![CDATA[text { font-family: monospace; font-size: 12px;} .h1 {font-size: 20px; font-weight: 600;}]]></style>',
            metaSVG,
            "</svg>"
        );
        bytes memory image = abi.encodePacked(
            "data:image/svg+xml;base64,",
            Base64._encode(bytes(svg))
        );
        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64._encode(
                    bytes(
                        abi.encodePacked(
                            '{"name":"',
                            name,
                            '", "image":"',
                            image,
                            '", "description": "I, msg.sender, hereby relinquish my soul (my incorporeal essence) to the holder of this deed, to be collected after my death. I retain full possession of my soul as long as I am alive, no matter however so slightly. This deed does not affect any copyright, immaterial, or other earthly rights, recognized by human courts, before or after my death. I take no responsibility about whether my soul does or does not exist. I am not liable in the case there is nothing to collect. This deed shall be vanquished upon calling the unbindSoul() function."}'
                        )
                    )
                )
            )
        );
    }

    function addressToString(address x) internal pure returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint(uint160(x)) / (2**(8*(19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2*i] = char(hi);
            s[2*i+1] = char(lo);            
        }
        return string(s);
    }

    /// @notice  Converts wei to ether string with 2 decimal places
    function weiToEtherString(uint256 amountInWei)
        public
        pure
        returns (string memory)
    {
        uint256 amountInFinney = amountInWei / 1e15; // 1 finney == 1e15
        return
            string(
                abi.encodePacked(
                    Strings.toString(amountInFinney / 1000), //left of decimal
                    ".",
                    Strings.toString((amountInFinney % 1000) / 100), //first decimal
                    Strings.toString(((amountInFinney % 1000) % 100) / 10) // first decimal
                )
            );
    }

    function char(bytes1 b) internal pure returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }
}

// IERC20
interface IERC20 {
    function totalSupply() external view returns (uint);

    function balanceOf(address account) external view returns (uint);

    function transfer(address recipient, uint amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
}

interface IArm0ryTasks {
    function tasks(uint16 taskId) external view returns (Task calldata);

    function getTaskXp(uint16 taskId) external view returns (uint8);

    function getTaskExpiration(uint16 taskId) external view returns (uint40);

    function getTaskCreator(uint16 taskId) external view returns (address);
}

/// @title Arm0ry tasks
/// @notice A list of tasks. 
/// @author audsssy.eth

struct Task {
    uint8 xp;
    uint40 expiration;
    address creator;
    string details;
}

contract Arm0ryTasks {

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event PermissionUpdated (
        address indexed caller,
        address indexed admin,
        address indexed manager
    );

    event TaskSet(
        uint40 expiration,
        uint8 points,
        address creator,
        string details
    );

    event TasksUpdated(
        uint40 expiration,
        uint8 points,
        address creator,
        string details
    );

    /// -----------------------------------------------------------------------
    /// Custom Errors
    /// -----------------------------------------------------------------------

    error NotAuthorized();

    error LengthMismatch();
    
    /// -----------------------------------------------------------------------
    /// Task Storage
    /// -----------------------------------------------------------------------

    address public admin;

    address public manager;

    uint16 public taskId;

    mapping(uint16 => Task) public tasks;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(address _admin) {
        admin = _admin;
    }

    /// -----------------------------------------------------------------------
    /// Task Logic
    /// -----------------------------------------------------------------------

    function setTasks(bytes[] calldata taskData) external payable {
        if (msg.sender != admin && msg.sender != manager) revert NotAuthorized();

        uint256 length = taskData.length;

        for (uint i = 0; i < length;) {
            
            unchecked {
                ++taskId;
            }

            (
                uint40 expiration,
                uint8 xp,
                address creator,
                string memory details
            ) = abi.decode(
                taskData[i],
                (uint40, uint8, address, string)
            );

            tasks[taskId].expiration = expiration;
            tasks[taskId].xp = xp;
            tasks[taskId].creator = creator;
            tasks[taskId].details = details;

            emit TaskSet(expiration, xp, creator, details);

            // Unchecked because the only math done is incrementing
            // the array index counter which cannot possibly overflow.
            unchecked {
                ++i;
            }
        }
    }

    function updateTasks(uint16[] calldata ids, bytes[] calldata taskData) external payable  {
        if (msg.sender != admin && msg.sender != manager) revert NotAuthorized();

        uint256 length = ids.length;
        
        if (length != taskData.length) revert LengthMismatch();

        for (uint i = 0; i < length;) {
            (
                uint40 expiration,
                uint8 xp,
                address creator,
                string memory details
            ) = abi.decode(
                taskData[i],
                (uint40, uint8, address, string)
            );

            tasks[ids[i]].expiration = expiration;
            tasks[ids[i]].xp = xp;
            tasks[ids[i]].creator = creator;
            tasks[ids[i]].details = details;

            emit TasksUpdated(expiration, xp, creator, details);

            // Unchecked because the only math done is incrementing
            // the array index counter which cannot possibly overflow.
            unchecked {
                ++i;
            }
        }
    }

    function getTaskXp(uint16 _taskId) external view returns (uint8) {
        return tasks[_taskId].xp;
    }

    function getTaskExpiration(uint16 _taskId) external view returns (uint40) {
        return tasks[_taskId].expiration;
    }

    function getTaskCreator(uint16 _taskId) external view returns (address) {
        return tasks[_taskId].creator;
    }
    
    function updatePermission(address _admin, address _manager) public {
        if (admin != msg.sender) revert NotAuthorized();
        
        if (_admin != admin) {
            admin = _admin;
        }

        if (_manager != address(0)) {
            manager = _manager;
        }

        emit PermissionUpdated(msg.sender, admin, manager);
    }
}

/// @title Arm0ry Missions
/// @notice .
/// @author audsssy.eth

struct Mission {
    Phase phase;
    // Status status;
    uint8 progress;
    uint8 xpGained;
    address[] buddies;
    uint16[] taskIds;
    uint40 expiration;
}

struct Deliverable {
    uint16 taskId;
    string deliverable;
    bool[] results; 
}

enum Phase {
    PLAYGROUND_BASICS, 
    PLAYGROUND_TRACKS
}

contract Arm0ryMissions {
    using SafeTransferLib for address;

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------


    /// -----------------------------------------------------------------------
    /// Custom Errors
    /// -----------------------------------------------------------------------

    error NotAuthorized();

    error InvalidTraveller();

    error InvalidClaim();

    error InvalidBuddy();

    error InvalidReview();

    error TaskNotReadyForReview();
    
    error TaskNotActive();

    error IncompleteTask();

    error AlreadyClaimed();

    error LengthMismatch();

    error NeedMoreCoins();
    
    /// -----------------------------------------------------------------------
    /// Mission Storage
    /// -----------------------------------------------------------------------

    uint256 public immutable THRESHOLD = 10 * 10 ** 18;

    uint256 public immutable CREATOR_REWARD = 10 ** 17;

    address public arm0ry;

    address public immutable WETH;
        
    IArm0ryTravellers public travellers;

    IArm0ryTasks public tasks;

    // Traveller's history of missions
    mapping(address => mapping(uint256 => Mission)) public missions;

    // Counter indicating Mission count per Traveller
    mapping(address => uint256) public missionNonce;

    // Status indicating if a Task is part of an active Mission
    mapping(address => mapping(uint256 => bool)) public isMissionTask;

    // Status indicating if an address belongs to a Buddy of an active Mission
    mapping(address => mapping(address => bool)) public isMissionBuddy;

    // Deliverable per Task of an active Mission
    mapping(address => mapping(uint256 => string)) public taskDeliverables;

    // Status indicating if a Task of an active Mission is ready for review
    mapping(address => mapping(uint256 => bool)) public taskReadyForReview;

    // Review results of a Task of an active Mission
    // 0 - not yet reviewed
    // 1 - reviewed with a check
    // 2 - reviewed with an x
    mapping(address => mapping(uint256 => mapping(address => uint8))) taskReviews; 

    // Status indicating if a Task of an active Mission is completed
    mapping(address => mapping(uint256 => bool)) isTaskCompleted;

    // Rewards per creators
    mapping(address => uint256) taskCreatorRewards;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(
        IArm0ryTravellers _travellers, 
        IArm0ryTasks _tasks, 
        address _weth
    ) {
        travellers = _travellers;
        tasks = _tasks;
        WETH = _weth;
    }

    /// -----------------------------------------------------------------------
    /// Mission Logic
    /// -----------------------------------------------------------------------

    // 
    function startMission(
        Phase phase,
        address[] calldata buddies, 
        uint16[] calldata taskIds
    ) external payable {
        if (travellers.balanceOf(msg.sender) == 0) revert InvalidTraveller();
        uint256 id = uint256(uint160(msg.sender));

        // Calculate expiration
        uint40 exp;
        for (uint256 i = 0; i < taskIds.length;) {
            uint40 _exp = tasks.getTaskExpiration(taskIds[i]);
            exp = (_exp > exp) ? _exp : exp;

            // cannot possibly overflow
            unchecked{
                ++i;
            }
        }

        // Lock Traveller's NFT 
        if (phase == Phase.PLAYGROUND_BASICS) {
            travellers.transferFrom(msg.sender, address(this), id);
        } 
        
        // Lock Traveller's NFT + 10 arm0ry token
        if (phase == Phase.PLAYGROUND_TRACKS) {
            if (IERC20(arm0ry).balanceOf(msg.sender) < THRESHOLD) revert NeedMoreCoins();
            IERC20(arm0ry).transferFrom(msg.sender, address(this), THRESHOLD);
            travellers.transferFrom(msg.sender, address(this), id);
        } 

        // Update active tasks
        for (uint256 i = 0; i < taskIds.length;){
            isMissionTask[msg.sender][taskIds[i]] = true;
            taskReadyForReview[msg.sender][taskIds[i]] = false;

            unchecked{ 
                ++i;
            }
        }

        // Update buddies
        for (uint256 i = 0; i < buddies.length;){
            isMissionBuddy[msg.sender][buddies[i]] = true;
            
            unchecked{ 
                ++i;
            }
        }
        
        // Create a Mission
        missions[msg.sender][missionNonce[msg.sender]] = Mission({
            phase: phase,
            progress: 0,
            xpGained: 0,
            buddies: buddies,
            taskIds: taskIds,
            expiration: exp
        });

        // Cannot possibly overflow.
        unchecked{
            ++missionNonce[msg.sender];
        }
    }

    function updateBuddies(
        address[] calldata preBuddies,
        address[] calldata newBuddies
    ) external payable {
        uint256 id = uint256(uint160(msg.sender));
        if (travellers.ownerOf(id) != address(this)) revert InvalidTraveller();

        // Remove previous buddies
        for (uint256 i = 0; i < preBuddies.length;){
            isMissionBuddy[msg.sender][preBuddies[i]] = false;
            
            unchecked{ 
                ++i;
            }
        }

        // Add new buddies
        for (uint256 i = 0; i < newBuddies.length;){
            isMissionBuddy[msg.sender][newBuddies[i]] = true;
            
            unchecked{ 
                ++i;
            }
        }

        missions[msg.sender][missionNonce[msg.sender]] = Mission({
            phase: missions[msg.sender][missionNonce[msg.sender]].phase,
            progress: missions[msg.sender][missionNonce[msg.sender]].progress,
            xpGained: missions[msg.sender][missionNonce[msg.sender]].xpGained,
            buddies: newBuddies,
            taskIds: missions[msg.sender][missionNonce[msg.sender]].taskIds,
            expiration: missions[msg.sender][missionNonce[msg.sender]].expiration
        });
    }

    function submitTasks(uint16 taskId, string calldata deliverable) external payable {
        uint256 id = uint256(uint160(msg.sender));
        if (travellers.ownerOf(id) != address(this)) revert InvalidTraveller();
        if (!isMissionTask[msg.sender][taskId]) revert TaskNotActive();
        if (!isTaskCompleted[msg.sender][taskId]) revert IncompleteTask();

        taskDeliverables[msg.sender][taskId] = deliverable;
        taskReadyForReview[msg.sender][taskId] = true;
    }

    /// -----------------------------------------------------------------------
    /// Review Functions
    /// -----------------------------------------------------------------------

    function reviewTasks(address traveller, uint16 taskId, uint8 review) external payable {
        if (!isMissionBuddy[traveller][msg.sender]) revert InvalidBuddy();
        if (!taskReadyForReview[msg.sender][taskId]) revert TaskNotReadyForReview();
        if (review == 0) revert InvalidReview();

        taskReviews[traveller][taskId][msg.sender] = review;

        Mission memory mission = missions[traveller][missionNonce[traveller]];
        address[] memory buddies = mission.buddies;
        bool check;

        if (review == 1) {
            for (uint256 i = 0; i < buddies.length;) {
                if (buddies[i] == msg.sender) {
                    continue;
                }
                
                if (taskReviews[traveller][taskId][buddies[i]] != 1) {
                    check = false;
                    break;
                }

                check = true;

                // cannot possibly overflow in array loop
                unchecked {
                    ++i;
                }
            }
        } 

        if (check) {
            isTaskCompleted[msg.sender][taskId] = true;
            taskReadyForReview[traveller][taskId] = false;

            address creator = tasks.getTaskCreator(taskId);
            taskCreatorRewards[creator] += CREATOR_REWARD;
        }
    }

    /// -----------------------------------------------------------------------
    /// Arm0ry Functions
    /// ----------------------------------------------------------------------- 

    function updateMissionProgress(address traveller) external payable {
        Mission memory mission = missions[traveller][missionNonce[traveller]];
        uint16[] memory taskIds = mission.taskIds;

        uint8 completedCount;
        uint8 incompleteCount;
        uint8 progress;
        uint8 xpEarned;

        for (uint256 i = 0; i < taskIds.length; ) {
            uint8 xp = tasks.getTaskXp(taskIds[i]);

            if (!isTaskCompleted[traveller][taskIds[i]]) {
                // cannot possibly overflow 
                unchecked {
                    ++incompleteCount;
                }
            } else {
                // cannot possibly overflow 
                unchecked {
                    ++completedCount;
                    xpEarned += xp;
                }
            }
            
            // cannot possibly overflow in array loop
            unchecked {
                ++i;
            }
        }

        // cannot possibly overflow
        unchecked {
            progress = completedCount / (completedCount + incompleteCount) * 100;
        }

        missions[msg.sender][missionNonce[msg.sender]] = Mission({
            phase: missions[msg.sender][missionNonce[msg.sender]].phase,
            progress: progress,
            xpGained: xpEarned,
            buddies: missions[msg.sender][missionNonce[msg.sender]].buddies,
            taskIds: missions[msg.sender][missionNonce[msg.sender]].taskIds,
            expiration: missions[msg.sender][missionNonce[msg.sender]].expiration
        });

        // Return locked NFT & arm0ry token when Mission is completed
        if (progress == 100) {
            if (mission.phase == Phase.PLAYGROUND_TRACKS) {
                IERC20(arm0ry).transfer(traveller, THRESHOLD);
            }
            travellers.transferFrom(address(this), traveller, uint256(uint160(traveller)));
        }
    }

    function RewardCreator(address creator) external payable {
        if (msg.sender != arm0ry) revert NotAuthorized();

        uint256 reward = taskCreatorRewards[creator];    

        taskCreatorRewards[creator] = 0;    

        IKaliShareManager(msg.sender).mintShares(address(this), reward);
    }
}
