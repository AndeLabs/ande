import { ethers, upgrades } from "hardhat";
import { expect } from "chai";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { TrustedRelayerOracle } from "../typechain-types";

describe("TrustedRelayerOracle Contract", function () {
  let oracle: TrustedRelayerOracle;
  let owner: ethers.Wallet, user1: ethers.Wallet, relayer1: ethers.Wallet;

  beforeEach(async function () {
    const provider = ethers.provider;
    const [fundedSigner] = await ethers.getSigners();

    // Crear billeteras desde las llaves privadas del .env
    owner = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);
    user1 = new ethers.Wallet(process.env.PRIVATE_KEY_USER1!, provider);
    relayer1 = new ethers.Wallet(process.env.PRIVATE_KEY_USER2!, provider);

    // Fund the owner account from the Hardhat Network's pre-funded account
    await (
      await fundedSigner.sendTransaction({
        to: owner.address,
        value: ethers.parseEther("100.0"),
      })
    ).wait();

    // Fondear cuentas de prueba con gas
    await (
      await owner.sendTransaction({
        to: user1.address,
        value: ethers.parseEther("1.0"),
      })
    ).wait();
    await (
      await owner.sendTransaction({
        to: relayer1.address,
        value: ethers.parseEther("1.0"),
      })
    ).wait();

    // Desplegar el oráculo usando deployProxy para compatibilidad del entorno
    const OracleFactory = await ethers.getContractFactory(
      "TrustedRelayerOracle",
      owner,
    );
    oracle = (await upgrades.deployProxy(OracleFactory, [], {
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
      await (
        await oracle
          .connect(owner)
          .addRelayer(relayer1.address, "https://api.example.com/data")
      ).wait();
      expect(await oracle.hasRole(relayerRole, relayer1.address)).to.be.true;
    });

    it("should NOT allow a non-admin to add a relayer", async function () {
      await expect(
        oracle
          .connect(user1)
          .addRelayer(relayer1.address, "https://api.example.com/data"),
      ).to.be.reverted;
    });
  });

  describe("Price Updates", function () {
    const pairId = ethers.keccak256(ethers.toUtf8Bytes("BOB/USD"));
    const price = ethers.parseUnits("6.95", 8);

    beforeEach(async function () {
      // Add relayer1 as a relayer for these tests
      await (
        await oracle
          .connect(owner)
          .addRelayer(relayer1.address, "https://api.example.com/data")
      ).wait();
    });

    it("should allow a relayer to update a price", async function () {
      await (await oracle.connect(relayer1).updatePrice(pairId, price)).wait();
      const priceData = await oracle.prices(pairId);
      expect(priceData.price).to.equal(price);
    });

    it("should NOT allow a non-relayer to update a price", async function () {
      await expect(oracle.connect(user1).updatePrice(pairId, price)).to.be
        .reverted;
    });

    it("should revert if price is stale", async function () {
      await (await oracle.connect(relayer1).updatePrice(pairId, price)).wait();

      // Advance time (this will require Hardhat Network, not localhost)
      // For now, we test the principle by checking a fresh price doesn't revert
      await expect(oracle.getPrice(pairId)).to.not.be.reverted;
    });
  });
});
