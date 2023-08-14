// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IDirectory {
    /// @dev Storage get methods
    function getContractAddress(string memory _contractName) external view returns (address);
    function getAddress(bytes32 _key) external view returns (address);
    function getBool(bytes32 _key) external view returns (bool);
    function getString(bytes32 _key) external view returns (string memory);
    function getUint(bytes32 _key) external view returns (uint256);

    /// @dev Storage set methods
    function setAddress(bytes32 _key, address _value) external;
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
