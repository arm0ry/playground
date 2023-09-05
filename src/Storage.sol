// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {SafeMulticallable} from "solbase/utils/SafeMulticallable.sol";

/// @notice Directory for Quests
/// @author Modified from Kali (https://github.com/kalidao/kali-contracts/blob/main/contracts/access/KaliAccessManager.sol)
/// @author Storage pattern inspired by RocketPool (https://github.com/rocket-pool/rocketpool/blob/6a9dbfd85772900bb192aabeb0c9b8d9f6e019d1/contracts/contract/RocketStorage.sol)

contract Storage is SafeMulticallable {
    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error NotOperator();

    error LengthMismatch();

    /// -----------------------------------------------------------------------
    /// Immutable Storage
    /// -----------------------------------------------------------------------

    bytes32 immutable DAO_ADDRESS_KEY = keccak256(abi.encodePacked("dao"));

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

    /// -----------------------------------------------------------------------
    /// Modifier
    /// -----------------------------------------------------------------------

    modifier onlyOperator() {
        if (msg.sender != this.getDao() && msg.sender != address(this)) {
            revert NotOperator();
        }
        _;
    }
    /// -----------------------------------------------------------------------
    /// General Storage - Setter Logic
    /// -----------------------------------------------------------------------

    function setDao(address dao) public {
        address _dao = addressStorage[DAO_ADDRESS_KEY];
        if (_dao != address(0) && _dao != msg.sender) revert NotOperator();
        addressStorage[DAO_ADDRESS_KEY] = dao;
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

    /// -----------------------------------------------------------------------
    /// General Sotrage - Delete Logic
    /// -----------------------------------------------------------------------

    /// @param _key The key for the record.
    function deleteAddress(bytes32 _key) external onlyOperator {
        delete addressStorage[_key];
    }

    /// @param _key The key for the record.
    function deleteUint(bytes32 _key) external onlyOperator {
        delete uintStorage[_key];
    }

    /// @param _key The key for the record.
    function deleteString(bytes32 _key) external onlyOperator {
        delete stringStorage[_key];
    }

    /// @param _key The key for the record.
    function deleteBool(bytes32 _key) external onlyOperator {
        delete booleanStorage[_key];
    }

    /// -----------------------------------------------------------------------
    /// Add Logic
    /// -----------------------------------------------------------------------

    /// @param _key The key for the record.
    /// @param _amount An amount to add to the record's value
    function addUint(bytes32 _key, uint256 _amount) external onlyOperator returns (uint256) {
        return uintStorage[_key] = uintStorage[_key] + _amount;
    }

    /// @param _key The key for the record.
    /// @param _amount An amount to subtract from the record's value
    function subUint(bytes32 _key, uint256 _amount) external onlyOperator returns (uint256) {
        return uintStorage[_key] = uintStorage[_key] - _amount;
    }

    /// -----------------------------------------------------------------------
    /// General Storage - Getter Logic
    /// -----------------------------------------------------------------------

    /// @dev Get the address of DAO.
    function getDao() external view returns (address) {
        return addressStorage[DAO_ADDRESS_KEY];
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
