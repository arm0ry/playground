// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

/// @notice Directory for Quests
/// @author Modified from Kali (https://github.com/kalidao/kali-contracts/blob/main/contracts/access/KaliAccessManager.sol)
/// @author Storage pattern inspired by RocketPool (https://github.com/rocket-pool/rocketpool/blob/6a9dbfd85772900bb192aabeb0c9b8d9f6e019d1/contracts/contract/RocketStorage.sol)

abstract contract Directory {
    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error NotOperator();
    error ListClaimed();
    error NotListed();
    error InvalidMission();

    /// -----------------------------------------------------------------------
    /// List Storage
    /// -----------------------------------------------------------------------

    // Storage Keys (API into quest stats)
    //
    // Keys:
    // - quest.{key}.{questActivity}
    //
    // Example:
    // - quest.{questKey}.start -> uintStorage
    //      - missions.{missionId}.startCount -> uintStorage
    // - quest.{taskKey}.response -> stringStorage
    // - quest.{taskKey}.review -> boolStorage

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
    /// Setter Logic
    /// -----------------------------------------------------------------------

    /// @param newDao The address of new DAO
    function setDao(address newDao) external onlyPlaygroundOperators {
        dao = newDao;
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
    /// Delete Logic
    /// -----------------------------------------------------------------------

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
    /// Getter Logic
    /// -----------------------------------------------------------------------

    /// @dev Get the address of a network contract by name
    function getContractAddress(string memory _contractName) internal view returns (address) {
        // Get the current contract address
        address contractAddress = this.getAddress(keccak256(abi.encodePacked("contract.address", _contractName)));
        // Check it
        require(contractAddress != address(0x0), "Contract not found");
        // Return
        return contractAddress;
    }

    /// @param _key The key for the record
    function getAddress(bytes32 _key) external view returns (address r) {
        return addressStorage[_key];
    }

    /// @param _key The key for the record
    function getUint(bytes32 _key) external view returns (uint256 r) {
        return uintStorage[_key];
    }

    /// @param _key The key for the record
    function getString(bytes32 _key) external view returns (string memory) {
        return stringStorage[_key];
    }

    /// @param _key The key for the record
    function getBool(bytes32 _key) external view returns (bool r) {
        return booleanStorage[_key];
    }
}
