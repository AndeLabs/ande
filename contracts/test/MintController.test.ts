import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { MintController, ANDEToken, VeANDE } from "../typechain-types";
import { time } from "@nomicfoundation/hardhat-network-helpers";

describe("MintController - Production Test Suite", function () {
  let mintController: MintController;
  let andeToken: ANDEToken;
  let veANDE: VeANDE;
  let admin: HardhatEthersSigner;
  let governance: HardhatEthersSigner;
  let guardian: HardhatEthersSigner;
  let recipient: HardhatEthersSigner;
  let voter1: HardhatEthersSigner;
  let voter2: HardhatEthersSigner;
  let voter3: HardhatEthersSigner;
  let voter4: HardhatEthersSigner;
  let maliciousUser: HardhatEthersSigner;

  const HARD_CAP = ethers.parseUnits("1500000000", 18);
  const ANNUAL_LIMIT = ethers.parseUnits("50000000", 18);
  const MINT_AMOUNT = ethers.parseUnits("5000000", 18);
  const LOCK_AMOUNT = ethers.parseUnits("100000", 18);

  beforeEach(async function () {
    [admin, governance, guardian, recipient, voter1, voter2, voter3, voter4, maliciousUser] =
      await ethers.getSigners();

    const ANDETokenFactory = await ethers.getContractFactory("ANDEToken", admin);
    andeToken = (await upgrades.deployProxy(
      ANDETokenFactory,
      [admin.address, admin.address],
      { initializer: "initialize", kind: "uups" }
    )) as unknown as ANDEToken;
    await andeToken.waitForDeployment();

    const VeANDEFactory = await ethers.getContractFactory("VeANDE", admin);
    veANDE = (await upgrades.deployProxy(
      VeANDEFactory,
      [admin.address, await andeToken.getAddress()],
      { initializer: "initialize", kind: "uups" }
    )) as unknown as VeANDE;
    await veANDE.waitForDeployment();

    const MintControllerFactory = await ethers.getContractFactory("MintController", admin);
    mintController = (await upgrades.deployProxy(
      MintControllerFactory,
      [
        admin.address,
        governance.address,
        guardian.address,
        await andeToken.getAddress(),
        await veANDE.getAddress(),
        HARD_CAP,
        ANNUAL_LIMIT,
      ],
      { initializer: "initialize", kind: "uups" }
    )) as unknown as MintController;
    await mintController.waitForDeployment();

    const MINTER_ROLE = await andeToken.MINTER_ROLE();
    await andeToken.grantRole(MINTER_ROLE, await mintController.getAddress());

    const unlockTime = (await time.latest()) + 4 * 365 * 24 * 60 * 60;
    for (const voter of [voter1, voter2, voter3, voter4]) {
      await andeToken.mint(voter.address, LOCK_AMOUNT);
      await andeToken.connect(voter).approve(await veANDE.getAddress(), LOCK_AMOUNT);
      await veANDE.connect(voter).createLock(LOCK_AMOUNT, unlockTime);
    }

    await time.increase(1);
  });

  async function getVotingPower(voter: HardhatEthersSigner): Promise<bigint> {
    const currentBlock = await ethers.provider.getBlockNumber();
    return await veANDE.getPastVotes(voter.address, currentBlock > 0 ? currentBlock - 1 : 0);
  }

  async function passProposal(proposalId: number, execute: boolean = true): Promise<void> {
    await mintController.connect(voter1).castVote(proposalId, true);
    await mintController.connect(voter2).castVote(proposalId, true);
    await mintController.connect(voter3).castVote(proposalId, true);
    await mintController.connect(voter4).castVote(proposalId, true);
    
    const votingPeriod = await mintController.votingPeriod();
    await time.increase(votingPeriod + 1n);
    
    await mintController.queueProposal(proposalId);
    
    if (execute) {
        const executionDelay = await mintController.executionDelay();
        await time.increase(executionDelay + 1n);
        await mintController.connect(governance).executeProposal(proposalId);
    }
  }

  describe("1. Deployment and Initialization", function () {
    it("Should initialize with correct parameters", async function () {
      expect(await mintController.andeToken()).to.equal(await andeToken.getAddress());
      expect(await mintController.veANDE()).to.equal(await veANDE.getAddress());
      expect(await mintController.hardCap()).to.equal(HARD_CAP);
      expect(await mintController.annualMintLimit()).to.equal(ANNUAL_LIMIT);
    });

    it("Should have correct roles assigned", async function () {
      const GOVERNANCE_ROLE = await mintController.GOVERNANCE_ROLE();
      const GUARDIAN_ROLE = await mintController.GUARDIAN_ROLE();
      const DEFAULT_ADMIN_ROLE = await mintController.DEFAULT_ADMIN_ROLE();

      expect(await mintController.hasRole(DEFAULT_ADMIN_ROLE, admin.address)).to.be.true;
      expect(await mintController.hasRole(GOVERNANCE_ROLE, governance.address)).to.be.true;
      expect(await mintController.hasRole(GUARDIAN_ROLE, guardian.address)).to.be.true;
    });
  });

  describe("2. Proposal Creation - Real World Scenarios", function () {
    it("Should create a valid proposal for ecosystem development", async function () {
      const description = "Fund Q1 2025 ecosystem grants program";
      
      const tx = await mintController
        .connect(governance)
        .createProposal(MINT_AMOUNT, recipient.address, description);
      
      const receipt = await tx.wait();
      const event = receipt?.logs.find(
        (log: any) => log.fragment?.name === "ProposalCreated"
      );
      
      expect(event).to.not.be.undefined;
      
      const proposalId = 1;
      const proposal = await mintController.getProposalCore(proposalId);
      
      expect(proposal.amount).to.equal(MINT_AMOUNT);
      expect(proposal.recipient).to.equal(recipient.address);
      expect(proposal.description).to.equal(description);
    });

    it("Should reject proposal from non-governance role", async function () {
      const GOVERNANCE_ROLE = await mintController.GOVERNANCE_ROLE();
      
      await expect(
        mintController
          .connect(maliciousUser)
          .createProposal(MINT_AMOUNT, recipient.address, "Malicious proposal")
      ).to.be.revertedWithCustomError(mintController, "AccessControlUnauthorizedAccount")
        .withArgs(maliciousUser.address, GOVERNANCE_ROLE);
    });
  });

  describe("3. Voting Mechanics - Real World Scenarios", function () {
    let proposalId: number;

    beforeEach(async function () {
      const tx = await mintController
        .connect(governance)
        .createProposal(MINT_AMOUNT, recipient.address, "Test proposal");
      await tx.wait();
      proposalId = 1;
    });

    it("Should allow voters to cast votes during voting period", async function () {
        const proposalVotesBefore = await mintController.getProposalVotes(proposalId);
        const votePower = await getVotingPower(voter1);
        await expect(mintController.connect(voter1).castVote(proposalId, true))
            .to.emit(mintController, "VoteCast")
            .withArgs(proposalId, voter1.address, true, votePower, proposalVotesBefore.votesFor + votePower, proposalVotesBefore.votesAgainst);
        
        expect(await mintController.hasVoted(proposalId, voter1.address)).to.be.true;
    });

    it("Should allow voting against a proposal", async function () {
      await mintController.connect(voter1).castVote(proposalId, false);
      
      const proposal = await mintController.getProposalVotes(proposalId);
      expect(proposal.votesAgainst).to.be.gt(0);
    });

    it("Should prevent double voting", async function () {
      await mintController.connect(voter1).castVote(proposalId, true);
      
      await expect(
        mintController.connect(voter1).castVote(proposalId, true)
      ).to.be.revertedWithCustomError(mintController, "AlreadyVoted");
    });
  });

  describe("4. Proposal States and Lifecycle", function () {
    let proposalId: number;

    beforeEach(async function () {
      const tx = await mintController
        .connect(governance)
        .createProposal(MINT_AMOUNT, recipient.address, "Lifecycle test");
      await tx.wait();
      proposalId = 1;
    });

    it("Should transition from Active to Succeeded with supermajority", async function () {
      await mintController.connect(voter1).castVote(proposalId, true);
      await mintController.connect(voter2).castVote(proposalId, true);
      await mintController.connect(voter3).castVote(proposalId, true);
      
      const votingPeriod = await mintController.votingPeriod();
      await time.increase(votingPeriod + 1n);
      
      const state = await mintController.getProposalState(proposalId);
      expect(state).to.equal(3); // Succeeded
    });

    it("Should transition to Queued after queueProposal call", async function () {
      await passProposal(proposalId, false);
      
      const state = await mintController.getProposalState(proposalId);
      expect(state).to.equal(4); // Queued
    });
  });

  describe("5. Timelock and Execution", function () {
    let proposalId: number;

    beforeEach(async function () {
      const tx = await mintController
        .connect(governance)
        .createProposal(MINT_AMOUNT, recipient.address, "Timelock test");
      await tx.wait();
      proposalId = 1;
      
      await passProposal(proposalId, false);
    });

    it("Should reject execution before timelock expires", async function () {
      await expect(
        mintController.connect(governance).executeProposal(proposalId)
      ).to.be.revertedWithCustomError(mintController, "ProposalTimelockNotMet");
    });

    it("Should allow execution after timelock expires", async function () {
      const executionDelay = await mintController.executionDelay();
      await time.increase(executionDelay + 1n);
      
      const initialBalance = await andeToken.balanceOf(recipient.address);
      
      await expect(mintController.connect(governance).executeProposal(proposalId))
        .to.emit(mintController, "ProposalExecuted");
      
      const finalBalance = await andeToken.balanceOf(recipient.address);
      expect(finalBalance - initialBalance).to.equal(MINT_AMOUNT);
    });
  });

  describe("6. Economic Limits - Real World Scenarios", function () {
    it("Should enforce annual minting limit", async function () {
      const maxProposals = ANNUAL_LIMIT / MINT_AMOUNT;
      for (let i = 0; i < Number(maxProposals); i++) {
        const tx = await mintController
          .connect(governance)
          .createProposal(MINT_AMOUNT, recipient.address, `Proposal ${i + 1}`);
        await tx.wait();
        await passProposal(i + 1);
      }
      
      await expect(
        mintController
          .connect(governance)
          .createProposal(MINT_AMOUNT, recipient.address, "Over limit")
      ).to.be.revertedWithCustomError(mintController, "ExceedsAnnualLimit");
    });

          it("Should reset annual limit after year boundary", async function () {
            const tx1 = await mintController
              .connect(governance)
              .createProposal(MINT_AMOUNT, recipient.address, "Year 1 Proposal");
            await tx1.wait();
            await passProposal(1);
    
            await time.increase(365 * 24 * 60 * 60 + 1);
            
            const tx2 = await mintController
              .connect(governance)
              .createProposal(MINT_AMOUNT, recipient.address, "Year 2 Proposal");
            await tx2.wait();
            await passProposal(2);
    
            const finalBalance = await andeToken.balanceOf(recipient.address);
            expect(finalBalance).to.equal(MINT_AMOUNT * 2n);
          });  });

  describe("7. Cancellation and Emergency Functions", function () {
    let proposalId: number;

    beforeEach(async function () {
      const tx = await mintController
        .connect(governance)
        .createProposal(MINT_AMOUNT, recipient.address, "Cancellation test");
      await tx.wait();
      proposalId = 1;
    });

    it("Should allow governance to cancel proposal", async function () {
      await expect(mintController.connect(governance).cancelProposal(proposalId))
        .to.emit(mintController, "ProposalCancelled");
      
      const state = await mintController.getProposalState(proposalId);
      expect(state).to.equal(6); // Cancelled
    });

    it("Should prevent voting on cancelled proposal", async function () {
      await mintController.connect(governance).cancelProposal(proposalId);
      
      await expect(
        mintController.connect(voter1).castVote(proposalId, true)
      ).to.be.revertedWithCustomError(mintController, "ProposalIsCancelled");
    });
  });

  describe("8. Pause Functionality", function () {
    it("Should allow guardian to pause and admin to unpause", async function () {
      await mintController.connect(guardian).pause();
      expect(await mintController.paused()).to.be.true;

      await mintController.connect(admin).unpause();
      expect(await mintController.paused()).to.be.false;
    });

    it("Should prevent actions when paused", async function () {
      await mintController.connect(guardian).pause();
      await expect(
        mintController.connect(governance).createProposal(MINT_AMOUNT, recipient.address, "Paused")
      ).to.be.revertedWithCustomError(mintController, "EnforcedPause");
    });
  });

  describe("9. Governance Parameter Updates", function () {
    it("Should allow admin to update governance parameters", async function () {
      const newQuorum = 3000; // 30%
      await mintController.connect(admin).updateGovernanceParameters(newQuorum, 5 * 24 * 60 * 60, 3 * 24 * 60 * 60, 21 * 24 * 60 * 60);
      expect(await mintController.quorumPercentage()).to.equal(newQuorum);
    });
  });

  describe("10. Upgrade Scenarios", function () {
    it("Should allow admin to upgrade contract", async function () {
      const MintControllerV2Factory = await ethers.getContractFactory("MintController", admin);
      const upgraded = await upgrades.upgradeProxy(await mintController.getAddress(), MintControllerV2Factory);
      expect(await upgraded.hardCap()).to.equal(HARD_CAP);
    });
  });
});
