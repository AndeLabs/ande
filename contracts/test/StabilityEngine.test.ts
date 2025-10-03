import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import {
    StabilityEngine, 
    AbobToken, 
    MockERC20, 
    MockOracle
} from "../typechain-types";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

describe("StabilityEngine", function () {

  async function deployEngineFixture() {
    const [owner, user] = await ethers.getSigners();

    // Deploy mock tokens and oracle
    const MockERC20Factory = await ethers.getContractFactory("MockERC20");
    const andeToken = await MockERC20Factory.deploy("ANDE Token", "ANDE", 18) as MockERC20;
    const ausdToken = await MockERC20Factory.deploy("Ande USD", "AUSD", 18) as MockERC20;

    const MockOracleFactory = await ethers.getContractFactory("MockOracle");
    const andeOracle = await MockOracleFactory.deploy() as MockOracle;

    const AbobTokenFactory = await ethers.getContractFactory("AbobToken");
    const abobToken = await upgrades.deployProxy(AbobTokenFactory, [owner.address, owner.address]) as unknown as AbobToken;

    // Deploy the StabilityEngine with the mock oracle
    const StabilityEngineFactory = await ethers.getContractFactory("StabilityEngine");
    const engine = await upgrades.deployProxy(StabilityEngineFactory, [
        owner.address,
        await abobToken.getAddress(),
        await ausdToken.getAddress(),
        await andeToken.getAddress(),
        await andeOracle.getAddress() // Injecting mock oracle here
    ]) as unknown as StabilityEngine;
    await engine.waitForDeployment();

    // Grant MINTER_ROLE to the engine
    const MINTER_ROLE = await abobToken.MINTER_ROLE();
    await abobToken.grantRole(MINTER_ROLE, await engine.getAddress());

    // Fund user with collateral
    await ausdToken.mint(user.address, ethers.parseUnits("1000", 18));
    await andeToken.mint(user.address, ethers.parseUnits("500", 18));

    return { engine, abobToken, ausdToken, andeToken, andeOracle, owner, user };
  }

  describe("Deployment and Configuration", function () {
    it("Should set the correct addresses and initial ratio", async function () {
      const { engine, abobToken, ausdToken, andeToken, andeOracle } = await loadFixture(deployEngineFixture);
      
      expect(await engine.abobToken()).to.equal(await abobToken.getAddress());
      expect(await engine.ausdToken()).to.equal(await ausdToken.getAddress());
      expect(await engine.andeToken()).to.equal(await andeToken.getAddress());
      expect(await engine.andeOracle()).to.equal(await andeOracle.getAddress());

      const ratio = await engine.ratio();
      expect(ratio.ausd).to.equal(80);
      expect(ratio.ande).to.equal(20);
    });
  });

  describe("Minting and Burning Logic", function() {
    let engine: StabilityEngine;
    let abobToken: AbobToken;
    let ausdToken: MockERC20;
    let andeToken: MockERC20;
    let user: HardhatEthersSigner;

    beforeEach(async function() {
        const fixture = await loadFixture(deployEngineFixture);
        engine = fixture.engine;
        abobToken = fixture.abobToken;
        ausdToken = fixture.ausdToken;
        andeToken = fixture.andeToken;
        user = fixture.user;

        // Set ANDE price to $2 for all tests in this block
        const andePrice = ethers.parseUnits("2", 18);
        await fixture.andeOracle.setPrice(andePrice);
    });

    it("Should mint ABOB and take correct collateral amounts", async function() {
        const amountToMint = ethers.parseUnits("100", 18); // 100 ABOB

        // Expected collateral: 80 AUSD (80% of 100), 10 ANDE (20% of 100 = 20 value / $2 price)
        const expectedAusd = ethers.parseUnits("80", 18);
        const expectedAnde = ethers.parseUnits("10", 18);

        // Approve transfers
        await ausdToken.connect(user).approve(await engine.getAddress(), expectedAusd);
        await andeToken.connect(user).approve(await engine.getAddress(), expectedAnde);

        const userInitialAusd = await ausdToken.balanceOf(user.address);
        const userInitialAnde = await andeToken.balanceOf(user.address);

        await expect(engine.connect(user).mint(amountToMint))
            .to.emit(engine, "AbobMinted")
            .withArgs(user.address, amountToMint, expectedAusd, expectedAnde);

        // Check balances
        expect(await abobToken.balanceOf(user.address)).to.equal(amountToMint);
        expect(await ausdToken.balanceOf(user.address)).to.equal(userInitialAusd - expectedAusd);
        expect(await andeToken.balanceOf(user.address)).to.equal(userInitialAnde - expectedAnde);
    });

    it("Should burn ABOB and return correct collateral amounts", async function() {
        // Mint 100 ABOB first
        const amountToMintAndBurn = ethers.parseUnits("100", 18);
        const requiredAusd = ethers.parseUnits("80", 18);
        const requiredAnde = ethers.parseUnits("10", 18);
        await ausdToken.connect(user).approve(await engine.getAddress(), requiredAusd);
        await andeToken.connect(user).approve(await engine.getAddress(), requiredAnde);
        await engine.connect(user).mint(amountToMintAndBurn);

        // Now, test burning
        const userInitialAusd = await ausdToken.balanceOf(user.address);
        const userInitialAnde = await andeToken.balanceOf(user.address);

        // User approves the engine to burn their ABOB
        await abobToken.connect(user).approve(await engine.getAddress(), amountToMintAndBurn);

        // The burn function in the engine should call `burnFrom` on the token.
        // Let's modify the engine to do so.
        // For the test, we assume the user has approved the engine.
        // We also need to modify the AbobToken to have a burnFrom function accessible by the minter.
        // Let's assume the ERC20Burnable `burnFrom` is used.

        await expect(engine.connect(user).burn(amountToMintAndBurn))
            .to.emit(engine, "AbobBurned")
            .withArgs(user.address, amountToMintAndBurn, requiredAusd, requiredAnde);

        // Check balances
        expect(await abobToken.balanceOf(user.address)).to.equal(0);
        expect(await ausdToken.balanceOf(user.address)).to.equal(userInitialAusd + requiredAusd);
        expect(await andeToken.balanceOf(user.address)).to.equal(userInitialAnde + requiredAnde);
    });
  });

  describe("Admin Functions", function() {
    it("Should allow admin to set a new ratio", async function() {
        const { engine, owner } = await loadFixture(deployEngineFixture);
        await engine.connect(owner).setRatio(70, 30);
        const newRatio = await engine.ratio();
        expect(newRatio.ausd).to.equal(70);
        expect(newRatio.ande).to.equal(30);
    });

    it("Should revert if ratios do not sum to 100", async function() {
        const { engine, owner } = await loadFixture(deployEngineFixture);
        await expect(engine.connect(owner).setRatio(70, 29))
            .to.be.revertedWith("Ratios must sum to 100");
    });
  });
});
