// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

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
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
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

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
      return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    /**
      * @dev Safely transfers `tokenId` token from `from` to `to`.
      *
      * Requirements:
      *
      * - `from` cannot be the zero address.
      * - `to` cannot be the zero address.
      * - `tokenId` token must exist and be owned by `from`.
      * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
      * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
      *
      * Emits a {Transfer} event.
      */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
}

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Metadata is IERC721 {

    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721.onERC721Received.selector`.
     */
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
// contract ERC721 is ERC165, IERC721, IERC721Metadata {
//     using Address for address;
//     using Strings for uint256;

//     // Token name
//     string private _name;

//     // Token symbol
//     string private _symbol;

//     // Mapping from token ID to owner address
//     mapping (uint256 => address) private _owners;

//     // Mapping owner address to token count
//     mapping (address => uint256) private _balances;

//     // Mapping from token ID to approved address
//     mapping (uint256 => address) private _tokenApprovals;

//     // Mapping from owner to operator approvals
//     mapping (address => mapping (address => bool)) private _operatorApprovals;

//     /**
//      * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
//      */
//     constructor (string memory name_, string memory symbol_) {
//         _name = name_;
//         _symbol = symbol_;
//     }

//     /**
//      * @dev See {IERC165-supportsInterface}.
//      */
//     function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
//         return interfaceId == type(IERC721).interfaceId
//             || interfaceId == type(IERC721Metadata).interfaceId
//             || super.supportsInterface(interfaceId);
//     }

//     /**
//      * @dev See {IERC721-balanceOf}.
//      */
//     function balanceOf(address owner) public view virtual override returns (uint256) {
//         require(owner != address(0), "ERC721: balance query for the zero address");
//         return _balances[owner];
//     }

//     /**
//      * @dev See {IERC721-ownerOf}.
//      */
//     function ownerOf(uint256 tokenId) public view virtual override returns (address) {
//         address owner = _owners[tokenId];
//         require(owner != address(0), "ERC721: owner query for nonexistent token");
//         return owner;
//     }

//     /**
//      * @dev See {IERC721Metadata-name}.
//      */
//     function name() public view virtual override returns (string memory) {
//         return _name;
//     }

//     /**
//      * @dev See {IERC721Metadata-symbol}.
//      */
//     function symbol() public view virtual override returns (string memory) {
//         return _symbol;
//     }

//     /**
//      * @dev See {IERC721Metadata-tokenURI}.
//      */
//     function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
//         require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

//         string memory baseURI = _baseURI();
//         return bytes(baseURI).length > 0
//             ? string(abi.encodePacked(baseURI, tokenId.toString()))
//             : '';
//     }

//     /**
//      * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
//      * token will be the concatenation of the `baseURI` and the `tokenId`. Empty 
//      * by default, can be overriden in child contracts.
//      */
//     function _baseURI() internal view virtual returns (string memory) {
//         return "";
//     }

//     /**
//      * @dev See {IERC721-approve}.
//      */
//     function approve(address to, uint256 tokenId) public virtual override {
//         address owner = ERC721.ownerOf(tokenId);
//         require(to != owner, "ERC721: approval to current owner");

//         require(msg.sender == owner || isApprovedForAll(owner, msg.sender),
//             "ERC721: approve caller is not owner nor approved for all"
//         );

//         _approve(to, tokenId);
//     }

//     /**
//      * @dev See {IERC721-getApproved}.
//      */
//     function getApproved(uint256 tokenId) public view virtual override returns (address) {
//         require(_exists(tokenId), "ERC721: approved query for nonexistent token");

//         return _tokenApprovals[tokenId];
//     }

//     /**
//      * @dev See {IERC721-setApprovalForAll}.
//      */
//     function setApprovalForAll(address operator, bool approved) public virtual override {
//         require(operator != msg.sender, "ERC721: approve to caller");

//         _operatorApprovals[msg.sender][operator] = approved;
//         emit ApprovalForAll(msg.sender, operator, approved);
//     }

//     /**
//      * @dev See {IERC721-isApprovedForAll}.
//      */
//     function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
//         return _operatorApprovals[owner][operator];
//     }

//     /**
//      * @dev See {IERC721-transferFrom}.
//      */
//     function transferFrom(address from, address to, uint256 tokenId) public virtual override {
//         //solhint-disable-next-line max-line-length
//         require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: transfer caller is not owner nor approved");

//         _transfer(from, to, tokenId);
//     }

//     /**
//      * @dev See {IERC721-safeTransferFrom}.
//      */
//     function safeTransferFrom(address from, address to, uint256 tokenId) public virtual override {
//         safeTransferFrom(from, to, tokenId, "");
//     }

//     /**
//      * @dev See {IERC721-safeTransferFrom}.
//      */
//     function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public virtual override {
//         require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: transfer caller is not owner nor approved");
//         _safeTransfer(from, to, tokenId, _data);
//     }

//     /**
//      * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
//      * are aware of the ERC721 protocol to prevent tokens from being forever locked.
//      *
//      * `_data` is additional data, it has no specified format and it is sent in call to `to`.
//      *
//      * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
//      * implement alternative mechanisms to perform token transfer, such as signature-based.
//      *
//      * Requirements:
//      *
//      * - `from` cannot be the zero address.
//      * - `to` cannot be the zero address.
//      * - `tokenId` token must exist and be owned by `from`.
//      * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
//      *
//      * Emits a {Transfer} event.
//      */
//     function _safeTransfer(address from, address to, uint256 tokenId, bytes memory _data) internal virtual {
//         _transfer(from, to, tokenId);
//         require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
//     }

//     /**
//      * @dev Returns whether `tokenId` exists.
//      *
//      * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
//      *
//      * Tokens start existing when they are minted (`_mint`),
//      * and stop existing when they are burned (`_burn`).
//      */
//     function _exists(uint256 tokenId) internal view virtual returns (bool) {
//         return _owners[tokenId] != address(0);
//     }

//     /**
//      * @dev Returns whether `spender` is allowed to manage `tokenId`.
//      *
//      * Requirements:
//      *
//      * - `tokenId` must exist.
//      */
//     function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
//         require(_exists(tokenId), "ERC721: operator query for nonexistent token");
//         address owner = ERC721.ownerOf(tokenId);
//         return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
//     }

//     /**
//      * @dev Safely mints `tokenId` and transfers it to `to`.
//      *
//      * Requirements:
//      *
//      * - `tokenId` must not exist.
//      * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
//      *
//      * Emits a {Transfer} event.
//      */
//     function _safeMint(address to, uint256 tokenId) internal virtual {
//         _safeMint(to, tokenId, "");
//     }

//     /**
//      * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
//      * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
//      */
//     function _safeMint(address to, uint256 tokenId, bytes memory _data) internal virtual {
//         _mint(to, tokenId);
//         require(_checkOnERC721Received(address(0), to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
//     }

//     /**
//      * @dev Mints `tokenId` and transfers it to `to`.
//      *
//      * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
//      *
//      * Requirements:
//      *
//      * - `tokenId` must not exist.
//      * - `to` cannot be the zero address.
//      *
//      * Emits a {Transfer} event.
//      */
//     function _mint(address to, uint256 tokenId) internal virtual {
//         require(to != address(0), "ERC721: mint to the zero address");
//         require(!_exists(tokenId), "ERC721: token already minted");

//         // _beforeTokenTransfer(address(0), to, tokenId);

//         _balances[to] += 1;
//         _owners[tokenId] = to;

//         emit Transfer(address(0), to, tokenId);
//     }

//     /**
//      * @dev Destroys `tokenId`.
//      * The approval is cleared when the token is burned.
//      *
//      * Requirements:
//      *
//      * - `tokenId` must exist.
//      *
//      * Emits a {Transfer} event.
//      */
//     function _burn(uint256 tokenId) internal virtual {
//         address owner = ERC721.ownerOf(tokenId);

//         // _beforeTokenTransfer(owner, address(0), tokenId);

//         // Clear approvals
//         _approve(address(0), tokenId);

//         _balances[owner] -= 1;
//         delete _owners[tokenId];

//         emit Transfer(owner, address(0), tokenId);
//     }

//     /**
//      * @dev Transfers `tokenId` from `from` to `to`.
//      *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
//      *
//      * Requirements:
//      *
//      * - `to` cannot be the zero address.
//      * - `tokenId` token must be owned by `from`.
//      *
//      * Emits a {Transfer} event.
//      */
//     function _transfer(address from, address to, uint256 tokenId) internal virtual {
//         require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer of token that is not own");
//         require(to != address(0), "ERC721: transfer to the zero address");

//         // _beforeTokenTransfer(from, to, tokenId);

//         // Clear approvals from the previous owner
//         _approve(address(0), tokenId);

//         _balances[from] -= 1;
//         _balances[to] += 1;
//         _owners[tokenId] = to;

//         emit Transfer(from, to, tokenId);
//     }

//     /**
//      * @dev Approve `to` to operate on `tokenId`
//      *
//      * Emits a {Approval} event.
//      */
//     function _approve(address to, uint256 tokenId) internal virtual {
//         _tokenApprovals[tokenId] = to;
//         emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
//     }

//     /**
//      * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
//      * The call is not executed if the target address is not a contract.
//      *
//      * @param from address representing the previous owner of the given token ID
//      * @param to target address that will receive the tokens
//      * @param tokenId uint256 ID of the token to be transferred
//      * @param _data bytes optional data to send along with the call
//      * @return bool whether the call correctly returned the expected magic value
//      */
//     function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory _data)
//         private returns (bool)
//     {
//         if (to.isContract()) {
//             try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, _data) returns (bytes4 retval) {
//                 return retval == IERC721Receiver(to).onERC721Received.selector;
//             } catch (bytes memory reason) {
//                 if (reason.length == 0) {
//                     revert("ERC721: transfer to non ERC721Receiver implementer");
//                 } else {
//                     // solhint-disable-next-line no-inline-assembly
//                     assembly {
//                         revert(add(32, reason), mload(reason))
//                     }
//                 }
//             }
//         } else {
//             return true;
//         }
//     }

//     // modified from ERC721 template:
//     // removed BeforeTokenTransfer
// }

/// @title Base64
/// @author Brecht Devos - <brecht@loopring.org>
/// @notice Provides a function for encoding some bytes in base64
library Base64 {
    string internal constant TABLE = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

    function encode(bytes memory data) internal pure returns (string memory) {
        if (data.length == 0) return '';
        
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
            for {} lt(dataPtr, endPtr) {}
            {
               dataPtr := add(dataPtr, 3)
               
               // read 3 bytes
               let input := mload(dataPtr)
               
               // write 4 characters
               mstore(resultPtr, shl(248, mload(add(tablePtr, and(shr(18, input), 0x3F)))))
               resultPtr := add(resultPtr, 1)
               mstore(resultPtr, shl(248, mload(add(tablePtr, and(shr(12, input), 0x3F)))))
               resultPtr := add(resultPtr, 1)
               mstore(resultPtr, shl(248, mload(add(tablePtr, and(shr( 6, input), 0x3F)))))
               resultPtr := add(resultPtr, 1)
               mstore(resultPtr, shl(248, mload(add(tablePtr, and(        input,  0x3F)))))
               resultPtr := add(resultPtr, 1)
            }
            
            // padding with '='
            switch mod(mload(data), 3)
            case 1 { mstore(sub(resultPtr, 2), shl(240, 0x3d3d)) }
            case 2 { mstore(sub(resultPtr, 1), shl(248, 0x3d)) }
        }
        
        return result;
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
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
contract Arm0ryTravellers is ERC721 {

    // todo, change to UF specific owner.
    address payable public arm0ry; // Untitled Frontier collection address

    uint256 public defaultCertificatesSupply;
    // uint256 public deluxeCertificatesSupply;

    struct Certificate {
        uint256 nr;
        address sponsored;
    }

    // tokenId => Certificate
    mapping(uint256 => Certificate) public certificates;

    // 16 palettes
    string[4][16] palette = [
        ["#eca3f5", "#fdbaf9", "#b0efeb", "#edffa9"],
        ["#75cfb8", "#bbdfc8", "#f0e5d8", "#ffc478"],
        ["#ffab73", "#ffd384", "#fff9b0", "#ffaec0"],
        ["#94b4a4", "#d2f5e3", "#e5c5b5", "#f4d9c6"],
        ["#f4f9f9", "#ccf2f4", "#a4ebf3", "#aaaaaa"],
        ["#caf7e3", "#edffec", "#f6dfeb", "#e4bad4"],
        ["#f4f9f9", "#f1d1d0", "#fbaccc", "#f875aa"],
        ["#fdffbc", "#ffeebb", "#ffdcb8", "#ffc1b6"],
        ["#f0e4d7", "#f5c0c0", "#ff7171", "#9fd8df"],
        ["#e4fbff", "#b8b5ff", "#7868e6", "#edeef7"],
        ["#ffcb91", "#ffefa1", "#94ebcd", "#6ddccf"],
        ["#bedcfa", "#98acf8", "#b088f9", "#da9ff9"],
        ["#bce6eb", "#fdcfdf", "#fbbedf", "#fca3cc"],
        ["#ff75a0", "#fce38a", "#eaffd0", "#95e1d3"],
        ["#fbe0c4", "#8ab6d6", "#2978b5", "#0061a8"],
        ["#dddddd", "#f9f3f3", "#f7d9d9", "#f25287"]
    ];

    constructor (address payable arm0ry_) ERC721("Arm0ry Travellers", "ART") {
        arm0ry = arm0ry_;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        string memory name = string(abi.encodePacked('Arm0ry Traveller #', Strings.toString(certificates[tokenId].nr)));
        string memory description = "Arm0ry Travellers";
        string memory image = generateBase64Image(tokenId);

        return string(
            abi.encodePacked(
                'data:application/json;base64,',
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                            '{"name":"', 
                            name,
                            '", "description":"', 
                            description,
                            '", "image": "', 
                            'data:image/svg+xml;base64,', 
                            image,
                            '"}'
                        )
                    )
                )
            )
        );
    }

    function generateBase64Image(uint256 tokenId) public view returns (string memory) {
        return Base64.encode(bytes(generateImage(tokenId)));
    }

    function generateImage(uint256 tokenId) public view returns (string memory) {
        bytes memory hash = abi.encodePacked(bytes32(tokenId));
        uint256 pIndex = toUint8(hash,0)/16; // 16 palettes
        // uint256 rIndex = toUint8(hash,1)/4; // 64 reasons

        /* this is broken into functions to avoid stack too deep errors */
        string memory paletteSection = generatePaletteSection(tokenId, pIndex);

        return string(
            abi.encodePacked(
                '<svg class="svgBody" width="300" height="300" viewBox="0 0 300 300" xmlns="http://www.w3.org/2000/svg">',
                paletteSection,
                '<text x="15" y="125" class="score" stroke="black" stroke-width="2">65</text>',
                '<text x="110" y="125" class="tiny" stroke="black">% Progress</text>',
                '<text x="175" y="125" class="score" stroke="black" stroke-width="2">80</text>',
                '<text x="270" y="125" class="tiny" stroke="black">xp</text>',
                '<text x="15" y="170" class="medium" stroke="black">QUEST: </text>',
                '<rect x="15" y="175" width="205" height="40" style="fill:white;opacity:0.5"/>',
                '<text x="20" y="190" class="medium" stroke="black">BASIC</text>',
                '<text x="15" y="245" class="small" stroke="black">BUDDIES:</text>',
                '<text x="15" y="260" style="font-size:8px" stroke="black">0x4744cda32bE7b3e75b9334001da9ED21789d4c0d</text>',
                '<text x="15" y="275" style="font-size:8px" stroke="black">0x4744cda32bE7b3e75b9334001da9ED21789d4c0d</text>',
                '<style>.svgBody {font-family: "Courier New" } .tiny {font-size:6px; } .small {font-size: 12px;}.medium {font-size: 18px;}.score {font-size: 70px;}</style>',
                '</svg>'
            )
        );
    }

    function generatePaletteSection(uint256 tokenId, uint256 pIndex) internal view returns (string memory) {
        return string(abi.encodePacked(
                '<rect width="300" height="300" rx="10" style="fill:',palette[pIndex][0],'" />',
                '<rect y="205" width="300" height="80" rx="10" style="fill:',palette[pIndex][3],'" />',
                '<rect y="60" width="300" height="90" style="fill:',palette[pIndex][1],'"/>',
                '<rect y="150" width="300" height="75" style="fill:',palette[pIndex][2],'" />',
                '<text x="15" y="25" class="medium">Traveller ID#</text>',
                '<text x="17" y="50" class="small" opacity="0.5">',substring(Strings.toString(tokenId),0,24),'</text>',
                '<g filter="url(#a)">',
                '<path stroke="#FFBE0B" stroke-linecap="round" stroke-width="2.1" d="M207 48.3c12.2-8.5 65-24.8 87.5-21.6" fill="none"/></g><path fill="#000" d="M220.2 38h-.8l-2.2-.4-1 4.6-2.9-.7 1.5-6.4 1.6-8.3c1.9-.4 3.9-.6 6-.8l1.9 8.5 1.5 7.4-3 .5-1.4-7.3-1.2-6.1c-.5 0-1 0-1.5.2l-1 6 3.1.1-.4 2.6h-.2Zm8-5.6v-2.2l2.6-.3.5 1.9 1.8-2.1h1.5l.6 2.9-2 .4-1.8.4-.2 8.5-2.8.2-.2-9.7Zm8.7-2.2 2.6-.3.4 1.9 2.2-2h2.4c.3 0 .6.3 1 .6.4.4.7.9.7 1.3l2.1-1.8h3l.6.3.6.6.2.5-.4 10.7-2.8.2v-9.4a4.8 4.8 0 0 0-2.2.2l-1 .3-.3 8.7-2.7.2v-9.4a5 5 0 0 0-2.3.2l-.9.3-.3 8.6-2.7.2-.2-11.9Zm28.6 3.5a19.1 19.1 0 0 1-.3 4.3 15.4 15.4 0 0 1-.8 3.6c-.1.3-.3.4-.5.5l-.8.2h-2.3c-2 0-3.2-.2-3.6-.6-.4-.5-.8-2.1-1-5a25.7 25.7 0 0 1 0-5.6l.4-.5c.1-.2.5-.4 1-.5 2.3-.5 4.8-.8 7.4-.8h.4l.3 3-.6-.1h-.5a23.9 23.9 0 0 0-5.3.5 25.1 25.1 0 0 0 .3 7h2.4c.2-1.2.4-2.8.5-4.9v-.7l3-.4Zm3.7-1.3v-2.2l2.6-.3.5 1.9 1.9-2.1h1.4l.6 2.9-1.9.4-2 .4V42l-2.9.2-.2-9.7Zm8.5-2.5 3-.6.2 10 .8.1h.9l1.5-.6V30l2.8-.3.2 13.9c0 .4-.3.8-.8 1.1l-3 2-1.8 1.2-1.6.9-1.5-2.7 6-3-.1-3.1-1.9 2h-3.1c-.3 0-.5-.1-.8-.4-.4-.3-.6-.6-.6-1l-.2-10.7Z"/>',
                '<defs>',
                '<filter id="a" width="91.743" height="26.199" x="204.898" y="24.182" color-interpolation-filters="sRGB" filterUnits="userSpaceOnUse">',
                '<feBlend in="SourceGraphic" in2="BackgroundImageFix" result="shape"/>',
                '</filter>',
                '</defs>'
            )
        );
    }

    function mintCertificate() public payable returns (uint256 tokenId) {
        Certificate memory certificate;
        
        defaultCertificatesSupply += 1;
        certificate.nr = defaultCertificatesSupply;

        tokenId = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender)));
        certificates[tokenId] = certificate;

        super._mint(msg.sender, tokenId);
    }

    function withdrawETH() public {
        require(msg.sender == arm0ry, "NOT_arm0ry");
        arm0ry.transfer(address(this).balance);
    } 

    // GENERIC helpers

    // helper function for generation
    // from: https://github.com/GNSPS/solidity-bytes-utils/blob/master/contracts/BytesLib.sol 
    function toUint8(bytes memory _bytes, uint256 _start) internal pure returns (uint8) {
        require(_start + 1 >= _start, "toUint8_overflow");
        require(_bytes.length >= _start + 1 , "toUint8_outOfBounds");
        uint8 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x1), _start))
        }
        return tempUint;
    }
   
    // from: https://ethereum.stackexchange.com/questions/31457/substring-in-solidity/31470
    function substring(string memory str, uint startIndex, uint endIndex) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex-startIndex);
        for(uint i = startIndex; i < endIndex; i++) {
            result[i-startIndex] = strBytes[i];
        }
        return string(result);
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
// contract Arm0ryTravellers is ERC721("Arm0ry Travellers", "ArT") {
//     /// -----------------------------------------------------------------------
//     /// Soul Logic
//     /// -----------------------------------------------------------------------

//     function bindSoul() public {
//         _mint(msg.sender, uint256(uint160(msg.sender)));
//     }

//     function unbindSoul(uint256 id) public {
//         require(ownerOf[id] == msg.sender, "NOT_SOUL_BINDER");

//         _burn(id);
//     }

//     /// -----------------------------------------------------------------------
//     /// Metadata Logic
//     /// -----------------------------------------------------------------------

//     function tokenURI(uint256 id) public view override returns (string memory) {
//         return _buildTokenURI(id);
//     }

//     function _buildTokenURI(uint256 id) internal view returns (string memory) {
//         address soul = address(uint160(id));

//         string memory metaSVG = string(
//             abi.encodePacked(
//                 '<text class="h1" dominant-baseline="middle" text-anchor="middle" fill="white" x="50%" y="10%">',
//                 "Arm0ry Playground Season 1",
//                 "</text>"
//                 '<text dominant-baseline="middle" text-anchor="middle" fill="white" x="50%" y="20%">',
//                 "0x",
//                 addressToString(soul),
//                 "</text>",
//                 '<text dominant-baseline="middle" text-anchor="middle" fill="white" x="50%" y="30%">',
//                 "Wallet Balance: ",
//                 weiToEtherString(soul.balance),
//                 "</text>",
//                 '<text dominant-baseline="middle" text-anchor="middle" fill="white" x="50%" y="90%">',
//                 "I commit to completing arm0ry grants program",
//                 "</text>"
//                 // TASK NAME ---- TASK STATUS [ ] PASS [ ] FAIL
//                 // NAME - IArm0ryTask Task.name via taskId
//                 // STATUS - IArm0ryMission taskReviews(address traveller, uint256 taskId, address reviewer)     
//                 // mapping(address => mapping(uint256 => mapping(address => uint8))) taskReviews; 

//             )
//         );
//         bytes memory svg = abi.encodePacked(
//             '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400" preserveAspectRatio="xMidYMid meet" style="font:14px serif"><rect width="400" height="400" fill="black" />',
//             '<style type="text/css"><![CDATA[text { font-family: monospace; font-size: 12px;} .h1 {font-size: 20px; font-weight: 600;}]]></style>',
//             metaSVG,
//             "</svg>"
//         );
//         bytes memory image = abi.encodePacked(
//             "data:image/svg+xml;base64,",
//             Base64._encode(bytes(svg))
//         );
//         return string(
//             abi.encodePacked(
//                 "data:application/json;base64,",
//                 Base64._encode(
//                     bytes(
//                         abi.encodePacked(
//                             '{"name":"',
//                             name,
//                             '", "image":"',
//                             image,
//                             '", "description": "I, msg.sender, hereby relinquish my soul (my incorporeal essence) to the holder of this deed, to be collected after my death. I retain full possession of my soul as long as I am alive, no matter however so slightly. This deed does not affect any copyright, immaterial, or other earthly rights, recognized by human courts, before or after my death. I take no responsibility about whether my soul does or does not exist. I am not liable in the case there is nothing to collect. This deed shall be vanquished upon calling the unbindSoul() function."}'
//                         )
//                     )
//                 )
//             )
//         );
//     }

//     function addressToString(address x) internal pure returns (string memory) {
//         bytes memory s = new bytes(40);
//         for (uint i = 0; i < 20; i++) {
//             bytes1 b = bytes1(uint8(uint(uint160(x)) / (2**(8*(19 - i)))));
//             bytes1 hi = bytes1(uint8(b) / 16);
//             bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
//             s[2*i] = char(hi);
//             s[2*i+1] = char(lo);            
//         }
//         return string(s);
//     }

//     /// @notice  Converts wei to ether string with 2 decimal places
//     function weiToEtherString(uint256 amountInWei)
//         public
//         pure
//         returns (string memory)
//     {
//         uint256 amountInFinney = amountInWei / 1e15; // 1 finney == 1e15
//         return
//             string(
//                 abi.encodePacked(
//                     Strings.toString(amountInFinney / 1000), //left of decimal
//                     ".",
//                     Strings.toString((amountInFinney % 1000) / 100), //first decimal
//                     Strings.toString(((amountInFinney % 1000) % 100) / 10) // first decimal
//                 )
//             );
//     }

//     function char(bytes1 b) internal pure returns (bytes1 c) {
//         if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
//         else return bytes1(uint8(b) + 0x57);
//     }
// }

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

interface IArm0ryMission {
    function missions(uint8 missionId) external view returns (Mission calldata);

    function tasks(uint8 taskId) external view returns (Task calldata);

    function isTaskInMission(uint8 missionId, uint8 taskId) external returns (bool);

    function getTaskXp(uint16 taskId) external view returns (uint8);

    function getTaskExpiration(uint16 taskId) external view returns (uint40);

    function getTaskCreator(uint16 taskId) external view returns (address);
}

/// @title Arm0ry tasks
/// @notice A list of tasks. 
/// @author audsssy.eth

struct Mission {
    uint40 expiration;
    uint8[] taskIds;
    string details;
}

struct Task {
    uint8 xp;
    uint40 expiration;
    address creator;
    string details;
}

contract Arm0ryMission {

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event MissionSet (
        uint8 missionId,
        uint8[] indexed taskIds,
        string details
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

    event PermissionUpdated (
        address indexed caller,
        address indexed admin,
        address indexed manager
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

    uint8 public taskId;

    mapping(uint8 => Task) public tasks;

    uint8 public missionId;

    mapping(uint8 => Mission) public missions;

    // Status indicating if a Task is part of a Mission
    mapping(uint8 => mapping(uint8 => bool)) public isTaskInMission;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(address _admin) {
        admin = _admin;
    }

    /// -----------------------------------------------------------------------
    /// Mission / Task Logic
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

    function updateTasks(uint8[] calldata ids, bytes[] calldata taskData) external payable  {
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

    function setMission(uint8 _missionId, uint8[] calldata _taskIds, string calldata _details) external payable {
        if (msg.sender != admin && msg.sender != manager) revert NotAuthorized();

        if (_missionId == 0) {
            missions[_missionId] = Mission({
                expiration: 2524626000, // 01/01/2050
                taskIds: _taskIds,
                details: _details
            });
        } else {
            uint40 expiration;
            for (uint256 i = 0; i < _taskIds.length;) {
                // Calculate expiration
                uint40 _expiration = this.getTaskExpiration(_taskIds[i]);
                expiration = (_expiration > expiration) ? _expiration : expiration;

                // Update task status
                isTaskInMission[_missionId][_taskIds[i]] = true;

                // cannot possibly overflow
                unchecked{
                    ++i;
                }
            }

            missions[_missionId] = Mission({
                expiration: expiration,
                taskIds: _taskIds,
                details: _details
            });
        }

        emit MissionSet(_missionId, _taskIds, _details);
    }

    function updatePermission(address _admin, address _manager) external payable { 
        if (admin != msg.sender) revert NotAuthorized();
        
        if (_admin != admin) {
            admin = _admin;
        }

        if (_manager != address(0)) {
            manager = _manager;
        }

        emit PermissionUpdated(msg.sender, admin, manager);
    }

    /// -----------------------------------------------------------------------
    /// Getter Functions
    /// -----------------------------------------------------------------------

    function getTaskXp(uint8 _taskId) external view returns (uint8) {
        return tasks[_taskId].xp;
    }

    function getTaskExpiration(uint8 _taskId) external view returns (uint40) {
        return tasks[_taskId].expiration;
    }

    function getTaskCreator(uint8 _taskId) external view returns (address) {
        return tasks[_taskId].creator;
    }

    function getMissionTasks(uint8 _missionId) external view returns (uint8[] memory) {
        return missions[_missionId].taskIds;
    }
    
}

/// @title Arm0ry Quests
/// @notice .
/// @author audsssy.eth

enum Status {
    ACTIVE,
    INACTIVE
}

struct Quest {
    Status status;
    uint8 progress;
    uint8 xp;
    address[2] buddies;
    uint8 missionId;
    uint40 expiration;
    uint256 claimed;
}

struct Deliverable {
    uint16 taskId;
    string deliverable;
    bool[] results; 
}

contract Arm0ryQuests {
    using SafeTransferLib for address;

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event QuestCancelled(
        address indexed traveller,
        uint8 missionId
    );

    /// -----------------------------------------------------------------------
    /// Custom Errors
    /// -----------------------------------------------------------------------

    error NotAuthorized();

    error InvalidTraveller();

    error InvalidClaim();

    error InactiveQuest();

    error ActiveQuest();
    
    error InvalidBuddy();

    error InvalidReview();

    error TaskNotReadyForReview();
    
    error TaskNotActive();

    error IncompleteTask();

    error AlreadyClaimed();

    error LengthMismatch();

    error NeedMoreCoins();
    
    /// -----------------------------------------------------------------------
    /// Quest Storage
    /// -----------------------------------------------------------------------

    uint256 public immutable THRESHOLD = 10 * 1e18;

    uint256 public immutable CREATOR_REWARD = 1e17;

    address public arm0ry;

    address public immutable WETH;
        
    IArm0ryTravellers public travellers;

    IArm0ryMission public mission;

    // Traveller's history of quests
    mapping(address => mapping(uint256 => Quest)) public quests;

    // Counter indicating Quest count per Traveller
    mapping(address => uint256) public questNonce;

    // Status indicating if an address belongs to a Buddy of an active Quest
    mapping(address => mapping(address => bool)) public isQuestBuddy;

    // Deliverable per Task of an active Quest
    mapping(address => mapping(uint256 => string)) public taskDeliverables;

    // Status indicating if a Task of an active Quest is ready for review
    mapping(address => mapping(uint256 => bool)) public taskReadyForReview;

    // Review results of a Task of an active Quest
    // 0 - not yet reviewed
    // 1 - reviewed with a check
    // 2 - reviewed with an x
    mapping(address => mapping(uint256 => mapping(address => uint8))) taskReviews; 

    // Status indicating if a Task of an active Quest is completed
    mapping(address => mapping(uint256 => bool)) isTaskCompleted;

    // Rewards per creators
    mapping(address => uint256) taskCreatorRewards;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(
        IArm0ryTravellers _travellers, 
        IArm0ryMission _mission, 
        address _weth
    ) {
        travellers = _travellers;
        mission = _mission;
        WETH = _weth;
    }

    /// -----------------------------------------------------------------------
    /// Quest Logic
    /// -----------------------------------------------------------------------

    function startQuest(
        address[2] calldata buddies, 
        uint8 missionId
    ) external payable {
        if (travellers.balanceOf(msg.sender) == 0) revert InvalidTraveller();
        uint256 id = uint256(uint160(msg.sender));
        uint8[] memory _taskIds = mission.missions(missionId).taskIds;
        uint40 _expiration = mission.missions(missionId).expiration;

        // Lock Traveller's NFT 
        if (missionId == 0) {
            travellers.transferFrom(msg.sender, address(this), id);
        } else {
            if (IERC20(arm0ry).balanceOf(msg.sender) < THRESHOLD || msg.value >= 0.05 ether) revert NeedMoreCoins();
            IERC20(arm0ry).transferFrom(msg.sender, address(this), THRESHOLD);
            travellers.transferFrom(msg.sender, address(this), id);
        }

        // Update tasks review status
        for (uint256 i = 0; i < _taskIds.length;){
            taskReadyForReview[msg.sender][_taskIds[i]] = false;

            unchecked{ 
                ++i;
            }
        }

        // Update buddies
        for (uint256 i = 0; i < buddies.length;){
            isQuestBuddy[msg.sender][buddies[i]] = true;
            
            unchecked{ 
                ++i;
            }
        }
        
        // Create a Quest
        quests[msg.sender][questNonce[msg.sender]] = Quest({
            status: Status.ACTIVE,
            progress: 0,
            xp: 0,
            buddies: buddies,
            missionId: missionId,
            expiration: _expiration,
            claimed: 0
        });

        // Cannot possibly overflow.
        unchecked{
            ++questNonce[msg.sender];
        }
    }

    function continueQuest(uint8 _missionId) external payable {
        if (travellers.balanceOf(msg.sender) == 0) revert InvalidTraveller();
        if (quests[msg.sender][_missionId].status == Status.ACTIVE) revert ActiveQuest();

        // Mark Quest as active
        quests[msg.sender][_missionId].status = Status.ACTIVE;
    }

    function leaveQuest(
        uint8 _missionId
    ) external payable {
        uint256 id = uint256(uint160(msg.sender));
        if (travellers.ownerOf(id) != address(this)) revert InvalidTraveller();
        if (quests[msg.sender][_missionId].status == Status.INACTIVE) revert InactiveQuest();

        // Mark Quest as inactive
        quests[msg.sender][_missionId].status = Status.INACTIVE;

        // Airdrop any unclaimed rewards
        uint8 reward = quests[msg.sender][_missionId].xp;
        if (reward != 0) {
            IERC20(arm0ry).transfer(msg.sender, reward * 1e18);
            quests[msg.sender][_missionId].claimed += reward;
        }

        // Return locked NFT & arm0ry token when cancelling a Quest
        if (questNonce[msg.sender] != 0) {
            IERC20(arm0ry).transfer(msg.sender, THRESHOLD);
        }
        travellers.transferFrom(address(this), msg.sender, id);

        emit QuestCancelled(msg.sender, _missionId);
    }

    function updateBuddies(
        uint8 _missionId,
        address[2] calldata newBuddies
    ) external payable {
        uint256 id = uint256(uint160(msg.sender));
        if (travellers.ownerOf(id) != address(this)) revert InvalidTraveller();

        // Remove previous buddies
        for (uint256 i = 0; i < 2;){
            address buddy = quests[msg.sender][_missionId].buddies[i];
            isQuestBuddy[msg.sender][buddy] = false;
            
            unchecked{ 
                ++i;
            }
        }

        // Add new buddies
        for (uint256 i = 0; i < 2;){
            isQuestBuddy[msg.sender][newBuddies[i]] = true;
            
            unchecked{ 
                ++i;
            }
        }

        quests[msg.sender][_missionId].buddies = newBuddies;
    }

    function submitTasks(uint8 _missionId, uint8 _taskId, string calldata deliverable) external payable {
        uint256 id = uint256(uint160(msg.sender));
        if (travellers.ownerOf(id) != address(this)) revert InvalidTraveller();
        if (!mission.isTaskInMission(_missionId, _taskId)) revert TaskNotActive();
        if (!isTaskCompleted[msg.sender][_taskId]) revert IncompleteTask();
        if (quests[msg.sender][_missionId].status == Status.INACTIVE) revert InactiveQuest();

        taskDeliverables[msg.sender][_taskId] = deliverable;
        taskReadyForReview[msg.sender][_taskId] = true;
    }

    /// -----------------------------------------------------------------------
    /// Reward Functions
    /// -----------------------------------------------------------------------

    function claimCreatorReward() external payable {
        if (taskCreatorRewards[msg.sender] == 0) revert InvalidClaim();

        uint256 reward = taskCreatorRewards[msg.sender];    

        taskCreatorRewards[msg.sender] = 0;    

        IERC20(arm0ry).transfer(msg.sender, reward);
    }

    /// -----------------------------------------------------------------------
    /// Review Functions
    /// -----------------------------------------------------------------------

    function reviewTasks(address traveller, uint16 taskId, uint8 review) external payable {
        if (!isQuestBuddy[traveller][msg.sender]) revert InvalidBuddy();
        if (!taskReadyForReview[msg.sender][taskId]) revert TaskNotReadyForReview();
        if (review == 0) revert InvalidReview();

        taskReviews[traveller][taskId][msg.sender] = review;

        Quest memory quest = quests[traveller][questNonce[traveller]];
        address[2] memory buddies = quest.buddies;
        bool check;

        if (review == 1) {
            for (uint256 i = 0; i < 2;) {
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

            updateQuestProgress(traveller);

            address creator = mission.getTaskCreator(taskId);
            taskCreatorRewards[creator] += CREATOR_REWARD;
        }
    }

    /// -----------------------------------------------------------------------
    /// Internal Functions
    /// ----------------------------------------------------------------------- 

    function updateQuestProgress(address traveller) internal {
        uint8[] memory _taskIds = mission.missions(uint8(questNonce[traveller])).taskIds;

        uint8 completedTasksCount;
        uint8 incompleteTasksCount;
        uint8 progress;
        uint8 xpEarned;

        for (uint256 i = 0; i < _taskIds.length; ) {
            uint8 xp = mission.getTaskXp(_taskIds[i]);

            if (!isTaskCompleted[traveller][_taskIds[i]]) {
                // cannot possibly overflow 
                unchecked {
                    ++incompleteTasksCount;
                }
            } else {
                // cannot possibly overflow 
                unchecked {
                    ++completedTasksCount;
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
            progress = completedTasksCount / (completedTasksCount + incompleteTasksCount) * 100;
        }

        // Update progress and xp
        quests[msg.sender][questNonce[msg.sender]].progress = progress;
        quests[msg.sender][questNonce[msg.sender]].xp = xpEarned;

        uint256 claimed = quests[msg.sender][questNonce[msg.sender]].claimed;
        uint256 reward = (xpEarned - claimed) * 1e18;
        // Return locked NFT & arm0ry token when Quest is completed
        if (progress == 100) {
            
            if (questNonce[traveller] != 0) {
                IERC20(arm0ry).transfer(traveller, THRESHOLD);
            }

            IERC20(arm0ry).transfer(traveller, reward);
            travellers.transferFrom(address(this), traveller, uint256(uint160(traveller)));
        }
    }
}