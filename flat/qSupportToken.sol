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

/// @notice LibClone-compatible ERC721.
/// @author audsssy.eth
/// @author Modified from SolDAO (https://github.com/Sol-DAO/solbase/blob/main/src/tokens/ERC721.sol)
abstract contract SupportToken {
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

    function _init(string memory _name, string memory _symbol) internal virtual {
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

        if (msg.sender != from && !isApprovedForAll[from][msg.sender] && msg.sender != getApproved[id]) {
            revert Unauthorized();
        }

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
                ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, "")
                    != ERC721TokenReceiver.onERC721Received.selector
            ) revert UnsafeRecipient();
        }
    }

    function safeTransferFrom(address from, address to, uint256 id, bytes calldata data) public virtual {
        transferFrom(from, to, id);

        if (to.code.length != 0) {
            if (
                ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, data)
                    != ERC721TokenReceiver.onERC721Received.selector
            ) revert UnsafeRecipient();
        }
    }

    /// -----------------------------------------------------------------------
    /// ERC165 Logic
    /// -----------------------------------------------------------------------

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == 0x01ffc9a7 // ERC165 Interface ID for ERC165
            || interfaceId == 0x80ac58cd // ERC165 Interface ID for ERC721
            || interfaceId == 0x5b5e139f; // ERC165 Interface ID for ERC721Metadata
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
                ERC721TokenReceiver(to).onERC721Received(msg.sender, address(0), id, "")
                    != ERC721TokenReceiver.onERC721Received.selector
            ) revert UnsafeRecipient();
        }
    }

    function _safeMint(address to, uint256 id, bytes memory data) internal virtual {
        _mint(to, id);

        if (to.code.length != 0) {
            if (
                ERC721TokenReceiver(to).onERC721Received(msg.sender, address(0), id, data)
                    != ERC721TokenReceiver.onERC721Received.selector
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
    function setFee(uint256 fee) external payable;
    function getFee() external view returns (uint256);

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
    function getTotalTaskCompletions(uint256 taskId) external view returns (uint256);
    function getTotalTaskCompletionsByMission(uint256 missionId, uint256 taskId) external view returns (uint256);
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
    function getMissionTaskId(uint256 missionId, uint256 order) external view returns (uint256);
    function getMissionTaskIds(uint256 missionId) external view returns (uint256[] memory);
    function getMissionStarts(uint256 missionId) external view returns (uint256);
    function getMissionCompletions(uint256 missionId) external view returns (uint256);
    function getMissionCreator(uint256 missionId) external view returns (address);
    function getMissionDetail(uint256 missionId) external view returns (string memory);
    function getMissionDeadline(uint256 missionId) external view returns (uint256);

    /// @dev Mission set methods
    function incrementTotalTaskCompletions(uint256 taskId) external payable;
    function incrementTotalTaskCompletionsByMission(uint256 missionId, uint256 taskId) external payable;
    function incrementMissionStarts(uint256 missionId) external payable;
    function incrementMissionCompletions(uint256 missionId) external payable;
}

/// @notice An extensible DAO-managed storage
/// @author audsssy.eth
/// credit: inspired by RocketPool (https://github.com/rocket-pool/rocketpool/blob/6a9dbfd85772900bb192aabeb0c9b8d9f6e019d1/contracts/contract/RocketStorage.sol)
contract Storage {
    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error NotOperator();
    error NotPlayground();
    error LengthMismatch();

    /// -----------------------------------------------------------------------
    /// List Storage
    /// -----------------------------------------------------------------------

    mapping(bytes32 => string) public stringStorage;
    mapping(bytes32 => address) public addressStorage;
    mapping(bytes32 => uint256) public uintStorage;
    mapping(bytes32 => bool) public booleanStorage;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    function init(address dao) internal {
        _setDao(dao);
    }

    /// -----------------------------------------------------------------------
    /// Modifier
    /// -----------------------------------------------------------------------

    modifier onlyOperator() {
        if (msg.sender != this.getDao()) revert NotOperator();
        _;
    }

    /// -----------------------------------------------------------------------
    /// General Storage - Setter Logic
    /// -----------------------------------------------------------------------

    /// @param dao The DAO address.
    function setDao(address dao) external onlyOperator {
        addressStorage[keccak256(abi.encodePacked("dao"))] = dao;
    }

    /// @param _key The key for the record.
    function setAddress(bytes32 _key, address _value) external onlyOperator {
        addressStorage[_key] = _value;
    }

    /// @param _key The key for the record.
    function setUint(bytes32 _key, uint256 _value) external onlyOperator {
        uintStorage[_key] = _value;
    }

    /// @param _key The key for the record.
    function setString(bytes32 _key, string calldata _value) external onlyOperator {
        stringStorage[_key] = _value;
    }

    /// @param _key The key for the record.
    function setBool(bytes32 _key, bool _value) external onlyOperator {
        booleanStorage[_key] = _value;
    }

    /// @param dao The DAO address.
    function _setDao(address dao) internal {
        addressStorage[keccak256(abi.encodePacked("dao"))] = dao;
    }

    /// @param _key The key for the record.
    function _setAddress(bytes32 _key, address _value) internal {
        addressStorage[_key] = _value;
    }

    /// @param _key The key for the record.
    function _setUint(bytes32 _key, uint256 _value) internal {
        uintStorage[_key] = _value;
    }

    /// @param _key The key for the record.
    function _setString(bytes32 _key, string calldata _value) internal {
        stringStorage[_key] = _value;
    }

    /// @param _key The key for the record.
    function _setBool(bytes32 _key, bool _value) internal {
        booleanStorage[_key] = _value;
    }
    /// -----------------------------------------------------------------------
    /// General Sotrage - Delete Logic
    /// -----------------------------------------------------------------------

    /// @param _key The key for the record.
    function deleteAddress(bytes32 _key) internal {
        delete addressStorage[_key];
    }

    /// @param _key The key for the record.
    function deleteUint(bytes32 _key) internal {
        delete uintStorage[_key];
    }

    /// @param _key The key for the record.
    function deleteString(bytes32 _key) internal {
        delete stringStorage[_key];
    }

    /// @param _key The key for the record.
    function deleteBool(bytes32 _key) internal {
        delete booleanStorage[_key];
    }

    /// -----------------------------------------------------------------------
    /// Add Logic
    /// -----------------------------------------------------------------------

    /// @param _key The key for the record.
    /// @param _amount An amount to add to the record's value
    function addUint(bytes32 _key, uint256 _amount) internal returns (uint256) {
        return uintStorage[_key] = uintStorage[_key] + _amount;
    }

    /// @param _key The key for the record.
    /// @param _amount An amount to subtract from the record's value
    function subUint(bytes32 _key, uint256 _amount) internal returns (uint256) {
        uint256 value = uintStorage[_key];
        return (value >= _amount) ? uintStorage[_key] = value - _amount : 0;
    }

    /// -----------------------------------------------------------------------
    /// General Storage - Getter Logic
    /// -----------------------------------------------------------------------

    /// @dev Get the address of DAO.
    function getDao() external view returns (address) {
        return addressStorage[keccak256(abi.encodePacked("dao"))];
    }

    /// @param _key The key for the record.
    function getAddress(bytes32 _key) external view returns (address) {
        return addressStorage[_key];
    }

    /// @param _key The key for the record.
    function getUint(bytes32 _key) external view returns (uint256) {
        return uintStorage[_key];
    }

    /// @param _key The key for the record.
    function getString(bytes32 _key) external view returns (string memory) {
        return stringStorage[_key];
    }

    /// @param _key The key for the record.
    function getBool(bytes32 _key) external view returns (bool) {
        return booleanStorage[_key];
    }
}

/// @title Missions
/// @notice A list of missions and tasks.
/// @author audsssy.eth
contract Mission is Storage {
    /// -----------------------------------------------------------------------
    /// Custom Errors
    /// -----------------------------------------------------------------------

    error NotAuthorized();
    error InvalidTask();
    error InvalidMission();
    error InvalidFee();
    error TransferFailed();

    /// -----------------------------------------------------------------------
    /// Modifier
    /// -----------------------------------------------------------------------

    modifier onlyQuest() {
        if (!this.isQuestAuthorized(msg.sender)) revert NotAuthorized();
        _;
    }

    modifier priceCheck() {
        uint256 fee = this.getFee();
        if (fee > 0 && msg.value == this.getFee()) {
            (bool success,) = this.getDao().call{value: msg.value}("");
            if (!success) revert TransferFailed();
            _;
        } else if (fee == 0) {
            _;
        } else {
            revert InvalidFee();
        }
    }

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    function initialize(address dao) external payable {
        init(dao);
    }

    /// -----------------------------------------------------------------------
    /// DAO Logic
    /// ----------------------------------------------------------------------

    /// @notice Authorize a Quest contract to export data to this Mission contract.
    function authorizeQuest(address quest, bool status) external payable onlyOperator {
        _setBool(keccak256(abi.encode(address(this), quest, ".authorized")), status);
    }

    function isQuestAuthorized(address target) external view returns (bool) {
        return this.getBool(keccak256(abi.encode(address(this), target, ".authorized")));
    }

    function setFee(uint256 fee) external payable onlyOperator {
        _setUint(keccak256(abi.encode(address(this), ".fee")), fee);
    }

    function getFee() external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), ".fee")));
    }

    /// -----------------------------------------------------------------------
    /// Task Logic - Setter
    /// -----------------------------------------------------------------------

    /// @notice  Create task by dao.
    function setTasks(address[] calldata creators, uint256[] calldata deadlines, string[] calldata detail)
        external
        payable
        onlyOperator
    {
        _setTasks(creators, deadlines, detail);
    }

    /// @notice  Create task with payment.
    function payToSetTasks(address[] calldata creators, uint256[] calldata deadlines, string[] calldata detail)
        external
        payable
        priceCheck
    {
        _setTasks(creators, deadlines, detail);
    }

    /// @notice Update creator of a task.
    function setTaskCreator(uint256 taskId, address creator) external payable onlyOperator {
        _setTaskCreator(taskId, creator);
    }

    /// @notice Update deadline of a task.
    function setTaskDeadline(uint256 taskId, uint256 deadline) external payable onlyOperator {
        _setTaskDeadline(taskId, deadline);

        // Update deadline of associated missions, if any.
        uint256 count = this.getTaskMissionCount(taskId);
        if (count != 0) {
            uint256 missionId;
            for (uint256 i = 0; i < count; ++i) {
                missionId = this.getTaskMissionId(taskId, i + 1);
                if (deadline > this.getMissionDeadline(missionId)) {
                    __setMissionDeadline(missionId, deadline);
                }
            }
        }
    }

    /// @notice  Internal function to create task.
    function _setTasks(address[] calldata creators, uint256[] calldata deadlines, string[] calldata detail) internal {
        uint256 taskId;

        // Confirm inputs are valid.
        uint256 length = creators.length;
        if (length != deadlines.length || length != detail.length) revert LengthMismatch();
        if (length == 0) revert InvalidTask();

        // Set new task content.
        for (uint256 i = 0; i < length; ++i) {
            // Increment and retrieve taskId.
            taskId = incrementTaskId();
            _setTaskCreator(taskId, creators[i]);
            _setTaskDeadline(taskId, deadlines[i]);
            _setTaskDetail(taskId, detail[i]);
        }
    }

    /// @notice Update detail of a task.
    function setTaskDetail(uint256 taskId, string calldata detail) external payable onlyOperator {
        _setTaskDetail(taskId, detail);
    }

    /// @notice Internal function to set creator of a task.
    function _setTaskCreator(uint256 taskId, address creator) internal {
        if (creator == address(0)) revert InvalidTask();
        _setAddress(keccak256(abi.encode(address(this), ".tasks.", taskId, ".creator")), creator);
    }

    /// @notice Internal function to set deadline of a task.
    function _setTaskDeadline(uint256 taskId, uint256 deadline) internal {
        if (deadline == 0) revert InvalidTask();
        _setUint(keccak256(abi.encode(address(this), ".tasks.", taskId, ".deadline")), deadline);
    }

    /// @notice Internal function to set detail of a task.
    function _setTaskDetail(uint256 taskId, string calldata detail) internal {
        if (bytes(detail).length == 0) deleteString(keccak256(abi.encode(address(this), ".tasks.", taskId, ".detail")));
        _setString(keccak256(abi.encode(address(this), ".tasks.", taskId, ".detail")), detail);
    }

    /// @notice Increment and return task id.
    function incrementTaskId() internal returns (uint256) {
        return addUint(keccak256(abi.encode(address(this), "tasks.count")), 1);
    }

    /// @notice Increment number of task completions by task id by authorized Quest contracts only.
    function incrementTotalTaskCompletions(uint256 taskId) external payable onlyQuest {
        addUint(keccak256(abi.encode(address(this), ".tasks.", taskId, ".completions")), 1);
    }

    /// @notice Increment and return number of tasks a mission.
    function incrementTaskMissionCount(uint256 taskId) internal returns (uint256) {
        return addUint(keccak256(abi.encode(address(this), ".tasks.", taskId, ".missionCount")), 1);
    }

    /// -----------------------------------------------------------------------
    /// Mission Logic - Setter
    /// -----------------------------------------------------------------------

    /// @notice Create a mission.
    function setMission(address creator, string calldata title, string calldata detail, uint256[] calldata taskIds)
        external
        payable
        onlyOperator
    {
        _setMission(creator, title, detail, taskIds);
    }

    /// @notice Create mission with payment.
    function payToSetMission(address creator, string calldata title, string calldata detail, uint256[] calldata taskIds)
        external
        payable
        priceCheck
    {
        _setMission(creator, title, detail, taskIds);
    }

    /// @notice Update creator of a mission.
    function setMissionCreator(uint256 missionId, address creator) external payable onlyOperator {
        _setMissionCreator(missionId, creator);
    }

    /// @notice Update title of a mission.
    function setMissionTitle(uint256 missionId, string calldata title) external payable onlyOperator {
        _setMissionTitle(missionId, title);
    }

    /// @notice Update detail of a mission.
    function setMissionDetail(uint256 missionId, string calldata detail) external payable onlyOperator {
        _setMissionDetail(missionId, detail);
    }

    /// @notice Add tasks to a mission.
    function addMissionTasks(uint256 missionId, uint256[] calldata taskIds) external payable onlyOperator {
        if (taskIds.length > 0) _addMissionTasks(missionId, taskIds);
    }

    /// @notice Update a task by its order in a given mission.
    function setMissionTaskId(uint256 missionId, uint256 order, uint256 newTaskId) external payable onlyOperator {
        if (this.getTaskCreator(newTaskId) == address(0)) revert InvalidTask();

        // Delete status of old task id.
        uint256 oldTaskId = this.getMissionTaskId(missionId, order);
        deleteIsTaskInMission(missionId, oldTaskId);

        // Update task by its order.
        updateTaskInMission(missionId, order, newTaskId);

        // Associate mission with new task.
        associateMissionWithTask(missionId, newTaskId);

        // Update status of new task.
        setIsTaskInMission(missionId, newTaskId, true);

        // Update mission deadline, if needed.
        updateMissionDeadline(missionId, newTaskId);
    }

    /// @notice Increment and return mission id.
    function incrementMissionId() internal returns (uint256) {
        return addUint(keccak256(abi.encode(address(this), "missions.count")), 1);
    }

    /// @notice Internal function to create a mission.
    function _setMission(address creator, string calldata title, string calldata detail, uint256[] calldata taskIds)
        internal
    {
        // Retrieve missionId.
        uint256 missionId = incrementMissionId();

        // Set new mission content.
        if (taskIds.length == 0) revert InvalidMission();
        _addMissionTasks(missionId, taskIds);
        _setMissionDeadline(missionId, taskIds);
        _setMissionCreator(missionId, creator);
        _setMissionDetail(missionId, detail);
        _setMissionTitle(missionId, title);
    }

    /// @notice Add tasks to a mission.
    function _addMissionTasks(uint256 missionId, uint256[] calldata taskIds) internal {
        uint256 length = taskIds.length;
        for (uint256 i = 0; i < length; ++i) {
            // Add task.
            addNewTaskToMission(missionId, taskIds[i]);

            // Associate mission with given task.
            associateMissionWithTask(missionId, taskIds[i]);

            // Update status of task id in given mission.
            setIsTaskInMission(missionId, taskIds[i], true);
        }
    }

    /// @notice Set whether a task is part of a mission.
    function setIsTaskInMission(uint256 missionId, uint256 taskId, bool status) internal {
        _setBool(keccak256(abi.encode(address(this), ".missions.", missionId, ".tasks.", taskId, ".exists")), status);
    }

    /// @notice Set whether a task is part of a mission.
    function deleteIsTaskInMission(uint256 missionId, uint256 taskId) internal {
        deleteBool(keccak256(abi.encode(address(this), ".missions.", missionId, ".tasks.", taskId, ".exists")));
    }

    /// @notice Associate a task with a given mission.
    function addNewTaskToMission(uint256 missionId, uint256 taskId) internal {
        uint256 count = incrementMissionTaskCount(missionId);
        _setUint(keccak256(abi.encode(address(this), ".missions.", missionId, ".tasks.", count)), taskId);
    }

    /// @notice Increment and return number of tasks a mission.
    function incrementMissionTaskCount(uint256 missionId) internal returns (uint256) {
        return addUint(keccak256(abi.encode(address(this), ".missions.", missionId, ".taskCount")), 1);
    }

    /// @notice Associate a task with a given mission.
    function updateTaskInMission(uint256 missionId, uint256 order, uint256 taskId) internal {
        _setUint(keccak256(abi.encode(address(this), ".missions.", missionId, ".tasks.", order)), taskId);
    }

    /// @notice Associate a mission with a given task.
    function associateMissionWithTask(uint256 missionId, uint256 taskId) internal {
        uint256 count = incrementTaskMissionCount(taskId);
        _setUint(keccak256(abi.encode(address(this), ".tasks.", taskId, ".missionIds.", count)), missionId);
    }

    /// @notice Internal function to set creator of a mission.
    function _setMissionCreator(uint256 missionId, address creator) internal {
        if (creator == address(0)) revert InvalidMission();
        _setAddress(keccak256(abi.encode(address(this), ".missions.", missionId, ".creator")), creator);
    }

    /// @notice Internal function to set detail of a mission.
    function _setMissionDetail(uint256 missionId, string calldata detail) internal {
        if (bytes(detail).length == 0) {
            deleteString(keccak256(abi.encode(address(this), ".missions.", missionId, ".detail")));
        }
        _setString(keccak256(abi.encode(address(this), ".missions.", missionId, ".detail")), detail);
    }

    /// @notice Internal function to set title of a mission.
    function _setMissionTitle(uint256 missionId, string calldata title) internal {
        if (bytes(title).length == 0) revert InvalidMission();
        _setString(keccak256(abi.encode(address(this), ".missions.", missionId, ".title")), title);
    }

    // /// @notice Set mission deadline.
    // function setMissionDeadline(uint256 missionId) internal returns (uint256) {
    //     uint256 deadline = this.getMissionDeadline(missionId);

    //     // Confirm deadline is initialized.
    //     if (deadline == 0) {
    //         // If not, confirm mission is initialized.
    //         if (this.getMissionTaskCount(missionId) > 0) {
    //             // If so, set mission deadline.
    //             return _setMissionDeadline(missionId);
    //         } else {
    //             return 0;
    //         }
    //     } else {
    //         return deadline;
    //     }
    // }

    /// @notice Internal function to retrieve and set deadline of mission by using the latest task deadline.
    function _setMissionDeadline(uint256 missionId, uint256[] calldata taskIds) internal returns (uint256) {
        uint256 deadline;
        uint256 _deadline;

        for (uint256 i = 0; i < taskIds.length; ++i) {
            _deadline = this.getTaskDeadline(taskIds[i]);
            if (_deadline > deadline) deadline = _deadline;
        }

        __setMissionDeadline(missionId, deadline);
        return deadline;
    }

    function __setMissionDeadline(uint256 missionId, uint256 deadline) internal {
        _setUint(keccak256(abi.encode(address(this), ".missions.", missionId, ".deadline")), deadline);
    }

    /// @notice Internal function to retrieve and set deadline of mission by using the latest task deadline.
    function updateMissionDeadline(uint256 missionId, uint256 newTaskId) internal {
        uint256 deadline = this.getMissionDeadline(missionId);
        uint256 _deadline = this.getTaskDeadline(newTaskId);
        if (_deadline > deadline) __setMissionDeadline(missionId, _deadline);
    }

    // /// @notice Internal function to retrieve and set deadline of mission by using the latest task deadline.
    // function _setMissionDeadline(uint256 missionId) internal returns (uint256) {
    //     uint256 deadline;
    //     uint256[] memory taskIds = this.getMissionTaskIds(missionId);

    //     uint256 _deadline;
    //     for (uint256 i = 0; i < taskIds.length; ++i) {
    //         _deadline = this.getTaskDeadline(taskIds[i]);
    //         if (_deadline > deadline) deadline = _deadline;
    //     }

    //     __setMissionDeadline(missionId, deadline);
    //     return deadline;
    // }

    /// @notice Increment number of mission starts by mission id by authorized Quest contracts only.
    function incrementMissionStarts(uint256 missionId) external payable onlyQuest {
        addUint(keccak256(abi.encode(address(this), ".missions.", missionId, ".starts")), 1);
    }

    /// @notice Increment number of mission completions by mission id by authorized Quest contracts only.
    function incrementMissionCompletions(uint256 missionId) external payable onlyQuest {
        addUint(keccak256(abi.encode(address(this), ".missions.", missionId, ".completions")), 1);
    }

    /// @notice Increment number of task completions by task id by authorized Quest contracts only.
    function incrementTotalTaskCompletionsByMission(uint256 missionId, uint256 taskId) external payable onlyQuest {
        addUint(keccak256(abi.encode(address(this), ".missions.", missionId, ".tasks.", taskId, ".completions")), 1);
    }

    /// -----------------------------------------------------------------------
    /// Task Logic - Getter
    /// -----------------------------------------------------------------------

    /// @notice Get task id.
    function getTaskId() external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), "tasks.count")));
    }

    /// @notice Get creator of a task.
    function getTaskCreator(uint256 taskId) external view returns (address) {
        return this.getAddress(keccak256(abi.encode(address(this), ".tasks.", taskId, ".creator")));
    }

    /// @notice Get deadline of a task.
    function getTaskDeadline(uint256 taskId) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), ".tasks.", taskId, ".deadline")));
    }

    /// @notice Get detail of a task.
    function getTaskDetail(uint256 taskId) external view returns (string memory) {
        return this.getString(keccak256(abi.encode(address(this), ".tasks.", taskId, ".detail")));
    }

    /// @notice Returns whether a task is part of a mission.
    function isTaskInMission(uint256 missionId, uint256 taskId) external view returns (bool) {
        return this.getBool(keccak256(abi.encode(address(this), ".missions.", missionId, ".tasks.", taskId, ".exists")));
    }

    /// @notice Get number of task completions by task id.
    function getTotalTaskCompletions(uint256 taskId) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), ".tasks.", taskId, ".completions")));
    }

    /// @notice Get number of task completions by task id.
    function getTotalTaskCompletionsByMission(uint256 missionId, uint256 taskId) external view returns (uint256) {
        return this.getUint(
            keccak256(abi.encode(address(this), ".missions.", missionId, ".tasks.", taskId, ".completions"))
        );
    }

    /// @notice Get number of missions that are associated with a task.
    function getTaskMissionCount(uint256 taskId) external view returns (uint256 missionCount) {
        return this.getUint(keccak256(abi.encode(address(this), ".tasks.", taskId, ".missionCount")));
    }

    /// @notice Get mission ids associated with a task.
    function getTaskMissionId(uint256 taskId, uint256 order) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), ".tasks.", taskId, ".missionIds.", order)));
    }

    /// @notice Get all mission ids associated with a given task.
    function getTaskMissionIds(uint256 taskId) external view returns (uint256[] memory) {
        uint256 count = this.getTaskMissionCount(taskId);
        uint256[] memory missionIds = new uint256[](count);
        for (uint256 i; i < count; ++i) {
            missionIds[i] = this.getTaskMissionId(taskId, i + 1);
        }
        return missionIds;
    }

    /// -----------------------------------------------------------------------
    /// Mission Logic - Getter
    /// -----------------------------------------------------------------------

    /// @notice Get missoin id.
    function getMissionId() external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), "missions.count")));
    }

    /// @notice Get creator of a mission.
    function getMissionCreator(uint256 missionId) external view returns (address) {
        return this.getAddress(keccak256(abi.encode(address(this), ".missions.", missionId, ".creator")));
    }

    /// @notice Get deadline of a mission.
    function getMissionDeadline(uint256 missionId) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), ".missions.", missionId, ".deadline")));
    }

    /// @notice Get detail of a mission.
    function getMissionDetail(uint256 missionId) external view returns (string memory) {
        return this.getString(keccak256(abi.encode(address(this), ".missions.", missionId, ".detail")));
    }

    /// @notice Get title of a mission.
    function getMissionTitle(uint256 missionId) external view returns (string memory) {
        return this.getString(keccak256(abi.encode(address(this), ".missions.", missionId, ".title")));
    }

    /// @notice Get the number of mission starts by missionId.
    function getMissionStarts(uint256 missionId) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), ".missions.", missionId, ".starts")));
    }

    /// @notice Get the number of mission completions by missionId.
    function getMissionCompletions(uint256 missionId) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), ".missions.", missionId, ".completions")));
    }

    /// @notice Get number of tasks in a mission.
    function getMissionTaskCount(uint256 missionId) external view returns (uint256 taskCount) {
        return this.getUint(keccak256(abi.encode(address(this), ".missions.", missionId, ".taskCount")));
    }

    /// @notice Get a task id associated with in a given mission by order.
    function getMissionTaskId(uint256 missionId, uint256 order) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), ".missions.", missionId, ".tasks.", order)));
    }

    /// @notice Get all task ids associated with a given mission.
    function getMissionTaskIds(uint256 missionId) external view returns (uint256[] memory) {
        uint256 count = this.getMissionTaskCount(missionId);
        uint256[] memory taskIds = new uint256[](count);
        for (uint256 i; i < count; ++i) {
            taskIds[i] = this.getMissionTaskId(missionId, i + 1);
        }

        return taskIds;
    }
}

interface IQuest {
    /// @notice DAO logic.
    function initialize(address dao) external payable;
    function setCooldown(uint40 cd) external payable;
    function getCooldown() external view returns (uint256);

    /// @notice Public logic.
    function getPublicCount() external view returns (uint256);
    function isPublicUser(string calldata username) external view returns (bool);
    function getNumOfStartsByMissionByPublic(address missions, uint256 missionId) external view returns (uint256);

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
    function getQuestId() external view returns (uint256);
    function getQuestIdByUserAndMission(address user, address missions, uint256 missionId)
        external
        view
        returns (uint256);
    function getQuest(uint256 questId) external view returns (address, address, uint256);
    function isQuestActive(address user, address missions, uint256 missionId) external view returns (bool);
    function getQuestProgress(address user, address missions, uint256 missionId) external view returns (uint256);
    function getNumOfCompletedTasksInMission(address user, address missions, uint256 missionId)
        external
        view
        returns (uint256);
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
    function getTaskResponse(uint256 questId, uint256 taskId) external view returns (uint256);
    function getTaskFeedback(uint256 questId, uint256 taskId) external view returns (string memory);
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

struct Stats {
    uint8 first;
    uint8 second;
    uint8 third;
    uint8 fourth;
    uint8 fifth;
    uint8 sixth;
}

/// @title Support SVG NFTs.
/// @notice SVG NFTs displaying impact generated from quests.
contract qSupportToken is SupportToken {
    /// -----------------------------------------------------------------------
    /// SVG Storage
    /// -----------------------------------------------------------------------

    uint8 public first;
    uint8 public second;
    uint8 public third;
    uint8 public fourth;
    uint8 public fifth;
    uint8 public sixth;
    uint8 public seventh;
    uint8[7] public counters;

    /// -----------------------------------------------------------------------
    /// Core Storage
    /// -----------------------------------------------------------------------

    address public owner;
    address public quest;
    address public mission;
    uint256 public missionId;
    address public curve;
    uint256 public totalSupply;

    /// -----------------------------------------------------------------------
    /// Constructor & Modifier
    /// -----------------------------------------------------------------------

    function init(
        string memory _name,
        string memory _symbol,
        address _owner,
        address _quest,
        address _mission,
        uint256 _missionId,
        address _curve
    ) external payable {
        _init(_name, _symbol);

        owner = _owner;
        quest = _quest;
        mission = _mission;
        missionId = _missionId;
        curve = _curve;
    }

    modifier onlyCurve() {
        if (msg.sender != curve) revert Unauthorized();
        _;
    }

    modifier onlyOwnerOrCurve(uint256 id) {
        if (msg.sender != ownerOf(id) && msg.sender != curve) revert Unauthorized();

        _;
    }

    /// -----------------------------------------------------------------------
    /// Mint / Burn Logic
    /// -----------------------------------------------------------------------

    function mint(address to) external payable {
        unchecked {
            ++totalSupply;
        }

        _safeMint(to, totalSupply);
    }

    function burn(uint256 id) external payable onlyOwnerOrCurve(id) {
        unchecked {
            --totalSupply;
        }

        _burn(id);
    }

    /// -----------------------------------------------------------------------
    /// Metadata Storage & Logic
    /// -----------------------------------------------------------------------

    function tokenURI(uint256 id) public view override returns (string memory) {
        return _buildURI(id);
    }

    // credit: z0r0z.eth (https://github.com/kalidao/kali-contracts/blob/60ba3992fb8d6be6c09eeb74e8ff3086a8fdac13/contracts/access/KaliAccessManager.sol)
    function _buildURI(uint256 id) private view returns (string memory) {
        return JSON._formattedMetadata("Support Token", "", generateSvg(id));
    }

    function generateSvg(uint256 id) public view returns (string memory) {
        return string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300" style="background:#FFFBF5">',
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "40"),
                    SVG._prop("font-size", "20"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(unicode"沒有人 #", SVG._uint2str(id))
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
            buildSvgData(),
            // buildProgress(),
            // buildProfile(IQuest(quest).getProfilePicture(owner)),
            "</svg>"
        );
    }

    function buildSvgData() public view returns (string memory) {
        // Okay to use dynamic taskId as intent is to showcase latest attendance.
        uint256 taskId = IMission(mission).getTaskId();

        // The number of hackath0ns hosted by g0v.
        uint256 hackathonCount = 60 + IMission(mission).getMissionTaskCount(missionId);

        return string.concat(
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "100"),
                    SVG._prop("font-size", "20"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(unicode"零時政府第 ", SVG._uint2str(hackathonCount), unicode" 次 - 新手試煉")
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "140"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(
                    unicode"第 ",
                    SVG._uint2str(hackathonCount),
                    unicode" 次參與人數： ",
                    SVG._uint2str(IMission(mission).getTotalTaskCompletionsByMission(missionId, taskId)),
                    unicode" 人"
                )
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "160"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(unicode"👍 幫 g0v 粉專按讚： ", SVG._uint2str(counters[0]), unicode" 人")
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "180"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(unicode"🔔 打開專案頻道通知： ", SVG._uint2str(counters[1]), unicode" 人")
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "200"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(
                    unicode"📝 截圖任一提案的專案共筆： ", SVG._uint2str(counters[2]), unicode" 人"
                )
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "220"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(
                    unicode"🧐 加入三個你有興趣的頻道： ", SVG._uint2str(counters[3]), unicode" 人"
                )
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "240"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(
                    unicode"👀 瀏覽並截圖最新社群九分鐘： ", SVG._uint2str(counters[4]), unicode" 人"
                )
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "260"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(
                    unicode"🏷️ 拿三張符合你身份的技能貼紙：",
                    SVG._uint2str(counters[5]),
                    unicode" 人"
                )
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "280"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(
                    unicode"🎙️ 在有興趣的專案共筆上介紹自己： ",
                    SVG._uint2str(counters[6]),
                    unicode" 人"
                )
            )
        );
    }

    function tally(uint256 taskId) external {
        uint256 response;
        uint256 questId = IQuest(quest).getQuestId();

        if (questId > 0) {
            for (uint256 i = 1; i <= questId; ++i) {
                response = IQuest(quest).getTaskResponse(i, taskId);
                for (uint256 j; j < 7; ++j) {
                    if ((response / (10 ** j)) % 10 == 1) ++counters[j];
                }
            }
        } else {
            revert Unauthorized();
        }
    }
}
