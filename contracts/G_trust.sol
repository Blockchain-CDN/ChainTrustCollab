// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title G_trust - Trust management contract for industrial chain collaboration
 */
contract G_trust {
    
    // Only G_eval can call update functions
    address public g_eval_address;

    // Base trust value, 1e18 precision unit
    uint256 constant BASE_TRUST = 1 * 10**18;
    // Time decay factor
    uint256 constant DECAY_FACTOR = 100; 

    // Five verifiable collaboration dimensions (Q = {Dst, Dmt, Dif, Dtv, Ddp})
    struct TrustDimensions {
        uint256 successfulTimes;    // vst: successful times
        uint256 misbehaviorTimes;   // vmt: misbehavior times
        uint256 interactionTimes;    // vif: total interactions
        uint256 transactionValue;    // vtv: total transaction value
        uint256 diversityPartners;   // vdp: partner diversity
        uint256 lastBlockNumber;     // for time decay calculation
    }

    // Collaboration history: i -> j -> TrustDimensions
    mapping(address => mapping(address => TrustDimensions)) public collaborationHistory;

    modifier onlyEval() {
        require(msg.sender == g_eval_address, "Only G_eval can call this");
        _;
    }

    /**
     * @notice Set G_eval contract address
     */
    function setEvalContract(address _eval) external {
        require(g_eval_address == address(0), "Eval contract already set");
        g_eval_address = _eval;
    }

    /**
     * @notice Update collaboration dimensions between i and j
     */
    function updateTrustDimensions(
        address i, 
        address j, 
        bool isSuccess, 
        uint256 txValue, 
        bool isNewPartner
    ) external onlyEval {
        TrustDimensions storage data = collaborationHistory[i][j];

        if (isSuccess) {
            data.successfulTimes += 1;
        } else {
            data.misbehaviorTimes += 1;
        }
        
        data.interactionTimes += 1;
        data.transactionValue += txValue;
        
        if (isNewPartner) {
            data.diversityPartners += 1;
        }
        
        data.lastBlockNumber = block.number;
    }

    /**
     * @notice Calculate trust value Phi_ij
     */
    function getTrustValue(address i, address j) external view returns (uint256) {
        TrustDimensions memory data = collaborationHistory[i][j];

        // No interaction history, return base trust
        if (data.interactionTimes == 0) {
            return BASE_TRUST;
        }

        // Dimension-weighted calculation
        uint256 positiveScore = (data.successfulTimes * 1e18 * 2) + 
                                (data.interactionTimes * 1e17) + 
                                (data.diversityPartners * 1e18) +
                                (data.transactionValue / 100);

        uint256 negativeScore = data.misbehaviorTimes * 1e18 * 5;

        // Time decay based on block difference
        uint256 blockDiff = block.number - data.lastBlockNumber;
        uint256 decay = blockDiff * DECAY_FACTOR;

        uint256 currentTrust = BASE_TRUST;
        
        if (positiveScore > negativeScore) {
            uint256 netScore = positiveScore - negativeScore;
            // Apply decay
            if (netScore > decay) {
                netScore -= decay;
            } else {
                netScore = 0;
            }
            currentTrust += netScore;
        } else {
            // Circuit breaker for malicious behavior
            uint256 penalty = negativeScore - positiveScore;
            if (BASE_TRUST > penalty) {
                currentTrust = BASE_TRUST - penalty;
            } else {
                currentTrust = 0;
            }
        }

        return currentTrust;
    }
}