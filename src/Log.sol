// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

struct Activity {
    uint256 listId;
    address user;
    uint256 cooldown;
    Interaction[] interaction;
}

struct Interaction {
    bool pass;
    uint256 itemId;
    bytes touchpoint;
}

contract Log {
    event Responded();
    event Reviewed();

    error NotAuthorized();
    error InvalidUser();
    error InvalidReview();
    error InvalidBot();
    error InvalidReviewer();
    error InvalidMission();
    error InvalidTask();
    error Cooldown();

    /// -----------------------------------------------------------------------
    /// Activity Storage
    /// -----------------------------------------------------------------------

    address public dao;
    address public gasBuddy;
    uint256 public activityId;
    mapping(uint256 => Activity) public activities;

    /// -----------------------------------------------------------------------
    /// Sign Storage
    /// -----------------------------------------------------------------------

    uint256 internal INITIAL_CHAIN_ID;
    bytes32 internal INITIAL_DOMAIN_SEPARATOR;
    bytes32 public constant START_TYPEHASH = keccak256("Start(address signer,address missions,uint256 missionId)");
    bytes32 public constant RESPOND_TYPEHASH = keccak256(
        "Respond(address signer,address missions,uint256 missionId,uint256 taskId,uint256 response,string feedback)"
    );

    /// -----------------------------------------------------------------------
    /// Modifier
    /// -----------------------------------------------------------------------

    modifier onlyDao() {
        if (dao != msg.sender) revert NotAuthorized();
        _;
    }

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(address _dao) {
        dao = _dao;
    }

    /// -----------------------------------------------------------------------
    /// DAO Logic
    /// -----------------------------------------------------------------------

    function setGasBuddy(address buddy) external payable onlyDao {
        gasBuddy = buddy;
    }

    function getGasBuddy() public view returns (address) {
        return gasBuddy;
    }
    /// -----------------------------------------------------------------------
    /// Interact
    /// -----------------------------------------------------------------------

    function interact() external payable {}

    function interactBySig() external payable {}

    function sponsoredInteract() external payable {}

    /// -----------------------------------------------------------------------
    /// Review
    /// -----------------------------------------------------------------------
}
