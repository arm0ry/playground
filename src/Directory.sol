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
        // if (msg.sender != dao || booleanStorage[keccak256(abi.encodePacked("quest.exists", msg.sender))]) {
        //     revert NotOperator();
        // }
        if (msg.sender != dao && !booleanStorage[keccak256(abi.encodePacked("quest.exists", msg.sender))]) {
            revert NotOperator();
        }
        _;
    }

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    function initialize(address _dao) public {
        dao = _dao;
    }

    /// -----------------------------------------------------------------------
    /// General Storage - Setter Logic
    /// -----------------------------------------------------------------------

    /// @param newDao The address of new DAO.
    function setDao(address newDao) external onlyPlaygroundOperators {
        dao = newDao;
    }

    /// @param newMissionsAddress Contract address of Missions.sol.
    /// @dev
    function setMissionsAddress(address newMissionsAddress) external onlyPlaygroundOperators {
        addressStorage[keccak256(abi.encodePacked("missions"))] = newMissionsAddress;
    }

    /// @param newQuestAddress The address of new Quests.sol to give operator access to Directory.sol.
    function setQuestAddress(address newQuestAddress, bool status) external onlyPlaygroundOperators {
        booleanStorage[keccak256(abi.encodePacked("quest.exists", newQuestAddress))] = status;
    }

    /// @param _key The key for the record.
    function setAddress(bytes32 _key, address _value) external onlyPlaygroundOperators {
        addressStorage[_key] = _value;
    }

    /// @param _key The key for the record.
    function setUint(bytes32 _key, uint256 _value) external onlyPlaygroundOperators {
        uintStorage[_key] = _value;
    }

    /// @param _key The key for the record.
    function setString(bytes32 _key, string calldata _value) external onlyPlaygroundOperators {
        stringStorage[_key] = _value;
    }

    /// @param _key The key for the record.
    function setBool(bytes32 _key, bool _value) external onlyPlaygroundOperators {
        booleanStorage[_key] = _value;
    }

    /// -----------------------------------------------------------------------
    /// General Sotrage - Delete Logic
    /// -----------------------------------------------------------------------

    function deleteQuestsAddress(address questsAddress) external onlyPlaygroundOperators {
        delete booleanStorage[keccak256(abi.encodePacked("quest.exists", questsAddress))];
    }

    /// @param _key The key for the record.
    function deleteAddress(bytes32 _key) external onlyPlaygroundOperators {
        delete addressStorage[_key];
    }

    /// @param _key The key for the record.
    function deleteUint(bytes32 _key) external onlyPlaygroundOperators {
        delete uintStorage[_key];
    }

    /// @param _key The key for the record.
    function deleteString(bytes32 _key) external onlyPlaygroundOperators {
        delete stringStorage[_key];
    }

    /// @param _key The key for the record.
    function deleteBool(bytes32 _key) external onlyPlaygroundOperators {
        delete booleanStorage[_key];
    }

    /// -----------------------------------------------------------------------
    /// Add Logic
    /// -----------------------------------------------------------------------

    /// @param _key The key for the record.
    /// @param _amount An amount to add to the record's value
    function addUint(bytes32 _key, uint256 _amount) external onlyPlaygroundOperators {
        uintStorage[_key] = uintStorage[_key] + _amount;
    }

    /// @param _key The key for the record.
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

    /// @dev Get the address of missions contract.
    function getMissionsAddress() external view returns (address) {
        return this.getAddress(keccak256(abi.encodePacked("missions")));
    }

    /// @param questAddress The address of new Quests.sol to give operator access to Directory.sol.
    function getQuestAccessStatus(address questAddress) external view returns (bool) {
        return booleanStorage[keccak256(abi.encodePacked("quest.exists", questAddress))];
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
