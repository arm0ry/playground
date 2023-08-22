// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {SafeMulticallable} from "solbase/utils/SafeMulticallable.sol";

/// @notice Directory for Quests
/// @author Modified from Kali (https://github.com/kalidao/kali-contracts/blob/main/contracts/access/KaliAccessManager.sol)
/// @author Storage pattern inspired by RocketPool (https://github.com/rocket-pool/rocketpool/blob/6a9dbfd85772900bb192aabeb0c9b8d9f6e019d1/contracts/contract/RocketStorage.sol)

contract Directory is SafeMulticallable {
    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error NotOperator();

    error LengthMismatch();

    /// -----------------------------------------------------------------------
    /// List Storage
    /// -----------------------------------------------------------------------

    address public dao;
    mapping(bytes32 => string) public stringStorage;
    mapping(bytes32 => address) public addressStorage;
    mapping(bytes32 => uint256) public uintStorage;
    mapping(bytes32 => bool) public booleanStorage;

    modifier onlyPlaygroundOperators() {
        if (msg.sender != dao || booleanStorage[keccak256(abi.encodePacked("quests", msg.sender))]) {
            revert NotOperator();
        }
        _;
    }

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    function initialize(address _dao) public payable {
        dao = _dao;
    }

    /// -----------------------------------------------------------------------
    /// General Storage - Setter Logic
    /// -----------------------------------------------------------------------

    /// @param newDao The address of new DAO
    function setDao(address newDao) external onlyPlaygroundOperators {
        dao = newDao;
    }

    /// @param newQuestsAddress The address of new DAO
    function setQuestsAddress(address newQuestsAddress) external onlyPlaygroundOperators {
        addressStorage[keccak256(abi.encodePacked("quests"))] = newQuestsAddress;
    }

    /// @param _key The key for the record
    function setAddress(bytes32 _key, address _value) external onlyPlaygroundOperators {
        addressStorage[_key] = _value;
    }

    /// @param _key The key for the record
    function setUint(bytes32 _key, uint256 _value) external onlyPlaygroundOperators {
        uintStorage[_key] = _value;
    }

    /// @param _key The key for the record
    function setString(bytes32 _key, string calldata _value) external onlyPlaygroundOperators {
        stringStorage[_key] = _value;
    }

    /// @param _key The key for the record
    function setBool(bytes32 _key, bool _value) external onlyPlaygroundOperators {
        booleanStorage[_key] = _value;
    }

    /// -----------------------------------------------------------------------
    /// General Sotrage - Delete Logic
    /// -----------------------------------------------------------------------

    function deleteQuestsAddress() external onlyPlaygroundOperators {
        delete addressStorage[keccak256(abi.encodePacked("quests"))];
    }

    /// @param _key The key for the record
    function deleteAddress(bytes32 _key) external onlyPlaygroundOperators {
        delete addressStorage[_key];
    }

    /// @param _key The key for the record
    function deleteUint(bytes32 _key) external onlyPlaygroundOperators {
        delete uintStorage[_key];
    }

    /// @param _key The key for the record
    function deleteString(bytes32 _key) external onlyPlaygroundOperators {
        delete stringStorage[_key];
    }

    /// @param _key The key for the record
    function deleteBool(bytes32 _key) external onlyPlaygroundOperators {
        delete booleanStorage[_key];
    }

    /// -----------------------------------------------------------------------
    /// Add Logic
    /// -----------------------------------------------------------------------

    /// @param _key The key for the record
    /// @param _amount An amount to add to the record's value
    function addUint(bytes32 _key, uint256 _amount) external onlyPlaygroundOperators {
        uintStorage[_key] = uintStorage[_key] + _amount;
    }

    /// @param _key The key for the record
    /// @param _amount An amount to subtract from the record's value
    function subUint(bytes32 _key, uint256 _amount) external onlyPlaygroundOperators {
        uintStorage[_key] = uintStorage[_key] - _amount;
    }

    /// -----------------------------------------------------------------------
    /// General Storage - Getter Logic
    /// -----------------------------------------------------------------------

    /// @dev Get the address of DAO.
    function getDao() external view returns (address) {
        return dao;
    }

    /// @dev Get the address of quests contract.
    function getQuestsAddress() external view returns (address) {
        return this.getAddress(keccak256(abi.encodePacked("quests")));
    }

    /// @param _key The key for the record.
    function getAddress(bytes32 _key) external view returns (address r) {
        return addressStorage[_key];
    }

    /// @param _key The key for the record.
    function getUint(bytes32 _key) external view returns (uint256 r) {
        return uintStorage[_key];
    }

    /// @param _key The key for the record.
    function getString(bytes32 _key) external view returns (string memory) {
        return stringStorage[_key];
    }

    /// @param _key The key for the record.
    function getBool(bytes32 _key) external view returns (bool r) {
        return booleanStorage[_key];
    }

    /// -----------------------------------------------------------------------
    /// AccessList Storage - Setter Logic
    /// -----------------------------------------------------------------------

    function setAccessList(uint256 id, address[] calldata accounts, bool[] calldata approvals)
        external
        onlyPlaygroundOperators
    {
        uint256 length = accounts.length;
        if (length != approvals.length) revert LengthMismatch();

        // Update old list.
        if (id != 0) {
            // Increment and store total number of accounts on a list.
            uint256 accountCount = this.getUint(keccak256(abi.encodePacked("access.", id, ".count")));

            for (uint256 i; i < accountCount;) {
                address _account = this.getAddress(keccak256(abi.encodePacked("access.", id, i)));
                if (_account == accounts[i]) {
                    // Store approval
                    this.setBool(keccak256(abi.encodePacked("access.", id, accounts[i])), approvals[i]);
                }

                unchecked {
                    ++i;
                }
            }
        } else {
            // Increment and store total number of access lists.
            uint256 listCount = this.getUint(keccak256(abi.encodePacked("accessListCount")));
            this.setUint(keccak256(abi.encodePacked("accessListCount")), ++listCount);

            uint256 accountCount;

            // Increment and store total number of accounts on list.
            for (uint256 i; i < length;) {
                // Set account
                this.setAddress(keccak256(abi.encodePacked("access.", listCount, accountCount)), accounts[i]);
                // Store approval
                this.setBool(keccak256(abi.encodePacked("access.", id, accounts[i])), approvals[i]);

                unchecked {
                    ++i;
                    ++accountCount;
                }
            }

            this.setUint(keccak256(abi.encodePacked("access.", listCount, ".count")), accountCount);
        }
    }

    /// -----------------------------------------------------------------------
    /// AccessList Storage - Delete Logic
    /// -----------------------------------------------------------------------

    function deleteAccessList(uint256 id) external onlyPlaygroundOperators {
        // Increment and store total number of accounts on a list.
        uint256 accountCount = this.getUint(keccak256(abi.encodePacked("access.", id, ".count")));

        for (uint256 i; i < accountCount;) {
            address _account = this.getAddress(keccak256(abi.encodePacked("access.", id, i)));

            // Delete account.
            this.deleteBool(keccak256(abi.encodePacked("access.", id, i)));

            // Delete approval.
            this.deleteBool(keccak256(abi.encodePacked("access.", id, _account)));

            unchecked {
                ++i;
            }
        }
    }

    /// -----------------------------------------------------------------------
    /// AccessList Storage - Getter Logic
    /// -----------------------------------------------------------------------

    function getAccessList(uint256 id) external view returns (address[] memory) {
        // Increment and store total number of accounts on a list.
        uint256 accountCount = this.getUint(keccak256(abi.encodePacked("access.", id, ".count")));
        address[] memory list = new address[](accountCount);

        for (uint256 i; i < accountCount;) {
            // Retrieve addresses approval.
            address account = this.getAddress(keccak256(abi.encodePacked("access.", id, i)));

            list[i] = account;

            unchecked {
                ++i;
            }
        }

        return list;
    }

    function getAccessListStatus(uint256 id, address account) external view returns (bool) {
        return this.getBool(keccak256(abi.encodePacked("access.", id, account)));
    }
}
