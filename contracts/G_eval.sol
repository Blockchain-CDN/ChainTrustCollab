// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./G_trust.sol";

/**
 * @title G_eval - Industrial chain collaboration lifecycle contract
 */
contract G_eval {
    
    G_trust public trustContract;

    enum SessionState { None, Initialized, Joined, Confirmed, Completed }

    struct Session {
        address initiator;
        string description;
        address[] candidates;
        address selectedCollaborator;
        SessionState state;
    }

    // Session ID => Session details
    mapping(bytes32 => Session) public sessions;

    // 事件
    event Requested(bytes32 indexed sid, address indexed initiator, string description);
    event Joined(bytes32 indexed sid, address indexed candidate);
    event Confirmed(bytes32 indexed sid, address indexed initiator, address indexed selectedCandidate, uint256 trustScore);
    event Completed(bytes32 indexed sid, bool success);

    constructor(address _trustContractAddress) {
        trustContract = G_trust(_trustContractAddress);
    }

    /**
     * @notice Entity i initiates a collaboration request
     */
    function requestCollaboration(bytes32 sid, string memory description) external {
        require(sessions[sid].state == SessionState.None, "Session already exists");

        sessions[sid].initiator = msg.sender;
        sessions[sid].description = description;
        sessions[sid].state = SessionState.Initialized;

        emit Requested(sid, msg.sender, description);
    }

    /**
     * @notice Other entities join as candidates
     */
    function joinCollaboration(bytes32 sid) external {
        require(sessions[sid].state == SessionState.Initialized || sessions[sid].state == SessionState.Joined, "Invalid state");
        require(msg.sender != sessions[sid].initiator, "Initiator cannot join");

        sessions[sid].candidates.push(msg.sender);
        sessions[sid].state = SessionState.Joined;

        emit Joined(sid, msg.sender);
    }

    /**
     * @notice System selects the best collaborator based on trust values from G_trust
     */
    function confirmBestCollaborator(bytes32 sid) external {
        Session storage session = sessions[sid];
        require(msg.sender == session.initiator, "Only initiator can confirm");
        require(session.state == SessionState.Joined, "No candidates joined");
        require(session.candidates.length > 0, "Empty candidates");

        address bestCandidate = address(0);
        uint256 highestTrust = 0;

        for(uint256 k = 0; k < session.candidates.length; k++) {
            address candidate = session.candidates[k];
            uint256 currentTrust = trustContract.getTrustValue(session.initiator, candidate);

            if(currentTrust >= highestTrust) {
                highestTrust = currentTrust;
                bestCandidate = candidate;
            }
        }

        session.selectedCollaborator = bestCandidate;
        session.state = SessionState.Confirmed;

        emit Confirmed(sid, session.initiator, bestCandidate, highestTrust);
    }

    /**
     * @notice Settlement and trust dimension update after collaboration completes
     */
    function completeCollaboration(
        bytes32 sid,
        bool isSuccess,
        uint256 txValue,
        bool isNewPartner
    ) external {
        Session storage session = sessions[sid];
        
        require(session.state == SessionState.Confirmed, "Collaboration not confirmed");
        require(msg.sender == session.initiator || msg.sender == session.selectedCollaborator, "Not authorized");

        // Mark session as completed
        session.state = SessionState.Completed;

        // Update trust dimensions in G_trust
        trustContract.updateTrustDimensions(
            session.initiator, 
            session.selectedCollaborator, 
            isSuccess, 
            txValue, 
            isNewPartner
        );

        emit Completed(sid, isSuccess);
    }
}