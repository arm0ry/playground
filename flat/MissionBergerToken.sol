// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

/// @notice Core SVG utility library which helps us construct
/// onchain SVGs with a simple, web-like API
/// @author Modified from (https://github.com/w1nt3r-eth/hot-chain-svg)
/// License-Identifier: MIT
library SVG {
    /// -----------------------------------------------------------------------
    /// Constants
    /// -----------------------------------------------------------------------

    string internal constant NULL = "";

    /// -----------------------------------------------------------------------
    /// Elements
    /// -----------------------------------------------------------------------

    function _text(string memory props, string memory children) internal pure returns (string memory) {
        return _el("text", props, children);
    }

    function _rect(string memory props, string memory children) internal pure returns (string memory) {
        return _el("rect", props, children);
    }

    function _image(string memory href, string memory props) internal pure returns (string memory) {
        return _el("image", string.concat(_prop("href", href), " ", props), NULL);
    }

    function _circle(string memory _props, string memory _children) internal pure returns (string memory) {
        return _el("circle", _props, _children);
    }

    function _cdata(string memory content) internal pure returns (string memory) {
        return string.concat("<![CDATA[", content, "]]>");
    }

    /// -----------------------------------------------------------------------
    /// Generics
    /// -----------------------------------------------------------------------

    /// @dev a generic element, can be used to construct any SVG (or HTML) element
    function _el(string memory tag, string memory props, string memory children)
        internal
        pure
        returns (string memory)
    {
        return string.concat("<", tag, " ", props, ">", children, "</", tag, ">");
    }

    /// @dev an SVG attribute
    function _prop(string memory key, string memory val) internal pure returns (string memory) {
        return string.concat(key, "=", '"', val, '" ');
    }

    /// @dev converts an unsigned integer to a string
    function _uint2str(uint256 i) internal pure returns (string memory) {
        if (i == 0) {
            return "0";
        }
        uint256 j = i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(i - (i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            i /= 10;
        }
        return string(bstr);
    }
}

/// @notice JSON utilities for base64 encoded ERC721 JSON metadata scheme
/// @author Modified from (https://github.com/ColinPlatt/libSVG/blob/main/src/Utils.sol)
/// License-Identifier: MIT
library JSON {
    /// @dev Base64 encoding/decoding table
    string internal constant TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    function _formattedMetadata(string memory name, string memory description, string memory svgImg)
        internal
        pure
        returns (string memory)
    {
        return string.concat(
            "data:application/json;base64,",
            _encode(
                bytes(
                    string.concat("{", _prop("name", name), _prop("description", description), _xmlImage(svgImg), "}")
                )
            )
        );
    }

    function _xmlImage(string memory svgImg) internal pure returns (string memory) {
        return _prop("image", string.concat("data:image/svg+xml;base64,", _encode(bytes(svgImg))), true);
    }

    function _prop(string memory key, string memory val) internal pure returns (string memory) {
        return string.concat('"', key, '": ', '"', val, '", ');
    }

    function _prop(string memory key, string memory val, bool last) internal pure returns (string memory) {
        if (last) {
            return string.concat('"', key, '": ', '"', val, '"');
        } else {
            return string.concat('"', key, '": ', '"', val, '", ');
        }
    }

    function _object(string memory key, string memory val) internal pure returns (string memory) {
        return string.concat('"', key, '": ', "{", val, "}");
    }

    /// @dev converts `bytes` to `string` representation
    function _encode(bytes memory data) internal pure returns (string memory) {
        // Inspired by Brecht Devos (Brechtpd) implementation - MIT licence
        // https://github.com/Brechtpd/base64/blob/e78d9fd951e7b0977ddca77d92dc85183770daf4/base64.sol
        if (data.length == 0) return "";

        // Loads the table into memory
        string memory table = TABLE;

        // Encoding takes 3 bytes chunks of binary data from `bytes` data parameter
        // and split into 4 numbers of 6 bits.
        // The final Base64 length should be `bytes` data length multiplied by 4/3 rounded up
        // - `data.length + 2`  -> Round up
        // - `/ 3`              -> Number of 3-bytes chunks
        // - `4 *`              -> 4 characters for each chunk
        string memory result = new string(4 * ((data.length + 2) / 3));

        assembly {
            // Prepare the lookup table (skip the first "length" byte)
            let tablePtr := add(table, 1)

            // Prepare result pointer, jump over length
            let resultPtr := add(result, 32)

            // Run over the input, 3 bytes at a time
            for {
                let dataPtr := data
                let endPtr := add(data, mload(data))
            } lt(dataPtr, endPtr) {} {
                // Advance 3 bytes
                dataPtr := add(dataPtr, 3)
                let input := mload(dataPtr)

                // To write each character, shift the 3 bytes (18 bits) chunk
                // 4 times in blocks of 6 bits for each character (18, 12, 6, 0)
                // and apply logical AND with 0x3F which is the number of
                // the previous character in the ASCII table prior to the Base64 Table
                // The result is then added to the table to get the character to write,
                // and finally write it in the result pointer but with a left shift
                // of 256 (1 byte) - 8 (1 ASCII char) = 248 bits

                mstore8(resultPtr, mload(add(tablePtr, and(shr(18, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance

                mstore8(resultPtr, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance

                mstore8(resultPtr, mload(add(tablePtr, and(shr(6, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance

                mstore8(resultPtr, mload(add(tablePtr, and(input, 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance
            }

            // When data `bytes` is not exactly 3 bytes long
            // it is padded with `=` characters at the end
            switch mod(mload(data), 3)
            case 1 {
                mstore8(sub(resultPtr, 1), 0x3d)
                mstore8(sub(resultPtr, 2), 0x3d)
            }
            case 2 { mstore8(sub(resultPtr, 1), 0x3d) }
        }

        return result;
    }
}

/// @notice Library to encode and decode strings in Base64.
/// @author SolDAO (https://github.com/Sol-DAO/solbase/blob/main/src/utils/Base64.sol)
/// @author Modified from Solady (https://github.com/vectorized/solady/blob/main/src/utils/Base64.sol)
library Base64 {
    /// @dev Encodes `data` using the base64 encoding described in RFC 4648.
    /// See: https://datatracker.ietf.org/doc/html/rfc4648
    /// @param fileSafe  Whether to replace '+' with '-' and '/' with '_'.
    /// @param noPadding Whether to strip away the padding.
    function encode(bytes memory data, bool fileSafe, bool noPadding) internal pure returns (string memory result) {
        assembly {
            let dataLength := mload(data)

            if dataLength {
                // Multiply by 4/3 rounded up.
                // The `shl(2, ...)` is equivalent to multiplying by 4.
                let encodedLength := shl(2, div(add(dataLength, 2), 3))

                // Set `result` to point to the start of the free memory.
                result := mload(0x40)

                // Store the table into the scratch space.
                // Offsetted by -1 byte so that the `mload` will load the character.
                // We will rewrite the free memory pointer at `0x40` later with
                // the allocated size.
                // The magic constant 0x0230 will translate "-_" + "+/".
                mstore(0x1f, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdef")
                mstore(0x3f, sub("ghijklmnopqrstuvwxyz0123456789-_", mul(iszero(fileSafe), 0x0230)))

                // Skip the first slot, which stores the length.
                let ptr := add(result, 0x20)
                let end := add(ptr, encodedLength)

                // Run over the input, 3 bytes at a time.
                // prettier-ignore
                for {} 1 {} {
                    data := add(data, 3) // Advance 3 bytes.
                    let input := mload(data)

                    // Write 4 bytes. Optimized for fewer stack operations.
                    mstore8(    ptr    , mload(and(shr(18, input), 0x3F)))
                    mstore8(add(ptr, 1), mload(and(shr(12, input), 0x3F)))
                    mstore8(add(ptr, 2), mload(and(shr( 6, input), 0x3F)))
                    mstore8(add(ptr, 3), mload(and(        input , 0x3F)))
                    
                    ptr := add(ptr, 4) // Advance 4 bytes.
                    // prettier-ignore
                    if iszero(lt(ptr, end)) { break }
                }

                let r := mod(dataLength, 3)

                switch noPadding
                case 0 {
                    // Offset `ptr` and pad with '='. We can simply write over the end.
                    mstore8(sub(ptr, iszero(iszero(r))), 0x3d) // Pad at `ptr - 1` if `r > 0`.
                    mstore8(sub(ptr, shl(1, eq(r, 1))), 0x3d) // Pad at `ptr - 2` if `r == 1`.
                    // Write the length of the string.
                    mstore(result, encodedLength)
                }
                default {
                    // Write the length of the string.
                    mstore(result, sub(encodedLength, add(iszero(iszero(r)), eq(r, 1))))
                }

                // Allocate the memory for the string.
                // Add 31 and mask with `not(31)` to round the
                // free memory pointer up the next multiple of 32.
                mstore(0x40, and(add(end, 31), not(31)))
            }
        }
    }

    /// @dev Encodes `data` using the base64 encoding described in RFC 4648.
    /// Equivalent to `encode(data, false, false)`.
    function encode(bytes memory data) internal pure returns (string memory result) {
        result = encode(data, false, false);
    }

    /// @dev Encodes `data` using the base64 encoding described in RFC 4648.
    /// Equivalent to `encode(data, fileSafe, false)`.
    function encode(bytes memory data, bool fileSafe) internal pure returns (string memory result) {
        result = encode(data, fileSafe, false);
    }

    /// @dev Decodes base64 encoded `data`.
    ///
    /// Supports:
    /// - RFC 4648 (both standard and file-safe mode).
    /// - RFC 3501 (63: ',').
    ///
    /// Does not support:
    /// - Line breaks.
    ///
    /// Note: For performance reasons,
    /// this function will NOT revert on invalid `data` inputs.
    /// Outputs for invalid inputs will simply be undefined behaviour.
    /// It is the user's responsibility to ensure that the `data`
    /// is a valid base64 encoded string.
    function decode(string memory data) internal pure returns (bytes memory result) {
        assembly {
            let dataLength := mload(data)

            if dataLength {
                let end := add(data, dataLength)
                let decodedLength := mul(shr(2, dataLength), 3)

                switch and(dataLength, 3)
                case 0 {
                    // If padded.
                    decodedLength := sub(
                        decodedLength,
                        add(eq(and(mload(end), 0xFF), 0x3d), eq(and(mload(end), 0xFFFF), 0x3d3d))
                    )
                }
                default {
                    // If non-padded.
                    decodedLength := add(decodedLength, sub(and(dataLength, 3), 1))
                }

                result := mload(0x40)

                // Write the length of the string.
                mstore(result, decodedLength)

                // Skip the first slot, which stores the length.
                let ptr := add(result, 0x20)

                // Load the table into the scratch space.
                // Constants are optimized for smaller bytecode with zero gas overhead.
                // `m` also doubles as the mask of the upper 6 bits.
                let m := 0xfc000000fc00686c7074787c8084888c9094989ca0a4a8acb0b4b8bcc0c4c8cc
                mstore(0x5b, m)
                mstore(0x3b, 0x04080c1014181c2024282c3034383c4044484c5054585c6064)
                mstore(0x1a, 0xf8fcf800fcd0d4d8dce0e4e8ecf0f4)

                // prettier-ignore
                for {} 1 {} {
                    // Read 4 bytes.
                    data := add(data, 4)
                    let input := mload(data)

                    // Write 3 bytes.
                    mstore(ptr, or(
                        and(m, mload(byte(28, input))),
                        shr(6, or(
                            and(m, mload(byte(29, input))),
                            shr(6, or(
                                and(m, mload(byte(30, input))),
                                shr(6, mload(byte(31, input)))
                            ))
                        ))
                    ))

                    ptr := add(ptr, 3)
                    
                    // prettier-ignore
                    if iszero(lt(data, end)) { break }
                }

                // Allocate the memory for the string.
                // Add 32 + 31 and mask with `not(31)` to round the
                // free memory pointer up the next multiple of 32.
                mstore(0x40, and(add(add(result, decodedLength), 63), not(31)))

                // Restore the zero slot.
                mstore(0x60, 0)
            }
        }
    }
}

/// @notice Library for converting numbers into strings and other string operations.
/// @author SolDAO (https://github.com/Sol-DAO/solbase/blob/main/src/utils/LibString.sol)
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/LibString.sol)
library LibString {
    /// -----------------------------------------------------------------------
    /// Custom Errors
    /// -----------------------------------------------------------------------

    /// @dev The `length` of the output is too small to contain all the hex digits.
    error HexLengthInsufficient();

    /// -----------------------------------------------------------------------
    /// Constants
    /// -----------------------------------------------------------------------

    /// @dev The constant returned when the `search` is not found in the string.
    uint256 internal constant NOT_FOUND = uint256(int256(-1));

    /// -----------------------------------------------------------------------
    /// Decimal Operations
    /// -----------------------------------------------------------------------

    /// @dev Returns the base 10 decimal representation of `value`.
    function toString(uint256 value) internal pure returns (string memory str) {
        assembly {
            // The maximum value of a uint256 contains 78 digits (1 byte per digit), but
            // we allocate 0xa0 bytes to keep the free memory pointer 32-byte word aligned.
            // We will need 1 word for the trailing zeros padding, 1 word for the length,
            // and 3 words for a maximum of 78 digits. Total: 5 * 0x20 = 0xa0.
            let m := add(mload(0x40), 0xa0)
            // Update the free memory pointer to allocate.
            mstore(0x40, m)
            // Assign the `str` to the end.
            str := sub(m, 0x20)
            // Zeroize the slot after the string.
            mstore(str, 0)

            // Cache the end of the memory to calculate the length later.
            let end := str

            // We write the string from rightmost digit to leftmost digit.
            // The following is essentially a do-while loop that also handles the zero case.
            // prettier-ignore
            for { let temp := value } 1 {} {
                str := sub(str, 1)
                // Write the character to the pointer.
                // The ASCII index of the '0' character is 48.
                mstore8(str, add(48, mod(temp, 10)))
                // Keep dividing `temp` until zero.
                temp := div(temp, 10)
                // prettier-ignore
                if iszero(temp) { break }
            }

            let length := sub(end, str)
            // Move the pointer 32 bytes leftwards to make room for the length.
            str := sub(str, 0x20)
            // Store the length.
            mstore(str, length)
        }
    }

    /// -----------------------------------------------------------------------
    /// Hexadecimal Operations
    /// -----------------------------------------------------------------------

    /// @dev Returns the hexadecimal representation of `value`,
    /// left-padded to an input length of `length` bytes.
    /// The output is prefixed with "0x" encoded using 2 hexadecimal digits per byte,
    /// giving a total length of `length * 2 + 2` bytes.
    /// Reverts if `length` is too small for the output to contain all the digits.
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory str) {
        assembly {
            let start := mload(0x40)
            // We need 0x20 bytes for the trailing zeros padding, `length * 2` bytes
            // for the digits, 0x02 bytes for the prefix, and 0x20 bytes for the length.
            // We add 0x20 to the total and round down to a multiple of 0x20.
            // (0x20 + 0x20 + 0x02 + 0x20) = 0x62.
            let m := add(start, and(add(shl(1, length), 0x62), not(0x1f)))
            // Allocate the memory.
            mstore(0x40, m)
            // Assign the `str` to the end.
            str := sub(m, 0x20)
            // Zeroize the slot after the string.
            mstore(str, 0)

            // Cache the end to calculate the length later.
            let end := str
            // Store "0123456789abcdef" in scratch space.
            mstore(0x0f, 0x30313233343536373839616263646566)

            let temp := value
            // We write the string from rightmost digit to leftmost digit.
            // The following is essentially a do-while loop that also handles the zero case.
            // prettier-ignore
            for {} 1 {} {
                str := sub(str, 2)
                mstore8(add(str, 1), mload(and(temp, 15)))
                mstore8(str, mload(and(shr(4, temp), 15)))
                temp := shr(8, temp)
                length := sub(length, 1)
                // prettier-ignore
                if iszero(length) { break }
            }

            if temp {
                // Store the function selector of `HexLengthInsufficient()`.
                mstore(0x00, 0x2194895a)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }

            // Compute the string's length.
            let strLength := add(sub(end, str), 2)
            // Move the pointer and write the "0x" prefix.
            str := sub(str, 0x20)
            mstore(str, 0x3078)
            // Move the pointer and write the length.
            str := sub(str, 2)
            mstore(str, strLength)
        }
    }

    /// @dev Returns the hexadecimal representation of `value`.
    /// The output is prefixed with "0x" and encoded using 2 hexadecimal digits per byte.
    /// As address are 20 bytes long, the output will left-padded to have
    /// a length of `20 * 2 + 2` bytes.
    function toHexString(uint256 value) internal pure returns (string memory str) {
        assembly {
            let start := mload(0x40)
            // We need 0x20 bytes for the trailing zeros padding, 0x20 bytes for the length,
            // 0x02 bytes for the prefix, and 0x40 bytes for the digits.
            // The next multiple of 0x20 above (0x20 + 0x20 + 0x02 + 0x40) is 0xa0.
            let m := add(start, 0xa0)
            // Allocate the memory.
            mstore(0x40, m)
            // Assign the `str` to the end.
            str := sub(m, 0x20)
            // Zeroize the slot after the string.
            mstore(str, 0)

            // Cache the end to calculate the length later.
            let end := str
            // Store "0123456789abcdef" in scratch space.
            mstore(0x0f, 0x30313233343536373839616263646566)

            // We write the string from rightmost digit to leftmost digit.
            // The following is essentially a do-while loop that also handles the zero case.
            // prettier-ignore
            for { let temp := value } 1 {} {
                str := sub(str, 2)
                mstore8(add(str, 1), mload(and(temp, 15)))
                mstore8(str, mload(and(shr(4, temp), 15)))
                temp := shr(8, temp)
                // prettier-ignore
                if iszero(temp) { break }
            }

            // Compute the string's length.
            let strLength := add(sub(end, str), 2)
            // Move the pointer and write the "0x" prefix.
            str := sub(str, 0x20)
            mstore(str, 0x3078)
            // Move the pointer and write the length.
            str := sub(str, 2)
            mstore(str, strLength)
        }
    }

    /// @dev Returns the hexadecimal representation of `value`.
    /// The output is prefixed with "0x" and encoded using 2 hexadecimal digits per byte.
    function toHexString(address value) internal pure returns (string memory str) {
        assembly {
            let start := mload(0x40)
            // We need 0x20 bytes for the length, 0x02 bytes for the prefix,
            // and 0x28 bytes for the digits.
            // The next multiple of 0x20 above (0x20 + 0x02 + 0x28) is 0x60.
            str := add(start, 0x60)

            // Allocate the memory.
            mstore(0x40, str)
            // Store "0123456789abcdef" in scratch space.
            mstore(0x0f, 0x30313233343536373839616263646566)

            let length := 20
            // We write the string from rightmost digit to leftmost digit.
            // The following is essentially a do-while loop that also handles the zero case.
            // prettier-ignore
            for { let temp := value } 1 {} {
                str := sub(str, 2)
                mstore8(add(str, 1), mload(and(temp, 15)))
                mstore8(str, mload(and(shr(4, temp), 15)))
                temp := shr(8, temp)
                length := sub(length, 1)
                // prettier-ignore
                if iszero(length) { break }
            }

            // Move the pointer and write the "0x" prefix.
            str := sub(str, 32)
            mstore(str, 0x3078)
            // Move the pointer and write the length.
            str := sub(str, 2)
            mstore(str, 42)
        }
    }

    /// -----------------------------------------------------------------------
    /// Other String Operations
    /// -----------------------------------------------------------------------

    // For performance and bytecode compactness, all indices of the following operations
    // are byte (ASCII) offsets, not UTF character offsets.

    /// @dev Returns `subject` all occurances of `search` replaced with `replacement`.
    function replace(
        string memory subject,
        string memory search,
        string memory replacement
    ) internal pure returns (string memory result) {
        assembly {
            let subjectLength := mload(subject)
            let searchLength := mload(search)
            let replacementLength := mload(replacement)

            subject := add(subject, 0x20)
            search := add(search, 0x20)
            replacement := add(replacement, 0x20)
            result := add(mload(0x40), 0x20)

            let subjectEnd := add(subject, subjectLength)
            if iszero(gt(searchLength, subjectLength)) {
                let subjectSearchEnd := add(sub(subjectEnd, searchLength), 1)
                let h := 0
                if iszero(lt(searchLength, 32)) {
                    h := keccak256(search, searchLength)
                }
                let m := shl(3, sub(32, and(searchLength, 31)))
                let s := mload(search)
                // prettier-ignore
                for {} 1 {} {
                    let t := mload(subject)
                    // Whether the first `searchLength % 32` bytes of 
                    // `subject` and `search` matches.
                    if iszero(shr(m, xor(t, s))) {
                        if h {
                            if iszero(eq(keccak256(subject, searchLength), h)) {
                                mstore(result, t)
                                result := add(result, 1)
                                subject := add(subject, 1)
                                // prettier-ignore
                                if iszero(lt(subject, subjectSearchEnd)) { break }
                                continue
                            }
                        }
                        // Copy the `replacement` one word at a time.
                        // prettier-ignore
                        for { let o := 0 } 1 {} {
                            mstore(add(result, o), mload(add(replacement, o)))
                            o := add(o, 0x20)
                            // prettier-ignore
                            if iszero(lt(o, replacementLength)) { break }
                        }
                        result := add(result, replacementLength)
                        subject := add(subject, searchLength)
                        if searchLength {
                            // prettier-ignore
                            if iszero(lt(subject, subjectSearchEnd)) { break }
                            continue
                        }
                    }
                    mstore(result, t)
                    result := add(result, 1)
                    subject := add(subject, 1)
                    // prettier-ignore
                    if iszero(lt(subject, subjectSearchEnd)) { break }
                }
            }

            let resultRemainder := result
            result := add(mload(0x40), 0x20)
            let k := add(sub(resultRemainder, result), sub(subjectEnd, subject))
            // Copy the rest of the string one word at a time.
            // prettier-ignore
            for {} lt(subject, subjectEnd) {} {
                mstore(resultRemainder, mload(subject))
                resultRemainder := add(resultRemainder, 0x20)
                subject := add(subject, 0x20)
            }
            result := sub(result, 0x20)
            // Zeroize the slot after the string.
            let last := add(add(result, 0x20), k)
            mstore(last, 0)
            // Allocate memory for the length and the bytes,
            // rounded up to a multiple of 32.
            mstore(0x40, and(add(last, 31), not(31)))
            // Store the length of the result.
            mstore(result, k)
        }
    }

    /// @dev Returns the byte index of the first location of `search` in `subject`,
    /// searching from left to right, starting from `from`.
    /// Returns `NOT_FOUND` (i.e. `type(uint256).max`) if the `search` is not found.
    function indexOf(string memory subject, string memory search, uint256 from) internal pure returns (uint256 result) {
        assembly {
            // prettier-ignore
            for { let subjectLength := mload(subject) } 1 {} {
                if iszero(mload(search)) {
                    // `result = min(from, subjectLength)`.
                    result := xor(from, mul(xor(from, subjectLength), lt(subjectLength, from)))
                    break
                }
                let searchLength := mload(search)
                let subjectStart := add(subject, 0x20)    
                
                result := not(0) // Initialize to `NOT_FOUND`.

                subject := add(subjectStart, from)
                let subjectSearchEnd := add(sub(add(subjectStart, subjectLength), searchLength), 1)

                let m := shl(3, sub(32, and(searchLength, 31)))
                let s := mload(add(search, 0x20))

                // prettier-ignore
                if iszero(lt(subject, subjectSearchEnd)) { break }

                if iszero(lt(searchLength, 32)) {
                    // prettier-ignore
                    for { let h := keccak256(add(search, 0x20), searchLength) } 1 {} {
                        if iszero(shr(m, xor(mload(subject), s))) {
                            if eq(keccak256(subject, searchLength), h) {
                                result := sub(subject, subjectStart)
                                break
                            }
                        }
                        subject := add(subject, 1)
                        // prettier-ignore
                        if iszero(lt(subject, subjectSearchEnd)) { break }
                    }
                    break
                }
                // prettier-ignore
                for {} 1 {} {
                    if iszero(shr(m, xor(mload(subject), s))) {
                        result := sub(subject, subjectStart)
                        break
                    }
                    subject := add(subject, 1)
                    // prettier-ignore
                    if iszero(lt(subject, subjectSearchEnd)) { break }
                }
                break
            }
        }
    }

    /// @dev Returns the byte index of the first location of `search` in `subject`,
    /// searching from left to right.
    /// Returns `NOT_FOUND` (i.e. `type(uint256).max`) if the `search` is not found.
    function indexOf(string memory subject, string memory search) internal pure returns (uint256 result) {
        result = indexOf(subject, search, 0);
    }

    /// @dev Returns the byte index of the first location of `search` in `subject`,
    /// searching from right to left, starting from `from`.
    /// Returns `NOT_FOUND` (i.e. `type(uint256).max`) if the `search` is not found.
    function lastIndexOf(
        string memory subject,
        string memory search,
        uint256 from
    ) internal pure returns (uint256 result) {
        assembly {
            // prettier-ignore
            for {} 1 {} {
                let searchLength := mload(search)
                let fromMax := sub(mload(subject), searchLength)
                if iszero(gt(fromMax, from)) {
                    from := fromMax
                }
                if iszero(mload(search)) {
                    result := from
                    break
                }
                result := not(0) // Initialize to `NOT_FOUND`.

                let subjectSearchEnd := sub(add(subject, 0x20), 1)

                subject := add(add(subject, 0x20), from)
                // prettier-ignore
                if iszero(gt(subject, subjectSearchEnd)) { break }
                // As this function is not too often used,
                // we shall simply use keccak256 for smaller bytecode size.
                // prettier-ignore
                for { let h := keccak256(add(search, 0x20), searchLength) } 1 {} {
                    if eq(keccak256(subject, searchLength), h) {
                        result := sub(subject, add(subjectSearchEnd, 1))
                        break
                    }
                    subject := sub(subject, 1)
                    // prettier-ignore
                    if iszero(gt(subject, subjectSearchEnd)) { break }
                }
                break
            }
        }
    }

    /// @dev Returns the index of the first location of `search` in `subject`,
    /// searching from right to left.
    /// Returns `NOT_FOUND` (i.e. `type(uint256).max`) if the `search` is not found.
    function lastIndexOf(string memory subject, string memory search) internal pure returns (uint256 result) {
        result = lastIndexOf(subject, search, uint256(int256(-1)));
    }

    /// @dev Returns whether `subject` starts with `search`.
    function startsWith(string memory subject, string memory search) internal pure returns (bool result) {
        assembly {
            let searchLength := mload(search)
            // Just using keccak256 directly is actually cheaper.
            result := and(
                iszero(gt(searchLength, mload(subject))),
                eq(keccak256(add(subject, 0x20), searchLength), keccak256(add(search, 0x20), searchLength))
            )
        }
    }

    /// @dev Returns whether `subject` ends with `search`.
    function endsWith(string memory subject, string memory search) internal pure returns (bool result) {
        assembly {
            let searchLength := mload(search)
            let subjectLength := mload(subject)
            // Whether `search` is not longer than `subject`.
            let withinRange := iszero(gt(searchLength, subjectLength))
            // Just using keccak256 directly is actually cheaper.
            result := and(
                withinRange,
                eq(
                    keccak256(
                        // `subject + 0x20 + max(subjectLength - searchLength, 0)`.
                        add(add(subject, 0x20), mul(withinRange, sub(subjectLength, searchLength))),
                        searchLength
                    ),
                    keccak256(add(search, 0x20), searchLength)
                )
            )
        }
    }

    /// @dev Returns `subject` repeated `times`.
    function repeat(string memory subject, uint256 times) internal pure returns (string memory result) {
        assembly {
            let subjectLength := mload(subject)
            if iszero(or(iszero(times), iszero(subjectLength))) {
                subject := add(subject, 0x20)
                result := mload(0x40)
                let output := add(result, 0x20)
                // prettier-ignore
                for {} 1 {} {
                    // Copy the `subject` one word at a time.
                    // prettier-ignore
                    for { let o := 0 } 1 {} {
                        mstore(add(output, o), mload(add(subject, o)))
                        o := add(o, 0x20)
                        // prettier-ignore
                        if iszero(lt(o, subjectLength)) { break }
                    }
                    output := add(output, subjectLength)
                    times := sub(times, 1)
                    // prettier-ignore
                    if iszero(times) { break }
                }
                // Zeroize the slot after the string.
                mstore(output, 0)
                // Store the length.
                let resultLength := sub(output, add(result, 0x20))
                mstore(result, resultLength)
                // Allocate memory for the length and the bytes,
                // rounded up to a multiple of 32.
                mstore(0x40, add(result, and(add(resultLength, 63), not(31))))
            }
        }
    }

    /// @dev Returns a copy of `subject` sliced from `start` to `end` (exclusive).
    /// `start` and `end` are byte offsets.
    function slice(string memory subject, uint256 start, uint256 end) internal pure returns (string memory result) {
        assembly {
            let subjectLength := mload(subject)
            if iszero(gt(subjectLength, end)) {
                end := subjectLength
            }
            if iszero(gt(subjectLength, start)) {
                start := subjectLength
            }
            if lt(start, end) {
                result := mload(0x40)
                let resultLength := sub(end, start)
                mstore(result, resultLength)
                subject := add(subject, start)
                // Copy the `subject` one word at a time, backwards.
                // prettier-ignore
                for { let o := and(add(resultLength, 31), not(31)) } 1 {} {
                    mstore(add(result, o), mload(add(subject, o)))
                    o := sub(o, 0x20)
                    // prettier-ignore
                    if iszero(o) { break }
                }
                // Zeroize the slot after the string.
                mstore(add(add(result, 0x20), resultLength), 0)
                // Allocate memory for the length and the bytes,
                // rounded up to a multiple of 32.
                mstore(0x40, add(result, and(add(resultLength, 63), not(31))))
            }
        }
    }

    /// @dev Returns a copy of `subject` sliced from `start` to the end of the string.
    /// `start` is a byte offset.
    function slice(string memory subject, uint256 start) internal pure returns (string memory result) {
        result = slice(subject, start, uint256(int256(-1)));
    }

    /// @dev Returns all the indices of `search` in `subject`.
    /// The indices are byte offsets.
    function indicesOf(string memory subject, string memory search) internal pure returns (uint256[] memory result) {
        assembly {
            let subjectLength := mload(subject)
            let searchLength := mload(search)

            if iszero(gt(searchLength, subjectLength)) {
                subject := add(subject, 0x20)
                search := add(search, 0x20)
                result := add(mload(0x40), 0x20)

                let subjectStart := subject
                let subjectSearchEnd := add(sub(add(subject, subjectLength), searchLength), 1)
                let h := 0
                if iszero(lt(searchLength, 32)) {
                    h := keccak256(search, searchLength)
                }
                let m := shl(3, sub(32, and(searchLength, 31)))
                let s := mload(search)
                // prettier-ignore
                for {} 1 {} {
                    let t := mload(subject)
                    // Whether the first `searchLength % 32` bytes of 
                    // `subject` and `search` matches.
                    if iszero(shr(m, xor(t, s))) {
                        if h {
                            if iszero(eq(keccak256(subject, searchLength), h)) {
                                subject := add(subject, 1)
                                // prettier-ignore
                                if iszero(lt(subject, subjectSearchEnd)) { break }
                                continue
                            }
                        }
                        // Append to `result`.
                        mstore(result, sub(subject, subjectStart))
                        result := add(result, 0x20)
                        // Advance `subject` by `searchLength`.
                        subject := add(subject, searchLength)
                        if searchLength {
                            // prettier-ignore
                            if iszero(lt(subject, subjectSearchEnd)) { break }
                            continue
                        }
                    }
                    subject := add(subject, 1)
                    // prettier-ignore
                    if iszero(lt(subject, subjectSearchEnd)) { break }
                }
                let resultEnd := result
                // Assign `result` to the free memory pointer.
                result := mload(0x40)
                // Store the length of `result`.
                mstore(result, shr(5, sub(resultEnd, add(result, 0x20))))
                // Allocate memory for result.
                // We allocate one more word, so this array can be recycled for {split}.
                mstore(0x40, add(resultEnd, 0x20))
            }
        }
    }

    /// @dev Returns a arrays of strings based on the `delimiter` inside of the `subject` string.
    function split(string memory subject, string memory delimiter) internal pure returns (string[] memory result) {
        uint256[] memory indices = indicesOf(subject, delimiter);
        assembly {
            if mload(indices) {
                let indexPtr := add(indices, 0x20)
                let indicesEnd := add(indexPtr, shl(5, add(mload(indices), 1)))
                mstore(sub(indicesEnd, 0x20), mload(subject))
                mstore(indices, add(mload(indices), 1))
                let prevIndex := 0
                // prettier-ignore
                for {} 1 {} {
                    let index := mload(indexPtr)
                    mstore(indexPtr, 0x60)                        
                    if iszero(eq(index, prevIndex)) {
                        let element := mload(0x40)
                        let elementLength := sub(index, prevIndex)
                        mstore(element, elementLength)
                        // Copy the `subject` one word at a time, backwards.
                        // prettier-ignore
                        for { let o := and(add(elementLength, 31), not(31)) } 1 {} {
                            mstore(add(element, o), mload(add(add(subject, prevIndex), o)))
                            o := sub(o, 0x20)
                            // prettier-ignore
                            if iszero(o) { break }
                        }
                        // Zeroize the slot after the string.
                        mstore(add(add(element, 0x20), elementLength), 0)
                        // Allocate memory for the length and the bytes,
                        // rounded up to a multiple of 32.
                        mstore(0x40, add(element, and(add(elementLength, 63), not(31))))
                        // Store the `element` into the array.
                        mstore(indexPtr, element)                        
                    }
                    prevIndex := add(index, mload(delimiter))
                    indexPtr := add(indexPtr, 0x20)
                    // prettier-ignore
                    if iszero(lt(indexPtr, indicesEnd)) { break }
                }
                result := indices
                if iszero(mload(delimiter)) {
                    result := add(indices, 0x20)
                    mstore(result, sub(mload(indices), 2))
                }
            }
        }
    }

    /// @dev Returns a concatenated string of `a` and `b`.
    /// Cheaper than `string.concat()` and does not de-align the free memory pointer.
    function concat(string memory a, string memory b) internal pure returns (string memory result) {
        assembly {
            result := mload(0x40)
            let aLength := mload(a)
            // Copy `a` one word at a time, backwards.
            // prettier-ignore
            for { let o := and(add(mload(a), 32), not(31)) } 1 {} {
                mstore(add(result, o), mload(add(a, o)))
                o := sub(o, 0x20)
                // prettier-ignore
                if iszero(o) { break }
            }
            let bLength := mload(b)
            let output := add(result, mload(a))
            // Copy `b` one word at a time, backwards.
            // prettier-ignore
            for { let o := and(add(bLength, 32), not(31)) } 1 {} {
                mstore(add(output, o), mload(add(b, o)))
                o := sub(o, 0x20)
                // prettier-ignore
                if iszero(o) { break }
            }
            let totalLength := add(aLength, bLength)
            let last := add(add(result, 0x20), totalLength)
            // Zeroize the slot after the string.
            mstore(last, 0)
            // Stores the length.
            mstore(result, totalLength)
            // Allocate memory for the length and the bytes,
            // rounded up to a multiple of 32.
            mstore(0x40, and(add(last, 31), not(31)))
        }
    }

    /// @dev Packs a single string with its length into a single word.
    /// Returns `bytes32(0)` if the length is zero or greater than 31.
    function packOne(string memory a) internal pure returns (bytes32 result) {
        assembly {
            // We don't need to zero right pad the string,
            // since this is our own custom non-standard packing scheme.
            result := mul(
                // Load the length and the bytes.
                mload(add(a, 0x1f)),
                // `length != 0 && length < 32`. Abuses underflow.
                // Assumes that the length is valid and within the block gas limit.
                lt(sub(mload(a), 1), 0x1f)
            )
        }
    }

    /// @dev Unpacks a string packed using {packOne}.
    /// Returns the empty string if `packed` is `bytes32(0)`.
    /// If `packed` is not an output of {packOne}, the output behaviour is undefined.
    function unpackOne(bytes32 packed) internal pure returns (string memory result) {
        assembly {
            // Grab the free memory pointer.
            result := mload(0x40)
            // Allocate 2 words (1 for the length, 1 for the bytes).
            mstore(0x40, add(result, 0x40))
            // Zeroize the length slot.
            mstore(result, 0)
            // Store the length and bytes.
            mstore(add(result, 0x1f), packed)
            // Right pad with zeroes.
            mstore(add(add(result, 0x20), mload(result)), 0)
        }
    }

    /// @dev Packs two strings with their lengths into a single word.
    /// Returns `bytes32(0)` if combined length is zero or greater than 30.
    function packTwo(string memory a, string memory b) internal pure returns (bytes32 result) {
        assembly {
            let aLength := mload(a)
            // We don't need to zero right pad the strings,
            // since this is our own custom non-standard packing scheme.
            result := mul(
                // Load the length and the bytes of `a` and `b`.
                or(shl(shl(3, sub(0x1f, aLength)), mload(add(a, aLength))), mload(sub(add(b, 0x1e), aLength))),
                // `totalLength != 0 && totalLength < 31`. Abuses underflow.
                // Assumes that the lengths are valid and within the block gas limit.
                lt(sub(add(aLength, mload(b)), 1), 0x1e)
            )
        }
    }

    /// @dev Unpacks strings packed using {packTwo}.
    /// Returns the empty strings if `packed` is `bytes32(0)`.
    /// If `packed` is not an output of {packTwo}, the output behaviour is undefined.
    function unpackTwo(bytes32 packed) internal pure returns (string memory resultA, string memory resultB) {
        assembly {
            // Grab the free memory pointer.
            resultA := mload(0x40)
            resultB := add(resultA, 0x40)
            // Allocate 2 words for each string (1 for the length, 1 for the byte). Total 4 words.
            mstore(0x40, add(resultB, 0x40))
            // Zeroize the length slots.
            mstore(resultA, 0)
            mstore(resultB, 0)
            // Store the lengths and bytes.
            mstore(add(resultA, 0x1f), packed)
            mstore(add(resultB, 0x1f), mload(add(add(resultA, 0x20), mload(resultA))))
            // Right pad with zeroes.
            mstore(add(add(resultA, 0x20), mload(resultA)), 0)
            mstore(add(add(resultB, 0x20), mload(resultB)), 0)
        }
    }

    /// @dev Directly returns `a` without copying.
    function directReturn(string memory a) internal pure {
        assembly {
            // Right pad with zeroes. Just in case the string is produced
            // by a method that doesn't zero right pad.
            mstore(add(add(a, 0x20), mload(a)), 0)
            // Store the return offset.
            // Assumes that the string does not start from the scratch space.
            mstore(sub(a, 0x20), 0x20)
            // End the transaction, returning the string.
            return(sub(a, 0x20), add(mload(a), 0x40))
        }
    }
}

/// @notice Modern, minimalist, and gas-optimized ERC721 implementation.
/// @author SolDAO (https://github.com/Sol-DAO/solbase/blob/main/src/tokens/ERC721.sol)
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC721.sol)
abstract contract ERC721 {
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    event Approval(address indexed owner, address indexed spender, uint256 indexed id);

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /// -----------------------------------------------------------------------
    /// Custom Errors
    /// -----------------------------------------------------------------------

    error NotMinted();

    error ZeroAddress();

    error Unauthorized();

    error WrongFrom();

    error InvalidRecipient();

    error UnsafeRecipient();

    error AlreadyMinted();

    /// -----------------------------------------------------------------------
    /// Metadata Storage/Logic
    /// -----------------------------------------------------------------------

    string public name;

    string public symbol;

    function tokenURI(uint256 id) public view virtual returns (string memory);

    /// -----------------------------------------------------------------------
    /// ERC721 Balance/Owner Storage
    /// -----------------------------------------------------------------------

    mapping(uint256 => address) internal _ownerOf;

    mapping(address => uint256) internal _balanceOf;

    function ownerOf(uint256 id) public view virtual returns (address owner) {
        if ((owner = _ownerOf[id]) == address(0)) revert NotMinted();
    }

    function balanceOf(address owner) public view virtual returns (uint256) {
        if (owner == address(0)) revert ZeroAddress();
        return _balanceOf[owner];
    }

    /// -----------------------------------------------------------------------
    /// ERC721 Approval Storage
    /// -----------------------------------------------------------------------

    mapping(uint256 => address) public getApproved;

    mapping(address => mapping(address => bool)) public isApprovedForAll;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    /// -----------------------------------------------------------------------
    /// ERC721 Logic
    /// -----------------------------------------------------------------------

    function approve(address spender, uint256 id) public virtual {
        address owner = _ownerOf[id];

        if (msg.sender != owner && !isApprovedForAll[owner][msg.sender]) revert Unauthorized();

        getApproved[id] = spender;

        emit Approval(owner, spender, id);
    }

    function setApprovalForAll(address operator, bool approved) public virtual {
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(address from, address to, uint256 id) public virtual {
        if (from != _ownerOf[id]) revert WrongFrom();

        if (to == address(0)) revert InvalidRecipient();

        if (msg.sender != from && !isApprovedForAll[from][msg.sender] && msg.sender != getApproved[id])
            revert Unauthorized();

        // Underflow of the sender's balance is impossible because we check for
        // ownership above and the recipient's balance can't realistically overflow.
        unchecked {
            _balanceOf[from]--;

            _balanceOf[to]++;
        }

        _ownerOf[id] = to;

        delete getApproved[id];

        emit Transfer(from, to, id);
    }

    function safeTransferFrom(address from, address to, uint256 id) public virtual {
        transferFrom(from, to, id);

        if (to.code.length != 0) {
            if (
                ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, "") !=
                ERC721TokenReceiver.onERC721Received.selector
            ) revert UnsafeRecipient();
        }
    }

    function safeTransferFrom(address from, address to, uint256 id, bytes calldata data) public virtual {
        transferFrom(from, to, id);

        if (to.code.length != 0) {
            if (
                ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, data) !=
                ERC721TokenReceiver.onERC721Received.selector
            ) revert UnsafeRecipient();
        }
    }

    /// -----------------------------------------------------------------------
    /// ERC165 Logic
    /// -----------------------------------------------------------------------

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == 0x80ac58cd || // ERC165 Interface ID for ERC721
            interfaceId == 0x5b5e139f; // ERC165 Interface ID for ERC721Metadata
    }

    /// -----------------------------------------------------------------------
    /// Internal Mint/Burn Logic
    /// -----------------------------------------------------------------------

    function _mint(address to, uint256 id) internal virtual {
        if (to == address(0)) revert InvalidRecipient();

        if (_ownerOf[id] != address(0)) revert AlreadyMinted();

        // Counter overflow is incredibly unrealistic.
        unchecked {
            _balanceOf[to]++;
        }

        _ownerOf[id] = to;

        emit Transfer(address(0), to, id);
    }

    function _burn(uint256 id) internal virtual {
        address owner = _ownerOf[id];

        if (owner == address(0)) revert NotMinted();

        // Ownership check above ensures no underflow.
        unchecked {
            _balanceOf[owner]--;
        }

        delete _ownerOf[id];

        delete getApproved[id];

        emit Transfer(owner, address(0), id);
    }

    /// -----------------------------------------------------------------------
    /// Internal Safe Mint Logic
    /// -----------------------------------------------------------------------

    function _safeMint(address to, uint256 id) internal virtual {
        _mint(to, id);

        if (to.code.length != 0) {
            if (
                ERC721TokenReceiver(to).onERC721Received(msg.sender, address(0), id, "") !=
                ERC721TokenReceiver.onERC721Received.selector
            ) revert UnsafeRecipient();
        }
    }

    function _safeMint(address to, uint256 id, bytes memory data) internal virtual {
        _mint(to, id);

        if (to.code.length != 0) {
            if (
                ERC721TokenReceiver(to).onERC721Received(msg.sender, address(0), id, data) !=
                ERC721TokenReceiver.onERC721Received.selector
            ) revert UnsafeRecipient();
        }
    }
}

/// @notice A generic interface for a contract which properly accepts ERC721 tokens.
/// @author SolDAO (https://github.com/Sol-DAO/solbase/blob/main/src/tokens/ERC721.sol)
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC721.sol)
abstract contract ERC721TokenReceiver {
    function onERC721Received(address, address, uint256, bytes calldata) external virtual returns (bytes4) {
        return ERC721TokenReceiver.onERC721Received.selector;
    }
}

interface IMission {
    error InvalidMission();

    /// @dev DAO methods
    function initialize(address dao) external payable;

    /// @dev Quest methods
    function authorizeQuest(address quest) external payable;
    function isQuestAuthorized(address target) external view returns (bool);

    /// @dev Task set methods
    function setTask(address creator, uint256 deadline, string calldata detail) external payable;
    function setTaskCreator(uint256 taskId, address creator) external payable;
    function setTaskDeadline(uint256 taskId, uint256 deadline) external payable;
    function setTaskDetail(uint256 taskId, string calldata detail) external payable;

    /// @dev Task get methods
    function getTaskId() external view returns (uint256);
    function getTaskCompletions(uint256 taskId) external view returns (uint256);
    function getTaskCreator(uint256 taskId) external view returns (address);
    function getTaskDeadline(uint256 taskId) external view returns (uint256);
    function getTaskDetail(uint256 taskId) external view returns (string memory);
    function isTaskInMission(uint256 missionId, uint256 taskId) external view returns (bool);

    /// @dev Mission set methods
    function setMission(address creator, string calldata title, string calldata detail, uint256[] calldata taskIds)
        external
        payable;
    function setMissionCreator(uint256 missionId, address creator) external payable;
    function setMissionTitle(uint256 missionId, string calldata title) external payable;
    function setMissionDetail(uint256 missionId, string calldata detail) external payable;
    function setMissionTasks(uint256 missionId, uint256[] calldata taskIds) external payable;

    /// @dev Mission get methods

    function getMissionId() external view returns (uint256);
    function getMissionTitle(uint256 missionId) external view returns (string memory);
    function getMissionTaskCount(uint256 missionId) external view returns (uint256 count);
    function getMissionTaskIds(uint256 missionId) external view returns (uint256[] memory);
    function getMissionStarts(uint256 missionId) external view returns (uint256);
    function getMissionCompletions(uint256 missionId) external view returns (uint256);
    function getMissionCreator(uint256 missionId) external view returns (address);
    function getMissionDetail(uint256 missionId) external view returns (string memory);
    function getMissionDeadline(uint256 missionId) external view returns (uint256);

    /// @dev Mission set methods
    function incrementTaskCompletions(uint256 taskId) external payable;
    function incrementMissionStarts(uint256 missionId) external payable;
    function incrementMissionCompletions(uint256 missionId) external payable;
}

interface IQuest {
    /// @notice DAO logic.
    function initialize(address dao) external payable;
    function setCooldown(uint40 cd) external payable;
    function getCooldown() external view returns (uint256);

    /// @notice User logic.
    function setProfilePicture(string calldata url) external payable;
    function getProfilePicture(address user) external view returns (string memory);
    function start(address missions, uint256 missionId) external payable;
    function startBySig(address signer, address missions, uint256 missionId, uint8 v, bytes32 r, bytes32 s)
        external
        payable;
    function respond(address missions, uint256 missionId, uint256 taskId, string calldata feedback, uint256 response)
        external
        payable;
    function respondBySig(
        address signer,
        uint256 taskKey,
        string calldata feedback,
        uint256 response,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable;
    function getQuest(uint256 questId) external view returns (address, address, uint256);
    function isQuestActive(address user, address missions, uint256 missionId) external view returns (bool);
    function getQuestProgress(address user, address missions, uint256 missionId) external view returns (uint256);
    function getCompletedTaskCount(address user, address missions, uint256 missionId) external view returns (uint256);
    function getTimeLastTaskCompleted(address user) external view returns (uint256);
    function hasCooledDown(address user) external view returns (bool);

    /// @notice Reviewer logic.
    function setReviewer(address reviewer, bool status) external payable;
    function isReviewer(address user) external view;
    function getReviewStatus() external view returns (bool);
    function setReviewStatus(bool status) external payable;
    function review(
        address user,
        address missions,
        uint256 missionId,
        uint256 taskId,
        uint256 response,
        string calldata feedback
    ) external payable;
    function reviewBySig(
        address signer,
        address user,
        address missions,
        uint256 missionId,
        uint256 taskId,
        uint256 response,
        string calldata feedback,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable;

    /// @notice Get response & feedback.
    function getUserResponse(address user, address missions, uint256 missionId, uint256 taskId)
        external
        view
        returns (uint256);
    function getUserFeedback(address user, address missions, uint256 missionId, uint256 taskId)
        external
        view
        returns (string memory);
    function getReviewResponse(address reviewer, address user, address missions, uint256 missionId, uint256 taskId)
        external
        view
        returns (uint256);
    function getReviewFeedback(address reviewer, address user, address missions, uint256 missionId, uint256 taskId)
        external
        view
        returns (string memory);

    /// @notice Get quest related counter.
    function getMissionQuestedCount(address missions, uint256 missionId) external view returns (uint256, uint256);
    function getResponseCountByUser(address user, address missions, uint256 missionId, uint256 taskId)
        external
        view
        returns (uint256, uint256);
    function getReviewCountByReviewer(address reviewer, address missions, uint256 missionId, uint256 taskId)
        external
        view
        returns (uint256, uint256);

    /// @notice Get quest related stats.
    function getNumOfMissionsStarted() external view returns (uint256);
    function getNumOfMissionsCompleted() external view returns (uint256);
    function getNumOfTaskCompleted() external view returns (uint256);
    function getNumOfMissionsStartedByUser(address user, address missions, uint256 missionId)
        external
        view
        returns (uint256);
    function getNumOfMissionsCompletedByUser(address user, address missions, uint256 missionId)
        external
        view
        returns (uint256);
    function getNumOfTasksCompletedByUser(address user, address missions, uint256 missionId, uint256 taskId)
        external
        view
        returns (uint256);
}

interface IStorage {
    /// @dev Storage get methods
    function getDao() external view returns (address);
    function getAddress(bytes32 _key) external view returns (address);
    function getMissionsAddress() external view returns (address);
    function getQuestsAddress() external view returns (address);
    function getBool(bytes32 _key) external view returns (bool);
    function getString(bytes32 _key) external view returns (string memory);
    function getUint(bytes32 _key) external view returns (uint256);

    /// @dev Storage set methods
    function setAddress(bytes32 _key, address _value) external;
    function setMissionsAddress(address account) external;
    function setQuestsAddress(address account) external;
    function setBool(bytes32 _key, bool _value) external;
    function setString(bytes32 _key, string memory _value) external;
    function setUint(bytes32 _key, uint256 _value) external;

    /// @dev Storage delete methods
    function deleteAddress(bytes32 _key) external;
    function deleteBool(bytes32 _key) external;
    function deleteString(bytes32 _key) external;
    function deleteUint(bytes32 _key) external;

    /// @dev Storage arithmetic methods
    function addUint(bytes32 _key, uint256 _amount) external;
    function subUint(bytes32 _key, uint256 _amount) external;
}

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

/// @title Impact NFTs
/// @notice SVG NFTs displaying impact results and metrics.
/// Majory inspired by Kali, Async.art
contract MissionBergerToken is ERC721 {
    /// -----------------------------------------------------------------------
    /// DAO Storage
    /// -----------------------------------------------------------------------

    address public dao;
    address public kaliBerger;

    /// -----------------------------------------------------------------------
    /// Modifier
    /// -----------------------------------------------------------------------

    modifier onlyDao() {
        if (msg.sender != dao) revert Unauthorized();
        _;
    }

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(address _dao, address _kaliBerger, string memory name, string memory symbol) ERC721(name, symbol) {
        dao = _dao;
        kaliBerger = _kaliBerger;
    }

    modifier onlyMissionCreators(address missions, uint256 missionId, address user) {
        if (IMission(missions).getMissionCreator(missionId) != msg.sender) revert Unauthorized();
        _;
    }

    /// -----------------------------------------------------------------------
    /// Metadata Storage & Logic
    /// -----------------------------------------------------------------------

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return _buildURI(tokenId);
    }

    // credit: z0r0z.eth (https://github.com/kalidao/kali-contracts/blob/60ba3992fb8d6be6c09eeb74e8ff3086a8fdac13/contracts/access/KaliAccessManager.sol)
    function _buildURI(uint256 tokenId) private view returns (string memory) {
        return JSON._formattedMetadata("Mission Berger Token", "", generateSvg(tokenId));
    }

    function generateSvg(uint256 tokenId) public view returns (string memory) {
        (address missions, uint256 missionId) = this.decodeTokenId(tokenId);
        return string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300" style="background:#FFFBF5">',
            buildSvgData(missions, missionId),
            buildTreeRing(missions, missionId),
            "</svg>"
        );
    }

    function buildSvgData(address missions, uint256 missionId) public view returns (string memory) {
        return string.concat(
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "40"),
                    SVG._prop("font-size", "20"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat("Patron Impact")
            ),
            SVG._rect(
                string.concat(
                    SVG._prop("fill", "#FFBE0B"),
                    SVG._prop("x", "20"),
                    SVG._prop("y", "50"),
                    SVG._prop("width", SVG._uint2str(160)),
                    SVG._prop("height", SVG._uint2str(5))
                ),
                SVG.NULL
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "80"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat("Title: ")
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "110"),
                    SVG._prop("font-size", "18"),
                    SVG._prop("fill", "#00040a")
                ),
                IMission(missions).getMissionTitle(missionId)
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "170"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(
                    "Harberger Tax: ",
                    SVG._uint2str((kaliBerger == address(0)) ? IKaliBerger(kaliBerger).getTax(missions, missionId) : 0),
                    "%"
                )
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "210"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat("# of completions: ", SVG._uint2str(IMission(missions).getMissionCompletions(missionId)))
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "190"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat("Complete by: ", SVG._uint2str(IMission(missions).getMissionDeadline(missionId)))
            )
        );
    }

    function buildTreeRing(address missions, uint256 missionId) public view returns (string memory str) {
        uint256 baseRadius = 500;
        uint256[] memory taskIds = IMission(missions).getMissionTaskIds(missionId);

        for (uint256 i = 0; i < taskIds.length;) {
            uint256 completions = IMission(missions).getTaskCompletions(taskIds[i]);

            // radius = completions * max radius / max completions at max radius + base radius
            uint256 radius = completions * 500 / 100;
            baseRadius += radius / 10;

            str = string.concat(
                str,
                SVG._circle(
                    string.concat(
                        SVG._prop("cx", "265"),
                        SVG._prop("cy", "265"),
                        SVG._prop("r", SVG._uint2str(baseRadius / 10)),
                        SVG._prop("stroke", "#A1662F"),
                        SVG._prop("stroke-opacity", "0.1"),
                        SVG._prop("stroke-width", "3"),
                        SVG._prop("fill", "#FFBE0B"),
                        SVG._prop("fill-opacity", "0.1")
                    ),
                    ""
                )
            );

            unchecked {
                ++i;
            }
        }

        return str;
    }

    /// -----------------------------------------------------------------------
    /// DAO Logic
    /// -----------------------------------------------------------------------

    function setKaliBerger(address _kaliBerger) external payable onlyDao {
        kaliBerger = _kaliBerger;
    }

    /// -----------------------------------------------------------------------
    /// Mission Creator Logic
    /// -----------------------------------------------------------------------

    function mint(address missions, uint256 missionId)
        external
        payable
        onlyMissionCreators(missions, missionId, msg.sender)
    {
        _mint(msg.sender, this.getTokenId(missions, missionId));
    }

    function burn(address missions, uint256 missionId)
        external
        payable
        onlyMissionCreators(missions, missionId, msg.sender)
    {
        _burn(this.getTokenId(missions, missionId));
    }

    /// -----------------------------------------------------------------------
    /// Helper Functions
    /// -----------------------------------------------------------------------

    function getTokenId(address missions, uint256 missionId) external pure returns (uint256) {
        return uint256(bytes32(abi.encodePacked(missions, uint96(missionId))));
    }

    function decodeTokenId(uint256 tokenId) external pure returns (address missions, uint256 missionId) {
        uint96 _id;
        bytes32 key = bytes32(tokenId);
        assembly {
            _id := key
            missions := shr(96, key)
        }
        return (missions, uint256(_id));
    }
}
