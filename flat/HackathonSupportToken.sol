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

interface IQuest {
    /// @notice DAO logic.
    function initialize(address dao) external payable;
    function setCooldown(uint40 cd) external payable;
    function getCooldown() external view returns (uint256);
    function setGasbot(address bot) external payable;
    function isGasBot(address bot) external view returns (bool);

    /// @notice Public logic.
    function getNumOfPublicUsers() external view returns (uint256);
    function isPublicUser(string calldata username) external view returns (bool);
    function getNumOfStartsByMissionByPublic(address missions, uint256 missionId) external view returns (uint256);

    /// @notice User logic.
    function start(address missions, uint256 missionId) external payable;
    function startBySig(address signer, address missions, uint256 missionId, uint8 v, bytes32 r, bytes32 s)
        external
        payable;
    function sponsoredStart(string calldata username, address missions, uint256 missionId) external payable;
    function respond(address missions, uint256 missionId, uint256 taskId, uint256 response, string calldata feedback)
        external
        payable;
    function respondBySig(
        address signer,
        uint256 taskKey,
        uint256 response,
        string calldata feedback,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable;
    function sponsoredRespond(
        string calldata username,
        address missions,
        uint256 missionId,
        uint256 taskId,
        uint256 response,
        string calldata feedback
    ) external payable;

    /// @notice Quest logic.
    function getQuestId() external view returns (uint256);
    function getQuestIdByUserAndMission(address user, address missions, uint256 missionId)
        external
        view
        returns (uint256);
    function getQuest(uint256 questId) external view returns (address, address, uint256);
    function isTaskAccomplished(address user, address missions, uint256 missionId, uint256 taskId)
        external
        view
        returns (bool);
    function isMissionAccomplished(address user, address missions, uint256 missionId) external view returns (bool);
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
    function getReviewResponse(address reviewer, uint256 questId) external view returns (uint256);
    function getReviewFeedback(address reviewer, uint256 questId) external view returns (string memory);

    /// @notice Get quest related stats.
    function getNumOfMissionsStarted() external view returns (uint256);
    function getNumOfMissionsCompleted() external view returns (uint256);
    function getNumOfTaskCompleted() external view returns (uint256);
    function getNumOfTimesQuestedByUser(address user) external view returns (uint256);
    function getNumOfMissionQuested(address missions, uint256 missionId) external view returns (uint256, uint256);
}

/// @title Impact NFTs
/// @notice SVG NFTs displaying impact results and metrics.
contract HackathonSupportToken is SupportToken {
    /// -----------------------------------------------------------------------
    /// Storage
    /// -----------------------------------------------------------------------

    address public immutable quest;
    address public immutable mission;
    uint256 public missionId;
    uint256 public taskId;
    address public immutable curve;
    uint256 public totalSupply;

    /// -----------------------------------------------------------------------
    /// Constructor & Modifier
    /// -----------------------------------------------------------------------

    constructor(string memory _name, string memory _symbol, address _quest, address _mission, address _curve) {
        _init(_name, _symbol);

        quest = _quest;
        mission = _mission;
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

    function mint(address to) external payable onlyCurve {
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
    /// SVG Inputs
    /// -----------------------------------------------------------------------

    function setSvgInputs(uint256 _missionId, uint256 _taskId) external payable {
        missionId = _missionId;
        taskId = _taskId;
    }

    /// -----------------------------------------------------------------------
    /// Metadata Storage & Logic
    /// -----------------------------------------------------------------------

    function tokenURI(uint256 id) public view override returns (string memory) {
        return _buildURI(id);
    }

    // credit: z0r0z.eth (https://github.com/kalidao/kali-contracts/blob/60ba3992fb8d6be6c09eeb74e8ff3086a8fdac13/contracts/access/KaliAccessManager.sol)
    function _buildURI(uint256 id) private view returns (string memory) {
        return JSON._formattedMetadata("g0v Hackathon Support Token", "", generateSvg(id));
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
            // buildTaskChart(),
            buildSvgData(),
            "</svg>"
        );
    }

    function buildSvgData() public view returns (string memory) {
        // The number of hackath0ns hosted by g0v.
        uint256 hackathonCount = 59 + IMission(mission).getMissionTaskCount(missionId);

        return string.concat(
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "100"),
                    SVG._prop("font-size", "20"),
                    SVG._prop("fill", "#00040a")
                ),
                IMission(mission).getMissionTitle(missionId)
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "230"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(
                    unicode"n0body 參與人數：",
                    SVG._uint2str(IQuest(quest).getNumOfStartsByMissionByPublic(mission, missionId)),
                    unicode" 人"
                )
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "250"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(
                    unicode"總參與人數：",
                    SVG._uint2str(IMission(mission).getMissionStarts(missionId)),
                    unicode" 人"
                )
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "270"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(
                    unicode"100% 參與人數：",
                    SVG._uint2str(IMission(mission).getMissionCompletions(missionId)),
                    unicode" 人"
                )
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "170"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(unicode"第 ", SVG._uint2str(hackathonCount), unicode" 次參與人數：")
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "140"),
                    SVG._prop("y", "170"),
                    SVG._prop("font-size", "40"),
                    SVG._prop("fill", "#00040a")
                ),
                SVG._uint2str(IMission(mission).getTotalTaskCompletionsByMission(missionId, taskId))
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "230"),
                    SVG._prop("y", "170"),
                    SVG._prop("font-size", "11"),
                    SVG._prop("fill", "#00040a")
                ),
                unicode" 人"
            )
        );
    }
}
