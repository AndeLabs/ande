import { ethers, upgrades } from "hardhat";
import { expect } from "chai";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { AndeOracleAggregator, TrustedRelayerOracle } from "../typechain-types";

describe("AndeOracleAggregator Contract", function () {
  let aggregator: AndeOracleAggregator;
  let source1: TrustedRelayerOracle;
  let source2: TrustedRelayerOracle;
  let owner: ethers.Wallet,
    user1: ethers.Wallet,
    relayer1: ethers.Wallet,
    relayer2: ethers.Wallet;

  const pairId = ethers.keccak256(ethers.toUtf8Bytes("BOB/USD"));

  beforeEach(async function () {
    const provider = ethers.provider;
    const [fundedSigner] = await ethers.getSigners();

    // Crear billeteras
    owner = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);
    user1 = new ethers.Wallet(process.env.PRIVATE_KEY_USER1!, provider);
    relayer1 = new ethers.Wallet(process.env.PRIVATE_KEY_USER1!, provider); // user1 and relayer1 are the same account
    relayer2 = new ethers.Wallet(process.env.PRIVATE_KEY_USER2!, provider);

    // Fund the owner account from the Hardhat Network's pre-funded account
    await (
      await fundedSigner.sendTransaction({
        to: owner.address,
        value: ethers.parseEther("100.0"),
      })
    ).wait();

    // Fondear cuentas
    await (
      await owner.sendTransaction({
        to: user1.address,
        value: ethers.parseEther("2.0"),
      })
    ).wait(); // Funds user1/relayer1
    await (
      await owner.sendTransaction({
        to: relayer2.address,
        value: ethers.parseEther("2.0"),
      })
    ).wait();

    // Desplegar Aggregator usando deployProxy para compatibilidad
    const AggregatorFactory = await ethers.getContractFactory(
      "AndeOracleAggregator",
      owner,
    );
    aggregator = (await upgrades.deployProxy(AggregatorFactory, [], {
      kind: "transparent",
    })) as unknown as AndeOracleAggregator;
    await aggregator.waitForDeployment();

    // Desplegar Oráculos fuente usando deployProxy
    const OracleFactory = await ethers.getContractFactory(
      "TrustedRelayerOracle",
      owner,
    );
    source1 = (await upgrades.deployProxy(OracleFactory, [], {
      kind: "transparent",
    })) as unknown as TrustedRelayerOracle;
    await source1.waitForDeployment();
    source2 = (await upgrades.deployProxy(OracleFactory, [], {
      kind: "transparent",
    })) as unknown as TrustedRelayerOracle;
    await source2.waitForDeployment();

    // Añadir relayers a los oráculos fuente
    await (
      await source1.connect(owner).addRelayer(relayer1.address, "source1")
    ).wait();
    await (
      await source2.connect(owner).addRelayer(relayer2.address, "source2")
    ).wait();
  });

  describe("Deployment", function () {
    it("should deploy successfully and set the owner", async function () {
      expect(await aggregator.owner()).to.equal(owner.address);
    });
  });

  describe("Source Management", function () {
    it("should allow the owner to add a source", async function () {
      await (
        await aggregator
          .connect(owner)
          .addSource(pairId, await source1.getAddress(), 10000, 1, "Source 1")
      ).wait();
      const sources = await aggregator.sources(pairId, 0);
      expect(sources.oracle).to.equal(await source1.getAddress());
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
    it("should return a price from a single source", async function () {
      const price1 = ethers.parseUnits("6.95", 8);
      await (
        await source1.connect(relayer1).updatePrice(pairId, price1)
      ).wait();
      await (
        await aggregator
          .connect(owner)
          .addSource(pairId, await source1.getAddress(), 10000, 1, "Source 1")
      ).wait();

      const aggregatedPrice = await aggregator.getPrice(pairId);
      expect(aggregatedPrice).to.equal(price1);
    });

    it("should aggregate prices from multiple sources", async function () {
      const price1 = ethers.parseUnits("6.95", 8);
      const price2 = ethers.parseUnits("6.97", 8);
      await (
        await source1.connect(relayer1).updatePrice(pairId, price1)
      ).wait();
      await (
        await source2.connect(relayer2).updatePrice(pairId, price2)
      ).wait();

      await (
        await aggregator
          .connect(owner)
          .addSource(pairId, await source1.getAddress(), 5000, 1, "Source 1")
      ).wait(); // 50% weight
      await (
        await aggregator
          .connect(owner)
          .addSource(pairId, await source2.getAddress(), 5000, 1, "Source 2")
      ).wait(); // 50% weight

      const aggregatedPrice = await aggregator.getPrice(pairId);
      const expectedPrice = (price1 * 5000n + price2 * 5000n) / 10000n;

      expect(aggregatedPrice).to.equal(expectedPrice);
    });

    it("should exclude outliers from aggregation", async function () {
      // Setup: 3 sources, one is a clear outlier.
      const price1 = ethers.parseUnits("6.95", 8);
      const price2 = ethers.parseUnits("6.96", 8);
      const price3_outlier = ethers.parseUnits("8.50", 8); // > 5% deviation

      // Deploy a third source for a stable median
      const OracleFactory = await ethers.getContractFactory(
        "TrustedRelayerOracle",
        owner,
      );
      const source3 = (await upgrades.deployProxy(OracleFactory, [], {
        kind: "transparent",
      })) as unknown as TrustedRelayerOracle;
      await source3.waitForDeployment();
      await (
        await source3.connect(owner).addRelayer(owner.address, "source3")
      ).wait();

      // Update prices
      await (
        await source1.connect(relayer1).updatePrice(pairId, price1)
      ).wait();
      await (
        await source2.connect(relayer2).updatePrice(pairId, price2)
      ).wait();
      await (
        await source3.connect(owner).updatePrice(pairId, price3_outlier)
      ).wait();

      // Add sources to aggregator
      await (
        await aggregator
          .connect(owner)
          .addSource(pairId, await source1.getAddress(), 3333, 1, "Source 1")
      ).wait();
      await (
        await aggregator
          .connect(owner)
          .addSource(pairId, await source2.getAddress(), 3333, 1, "Source 2")
      ).wait();
      await (
        await aggregator
          .connect(owner)
          .addSource(pairId, await source3.getAddress(), 3334, 1, "Source 3")
      ).wait();

      const [price, confidence, sourcesUsed] =
        await aggregator.getPriceWithConfidence(pairId);

      // The median of [6.95, 6.96, 8.50] is 6.96.
      // 8.50 is an outlier relative to 6.96.
      // The final price should be the average of 6.95 and 6.96.
      const expectedPrice = (price1 + price2) / 2n;

      expect(sourcesUsed).to.equal(2);
      expect(price).to.equal(expectedPrice);
    });
  });
});
