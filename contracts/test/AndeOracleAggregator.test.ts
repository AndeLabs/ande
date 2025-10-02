import { ethers, upgrades } from "hardhat";
import { expect } from "chai";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import {
  AndeOracleAggregator,
  TrustedRelayerOracle,
} from "../typechain-types";
import { time } from "@nomicfoundation/hardhat-network-helpers";

describe("AndeOracleAggregator Contract", function () {
  let aggregator: AndeOracleAggregator;
  let source1: TrustedRelayerOracle;
  let source2: TrustedRelayerOracle;
  let source3: TrustedRelayerOracle;
  let owner: HardhatEthersSigner,
    user1: HardhatEthersSigner,
    relayer1: HardhatEthersSigner,
    relayer2: HardhatEthersSigner,
    relayer3: HardhatEthersSigner;

  const pairId = ethers.keccak256(ethers.toUtf8Bytes("BOB/USD"));

  beforeEach(async function () {
    [owner, user1, relayer1, relayer2, relayer3] = await ethers.getSigners();

    // Deploy Aggregator
    const AggregatorFactory = await ethers.getContractFactory(
      "AndeOracleAggregator",
      owner,
    );
    aggregator = (await upgrades.deployProxy(AggregatorFactory, [], {
      initializer: "initialize",
      kind: "transparent",
    })) as unknown as AndeOracleAggregator;
    await aggregator.waitForDeployment();

    // Deploy Source Oracles
    const OracleFactory = await ethers.getContractFactory(
      "TrustedRelayerOracle",
      owner,
    );
    source1 = (await upgrades.deployProxy(OracleFactory, [], {
      initializer: "initialize",
      kind: "transparent",
    })) as unknown as TrustedRelayerOracle;
    source2 = (await upgrades.deployProxy(OracleFactory, [], {
      initializer: "initialize",
      kind: "transparent",
    })) as unknown as TrustedRelayerOracle;
    source3 = (await upgrades.deployProxy(OracleFactory, [], {
      initializer: "initialize",
      kind: "transparent",
    })) as unknown as TrustedRelayerOracle;
    await Promise.all([
      source1.waitForDeployment(),
      source2.waitForDeployment(),
      source3.waitForDeployment(),
    ]);

    // Add relayers to source oracles
    await Promise.all([
      source1.connect(owner).addRelayer(relayer1.address, "source1"),
      source2.connect(owner).addRelayer(relayer2.address, "source2"),
      source3.connect(owner).addRelayer(relayer3.address, "source3"),
    ]);
  });

  describe("Deployment", function () {
    it("should deploy successfully and set the owner", async function () {
      expect(await aggregator.owner()).to.equal(owner.address);
    });
  });

  describe("Source Management", function () {
    it("should allow the owner to add a source", async function () {
      await expect(
        aggregator
          .connect(owner)
          .addSource(pairId, await source1.getAddress(), 10000, 1, "Source 1"),
      ).to.not.be.reverted;
      const sources = await aggregator.getSourcesForPair(pairId);
      expect(sources.length).to.equal(1);
      expect(sources[0].oracle).to.equal(await source1.getAddress());
    });

    it("should NOT allow a non-owner to add a source", async function () {
      await expect(
        aggregator
          .connect(user1)
          .addSource(pairId, await source1.getAddress(), 10000, 1, "Source 1"),
      )
        .to.be.revertedWithCustomError(aggregator, "OwnableUnauthorizedAccount")
        .withArgs(user1.address);
    });
  });

  describe("Price Aggregation", function () {
    beforeEach(async function () {
      // Add sources to aggregator
      await aggregator
        .connect(owner)
        .addSource(pairId, await source1.getAddress(), 3333, 1, "Source 1");
      await aggregator
        .connect(owner)
        .addSource(pairId, await source2.getAddress(), 3333, 1, "Source 2");
      await aggregator
        .connect(owner)
        .addSource(pairId, await source3.getAddress(), 3334, 1, "Source 3");
    });

    it("should revert if there are not enough active sources", async function () {
      // Two sources are active, but one is not updated.
      const price1 = ethers.parseUnits("6.95", 8);
      await source1.connect(relayer1).updatePrice(pairId, price1);

      // MIN_SOURCES is 3, so this should fail
      await expect(
        aggregator.getPrice(pairId),
      ).to.be.revertedWithCustomError(aggregator, "InsufficientSources");
    });

    it("should aggregate prices from multiple sources", async function () {
      const price1 = ethers.parseUnits("6.95", 8);
      const price2 = ethers.parseUnits("6.97", 8);
      const price3 = ethers.parseUnits("6.96", 8);

      await source1.connect(relayer1).updatePrice(pairId, price1);
      await time.increase(61); // Avoid rate limit
      await source2.connect(relayer2).updatePrice(pairId, price2);
      await time.increase(61); // Avoid rate limit
      await source3.connect(relayer3).updatePrice(pairId, price3);

      await aggregator.connect(owner).updateCache(pairId);

      const aggregatedPrice = await aggregator.getPrice(pairId);
      const expectedPrice = (price1 * 3333n + price2 * 3333n + price3 * 3334n) / 10000n;

      expect(aggregatedPrice).to.be.closeTo(expectedPrice, 1);
    });

    it("should exclude outliers from aggregation", async function () {
      const price1 = ethers.parseUnits("6.95", 8);
      const price2 = ethers.parseUnits("6.96", 8);
      const price3_outlier = ethers.parseUnits("8.50", 8); // > 5% deviation

      await source1.connect(relayer1).updatePrice(pairId, price1);
      await time.increase(61);
      await source2.connect(relayer2).updatePrice(pairId, price2);
      await time.increase(61);
      await source3.connect(relayer3).updatePrice(pairId, price3_outlier);

      const [price, confidence, sourcesUsed] =
        await aggregator.getPriceWithConfidence(pairId);

      // The median of [6.95, 6.96, 8.50] is 6.96.
      // 8.50 is an outlier relative to 6.96 and should be excluded.
      // The final price should be the weighted average of 6.95 and 6.96.
      const expectedPrice = (price1 * 3333n + price2 * 3333n) / (3333n + 3333n);

      expect(sourcesUsed).to.equal(2);
      expect(price).to.be.closeTo(expectedPrice, 1);
    });
  });
});