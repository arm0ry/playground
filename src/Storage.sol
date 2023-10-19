// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

// import {SafeMulticallable} from "solbase/utils/SafeMulticallable.sol";
import {IStorage} from "src/interface/IStorage.sol";

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

    function init(address dao, address target) internal {
        addressStorage[keccak256(abi.encodePacked("dao"))] = dao;
        if (target != address(0)) booleanStorage[keccak256(abi.encodePacked("playground.", target))] = true;
    }

    /// -----------------------------------------------------------------------
    /// Modifier
    /// -----------------------------------------------------------------------

    modifier onlyOperator() {
        // TODO: Double check if need to remove second condition
        if (msg.sender != this.getDao() && msg.sender != address(this)) {
            revert NotOperator();
        }
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
        return uintStorage[_key] = uintStorage[_key] - _amount;
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
