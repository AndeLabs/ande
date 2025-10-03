import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { P2POracleV2, MockERC20 } from "../typechain-types";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { time } from "@nomicfoundation/hardhat-network-helpers";

describe("P2POracleV2", function () {

  const MIN_STAKE = ethers.parseUnits("1000", 18);
  const EPOCH_DURATION = 3600; // 1 hour

  async function deployOracleFixture() {
    const [owner, finalizer, reporter1, reporter2, reporter3] = await ethers.getSigners();

    // Deploy Mock ANDE Token
    const MockERC20Factory = await ethers.getContractFactory("MockERC20");
    const andeToken = await MockERC20Factory.deploy("ANDE Token", "ANDE", 18) as MockERC20;
    await andeToken.waitForDeployment();
    const andeTokenAddress = await andeToken.getAddress();

    // Deploy P2POracleV2 (Upgradeable)
    const P2POracleV2Factory = await ethers.getContractFactory("P2POracleV2");
    const oracle = await upgrades.deployProxy(P2POracleV2Factory, [owner.address, andeTokenAddress, MIN_STAKE, EPOCH_DURATION], {
      kind: 'uups'
    }) as unknown as P2POracleV2;
    await oracle.waitForDeployment();

    // Grant roles
    const FINALIZER_ROLE = await oracle.FINALIZER_ROLE();
    await oracle.grantRole(FINALIZER_ROLE, finalizer.address);

    // Fund reporters
    await andeToken.mint(reporter1.address, MIN_STAKE);
    await andeToken.mint(reporter2.address, MIN_STAKE);
    await andeToken.mint(reporter3.address, MIN_STAKE);

    return { oracle, andeToken, owner, finalizer, reporter1, reporter2, reporter3 };
  }

  describe("Deployment and Configuration", function () {
    it("Should set the correct initial values", async function () {
      const { oracle, andeToken } = await loadFixture(deployOracleFixture);
      expect(await oracle.andeToken()).to.equal(await andeToken.getAddress());
      expect(await oracle.minStake()).to.equal(MIN_STAKE);
      expect(await oracle.reportEpochDuration()).to.equal(EPOCH_DURATION);
    });
  });

  describe("Reporter Management", function () {
    it("Should allow a user to register as a reporter", async function () {
      const { oracle, andeToken, reporter1 } = await loadFixture(deployOracleFixture);
      
      // Approve token transfer
      await andeToken.connect(reporter1).approve(await oracle.getAddress(), MIN_STAKE);

      await expect(oracle.connect(reporter1).register())
        .to.emit(oracle, "ReporterRegistered")
        .withArgs(reporter1.address, MIN_STAKE);

      const reporterInfo = await oracle.reporters(reporter1.address);
      expect(reporterInfo.isRegistered).to.be.true;
      expect(reporterInfo.stake).to.equal(MIN_STAKE);
      expect(await andeToken.balanceOf(await oracle.getAddress())).to.equal(MIN_STAKE);
    });

    it("Should fail if user does not approve token transfer", async function () {
        const { oracle, andeToken, reporter1 } = await loadFixture(deployOracleFixture);
        await expect(oracle.connect(reporter1).register()).to.be.revertedWithCustomError(andeToken, "ERC20InsufficientAllowance");
    });
  });

  describe("Price Reporting and Finalization", function () {
    async function registeredFixture() {
        const baseFix = await loadFixture(deployOracleFixture);
        const { oracle, andeToken, reporter1, reporter2, reporter3 } = baseFix;

        // Register all reporters
        await andeToken.connect(reporter1).approve(await oracle.getAddress(), MIN_STAKE);
        await oracle.connect(reporter1).register();
        await andeToken.connect(reporter2).approve(await oracle.getAddress(), MIN_STAKE);
        await oracle.connect(reporter2).register();
        await andeToken.connect(reporter3).approve(await oracle.getAddress(), MIN_STAKE);
        await oracle.connect(reporter3).register();

        return baseFix;
    }

    it("Should allow registered reporters to report a price", async function () {
        const { oracle, reporter1 } = await loadFixture(registeredFixture);
        const price = ethers.parseUnits("1.5", 18);

        await expect(oracle.connect(reporter1).reportPrice(price))
            .to.emit(oracle, "PriceReported");
    });

    it("Should NOT allow reporting twice in the same epoch", async function () {
        const { oracle, reporter1 } = await loadFixture(registeredFixture);
        const price = ethers.parseUnits("1.5", 18);
        await oracle.connect(reporter1).reportPrice(price);

        await expect(oracle.connect(reporter1).reportPrice(price))
            .to.be.revertedWith("Already reported this epoch");
    });

    it("Should NOT finalize epoch with less than 3 reports", async function () {
        const { oracle, finalizer, reporter1 } = await loadFixture(registeredFixture);
        await oracle.connect(reporter1).reportPrice(ethers.parseUnits("1.5", 18));

        // Advance time to next epoch to allow finalization
        await time.increase(EPOCH_DURATION);

        await expect(oracle.connect(finalizer).finalizeCurrentEpoch())
            .to.be.revertedWith("Not enough reports to finalize");
    });

    it("Should finalize epoch with enough reports", async function () {
        const { oracle, finalizer, reporter1, reporter2, reporter3 } = await loadFixture(registeredFixture);
        const price1 = ethers.parseUnits("1.5", 18);
        const price2 = ethers.parseUnits("1.51", 18);
        const price3 = ethers.parseUnits("1.49", 18);

        await oracle.connect(reporter1).reportPrice(price1);
        await oracle.connect(reporter2).reportPrice(price2);
        await oracle.connect(reporter3).reportPrice(price3);

        const currentEpoch = await oracle.currentEpoch();

        // Advance time to next epoch to allow finalization
        await time.increase(EPOCH_DURATION);

        await expect(oracle.connect(finalizer).finalizeCurrentEpoch())
            .to.emit(oracle, "EpochFinalized");
        
        // Note: The price logic is simplified in the contract, so we check that a price was set.
        expect(await oracle.finalizedPrices(currentEpoch)).to.not.equal(0);
    });

    it("Should return the last finalized price", async function () {
        const { oracle, finalizer, reporter1, reporter2, reporter3 } = await loadFixture(registeredFixture);
        const price1 = ethers.parseUnits("1.5", 18);
        await oracle.connect(reporter1).reportPrice(price1);
        await oracle.connect(reporter2).reportPrice(ethers.parseUnits("1.51", 18));
        await oracle.connect(reporter3).reportPrice(ethers.parseUnits("1.49", 18));

        await time.increase(EPOCH_DURATION);
        await oracle.connect(finalizer).finalizeCurrentEpoch();

        expect(await oracle.getPrice()).to.equal(price1); // Because of simplified logic
    });
  });
});
