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

struct Quest {
    uint40 start;
    uint40 duration;
    uint8 missionId;
    uint8 completed;
    uint8 incomplete;
    uint8 progress;
    uint8 xp;
    uint8 claimed;
}

interface IArm0ryQuests {
    function getQuest(address _traveler, uint8 _questId) external view returns (uint40, uint40, uint8, uint8, uint8, uint8, uint8, uint8);

    function getMissionTravelersCount(uint8 _missionId) external view returns (uint8);

    function getMissionCompletionsCount(uint8 _missionId) external view returns (uint8);

    function getMissionImpact(uint8 _missionId) external view returns (uint8);
}

interface IArm0ryMission {
    function isTaskInMission(uint8 missionId, uint8 taskId)
        external
        returns (bool);

    function getTask(uint8 taskId) external view returns (uint8, uint40, address, string memory, string memory);

    function getMission(uint8 _missionId) external view returns (uint8, uint40, uint8[] memory, string memory, string memory, address, uint256, uint256);
}

/// @title Arm0ry Mission
/// @notice A list of missions and tasks.
/// @author audsssy.eth

struct Mission {
    uint8 xp; //
    uint40 duration; //
    uint8[] taskIds; // 
    string details;
    string title;
    address creator;
    uint256 fee;
}

struct Task {
    uint8 xp;
    uint40 duration;
    address creator;
    string details;
    string title; 
}

contract Arm0ryMission is ERC1155, Multicall {
    using SafeTransferLib for address;

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event MissionUpdated(uint8 missionId);

    event TaskUpdated(
        uint40 duration,
        uint8 points,
        address creator,
        string details
    );

    event PermissionUpdated(
        address indexed caller,
        address indexed admin,
        address[] indexed managers
    );

    /// -----------------------------------------------------------------------
    /// Custom Errors
    /// -----------------------------------------------------------------------

    error NotAuthorized();

    error InvalidMission();

    /// -----------------------------------------------------------------------
    /// Task Storage
    /// -----------------------------------------------------------------------

    address public admin;

    address[] public managers;

    // Status indicating if an address is a Manager
    // Account -> True/False 
    mapping(address => bool) isManager;

    uint8 public tripId;

    uint8 public taskId;

    // A list of tasks ordered by taskId
    mapping(uint8 => Task) public tasks;

    uint8 public missionId;

    // A list of missions ordered by missionId
    mapping(uint8 => Mission) public missions;

    // Status indicating if a Task is part of a Mission
    // MissionId => TaskId => True/False
    mapping(uint8 => mapping(uint8 => bool)) public isTaskInMission;

    IArm0ryQuests public quests;

    /// -----------------------------------------------------------------------
    /// Metadata Storage & Logic
    /// -----------------------------------------------------------------------

    function uri(uint256 _missionId)
        public
        view
        override
        virtual
        returns (string memory)
    {
        string memory name = string(
            abi.encodePacked(
                "Mission #",
                Strings.toString(_missionId)
            )
        );
        string memory description = "Arm0ry Trips";
        string memory image = generateBase64Image(_missionId);

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

    function generateBase64Image(uint256 _missionId)
        public
        view
        returns (string memory)
    {
        return Base64.encode(bytes(generateImage(_missionId)));
    }

    function generateImage(uint256 _missionId)
        public
        view
        returns (string memory)
    {
        (, , , , string memory _title, , , ) = this.getMission(uint8(_missionId));
        uint8 completions = quests.getMissionCompletionsCount(uint8(_missionId));
        uint8 ratio = quests.getMissionImpact(uint8(_missionId));
        
        return
            string(
                abi.encodePacked(
                    '<svg class="svgBody" width="300" height="300" viewBox="0 0 300 300" xmlns="http://www.w3.org/2000/svg">',
                    '<text x="15" y="100" class="medium" stroke="black">',_title,'</text>',
                    '<text x="15" y="150" class="medium" stroke="grey">COMPLETIONS: </text>',
                    '<rect x="15" y="155" width="300" height="30" style="fill:yellow;opacity:0.2"/>',
                    '<text x="20" y="173" class="small">', Strings.toString(completions),'</text>',
                    '<text x="15" y="210" class="medium" stroke="grey">IMPACT %: </text>',
                    '<rect x="15" y="215" width="300" height="30" style="fill:yellow;opacity:0.2"/>',
                    '<text x="20" y="235" class="small">',Strings.toString(ratio),'%</text>',
                    '<style>.svgBody {font-family: "Courier New" } .small {font-size: 12px;}.medium {font-size: 18px;}</style>',
                    "</svg>"
                )
            );
    }

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(address _admin, IArm0ryQuests _quests) {
        admin = _admin;
        quests = _quests;
    }

    /// -----------------------------------------------------------------------
    /// Mission / Task Logic
    /// -----------------------------------------------------------------------

    /// @notice Create tasks
    /// @param taskData Encoded data to store as Task
    /// @dev
    function setTasks(bytes[] calldata taskData) external payable {
        if (msg.sender != admin && !isManager[msg.sender])
            revert NotAuthorized();

        uint256 length = taskData.length;

        for (uint256 i = 0; i < length; ) {
            (
                uint8 xp, // Xp of a Task
                uint40 duration, // Time allocated to complete a Task
                address creator, // Creator of a Task
                string memory title, // Title of a Task
                string memory details // Additional Task detail
            ) = abi.decode(taskData[i], (uint8, uint40, address, string, string));

            tasks[taskId] = Task({
                xp: xp,
                duration: duration,
                creator: creator,
                title: title,
                details: details
            });

            emit TaskUpdated(duration, xp, creator, details);

            // Unchecked because the only math done is incrementing
            // the array index counter which cannot possibly overflow.
            unchecked {
                ++i;
                ++taskId;
            }
        }
    }

    /// @notice Update tasks
    /// @param ids A list of tasks to be updated
    /// @param taskData Encoded data to update as Task
    /// @dev
    function updateTasks(uint8[] calldata ids, bytes[] calldata taskData)
        external
        payable
    {
        if (msg.sender != admin && !isManager[msg.sender])
            revert NotAuthorized();

        uint256 length = ids.length;

        if (length != taskData.length) revert LengthMismatch();

        for (uint256 i = 0; i < length; ) {
            (
                uint8 xp, // Xp of a Task
                uint40 duration, // Time allocated to complete a Task
                address creator, // Creator of a Task
                string memory title, // Title of a Task
                string memory details // Additional Task detail
            ) = abi.decode(taskData[i], (uint8, uint40, address, string, string));

            tasks[taskId] = Task({
                xp: xp,
                duration: duration,
                creator: creator,
                title: title,
                details: details
            });

            emit TaskUpdated(duration, xp, creator, details);

            // Unchecked because the only math done is incrementing
            // the array index counter which cannot possibly overflow.
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Create missions
    /// @param _taskIds A list of tasks to be added to a Mission
    /// @param _details Docs of a Mission
    /// @param _title Title of a Mission
    /// @dev
    function setMission(
        uint8[] calldata _taskIds,
        string calldata _details,
        string calldata _title,
        address _creator,
        uint256 _fee
    ) external payable {
        if (msg.sender != admin && !isManager[msg.sender])
            revert NotAuthorized();

        // Calculate xp and duration for Mission
        (uint8 totalXp, uint40 duration) = 
            calculateMissionDetail(missionId, _taskIds);

        // Create a Mission
        // Supply 01/01/2050 as deadline for first mission
         missions[missionId] = Mission({
            xp: totalXp,
            duration: (missionId == 0) ? 2524626000 : duration,
            taskIds: _taskIds, // The Task identifiers in a Mission
            details: _details, // Additional Mission detail
            title: _title, // Title of a Mission
            creator: _creator, // Creator of a Mission
            fee: _fee // Fee of a Mission
        });

        unchecked {
            ++missionId;
        }
        emit MissionUpdated(missionId);
    }

    /// @notice Update missions
    /// @param _missionId Identifiers of Mission to be updated
    /// @param _taskIds Identifiers of tasks to be updated
    /// @param _details Docs of a Mission
    /// @param _title Title of a Mission
    /// @dev
    function updateMission(
        uint8 _missionId, 
        uint8[] calldata _taskIds,
        string calldata _details,
        string calldata _title,
        address _creator,
        uint256 _fee
    ) external payable {
        if (msg.sender != admin && !isManager[msg.sender])
            revert NotAuthorized();

        // Calculate xp and duration for Mission
        (uint8 totalXp, uint40 duration) = 
            calculateMissionDetail(_missionId, _taskIds);

        // Update existing Mission
        // Supply 01/01/2050 as deadline for first mission
        missions[_missionId] = Mission({
            xp: totalXp,
            duration: (missionId == 0) ? 2524626000 : duration,
            taskIds: _taskIds,
            details: _details,
            title: _title,
            creator: _creator,
            fee: _fee
        });

        emit MissionUpdated(_missionId);
    }

    /// @notice Update missions
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

        emit PermissionUpdated(msg.sender, admin, managers);
    }

    /// @notice Update missions
    /// @param _managers The addresses to update managers to
    /// @dev
    function updateManagers(address[] calldata _managers)
        external
        payable
    {
        if (admin != msg.sender) revert NotAuthorized();

        delete managers;

        for (uint8 i = 0 ; i < _managers.length;) {

            if (_managers[i] != address(0)) {
                managers.push(_managers[i]);
                isManager[_managers[i]] = true;
            }

            // cannot possibly overflow
            unchecked {
                ++i;
            }
        }

        emit PermissionUpdated(msg.sender, admin, managers);
    }

     /// @notice Update Arm0ry contracts.
    /// @param _quests Contract address of Arm0ryTraveler.sol.
    /// @dev 
    function updateContracts(IArm0ryQuests _quests) external payable {
        if (msg.sender != admin) revert NotAuthorized();
        quests = _quests;
    }

    /// -----------------------------------------------------------------------
    /// Mint Logic
    /// -----------------------------------------------------------------------

    /// @notice Donate to receive Mission NFT 
    /// @param _missionId The identifier of the Mission to donate to.
    /// @dev
    function donate(uint8 _missionId) external payable {
        missions[_missionId].creator._safeTransferETH(missions[_missionId].fee);

        _mint(msg.sender, _missionId, 1, "0x");

        unchecked {
          ++tripId;
        }
    }

    /// -----------------------------------------------------------------------
    /// Getter Functions
    /// -----------------------------------------------------------------------

    function getTask(uint8 _taskId) external view returns (uint8, uint40, address, string memory, string memory) {
        Task memory task = tasks[_taskId];
        return (task.xp, task.duration, task.creator, task.details, task.title);
    }

    function getMission(uint8 _missionId) external view returns (uint8, uint40, uint8[] memory, string memory, string memory, address, uint256, uint256) {
        Mission memory mission = missions[_missionId];
        return (mission.xp, mission.duration, mission.taskIds, mission.details, mission.title, mission.creator, mission.fee, mission.taskIds.length);
    }

    /// -----------------------------------------------------------------------
    /// Internal Functions
    /// -----------------------------------------------------------------------

    function calculateMissionDetail(uint8 _missionId, uint8[] calldata _taskIds) internal returns (uint8, uint40) {
        // Calculate xp and duration for Mission
        uint8 totalXp;
        uint40 duration;
        for (uint256 i = 0; i < _taskIds.length; ) {
            // Aggregate Task duration to create Mission duration
            (uint8 taskXp, uint40 _duration, , , ) = this.getTask(_taskIds[i]);
            duration += _duration;
            totalXp += taskXp;

            // Update task status
            isTaskInMission[_missionId][_taskIds[i]] = true;

            // cannot possibly overflow
            unchecked {
                ++i;
            }
        }

        return  (totalXp, duration);
    }
}
