/**
 * MintController Frontend Integration Guide
 * 
 * This file provides ready-to-use React hooks and utilities
 * for integrating MintController into your frontend application.
 */

import { ethers, Contract } from "ethers";
import { useState, useEffect, useCallback } from "react";

// ============================================
// TYPES & INTERFACES
// ============================================

export enum ProposalState {
  Pending = 0,
  Active = 1,
  Defeated = 2,
  Succeeded = 3,
  Queued = 4,
  Executed = 5,
  Cancelled = 6,
  Expired = 7,
}

export interface Proposal {
  id: number;
  amount: bigint;
  recipient: string;
  description: string;
  snapshotBlock: bigint;
  creationTime: number;
  votingDeadline: number;
  executionETA: number;
  votesFor: bigint;
  votesAgainst: bigint;
  totalVotingPower: bigint;
  executed: boolean;
  cancelled: boolean;
  state: ProposalState;
  
  // Computed fields
  supportPercentage: number;
  participationPercentage: number;
  timeRemaining: number;
  canVote: boolean;
  canQueue: boolean;
  canExecute: boolean;
}

export interface GovernanceMetrics {
  hardCap: bigint;
  totalMinted: bigint;
  annualMintLimit: bigint;
  mintedThisYear: bigint;
  remainingAnnualCapacity: bigint;
  remainingHardCapCapacity: bigint;
  quorumPercentage: number;
  votingPeriod: number;
  executionDelay: number;
  proposalLifetime: number;
  maxProposalAmount: bigint;
  minProposalAmount: bigint;
  proposalCount: number;
}

export interface UserVotingInfo {
  votingPower: bigint;
  hasVoted: boolean;
  canVote: boolean;
}

// ============================================
// REACT HOOKS
// ============================================

/**
 * Hook to get governance metrics
 */
export function useGovernanceMetrics(
  contract: Contract | null
): [GovernanceMetrics | null, boolean, Error | null] {
  const [metrics, setMetrics] = useState<GovernanceMetrics | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    if (!contract) return;

    const fetchMetrics = async () => {
      try {
        setLoading(true);
        
        const [
          hardCap,
          totalMinted,
          annualMintLimit,
          mintedThisYear,
          remainingAnnual,
          remainingHardCap,
          quorum,
          votingPeriod,
          executionDelay,
          proposalLifetime,
          maxProposal,
          minProposal,
          proposalCount,
        ] = await Promise.all([
          contract.hardCap(),
          contract.totalMinted(),
          contract.annualMintLimit(),
          contract.mintedThisYear(),
          contract.getRemainingAnnualCapacity(),
          contract.getRemainingHardCapCapacity(),
          contract.quorumPercentage(),
          contract.votingPeriod(),
          contract.executionDelay(),
          contract.proposalLifetime(),
          contract.maxProposalAmount(),
          contract.minProposalAmount(),
          contract.proposalCount(),
        ]);

        setMetrics({
          hardCap,
          totalMinted,
          annualMintLimit,
          mintedThisYear,
          remainingAnnualCapacity: remainingAnnual,
          remainingHardCapCapacity: remainingHardCap,
          quorumPercentage: Number(quorum),
          votingPeriod: Number(votingPeriod),
          executionDelay: Number(executionDelay),
          proposalLifetime: Number(proposalLifetime),
          maxProposalAmount: maxProposal,
          minProposalAmount: minProposal,
          proposalCount: Number(proposalCount),
        });
        
        setError(null);
      } catch (err) {
        setError(err as Error);
      } finally {
        setLoading(false);
      }
    };

    fetchMetrics();
    
    // Refresh every 30 seconds
    const interval = setInterval(fetchMetrics, 30000);
    return () => clearInterval(interval);
  }, [contract]);

  return [metrics, loading, error];
}

/**
 * Hook to get a single proposal with computed fields
 */
export function useProposal(
  contract: Contract | null,
  proposalId: number,
  userAddress: string | null
): [Proposal | null, boolean, Error | null] {
  const [proposal, setProposal] = useState<Proposal | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    if (!contract || !proposalId) return;

    const fetchProposal = async () => {
      try {
        setLoading(true);
        
        const details = await contract.getProposalDetails(proposalId);
        const state = await contract.getProposalState(proposalId);
        
        let hasVoted = false;
        if (userAddress) {
          hasVoted = await contract.hasVoted(proposalId, userAddress);
        }

        const now = Math.floor(Date.now() / 1000);
        const votingDeadline = Number(details.votingDeadline);
        const totalVotes = details.votesFor + details.votesAgainst;
        
        const supportPercentage = totalVotes > 0n
          ? Number((details.votesFor * 10000n) / totalVotes) / 100
          : 0;
        
        const participationPercentage = details.totalVotingPower > 0n
          ? Number((totalVotes * 10000n) / details.totalVotingPower) / 100
          : 0;

        const timeRemaining = Math.max(0, votingDeadline - now);
        const canVote = state === ProposalState.Active && !hasVoted && timeRemaining > 0;
        const canQueue = state === ProposalState.Succeeded;
        const canExecute = state === ProposalState.Queued && now >= Number(details.executionETA);

        setProposal({
          id: proposalId,
          amount: details.amount,
          recipient: details.recipient,
          description: details.description,
          snapshotBlock: details.snapshotBlock,
          creationTime: Number(details.creationTime),
          votingDeadline,
          executionETA: Number(details.executionETA),
          votesFor: details.votesFor,
          votesAgainst: details.votesAgainst,
          totalVotingPower: details.totalVotingPower,
          executed: details.executed,
          cancelled: details.cancelled,
          state,
          supportPercentage,
          participationPercentage,
          timeRemaining,
          canVote,
          canQueue,
          canExecute,
        });
        
        setError(null);
      } catch (err) {
        setError(err as Error);
      } finally {
        setLoading(false);
      }
    };

    fetchProposal();
    
    // Refresh every 10 seconds
    const interval = setInterval(fetchProposal, 10000);
    return () => clearInterval(interval);
  }, [contract, proposalId, userAddress]);

  return [proposal, loading, error];
}

/**
 * Hook to get all proposals
 */
export function useProposals(
  contract: Contract | null,
  userAddress: string | null
): [Proposal[], boolean, Error | null] {
  const [proposals, setProposals] = useState<Proposal[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    if (!contract) return;

    const fetchProposals = async () => {
      try {
        setLoading(true);
        
        const count = await contract.proposalCount();
        const proposalPromises = [];
        
        for (let i = 1; i <= Number(count); i++) {
          proposalPromises.push(
            (async () => {
              const details = await contract.getProposalDetails(i);
              const state = await contract.getProposalState(i);
              
              let hasVoted = false;
              if (userAddress) {
                hasVoted = await contract.hasVoted(i, userAddress);
              }

              const now = Math.floor(Date.now() / 1000);
              const votingDeadline = Number(details.votingDeadline);
              const totalVotes = details.votesFor + details.votesAgainst;
              
              const supportPercentage = totalVotes > 0n
                ? Number((details.votesFor * 10000n) / totalVotes) / 100
                : 0;
              
              const participationPercentage = details.totalVotingPower > 0n
                ? Number((totalVotes * 10000n) / details.totalVotingPower) / 100
                : 0;

              const timeRemaining = Math.max(0, votingDeadline - now);
              const canVote = state === ProposalState.Active && !hasVoted && timeRemaining > 0;
              const canQueue = state === ProposalState.Succeeded;
              const canExecute = state === ProposalState.Queued && now >= Number(details.executionETA);

              return {
                id: i,
                amount: details.amount,
                recipient: details.recipient,
                description: details.description,
                snapshotBlock: details.snapshotBlock,
                creationTime: Number(details.creationTime),
                votingDeadline,
                executionETA: Number(details.executionETA),
                votesFor: details.votesFor,
                votesAgainst: details.votesAgainst,
                totalVotingPower: details.totalVotingPower,
                executed: details.executed,
                cancelled: details.cancelled,
                state,
                supportPercentage,
                participationPercentage,
                timeRemaining,
                canVote,
                canQueue,
                canExecute,
              };
            })()
          );
        }
        
        const allProposals = await Promise.all(proposalPromises);
        setProposals(allProposals);
        setError(null);
      } catch (err) {
        setError(err as Error);
      } finally {
        setLoading(false);
      }
    };

    fetchProposals();
    
    // Refresh every 30 seconds
    const interval = setInterval(fetchProposals, 30000);
    return () => clearInterval(interval);
  }, [contract, userAddress]);

  return [proposals, loading, error];
}

/**
 * Hook to get user's voting information for a proposal
 */
export function useUserVotingInfo(
  contract: Contract | null,
  veANDEContract: Contract | null,
  proposalId: number,
  userAddress: string | null
): [UserVotingInfo | null, boolean, Error | null] {
  const [info, setInfo] = useState<UserVotingInfo | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    if (!contract || !veANDEContract || !proposalId || !userAddress) {
      setInfo(null);
      setLoading(false);
      return;
    }

    const fetchVotingInfo = async () => {
      try {
        setLoading(true);
        
        const proposal = await contract.proposals(proposalId);
        const snapshotBlock = proposal.snapshotBlock;
        
        const votingPower = await veANDEContract.getPastVotes(userAddress, snapshotBlock);
        const hasVoted = await contract.hasVoted(proposalId, userAddress);
        const state = await contract.getProposalState(proposalId);
        
        const now = Math.floor(Date.now() / 1000);
        const votingDeadline = Number(proposal.votingDeadline);
        const canVote = state === ProposalState.Active && 
                       !hasVoted && 
                       now < votingDeadline && 
                       votingPower > 0n;

        setInfo({
          votingPower,
          hasVoted,
          canVote,
        });
        
        setError(null);
      } catch (err) {
        setError(err as Error);
      } finally {
        setLoading(false);
      }
    };

    fetchVotingInfo();
  }, [contract, veANDEContract, proposalId, userAddress]);

  return [info, loading, error];
}

// ============================================
// TRANSACTION FUNCTIONS
// ============================================

/**
 * Create a new mint proposal
 */
export async function createProposal(
  contract: Contract,
  amount: bigint,
  recipient: string,
  description: string
): Promise<ethers.ContractTransactionResponse> {
  const tx = await contract.createProposal(amount, recipient, description);
  return tx;
}

/**
 * Cast a vote on a proposal
 */
export async function castVote(
  contract: Contract,
  proposalId: number,
  support: boolean
): Promise<ethers.ContractTransactionResponse> {
  const tx = await contract.castVote(proposalId, support);
  return tx;
}

/**
 * Queue a successful proposal
 */
export async function queueProposal(
  contract: Contract,
  proposalId: number
): Promise<ethers.ContractTransactionResponse> {
  const tx = await contract.queueProposal(proposalId);
  return tx;
}

/**
 * Execute a queued proposal
 */
export async function executeProposal(
  contract: Contract,
  proposalId: number
): Promise<ethers.ContractTransactionResponse> {
  const tx = await contract.executeProposal(proposalId);
  return tx;
}

/**
 * Cancel a proposal
 */
export async function cancelProposal(
  contract: Contract,
  proposalId: number
): Promise<ethers.ContractTransactionResponse> {
  const tx = await contract.cancelProposal(proposalId);
  return tx;
}

// ============================================
// EVENT LISTENERS
// ============================================

/**
 * Setup event listeners for real-time updates
 */
export function setupEventListeners(
  contract: Contract,
  callbacks: {
    onProposalCreated?: (proposalId: number, amount: bigint, recipient: string) => void;
    onVoteCast?: (proposalId: number, voter: string, support: boolean, weight: bigint) => void;
    onProposalQueued?: (proposalId: number, executionETA: number) => void;
    onProposalExecuted?: (proposalId: number, amount: bigint, recipient: string) => void;
    onProposalCancelled?: (proposalId: number) => void;
    onPaused?: () => void;
    onUnpaused?: () => void;
  }
): () => void {
  const { 
    onProposalCreated, 
    onVoteCast, 
    onProposalQueued, 
    onProposalExecuted,
    onProposalCancelled,
    onPaused,
    onUnpaused 
  } = callbacks;

  if (onProposalCreated) {
    contract.on("ProposalCreated", (proposalId, amount, recipient) => {
      onProposalCreated(Number(proposalId), amount, recipient);
    });
  }

  if (onVoteCast) {
    contract.on("VoteCast", (proposalId, voter, support, weight) => {
      onVoteCast(Number(proposalId), voter, support, weight);
    });
  }

  if (onProposalQueued) {
    contract.on("ProposalQueued", (proposalId, executionETA) => {
      onProposalQueued(Number(proposalId), Number(executionETA));
    });
  }

  if (onProposalExecuted) {
    contract.on("ProposalExecuted", (proposalId, amount, recipient) => {
      onProposalExecuted(Number(proposalId), amount, recipient);
    });
  }

  if (onProposalCancelled) {
    contract.on("ProposalCancelled", (proposalId) => {
      onProposalCancelled(Number(proposalId));
    });
  }

  if (onPaused) {
    contract.on("Paused", () => {
      onPaused();
    });
  }

  if (onUnpaused) {
    contract.on("Unpaused", () => {
      onUnpaused();
    });
  }

  // Return cleanup function
  return () => {
    contract.removeAllListeners();
  };
}

// ============================================
// UTILITY FUNCTIONS
// ============================================

/**
 * Format proposal state as human-readable text
 */
export function formatProposalState(state: ProposalState): string {
  const stateNames = {
    [ProposalState.Pending]: "Pending",
    [ProposalState.Active]: "Active",
    [ProposalState.Defeated]: "Defeated",
    [ProposalState.Succeeded]: "Succeeded",
    [ProposalState.Queued]: "Queued",
    [ProposalState.Executed]: "Executed",
    [ProposalState.Cancelled]: "Cancelled",
    [ProposalState.Expired]: "Expired",
  };
  return stateNames[state] || "Unknown";
}

/**
 * Format time remaining as human-readable text
 */
export function formatTimeRemaining(seconds: number): string {
  if (seconds <= 0) return "Ended";
  
  const days = Math.floor(seconds / (24 * 60 * 60));
  const hours = Math.floor((seconds % (24 * 60 * 60)) / (60 * 60));
  const minutes = Math.floor((seconds % (60 * 60)) / 60);
  
  if (days > 0) return `${days}d ${hours}h`;
  if (hours > 0) return `${hours}h ${minutes}m`;
  return `${minutes}m`;
}

/**
 * Calculate if proposal meets requirements
 */
export function meetsRequirements(
  proposal: Proposal,
  quorumPercentage: number
): {
  meetsQuorum: boolean;
  meetsSupermajority: boolean;
  canPass: boolean;
} {
  const totalVotes = proposal.votesFor + proposal.votesAgainst;
  const quorumRequired = (proposal.totalVotingPower * BigInt(quorumPercentage)) / 10000n;
  const meetsQuorum = totalVotes >= quorumRequired;
  
  const supermajorityRequired = 7500; // 75%
  const meetsSupermajority = proposal.supportPercentage >= 75;
  
  return {
    meetsQuorum,
    meetsSupermajority,
    canPass: meetsQuorum && meetsSupermajority,
  };
}

/**
 * Get proposal status color
 */
export function getProposalStatusColor(state: ProposalState): string {
  const colors = {
    [ProposalState.Pending]: "gray",
    [ProposalState.Active]: "blue",
    [ProposalState.Defeated]: "red",
    [ProposalState.Succeeded]: "green",
    [ProposalState.Queued]: "yellow",
    [ProposalState.Executed]: "green",
    [ProposalState.Cancelled]: "red",
    [ProposalState.Expired]: "gray",
  };
  return colors[state] || "gray";
}

/**
 * Validate proposal parameters before creation
 */
export function validateProposalParams(
  amount: bigint,
  recipient: string,
  description: string,
  metrics: GovernanceMetrics
): { valid: boolean; errors: string[] } {
  const errors: string[] = [];
  
  if (amount <= 0n) {
    errors.push("Amount must be greater than zero");
  }
  
  if (amount < metrics.minProposalAmount) {
    errors.push(`Amount must be at least ${ethers.formatUnits(metrics.minProposalAmount, 18)} ANDE`);
  }
  
  if (amount > metrics.maxProposalAmount) {
    errors.push(`Amount cannot exceed ${ethers.formatUnits(metrics.maxProposalAmount, 18)} ANDE`);
  }
  
  if (amount > metrics.remainingAnnualCapacity) {
    errors.push("Amount exceeds remaining annual capacity");
  }
  
  if (amount > metrics.remainingHardCapCapacity) {
    errors.push("Amount exceeds remaining hard cap capacity");
  }
  
  if (!ethers.isAddress(recipient)) {
    errors.push("Invalid recipient address");
  }
  
  if (recipient === ethers.ZeroAddress) {
    errors.push("Cannot send to zero address");
  }
  
  if (!description || description.trim().length === 0) {
    errors.push("Description is required");
  }
  
  if (description.length > 500) {
    errors.push("Description too long (max 500 characters)");
  }
  
  return {
    valid: errors.length === 0,
    errors,
  };
}

// ============================================
// EXAMPLE USAGE IN REACT COMPONENT
// ============================================

/**
 * Example React component showing integration
 */
/*
import React from 'react';

function GovernanceDashboard() {
  const { contract, veANDEContract, userAddress } = useWeb3(); // Your web3 hook
  
  const [metrics, metricsLoading, metricsError] = useGovernanceMetrics(contract);
  const [proposals, proposalsLoading, proposalsError] = useProposals(contract, userAddress);
  
  if (metricsLoading || proposalsLoading) return <div>Loading...</div>;
  if (metricsError || proposalsError) return <div>Error loading data</div>;
  
  return (
    <div>
      <h1>Governance Dashboard</h1>
      
      {metrics && (
        <div>
          <h2>Metrics</h2>
          <p>Total Minted: {ethers.formatUnits(metrics.totalMinted, 18)} ANDE</p>
          <p>Remaining Annual: {ethers.formatUnits(metrics.remainingAnnualCapacity, 18)} ANDE</p>
          <p>Active Proposals: {proposals.filter(p => p.state === ProposalState.Active).length}</p>
        </div>
      )}
      
      <div>
        <h2>Proposals</h2>
        {proposals.map(proposal => (
          <ProposalCard 
            key={proposal.id} 
            proposal={proposal}
            contract={contract}
            userAddress={userAddress}
          />
        ))}
      </div>
    </div>
  );
}
*/