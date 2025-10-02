import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { DualTrackBurnEngine, ANDEToken } from "../typechain-types";
import { time } from "@nomicfoundation/hardhat-network-helpers";

describe("DualTrackBurnEngine", function () {
  let dualTrackBurnEngine: DualTrackBurnEngine;
  let andeToken: ANDEToken;
  let owner: HardhatEthersSigner,
    burner: HardhatEthersSigner,
    otherAccount: HardhatEthersSigner;

  beforeEach(async function () {
    [owner, burner, otherAccount] = await ethers.getSigners();

    // Deploy ANDEToken
    const ANDETokenFactory = await ethers.getContractFactory(
      "ANDEToken",
      owner,
    );
    andeToken = (await upgrades.deployProxy(
      ANDETokenFactory,
      [owner.address, owner.address], // admin and minter
      { initializer: "initialize", kind: "uups" },
    )) as unknown as ANDEToken;
    await andeToken.waitForDeployment();

    // Deploy DualTrackBurnEngine
    const DualTrackBurnEngineFactory = await ethers.getContractFactory(
      "DualTrackBurnEngine",
      owner,
    );
    dualTrackBurnEngine = (await upgrades.deployProxy(
      DualTrackBurnEngineFactory,
      [owner.address, burner.address, await andeToken.getAddress()],
      {
        initializer: "initialize",
        kind: "uups",
      },
    )) as unknown as DualTrackBurnEngine;
    await dualTrackBurnEngine.waitForDeployment();

    // Mint some tokens to the burn engine
    const initialBurnableAmount = ethers.parseUnits("10000", 18);
    await andeToken
      .connect(owner)
      .mint(await dualTrackBurnEngine.getAddress(), initialBurnableAmount);
  });

  describe("Deployment and Initialization", function () {
    it("Should set the right admin, burner, and token address", async function () {
      const ADMIN_ROLE = await dualTrackBurnEngine.DEFAULT_ADMIN_ROLE();
      const BURNER_ROLE = await dualTrackBurnEngine.BURNER_ROLE();

      expect(await dualTrackBurnEngine.hasRole(ADMIN_ROLE, owner.address)).to.be
        .true;
      expect(await dualTrackBurnEngine.hasRole(BURNER_ROLE, burner.address)).to
        .be.true;
      expect(await dualTrackBurnEngine.andeToken()).to.equal(
        await andeToken.getAddress(),
      );
    });
  });

  describe("Impulsive Burn", function () {
    it("Should allow the burner to burn tokens", async function () {
      const burnAmount = ethers.parseUnits("100", 18);
      const initialBalance = await andeToken.balanceOf(
        await dualTrackBurnEngine.getAddress(),
      );
      const initialTotalSupply = await andeToken.totalSupply();

      await dualTrackBurnEngine.connect(burner).impulsiveBurn(burnAmount);

      const finalBalance = await andeToken.balanceOf(
        await dualTrackBurnEngine.getAddress(),
      );
      const finalTotalSupply = await andeToken.totalSupply();

      expect(finalBalance).to.equal(initialBalance - burnAmount);
      expect(finalTotalSupply).to.equal(initialTotalSupply - burnAmount);
    });

    it("Should NOT allow a non-burner to burn tokens", async function () {
      const burnAmount = ethers.parseUnits("100", 18);
      const BURNER_ROLE = await dualTrackBurnEngine.BURNER_ROLE();

      await expect(
        dualTrackBurnEngine.connect(otherAccount).impulsiveBurn(burnAmount),
      )
        .to.be.revertedWithCustomError(
          dualTrackBurnEngine,
          "AccessControlUnauthorizedAccount",
        )
        .withArgs(otherAccount.address, BURNER_ROLE);
    });

    it("Should revert if burn amount is zero", async function () {
      await expect(
        dualTrackBurnEngine.connect(burner).impulsiveBurn(0),
      ).to.be.revertedWith("Burn amount must be positive");
    });

    it("Should revert if burn amount exceeds balance", async function () {
      const balance = await andeToken.balanceOf(
        await dualTrackBurnEngine.getAddress(),
      );
      const burnAmount = balance + ethers.parseUnits("1", 18);

      await expect(
        dualTrackBurnEngine.connect(burner).impulsiveBurn(burnAmount),
      ).to.be.revertedWith("Burn amount exceeds balance");
    });
  });

  describe("Scheduled Burn", function () {
    it("Should NOT allow burning before the schedule period has passed", async function () {
      await expect(dualTrackBurnEngine.scheduledBurn()).to.be.revertedWith(
        "Scheduled burn period not yet passed",
      );
    });

    it("Should allow burning after the schedule period has passed", async function () {
      const schedulePeriod = await dualTrackBurnEngine.SCHEDULE_PERIOD();
      await time.increase(schedulePeriod);

      const initialBalance = await andeToken.balanceOf(
        await dualTrackBurnEngine.getAddress(),
      );
      expect(initialBalance).to.be.gt(0);

      await dualTrackBurnEngine.scheduledBurn();

      const finalBalance = await andeToken.balanceOf(
        await dualTrackBurnEngine.getAddress(),
      );
      expect(finalBalance).to.equal(0);
    });

    it("Should burn the entire contract balance", async function () {
      const schedulePeriod = await dualTrackBurnEngine.SCHEDULE_PERIOD();
      await time.increase(schedulePeriod);

      const initialTotalSupply = await andeToken.totalSupply();
      const initialBalance = await andeToken.balanceOf(
        await dualTrackBurnEngine.getAddress(),
      );

      await dualTrackBurnEngine.scheduledBurn();

      const finalTotalSupply = await andeToken.totalSupply();
      expect(finalTotalSupply).to.equal(initialTotalSupply - initialBalance);
    });

    it("Should reset the lastScheduledBurnTimestamp", async function () {
      const schedulePeriod = await dualTrackBurnEngine.SCHEDULE_PERIOD();
      await time.increase(schedulePeriod);

      const beforeTimestamp =
        await dualTrackBurnEngine.lastScheduledBurnTimestamp();

      await dualTrackBurnEngine.scheduledBurn();

      const afterTimestamp =
        await dualTrackBurnEngine.lastScheduledBurnTimestamp();
      expect(afterTimestamp).to.be.gt(beforeTimestamp);
    });
  });
});
