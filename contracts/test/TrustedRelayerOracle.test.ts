import { ethers, upgrades } from "hardhat";
import { expect } from "chai";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { TrustedRelayerOracle } from "../typechain-types";
import { time } from "@nomicfoundation/hardhat-network-helpers";

describe("TrustedRelayerOracle Contract", function () {
  let oracle: TrustedRelayerOracle;
  let owner: HardhatEthersSigner,
    user1: HardhatEthersSigner,
    relayer1: HardhatEthersSigner;

  beforeEach(async function () {
    [owner, user1, relayer1] = await ethers.getSigners();

    const OracleFactory = await ethers.getContractFactory(
      "TrustedRelayerOracle",
      owner,
    );
    oracle = (await upgrades.deployProxy(OracleFactory, [], {
      initializer: "initialize",
      kind: "transparent",
    })) as unknown as TrustedRelayerOracle;
    await oracle.waitForDeployment();
  });

  describe("Deployment", function () {
    it("should deploy successfully and assign admin role", async function () {
      const adminRole = await oracle.ADMIN_ROLE();
      expect(await oracle.hasRole(adminRole, owner.address)).to.be.true;
    });
  });

  describe("Relayer Management", function () {
    it("should allow admin to add a relayer", async function () {
      const relayerRole = await oracle.RELAYER_ROLE();
      await expect(
        oracle
          .connect(owner)
          .addRelayer(relayer1.address, "https://api.example.com/data"),
      ).to.not.be.reverted;
      expect(await oracle.hasRole(relayerRole, relayer1.address)).to.be.true;
    });

    it("should NOT allow a non-admin to add a relayer", async function () {
      const adminRole = await oracle.ADMIN_ROLE();
      await expect(
        oracle
          .connect(user1)
  .addRelayer(relayer1.address, "https://api.example.com/data"),
      ).to.be.revertedWithCustomError(oracle, "AccessControlUnauthorizedAccount").withArgs(user1.address, adminRole);
    });
  });

  describe("Price Updates", function () {
    const pairId = ethers.keccak256(ethers.toUtf8Bytes("BOB/USD"));
    const price = ethers.parseUnits("6.95", 8);

    beforeEach(async function () {
      // Add relayer1 as a relayer for these tests
      await oracle
        .connect(owner)
        .addRelayer(relayer1.address, "https://api.example.com/data");
    });

    it("should allow a relayer to update a price", async function () {
      await expect(oracle.connect(relayer1).updatePrice(pairId, price)).to.not.be
        .reverted;
      const priceData = await oracle.prices(pairId);
      expect(priceData.price).to.equal(price);
    });

    it("should NOT allow a non-relayer to update a price", async function () {
      const relayerRole = await oracle.RELAYER_ROLE();
      await expect(
        oracle.connect(user1).updatePrice(pairId, price),
      ).to.be.revertedWithCustomError(oracle, "AccessControlUnauthorizedAccount").withArgs(user1.address, relayerRole);
    });


    it("should revert if price is stale", async function () {
      await oracle.connect(relayer1).updatePrice(pairId, price);

      // Advance time by more than MAX_PRICE_AGE (5 minutes)
      const MAX_PRICE_AGE = await oracle.MAX_PRICE_AGE();
      await time.increase(MAX_PRICE_AGE + 1n);

      await expect(oracle.getPrice(pairId)).to.be.revertedWithCustomError(
        oracle,
        "PriceStale",
      );
    });

    it("should prevent a relayer from updating too frequently", async function () {
      await oracle.connect(relayer1).updatePrice(pairId, price);

      // Attempt to update again immediately
      await expect(
        oracle.connect(relayer1).updatePrice(pairId, price),
      ).to.be.revertedWith("Action too soon");
    });
  });
});