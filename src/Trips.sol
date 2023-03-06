// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

/// @notice Helper utility that enables calling multiple local methods in a single call
/// @author Modified from Uniswap (https://github.com/Uniswap/v3-periphery/blob/main/contracts/base/Multicall.sol)
/// License-Identifier: GPL-2.0-or-later
abstract contract Multicall {
    function multicall(bytes[] calldata data) external returns (bytes[] memory results) {
        results = new bytes[](data.length);
        
        for (uint256 i; i < data.length; ) {
            (bool success, bytes memory result) = address(this).delegatecall(data[i]);

            if (!success) {
                if (result.length < 68) revert();
                    
                assembly {
                    result := add(result, 0x04)
                }
                    
                revert(abi.decode(result, (string)));
            }

            results[i] = result;

            // cannot realistically overflow on human timescales
            unchecked {
                ++i;
            }
        }
    }
}

/// @notice Modern, minimalist, and gas-optimized ERC1155 implementation.
/// @author SolDAO (https://github.com/Sol-DAO/solbase/blob/main/src/tokens/ERC1155/ERC1155.sol)
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC1155/ERC1155.sol)
abstract contract ERC1155 {
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 amount
    );

    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] amounts
    );

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    event URI(string value, uint256 indexed id);

    /// -----------------------------------------------------------------------
    /// Custom Errors
    /// -----------------------------------------------------------------------

    error Unauthorized();

    error UnsafeRecipient();

    error InvalidRecipient();

    error LengthMismatch();

    /// -----------------------------------------------------------------------
    /// ERC1155 Storage
    /// -----------------------------------------------------------------------

    mapping(address => mapping(uint256 => uint256)) public balanceOf;

    mapping(address => mapping(address => bool)) public isApprovedForAll;

    /// -----------------------------------------------------------------------
    /// Metadata Logic
    /// -----------------------------------------------------------------------

    function uri(uint256 id) public view virtual returns (string memory);

    /// -----------------------------------------------------------------------
    /// ERC1155 Logic
    /// -----------------------------------------------------------------------

    function setApprovalForAll(address operator, bool approved) public virtual {
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public virtual {
        if (msg.sender != from && !isApprovedForAll[from][msg.sender]) revert Unauthorized();

        balanceOf[from][id] -= amount;
        balanceOf[to][id] += amount;

        emit TransferSingle(msg.sender, from, to, id, amount);

        if (to.code.length != 0) {
            if (
                ERC1155TokenReceiver(to).onERC1155Received(msg.sender, from, id, amount, data) !=
                ERC1155TokenReceiver.onERC1155Received.selector
            ) revert UnsafeRecipient();
        } else if (to == address(0)) revert InvalidRecipient();
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) public virtual {
        if (ids.length != amounts.length) revert LengthMismatch();

        if (msg.sender != from && !isApprovedForAll[from][msg.sender]) revert Unauthorized();

        // Storing these outside the loop saves ~15 gas per iteration.
        uint256 id;
        uint256 amount;

        for (uint256 i = 0; i < ids.length; ) {
            id = ids[i];
            amount = amounts[i];

            balanceOf[from][id] -= amount;
            balanceOf[to][id] += amount;

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, from, to, ids, amounts);

        if (to.code.length != 0) {
            if (
                ERC1155TokenReceiver(to).onERC1155BatchReceived(msg.sender, from, ids, amounts, data) !=
                ERC1155TokenReceiver.onERC1155BatchReceived.selector
            ) revert UnsafeRecipient();
        } else if (to == address(0)) revert InvalidRecipient();
    }

    function balanceOfBatch(address[] calldata owners, uint256[] calldata ids)
        public
        view
        virtual
        returns (uint256[] memory balances)
    {
        if (ids.length != owners.length) revert LengthMismatch();

        balances = new uint256[](owners.length);

        // Unchecked because the only math done is incrementing
        // the array index counter which cannot possibly overflow.
        unchecked {
            for (uint256 i = 0; i < owners.length; ++i) {
                balances[i] = balanceOf[owners[i]][ids[i]];
            }
        }
    }

    /// -----------------------------------------------------------------------
    /// ERC165 Logic
    /// -----------------------------------------------------------------------

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == 0xd9b67a26 || // ERC165 Interface ID for ERC1155
            interfaceId == 0x0e89341c; // ERC165 Interface ID for ERC1155MetadataURI
    }

    /// -----------------------------------------------------------------------
    /// Internal Mint/Burn Logic
    /// -----------------------------------------------------------------------

    function _mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        balanceOf[to][id] += amount;

        emit TransferSingle(msg.sender, address(0), to, id, amount);

        if (to.code.length != 0) {
            if (
                ERC1155TokenReceiver(to).onERC1155Received(msg.sender, address(0), id, amount, data) !=
                ERC1155TokenReceiver.onERC1155Received.selector
            ) revert UnsafeRecipient();
        } else if (to == address(0)) revert InvalidRecipient();
    }

    function _batchMint(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        uint256 idsLength = ids.length; // Saves MLOADs.

        if (ids.length != amounts.length) revert LengthMismatch();

        for (uint256 i = 0; i < idsLength; ) {
            balanceOf[to][ids[i]] += amounts[i];

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, address(0), to, ids, amounts);

        if (to.code.length != 0) {
            if (
                ERC1155TokenReceiver(to).onERC1155BatchReceived(msg.sender, address(0), ids, amounts, data) !=
                ERC1155TokenReceiver.onERC1155BatchReceived.selector
            ) revert UnsafeRecipient();
        } else if (to == address(0)) revert InvalidRecipient();
    }

    function _batchBurn(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual {
        uint256 idsLength = ids.length; // Saves MLOADs.

        if (ids.length != amounts.length) revert LengthMismatch();

        for (uint256 i = 0; i < idsLength; ) {
            balanceOf[from][ids[i]] -= amounts[i];

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, from, address(0), ids, amounts);
    }

    function _burn(
        address from,
        uint256 id,
        uint256 amount
    ) internal virtual {
        balanceOf[from][id] -= amount;

        emit TransferSingle(msg.sender, from, address(0), id, amount);
    }
}

/// @author SolDAO (https://github.com/Sol-DAO/solbase/blob/main/src/tokens/ERC1155/ERC1155.sol)
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC1155/ERC1155.sol)
abstract contract ERC1155TokenReceiver {
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155BatchReceived.selector;
    }
}

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant alphabet = "0123456789abcdef";

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length)
        internal
        pure
        returns (string memory)
    {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = alphabet[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }
}

/// @title Base64
/// @author Brecht Devos - <brecht@loopring.org>
/// @notice Provides a function for encoding some bytes in base64
library Base64 {
    string internal constant TABLE =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    function encode(bytes memory data) internal pure returns (string memory) {
        if (data.length == 0) return "";

        // load the table into memory
        string memory table = TABLE;

        // multiply by 4/3 rounded up
        uint256 encodedLen = 4 * ((data.length + 2) / 3);

        // add some extra buffer at the end required for the writing
        string memory result = new string(encodedLen + 32);

        assembly {
            // set the actual output length
            mstore(result, encodedLen)

            // prepare the lookup table
            let tablePtr := add(table, 1)

            // input ptr
            let dataPtr := data
            let endPtr := add(dataPtr, mload(data))

            // result ptr, jump over length
            let resultPtr := add(result, 32)

            // run over the input, 3 bytes at a time
            for {

            } lt(dataPtr, endPtr) {

            } {
                dataPtr := add(dataPtr, 3)

                // read 3 bytes
                let input := mload(dataPtr)

                // write 4 characters
                mstore(
                    resultPtr,
                    shl(248, mload(add(tablePtr, and(shr(18, input), 0x3F))))
                )
                resultPtr := add(resultPtr, 1)
                mstore(
                    resultPtr,
                    shl(248, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                )
                resultPtr := add(resultPtr, 1)
                mstore(
                    resultPtr,
                    shl(248, mload(add(tablePtr, and(shr(6, input), 0x3F))))
                )
                resultPtr := add(resultPtr, 1)
                mstore(
                    resultPtr,
                    shl(248, mload(add(tablePtr, and(input, 0x3F))))
                )
                resultPtr := add(resultPtr, 1)
            }

            // padding with '='
            switch mod(mload(data), 3)
            case 1 {
                mstore(sub(resultPtr, 2), shl(240, 0x3d3d))
            }
            case 2 {
                mstore(sub(resultPtr, 1), shl(248, 0x3d))
            }
        }

        return result;
    }
}

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
            mstore(
                0,
                0xa9059cbb00000000000000000000000000000000000000000000000000000000
            )
            mstore(4, to) // append the 'to' argument
            mstore(36, amount) // append the 'amount' argument

            success := and(
                // set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data
                or(
                    and(eq(mload(0), 1), gt(returndatasize(), 31)),
                    iszero(returndatasize())
                ),
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
            mstore(
                0,
                0x23b872dd00000000000000000000000000000000000000000000000000000000
            )
            mstore(4, from) // append the 'from' argument
            mstore(36, to) // append the 'to' argument
            mstore(68, amount) // append the 'amount' argument

            success := and(
                // set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data
                or(
                    and(eq(mload(0), 1), gt(returndatasize(), 31)),
                    iszero(returndatasize())
                ),
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

/// @title Arm0ry Mission
/// @notice A list of Arm0ry missions and tasks.
/// @author audsssy.eth

struct Trip {
    bool active; // The activity status of a Trip
    uint8 xp; // The xp of a Trip
    uint8 condition; // The condition required for taking on a Trip
    uint40 duration; // The expected duration of a Trip
    uint256[] partOf; // A list of related Trips; 
    uint256[] consistOf; // A list of related Trips;
    string detail; // The detail of a Trip
    string title; // The title of a Trip
    address pathfinder; // The creator of a Trip
    uint256 ask; // The ask of a Trip
}

contract Arm0ryTrips is ERC1155, Multicall {
    using SafeTransferLib for address;

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event TripUpdated(
        uint256 tripId,
        // TripType tripType,
        uint8 xp,
        uint40 duration,
        uint256[] partOf,
        uint256[] consistOf,
        string detail,
        string title,
        address creator,
        uint256 ask,
        uint256 condition
    );

    event PermissionUpdated(
        address caller,
        address admin
    );

    /// -----------------------------------------------------------------------
    /// Custom Errors
    /// -----------------------------------------------------------------------

    error TripsNotSet();

    error NotAuthorized();

    error InvalidSponsorship();

    error InvalidTrip();

    error InvalidPathfinder();

    /// -----------------------------------------------------------------------
    /// Task Storage
    /// -----------------------------------------------------------------------

    address public admin;

    uint256 public tripId;

    mapping(uint256 /* tripId */ => Trip) public trips;

    /// -----------------------------------------------------------------------
    /// Metadata Storage & Logic
    /// -----------------------------------------------------------------------

    function uri(uint256 id)
        public
        view
        override
        virtual
        returns (string memory)
    {
        string memory name = string(
            abi.encodePacked(
                "Trip #",
                Strings.toString(id)
            )
        );
        string memory description = "Arm0ry Trips";
        string memory image = generateBase64Image(id);

        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name":"',
                                name,
                                '", "description":"',
                                description,
                                '", "image": "',
                                "data:image/svg+xml;base64,",
                                image,
                                '"}'
                            )
                        )
                    )
                )
            );
    }

    function generateBase64Image(uint256 tokenId)
        public
        view
        returns (string memory)
    {
        return Base64.encode(bytes(generateImage(tokenId)));
    }

    function generateImage(uint256 _tripId)
        public
        view
        returns (string memory)
    {
        // Retrieve seeds
        string memory _title = trips[_tripId].title;
        address _pathfinder = trips[_tripId].pathfinder;

        // Prepare palette
        // bytes memory hash = abi.encodePacked(toBytes(traveler));

        return
            string(
                abi.encodePacked(
                    '<svg class="svgBody" width="300" height="300" viewBox="0 0 300 300" xmlns="http://www.w3.org/2000/svg">',

                    '<text x="20" y="120" class="score" stroke="black" stroke-width="2">',Strings.toString(_tripId),'</text>',
                    '<text x="112" y="120" class="tiny" stroke="grey">#</text>',
                    '<text x="20" y="120" class="score" stroke="black" stroke-width="2">',_title,'</text>',
                    '<text x="272" y="120" class="tiny" stroke="grey">title</text>',
                    '<text x="15" y="170" class="medium" stroke="grey">CREATOR: </text>',
                    '<rect x="15" y="175" width="205" height="40" style="fill:white;opacity:0.5"/>',
                    '<text x="20" y="190" class="medium" stroke="black">', Strings.toHexString(uint256(uint160(_pathfinder)), 20),'</text>',
                    // unicode'  <text x="30" y="260" class="tiny" stroke="grey">Thank you for joining us at g0v 55th Hackathon! 🤙</text>',
                    '<style>.svgBody {font-family: "Courier New" } .tiny {font-size:8px; } .small {font-size: 12px;}.medium {font-size: 18px;}.score {font-size: 70px;}</style>',
                    "</svg>"
                )
            );
    }

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(address _admin)  {
        admin = _admin;
    }

    /// -----------------------------------------------------------------------
    /// Trip Logic
    /// -----------------------------------------------------------------------

    function setTrip(
        bool _active,
        uint8 _xp, 
        uint8 _condition,
        uint40 _duration,
        uint256[] memory _consistOf,
        string memory _detail,
        string memory _title,
        address _pathfinder,
        uint256 _ask
    ) external payable {
        if (msg.sender != admin)
            revert NotAuthorized();

        if (_pathfinder == address(0)) revert InvalidPathfinder();

        if (_consistOf.length != 0) {
            // Calculate xp and duration
            (uint8 totalXp, uint40 totalDuration) = 
                calculateTotalXpAndDuration(_consistOf);
        
            trips[tripId].xp = totalXp;
            trips[tripId].duration = totalDuration;
            trips[tripId].consistOf = _consistOf;
        } else {
            trips[tripId].xp = _xp;
            trips[tripId].duration = _duration;
            // trips[tripId].consistOf = _consistOf;
        }
        
        trips[tripId].active = _active;
        trips[tripId].detail = _detail;
        trips[tripId].title = _title;
        trips[tripId].pathfinder = _pathfinder;
        trips[tripId].ask = _ask;
        trips[tripId].condition = _condition;

        for (uint256 j = 0; j < _consistOf.length;) {
            
            // Add Trip to each Task's own list of associated missions 
            trips[_consistOf[j]].partOf.push(tripId);

            // Unchecked because the only math done is incrementing
            // the array index counter which cannot possibly overflow.
            unchecked {
                ++j;
            }
        }

        // Unchecked because the only math done is incrementing
        // the array index counter which cannot possibly overflow.
        unchecked {
            ++tripId;
        }
    }

    /// @notice Update ask of a Trip
    /// @param _tripId The identifier of a Trip.
    /// @param _ask New ask fo a Trip
    /// @dev
    function updateTripAsk(uint8 _tripId, uint256 _ask)
        external
        payable
    {
        if (msg.sender != admin)
            revert NotAuthorized();

        trips[_tripId].ask = _ask;
    }

    /// @notice Update activity status of a Trip
    /// @param _tripId The identifier of a Trip.
    /// @param _active New activtiy status fo a Trip
    /// @dev
    function updateTripActivity(uint8 _tripId, bool _active)
        external
        payable
    {
        if (msg.sender != admin)
            revert NotAuthorized();

        trips[_tripId].active = _active;
    }
    /// -----------------------------------------------------------------------
    /// Mint Logic
    /// -----------------------------------------------------------------------

    /// @notice Sponsor to receive Trip NFT 
    /// @param _tripIds The identifier of the Trip to sponsor.
    /// @dev
    function sponsor(uint8[] calldata _tripIds) external payable {
        
        uint256 length = _tripIds.length;
        if (length == 0) revert InvalidSponsorship();


        uint256 _ask;

        for (uint256 i = 0; i < length; ) {
            _ask = trips[_tripIds[i]].ask;
            
            admin._safeTransferETH(_ask);

            _mint(msg.sender, _tripIds[i], 1, "0x");

            unchecked {
                ++i;
            }
        }
    }

    /// -----------------------------------------------------------------------
    /// Admin Functions
    /// -----------------------------------------------------------------------

    /// @notice Update admin
    /// @param _admin The address to update admin to
    /// @dev
    function updateAdmin(address _admin)
        external
        payable
    {
        if (admin != msg.sender) revert NotAuthorized();

        if (_admin != admin) {
            admin = _admin;
        }

        emit PermissionUpdated(msg.sender, admin);
    }

    /// -----------------------------------------------------------------------
    /// Getter Functions
    /// -----------------------------------------------------------------------

    function getTripXp(uint256 _tripId) external view returns (uint8) {
        return trips[_tripId].xp;
    }

    // function getTripType(uint256 _tripId) external view returns (TripType) {
    //     return trips[_tripId].tripType;
    // }

    function getTripDuration(uint256 _tripId) external view returns (uint40) {
        return trips[_tripId].duration;
    }

    function getTripPathfinder(uint256 _tripId) external view returns (address) {
        return trips[_tripId].pathfinder;
    }

    function getTripTitle(uint256 _tripId) external view returns (string memory) {
        return trips[_tripId].title;
    }

    function getTripConsistOf(uint256 _tripId) external view returns (uint256[] memory) {
        return trips[_tripId].consistOf;
    }

    function getTripPartOf(uint256 _tripId) external view returns (uint256[] memory) {
        return trips[_tripId].partOf;
    }

    function getTripAsk(uint256 _tripId) external view returns (uint256){
        return trips[_tripId].ask;
    }

    function getTripCondition(uint256 _tripId) external view returns (uint256){
        return trips[_tripId].condition;
    }

    /// -----------------------------------------------------------------------
    /// Internal Functions
    /// -----------------------------------------------------------------------

    function calculateTotalXpAndDuration(uint256[] memory _tripIds) internal view returns (uint8, uint40) {
        uint8 totalXp;
        uint40 duration;
        for (uint256 i = 0; i < _tripIds.length; ) {
            duration += this.getTripDuration(_tripIds[i]);
            totalXp += this.getTripXp(_tripIds[i]);

            // cannot possibly overflow
            unchecked {
                ++i;
            }
        }

        return  (totalXp, duration);
    }
}
