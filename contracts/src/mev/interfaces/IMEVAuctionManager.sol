// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IMEVAuctionManager
 * @notice Interface for MEV Auction Manager contract
 */
interface IMEVAuctionManager {
    // ========================================
    // STRUCTS
    // ========================================
    
    struct Bundle {
        bytes32 bundleHash;
        address searcher;
        uint256 bidAmount;
        uint256 blockNumber;
        bool executed;
        uint256 timestamp;
        uint256 mevCaptured;
    }
    
    struct SearcherStats {
        uint256 totalBundles;
        uint256 executedBundles;
        uint256 totalMEVCaptured;
        uint256 totalBidsPaid;
        bool registered;
    }
    
    // ========================================
    // FUNCTIONS
    // ========================================
    
    function registerSearcher() external;
    function unregisterSearcher() external;
    function submitBundle(bytes32 bundleHash, uint256 bidAmount, uint256 targetBlock) external;
    function markBundleExecuted(bytes32 bundleHash, uint256 mevCaptured, uint256 bidPaid) external;
    function markBundleRejected(bytes32 bundleHash, string calldata reason) external;
    function getBlockBundles(uint256 blockNumber) external view returns (bytes32[] memory bundleHashes);
    function getBundle(bytes32 bundleHash) external view returns (Bundle memory bundle);
    function getSearcherStats(address searcher) external view returns (SearcherStats memory stats);
    function getAuctionStats() external view returns (uint256 totalBundles, uint256 totalExecuted, uint256 totalMEVCaptured, uint256 registeredSearchersCount);
    
    // ========================================
    // VARIABLES
    // ========================================
    
    function sequencer() external view returns (address);
    function andeToken() external view returns (IERC20);
    function minimumBid() external view returns (uint256);
    function registrationDeposit() external view returns (uint256);
    function registrationOpen() external view returns (bool);
    function registeredSearchers(address searcher) external view returns (bool);
    function registrationDeposits(address searcher) external view returns (uint256);
    function searcherBundleCount(address searcher) external view returns (uint256);
    function searcherMEVCaptured(address searcher) external view returns (uint256);
}