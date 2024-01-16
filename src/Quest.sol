// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {IMission} from "./interface/IMission.sol";
import {Storage} from "kali-markets/Storage.sol";

/// @title An interface between physical and digital operation.
/// @author audsssy.eth
contract Quest is Storage {
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event Started(address user, address missions, uint256 missionId);
    event Responded(
        address user, address missions, uint256 missionId, uint256 taskId, uint256 response, string feedback
    );
    event Reviewed(
        address reviewer,
        address user,
        address missions,
        uint256 missionId,
        uint256 taskId,
        uint256 response,
        string feedback
    );

    /// -----------------------------------------------------------------------
    /// Custom Errors
    /// -----------------------------------------------------------------------

    error NotInitialized();
    error InvalidUser();
    // error QuestInactive();
    // error QuestInProgress();
    error InvalidReview();
    error InvalidBot();
    error InvalidReviewer();
    error InvalidMission();
    error Cooldown();

    /// -----------------------------------------------------------------------
    /// Sign Storage
    /// -----------------------------------------------------------------------

    uint256 internal INITIAL_CHAIN_ID;
    bytes32 internal INITIAL_DOMAIN_SEPARATOR;
    bytes32 public constant START_TYPEHASH = keccak256("Start(address signer,address missions,uint256 missionId)");
    bytes32 public constant RESPOND_TYPEHASH = keccak256(
        "Respond(address signer,address missions,uint256 missionId,uint256 taskId,uint256 response,string feedback)"
    );
    bytes32 public constant REVIEW_TYPEHASH =
        keccak256("Review(address signer,address user,bytes32 taskKey,uint256 response,string feedback)");

    /// -----------------------------------------------------------------------
    /// Modifier
    /// -----------------------------------------------------------------------

    modifier onlyReviewer(address reviewer) {
        if (!this.isReviewer((reviewer == address(0)) ? msg.sender : reviewer)) revert InvalidReviewer();
        _;
    }

    modifier onlyGasBot() {
        if (!this.isGasBot(msg.sender)) revert InvalidBot();
        _;
    }

    modifier hasExpired(address missions, uint256 missionId) {
        checkExpiry(missions, missionId);
        _;
    }

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    /// @notice Initialize dao.
    function initialize(address dao) external payable {
        init(dao);
    }

    /// -----------------------------------------------------------------------
    /// DAO Logic
    /// -----------------------------------------------------------------------

    /// @notice Add global cooldown.
    function setCooldown(uint40 cd) external payable onlyOperator {
        _setUint(keccak256(abi.encode(address(this), ".quests.cd")), cd);
    }

    /// @notice Retrieve global cooldown.
    function getCooldown() external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), ".quests.cd")));
    }

    /// @notice Update review status.
    function setReviewStatus(bool status) external payable onlyOperator {
        _setBool(keccak256(abi.encode(address(this), ".quests.review")), status);
    }

    /// @notice Retrieve review status.
    function getReviewStatus() external view returns (bool) {
        return this.getBool(keccak256(abi.encode(address(this), ".quests.review")));
    }

    /// @notice Update gas bot.
    function setGasbot(address bot) external payable onlyOperator {
        _setAddress(keccak256(abi.encode(address(this), ".gasbot")), bot);
    }

    /// @notice Confirm bot status.
    function isGasBot(address bot) external view returns (bool) {
        return (this.getAddress(keccak256(abi.encode(address(this), ".gasbot"))) == bot) ? true : false;
    }

    /// -----------------------------------------------------------------------
    /// EIP-2612 LOGIC
    /// -----------------------------------------------------------------------

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : _computeDomainSeparator();
    }

    function _computeDomainSeparator() internal view virtual returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("Quest")),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

    /// -----------------------------------------------------------------------
    /// User Logic
    /// -----------------------------------------------------------------------

    /// @notice Set profile picture.
    function setProfilePicture(string calldata url) external payable {
        _setString(keccak256(abi.encode(address(this), ".users.", msg.sender, ".profile")), url);
    }

    /// @notice Start a quest.
    function start(address missions, uint256 missionId) external payable hasExpired(missions, missionId) {
        _start(msg.sender, missions, missionId);
    }

    /// @notice Start a quest (gasless).
    /// @param signer .
    /// @param missions .
    /// @param missionId .
    /// @dev
    function startBySig(address signer, address missions, uint256 missionId, uint8 v, bytes32 r, bytes32 s)
        external
        payable
        virtual
        hasExpired(missions, missionId)
        onlyGasBot
    {
        // Validate signed message.
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01", DOMAIN_SEPARATOR(), keccak256(abi.encode(START_TYPEHASH, signer, missions, missionId))
            )
        );

        address recoveredAddress = ecrecover(digest, v, r, s);
        if (recoveredAddress == address(0) || recoveredAddress != signer) revert InvalidUser();

        // Start.
        _start(signer, missions, missionId);
    }

    /// @notice Start a quest (gasless) with a username.
    function sponsoredStart(string calldata username, address missions, uint256 missionId)
        external
        payable
        virtual
        hasExpired(missions, missionId)
        onlyGasBot
    {
        // Validate
        if (this.isPublicUser(username)) revert InvalidUser();

        // Start.
        _start(getPublicUserAddress(username), missions, missionId);

        // Set public registry.
        setPublicRegistry(username, missions, missionId);
    }

    /// @notice Respond to a task.
    /// @notice User respond to Task to progress Quest.
    function respond(address missions, uint256 missionId, uint256 taskId, uint256 response, string calldata feedback)
        external
        payable
        hasExpired(missions, missionId)
    {
        _respond(msg.sender, missions, missionId, taskId, response, feedback);
    }

    /// @notice Respond to a task (gasless).
    function respondBySig(
        address signer,
        address missions,
        uint256 missionId,
        uint256 taskId,
        uint256 response,
        string calldata feedback,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable virtual hasExpired(missions, missionId) onlyGasBot {
        // Validate signed message.
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(abi.encode(RESPOND_TYPEHASH, signer, missions, missionId, taskId, response, feedback))
            )
        );

        address recoveredAddress = ecrecover(digest, v, r, s);
        if (recoveredAddress == address(0) || recoveredAddress != signer) revert InvalidUser();

        // Respond.
        _respond(signer, missions, missionId, taskId, response, feedback);
    }

    /// @notice Respond to a task (gasless) with a username and salt.
    function sponsoredRespond(
        string calldata username,
        address missions,
        uint256 missionId,
        uint256 taskId,
        uint256 response,
        string calldata feedback
    ) external payable virtual hasExpired(missions, missionId) onlyGasBot {
        // Respond by dao.
        _respond(getPublicUserAddress(username), missions, missionId, taskId, response, feedback);
    }

    /// -----------------------------------------------------------------------
    /// Review Logic
    /// -----------------------------------------------------------------------

    /// @notice Review a task.
    function review(
        address user,
        address missions,
        uint256 missionId,
        uint256 taskId,
        uint256 response,
        string calldata feedback
    ) external payable onlyReviewer(address(0)) hasExpired(missions, missionId) {
        _review(msg.sender, user, missions, missionId, taskId, response, feedback);
    }

    /// -----------------------------------------------------------------------
    /// Reviewer Logic - Setter
    /// -----------------------------------------------------------------------

    /// @notice Set reviewer status.
    function setReviewer(address reviewer, bool status) external payable onlyOperator {
        _setReviewer(reviewer, status);
    }

    /// @notice Internal function to set reviewer status.
    function _setReviewer(address reviewer, bool status) internal {
        if (status) _setBool(keccak256(abi.encode(address(this), ".reviewers.", reviewer, ".approved")), status);
    }

    /// -----------------------------------------------------------------------
    /// Reviewer Logic - Getter
    /// -----------------------------------------------------------------------

    /// @notice Retrieve reviewer status.
    function isReviewer(address user) external view returns (bool) {
        return this.getBool(keccak256(abi.encode(address(this), ".reviewers.", user, ".approved")));
    }

    /// @notice Retrieve review response.
    function getReviewResponse(address reviewer, uint256 order) external view returns (uint256) {
        return (order == 0)
            ? this.getUint(
                keccak256(
                    abi.encode(
                        address(this),
                        ".reviewers.",
                        reviewer,
                        ".reviewId.",
                        this.getNumOfReviewByReviewer(reviewer),
                        ".response"
                    )
                )
            )
            : this.getUint(keccak256(abi.encode(address(this), ".reviewers.", reviewer, ".reviewId.", order, ".response")));
    }

    /// @notice Retrieve review feedback.
    function getReviewFeedback(address reviewer, uint256 order) external view returns (string memory) {
        return (order == 0)
            ? this.getString(
                keccak256(
                    abi.encode(
                        address(this),
                        ".reviewers.",
                        reviewer,
                        ".reviewId.",
                        this.getNumOfReviewByReviewer(reviewer),
                        ".feedback"
                    )
                )
            )
            : this.getString(
                keccak256(abi.encode(address(this), ".reviewers.", reviewer, ".reviewId.", order, ".feedback"))
            );
    }

    /// -----------------------------------------------------------------------
    /// User Logic - Internal
    /// -----------------------------------------------------------------------

    /// @notice Internal function to delete quest activity.
    // function deleteQuestProgress(address user, address missions, uint256 missionId) internal virtual {
    //     deleteUint(keccak256(abi.encode(address(this), ".users.", user, ".quests.", missions, missionId, ".progress")));
    // }

    /// @notice Internal function to update and return quest progress.
    // function updateQuestProgress(address user, address missions, uint256 missionId, uint256 completed)
    //     internal
    //     virtual
    //     returns (uint256)
    // {
    //     uint256 count = IMission(missions).getMissionTaskCount(missionId);
    //     uint256 progress = completed * 100 / count;
    //     _setUint(
    //         keccak256(abi.encode(address(this), ".users.", user, ".quests.", missions, missionId, ".progress")),
    //         progress
    //     );
    //     return progress;
    // }

    /// @notice Increment number of tasks completed by a user in this quest contract.
    function setIsTaskAccomplished(address user, address missions, uint256 missionId, uint256 taskId) internal {
        _setBool(
            keccak256(
                abi.encode(address(this), ".users.", user, ".quests.", missions, missionId, taskId, ".isAccomplished")
            ),
            true
        );
    }

    /// @notice Increment number of tasks completed by a user in this quest contract.
    function setIsMissionAccomplished(address user, address missions, uint256 missionId) internal {
        _setBool(
            keccak256(abi.encode(address(this), ".users.", user, ".quests.", missions, missionId, ".isAccomplished")),
            true
        );
    }

    /// -----------------------------------------------------------------------
    /// User Logic - Getter
    /// -----------------------------------------------------------------------

    /// @notice Retrieve profile picture.
    function getProfilePicture(address user) external view returns (string memory) {
        return this.getString(keccak256(abi.encode(address(this), ".users.", user, ".profile")));
    }

    /// @notice Increment number of tasks completed by a user in this quest contract.
    function isTaskAccomplished(address user, address missions, uint256 missionId, uint256 taskId)
        external
        view
        returns (bool)
    {
        return this.getBool(
            keccak256(
                abi.encode(address(this), ".users.", user, ".quests.", missions, missionId, taskId, ".isAccomplished")
            )
        );
    }

    /// @notice Increment number of tasks completed by a user in this quest contract.
    function isMissionAccomplished(address user, address missions, uint256 missionId) external view returns (bool) {
        return this.getBool(
            keccak256(abi.encode(address(this), ".users.", user, ".quests.", missions, missionId, ".isAccomplished"))
        );
    }

    /// @notice Retrieve number of completed tasks in a given mission.
    function getNumOfCompletedTasksInMission(address user, address missions, uint256 missionId)
        external
        view
        returns (uint256)
    {
        return this.getUint(
            keccak256(
                abi.encode(address(this), ".users.", user, ".quests.", missions, missionId, ".numOfCompletedTasks")
            )
        );
    }

    /// @notice Retrieve time stamp of last task comnpletion.
    function getTimeLastTaskCompleted(address user) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), ".users.", user, ".timeLastCompleted")));
    }

    /// @notice Retrieve cooldown status.
    function hasCooledDown(address user) external view returns (bool) {
        return (block.timestamp >= this.getTimeLastTaskCompleted(user) + this.getCooldown()) ? true : false;
    }

    /// @notice Retrieve mission contract, mission id, and task id by a given user.
    function getTaskResponded(address user, uint256 order)
        external
        view
        returns (address mission, uint256 missionId, uint256 taskId)
    {
        // Using number of responds by a user as respond id, establish link between task id to user's respond id.
        (mission, missionId, taskId) = this.decodeTaskKey(
            this.getUint(keccak256(abi.encode(address(this), ".users.", user, ".responseId.", order, ".task")))
        );
    }

    /// @notice Retrieve task response by a given user.
    function getTaskResponse(address user, uint256 order) external view returns (uint256) {
        return (order == 0)
            ? this.getUint(
                keccak256(
                    abi.encode(
                        address(this), ".users.", user, ".responseId.", this.getNumOfResponseByUser(user), ".response"
                    )
                )
            )
            : this.getUint(keccak256(abi.encode(address(this), ".users.", user, ".responseId.", order, ".response")));
    }

    /// @notice Retrieve task feedback by a given user.
    function getTaskFeedback(address user, uint256 order) external view returns (string memory) {
        return (order == 0)
            ? this.getString(
                keccak256(
                    abi.encode(
                        address(this), ".users.", user, ".responseId.", this.getNumOfResponseByUser(user), ".feedback"
                    )
                )
            )
            : this.getString(keccak256(abi.encode(address(this), ".users.", user, ".responseId.", order, ".feedback")));
    }

    /// -----------------------------------------------------------------------
    /// Quest Logic - Public Registry
    /// -----------------------------------------------------------------------

    /// @notice Retrieve number of public users.
    function getPublicCount() external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), ".public.count")));
    }

    /// @notice Retrieve public user status.
    function isPublicUser(string calldata username) external view returns (bool) {
        return this.getBool(keccak256(abi.encode(address(this), ".users.", getPublicUserAddress(username), ".exists")));
    }

    /// @notice Retrieve public user address by public user id.
    function getNumOfStartsByMissionByPublic(address missions, uint256 missionId) external view returns (uint256) {
        return this.getUint(
            keccak256(abi.encode(address(this), ".public.", this.getTaskKey(missions, missionId, 0), ".count"))
        );
    }

    /// @notice Increment number of public users (e.g., public user id).
    function incrementPublicCount() internal {
        addUint(keccak256(abi.encode(address(this), ".public.count")), 1);
    }

    /// @notice Set new public user..
    function setPublicRegistry(string calldata username, address missions, uint256 missionId) internal {
        // Increment public user id.
        incrementPublicCount();

        // Increment number of public participation for mission and mission id.
        addUint(keccak256(abi.encode(address(this), ".public.", this.getTaskKey(missions, missionId, 0), ".count")), 1);

        // Register user existance.
        _setBool(keccak256(abi.encode(address(this), ".users.", getPublicUserAddress(username), ".exists")), true);
    }

    /// -----------------------------------------------------------------------
    /// Quest Logic - Quest Registry
    /// -----------------------------------------------------------------------

    /// @notice Retrieve number of quests.
    function getQuestCount() external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), ".quests.count")));
    }

    /// @notice Retrieve quest by quest id.
    function getQuest(uint256 questId) external view returns (address, address, uint256) {
        return (
            this.getAddress(keccak256(abi.encode(address(this), ".quests.", questId, ".user"))),
            this.getAddress(keccak256(abi.encode(address(this), ".quests.", questId, ".missions"))),
            this.getUint(keccak256(abi.encode(address(this), ".quests.", questId, ".missionId")))
        );
    }

    /// @notice Increment number of quests  (e.g., quest id).
    function incrementQuestCount() internal returns (uint256) {
        return addUint(keccak256(abi.encode(address(this), ".quests.count")), 1);
    }

    /// -----------------------------------------------------------------------
    /// Quest Logic - Stats Setter
    /// -----------------------------------------------------------------------

    /// @notice Increment number of missions started in this quest contract.
    function incrementNumOfMissionsStarted() internal {
        addUint(keccak256(abi.encode(address(this), ".stats.mission.starts")), 1);
    }

    /// @notice Increment number of missions completed in this quest contract.
    function incrementNumOfMissionsCompleted() internal {
        addUint(keccak256(abi.encode(address(this), ".stats.mission.completions")), 1);
    }

    /// @notice Increment number of tasks completed in this quest contract.
    function incrementNumOfTaskCompleted() internal {
        addUint(keccak256(abi.encode(address(this), ".stats.task.completions")), 1);
    }

    /// @notice Increment number of missions started by a user in this quest contract.
    function incrementNumOfMissionsStartedByUser(address user, address missions, uint256 missionId) internal {
        addUint(keccak256(abi.encode(address(this), ".users.", user, ".quests.", missions, missionId, ".starts")), 1);
    }

    // / @notice Increment number of missions completed by a user in this quest contract.
    // function incrementNumOfMissionsCompletedByUser(address user, address missions, uint256 missionId) internal {
    //     addUint(
    //         keccak256(abi.encode(address(this), ".users.", user, ".quests.", missions, missionId, ".completions")), 1
    //     );
    // }

    /// @notice Increment number of tasks completed by a user in this quest contract.
    function incrementNumOfCompletionsByTask(address user, address missions, uint256 missionId, uint256 taskId)
        internal
    {
        addUint(
            keccak256(
                abi.encode(address(this), ".users.", user, ".quests.", missions, missionId, taskId, ".completions")
            ),
            1
        );
    }

    /// @notice Increment number of tasks completed in a mission.
    function incrementNumOfCompletedTasksInMission(address user, address missions, uint256 missionId)
        internal
        returns (uint256)
    {
        return addUint(
            keccak256(
                abi.encode(address(this), ".users.", user, ".quests.", missions, missionId, ".numOfCompletedTasks")
            ),
            1
        );
    }

    /// @notice Reset number of completed tasks in a given mission.
    // function deleteNumOfCompletedTasksInMission(address user, address missions, uint256 missionId) internal {
    //     deleteUint(
    //         keccak256(
    //             abi.encode(address(this), ".users.", user, ".quests.", missions, missionId, ".numOfCompletedTasks")
    //         )
    //     );
    // }

    /// @notice Increment number of quests by user.
    function incrementNumOfTimesQuestedByUser(address user) internal returns (uint256) {
        return addUint(keccak256(abi.encode(address(this), ".users.", user, ".quests.count")), 1);
    }

    /// @notice Increment number of quests by mission and mission id.
    function incrementNumOfTimesQuestedByMission(address missions, uint256 missionId)
        internal
        returns (uint256, uint256)
    {
        return (
            addUint(keccak256(abi.encode(address(this), ".quests.", missions, missionId, ".count")), 1),
            addUint(keccak256(abi.encode(address(this), ".quests.", missions, ".count")), 1)
        );
    }

    /// @notice Increment number of responses by user.
    function incrementNumOfResponseByUser(address user) internal returns (uint256) {
        return addUint(keccak256(abi.encode(address(this), ".users.", user, ".responses.count")), 1);
    }

    /// @notice Increment number of reviews by reviewer.
    function incrementNumOfReviewByReviewer(address reviewer) internal returns (uint256) {
        return addUint(keccak256(abi.encode(address(this), ".reviewers.", reviewer, ".reviews.count")), 1);
    }

    /// -----------------------------------------------------------------------
    /// Quest Logic - Stats Getter
    /// -----------------------------------------------------------------------

    function getNumOfMissionsStarted() external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), ".stats.mission.starts")));
    }

    function getNumOfMissionsCompleted() external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), ".stats.mission.completions")));
    }

    function getNumOfTaskCompleted() external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), ".stats.task.completions")));
    }

    function getNumOfMissionsStartedByUser(address user, address missions, uint256 missionId)
        external
        view
        returns (uint256)
    {
        return this.getUint(
            keccak256(abi.encode(address(this), ".users.", user, ".quests.", missions, missionId, ".starts"))
        );
    }

    // function getNumOfMissionsCompletedByUser(address user, address missions, uint256 missionId)
    //     external
    //     view
    //     returns (uint256)
    // {
    //     return this.getUint(
    //         keccak256(abi.encode(address(this), ".users.", user, ".quests.", missions, missionId, ".completions"))
    //     );
    // }

    // function getNumOfCompletionsByTask(address user, address missions, uint256 missionId, uint256 taskId)
    //     external
    //     view
    //     returns (uint256)
    // {
    //     return this.getUint(
    //         keccak256(
    //             abi.encode(address(this), ".users.", user, ".quests.", missions, missionId, taskId, ".completions")
    //         )
    //     );
    // }

    function getQuestCountByUser(address user) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), ".users.", user, ".quests.count")));
    }

    /// @notice Retrieve number of quests by mission and mission id.
    function getNumOfMissionQuested(address missions, uint256 missionId) external view returns (uint256, uint256) {
        return (
            this.getUint(keccak256(abi.encode(address(this), ".quests.", missions, missionId, ".count"))),
            this.getUint(keccak256(abi.encode(address(this), ".quests.", missions, ".count")))
        );
    }

    function getNumOfResponseByUser(address user) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), ".users.", user, ".responses.count")));
    }

    function getNumOfReviewByReviewer(address reviewer) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(address(this), ".reviewers.", reviewer, ".reviews.count")));
    }

    /// -----------------------------------------------------------------------
    /// Quest Logic - Internal
    /// -----------------------------------------------------------------------

    /// @notice Internal function to start quest.
    function _start(address user, address missions, uint256 missionId) internal virtual {
        if (this.isMissionAccomplished(user, missions, missionId)) revert InvalidMission();
        if (this.getNumOfMissionsStartedByUser(user, missions, missionId) > 0) revert InvalidMission();
        // deleteQuestProgress(user, missions, missionId);

        // Update mission-related stats.
        updateStats(user, missions, missionId);

        // Record quest.
        uint256 count = incrementQuestCount();
        setQuest(count, user, missions, missionId);

        // Increment Quest-related counter.
        incrementNumOfTimesQuestedByUser(user);
        incrementNumOfTimesQuestedByMission(missions, missionId);

        emit Started(user, missions, missionId);
    }

    /// @notice Internal function to update starting stats.
    function updateStats(address user, address missions, uint256 missionId) internal {
        // Increment number of missions started by user, as facilitated by this Quest contract.
        incrementNumOfMissionsStartedByUser(user, missions, missionId);

        // Increment number of missions started and facilitated by this Quest contract.
        incrementNumOfMissionsStarted();

        // Confirm Mission contract allows input from this Quest contract.
        if (IMission(missions).isQuestAuthorized(address(this))) {
            // Increment number of mission starts.
            IMission(missions).incrementMissionStarts(missionId);
        }
    }

    /// @notice Internal function to set quest.
    function setQuest(uint256 questId, address user, address missions, uint256 missionId) internal {
        _setAddress(keccak256(abi.encode(address(this), ".quests.", questId, ".user")), user);
        _setAddress(keccak256(abi.encode(address(this), ".quests.", questId, ".missions")), missions);
        _setUint(keccak256(abi.encode(address(this), ".quests.", questId, ".missionId")), missionId);
    }

    /// @notice Internal function to respond to quest tasks and update associated data.
    function _respond(
        address user,
        address missions,
        uint256 missionId,
        uint256 taskId,
        uint256 response,
        string calldata feedback
    ) internal virtual {
        // Confirm Task is valid
        if (!IMission(missions).isTaskInMission(missionId, taskId)) revert InvalidMission();

        // Confirm user is no longer in cooldown.
        if (!this.hasCooledDown(user)) revert Cooldown();

        // Store responses.
        setResponse(user, missions, missionId, taskId, response, feedback);

        // Start cooldown.
        setTimeLastTaskCompleted(user);

        // When review is not required, update quest detail and stats.
        if (!this.getReviewStatus()) {
            updateQuestAndStats(user, missions, missionId, taskId);
        }

        emit Responded(user, missions, missionId, taskId, response, feedback);
    }

    /// @notice Internal function to set a response.
    function setResponse(
        address user,
        address missions,
        uint256 missionId,
        uint256 taskId,
        uint256 response,
        string calldata feedback
    ) internal virtual {
        // Retrieve number of responses as response id.
        uint256 count = incrementNumOfResponseByUser(user);

        // Add response.
        setTaskResponded(user, count, missions, missionId, taskId);
        setTaskResponse(user, count, response);
        setTaskFeedback(user, count, feedback);
    }

    /// @notice Internal function to associate response with a task.
    function setTaskResponded(address user, uint256 order, address missions, uint256 missionId, uint256 taskId)
        internal
        virtual
    {
        // Using number of responds by a user as respond id, establish link between task id to user's respond id.
        _setUint(
            keccak256(abi.encode(address(this), ".users.", user, ".responseId.", order, ".task")),
            this.getTaskKey(missions, missionId, taskId)
        );
    }

    /// @notice Internal function to add response to a task.
    function setTaskResponse(address user, uint256 order, uint256 response) internal virtual {
        // Set respond content.
        _setUint(keccak256(abi.encode(address(this), ".users.", user, ".responseId.", order, ".response")), response);
    }

    /// @notice Internal function to add feedback to a task.
    function setTaskFeedback(address user, uint256 order, string calldata feedback) internal virtual {
        // Set any respond feedback.
        if (bytes(feedback).length > 0) {
            _setString(
                keccak256(abi.encode(address(this), ".users.", user, ".responseId.", order, ".feedback")), feedback
            );
        }
    }

    /// @notice Internal function to set time of last task completed.
    function setTimeLastTaskCompleted(address user) internal virtual {
        _setUint(keccak256(abi.encode(address(this), ".users.", user, ".timeLastCompleted")), block.timestamp);
    }

    /// @notice Internal function using signature to review quest tasks.
    function _review(
        address reviewer,
        address user,
        address missions,
        uint256 missionId,
        uint256 taskId,
        uint256 response,
        string calldata feedback
    ) internal virtual {
        if (!this.getReviewStatus()) revert InvalidReview();

        // Add review.
        setReview(reviewer, missions, missionId, taskId, response, feedback);

        // Update quest detail.
        updateQuestAndStats(user, missions, missionId, taskId);

        emit Reviewed(reviewer, user, missions, missionId, taskId, response, feedback);
    }

    /// @notice Add a review.
    function setReview(
        address reviewer,
        address missions,
        uint256 missionId,
        uint256 taskId,
        uint256 response,
        string calldata feedback
    ) internal virtual {
        // Retrieve number of responses as review id.
        uint256 count = incrementNumOfReviewByReviewer(reviewer);

        // Add review.
        setTaskReviewed(reviewer, count, missions, missionId, taskId);
        setReviewResponse(reviewer, count, response);
        setReviewFeedback(reviewer, count, feedback);
    }

    /// @notice Internal function to associate review with a task.
    function setTaskReviewed(address reviewer, uint256 order, address missions, uint256 missionId, uint256 taskId)
        internal
        virtual
    {
        // Using number of reviews by a reviewer as review id, establish link between task id to reviewer's review id.
        _setUint(
            keccak256(abi.encode(address(this), ".reviewers.", reviewer, ".reviewId.", order, ".task")),
            this.getTaskKey(missions, missionId, taskId)
        );
    }

    /// @notice Internal function to add review response to a task.
    function setReviewResponse(address reviewer, uint256 order, uint256 response) internal virtual {
        // Set review content.
        _setUint(
            keccak256(abi.encode(address(this), ".reviewers.", reviewer, ".reviewId.", order, ".response")), response
        );
    }

    /// @notice Internal function to add review feedback to a task.
    function setReviewFeedback(address reviewer, uint256 order, string calldata feedback) internal virtual {
        // Set any review feedback.
        if (bytes(feedback).length > 0) {
            _setString(
                keccak256(abi.encode(address(this), ".reviewers.", reviewer, ".reviewId.", order, ".feedback")),
                feedback
            );
        }
    }

    /// @notice Update, and finalize when appropriate, the Quest detail.
    function updateQuestAndStats(address user, address missions, uint256 missionId, uint256 taskId) internal {
        // Update Task-related stats.
        updateTaskCompletionStats(user, missions, missionId, taskId);

        // Calculate and update quest progress.
        uint256 count = IMission(missions).getMissionTaskCount(missionId);
        uint256 progress;

        if (!this.isTaskAccomplished(user, missions, missionId, taskId)) {
            uint256 completionCount = incrementNumOfCompletedTasksInMission(user, missions, missionId);
            progress = completionCount * 100 / count;

            // Finalize quest.
            if (progress == 100) {
                // Update Mission-related stats
                updateMissionCompletionStats(missions, missionId);

                setIsMissionAccomplished(user, missions, missionId);
            }
        }

        // if (progress == 100) {
        // Increment number of times missionId is completed , as facilitated by this Quest contract.
        // incrementNumOfMissionsCompletedByUser(user, missions, missionId);

        // Reset number of tasks completed to enable multiple participation.
        // deleteNumOfCompletedTasksInMission(user, missions, missionId);
        // }
    }

    /// @notice Update task related stats.
    function updateTaskCompletionStats(address user, address missions, uint256 missionId, uint256 taskId) internal {
        // Increment total number of tasks completed, as facilitated by this Quest contract.
        incrementNumOfTaskCompleted();

        // Increment number of tasks completed by user, as facilitated by this Quest contract.
        incrementNumOfCompletionsByTask(user, missions, missionId, taskId);

        // Increment task completion at Mission contract.
        if (IMission(missions).isQuestAuthorized(address(this))) {
            IMission(missions).incrementTotalTaskCompletions(taskId);
            IMission(missions).incrementTotalTaskCompletionsByMission(missionId, taskId);
        }
    }

    /// @notice Update mission related stats.
    function updateMissionCompletionStats(address missions, uint256 missionId) internal {
        // Increment number of missions facilitated by this Quest contract.
        incrementNumOfMissionsCompleted();

        // Increment number of mission completions.
        if (IMission(missions).isQuestAuthorized(address(this))) {
            IMission(missions).incrementMissionCompletions(missionId);
        }
    }

    /// -----------------------------------------------------------------------
    /// Helper Logic
    /// -----------------------------------------------------------------------

    /// @notice Check if mission has expired.
    function checkExpiry(address missions, uint256 missionId) internal view {
        uint256 deadline = IMission(missions).getMissionDeadline(missionId);
        if (deadline == 0) revert NotInitialized();
        if (block.timestamp > deadline) revert InvalidMission();
    }

    /// @notice Encode address of mission, mission id and task id as type uint256.
    function getTaskKey(address mission, uint256 missionId, uint256 taskId) external pure returns (uint256) {
        return uint256(bytes32(abi.encodePacked(mission, uint48(missionId), uint48(taskId))));
    }

    /// @notice Decode uint256 into address of mission, mission id and task id.
    function decodeTaskKey(uint256 tokenId) external pure returns (address, uint256, uint256) {
        // Convert tokenId from type uint256 to bytes32.
        bytes32 key = bytes32(tokenId);

        // Declare variables to return later.
        uint48 taskId;
        uint48 missionId;
        address mission;

        // Parse data via assembly.
        assembly {
            taskId := key
            missionId := shr(48, key)
            mission := shr(96, key)
        }

        return (mission, uint256(missionId), uint256(taskId));
    }

    /// @notice Encode publicly submitted username and salt as an address.
    function getPublicUserAddress(string calldata username) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encode(username)))));
    }
}
