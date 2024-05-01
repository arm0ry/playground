// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {ILog} from "interface/ILog.sol";
import {IBulletin} from "interface/IBulletin.sol";
import {ISupportToken} from "./interface/ISupportToken.sol";
import {LibClone} from "solbase/utils/LibClone.sol";

contract Factory {
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event BulletinDeployed(address mission);
    event LoggerDeployed(address quest);

    /// -----------------------------------------------------------------------
    /// Library Usage
    /// -----------------------------------------------------------------------

    using LibClone for address;

    /// -----------------------------------------------------------------------
    /// Storage
    /// -----------------------------------------------------------------------

    address public immutable bulletin;
    address public immutable logger;
    mapping(address => uint256) public nonces;

    constructor(address _bulletin, address _logger) payable {
        bulletin = _bulletin;
        logger = _logger;
    }

    /// -----------------------------------------------------------------------
    /// Determine Address Logic
    /// -----------------------------------------------------------------------

    function determineBulletinAddress(address user) external virtual returns (address) {
        return bulletin.predictDeterministicAddress(
            abi.encodePacked(user), keccak256(abi.encode(user, nonces[user] + 1)), address(this)
        );
    }

    function determineLoggerAddress(address user) external virtual returns (address) {
        return logger.predictDeterministicAddress(
            abi.encodePacked(user), keccak256(abi.encode(user, nonces[user] + 1)), address(this)
        );
    }

    /// -----------------------------------------------------------------------
    /// Deployment Logic
    /// -----------------------------------------------------------------------

    function deployBulletin(
        address user // create2 salt.
    ) public payable virtual returns (address) {
        address addr = bulletin.cloneDeterministic(abi.encodePacked(user), keccak256(abi.encode(user, ++nonces[user])));
        IBulletin(addr).initialize(user);
        emit BulletinDeployed(addr);
        return (addr);
    }

    function deployLogger(
        address user // create2 salt.
    ) public payable virtual returns (address) {
        address addr = logger.cloneDeterministic(abi.encodePacked(user), keccak256(abi.encode(user, ++nonces[user])));
        ILog(addr).initialize(user);
        emit LoggerDeployed(addr);
        return (addr);
    }
}
