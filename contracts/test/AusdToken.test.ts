import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { AusdToken, MockERC20, MockOracle } from "../typechain-types";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

describe("AusdToken V2 (Vault)", function () {
  
  async function deployAusdTokenFixture() {
    const [owner, user, collateralManager, pauser] = await ethers.getSigners();

    // Deploy Mock Contracts
    const MockERC20Factory = await ethers.getContractFactory("MockERC20", owner);
    const usdcCollateral = await MockERC20Factory.deploy("Mock USDC", "USDC", 6) as MockERC20;
    await usdcCollateral.waitForDeployment();

    const MockOracleFactory = await ethers.getContractFactory("MockOracle", owner);
    const usdcOracle = await MockOracleFactory.deploy() as MockOracle;
    await usdcOracle.waitForDeployment();
    await usdcOracle.setPrice(ethers.parseUnits("1", 8)); // 1 USD with 8 decimals

    // Deploy AusdToken (Upgradeable)
    const AusdTokenFactory = await ethers.getContractFactory("AusdToken", owner);
    const ausdToken = await upgrades.deployProxy(AusdTokenFactory, [owner.address], {
      kind: 'uups'
    }) as unknown as AusdToken;
    await ausdToken.waitForDeployment();

    // Grant roles
    const COLLATERAL_MANAGER_ROLE = await ausdToken.COLLATERAL_MANAGER_ROLE();
    const PAUSER_ROLE = await ausdToken.PAUSER_ROLE();
    await ausdToken.grantRole(COLLATERAL_MANAGER_ROLE, collateralManager.address);
    await ausdToken.grantRole(PAUSER_ROLE, pauser.address);
    
    await usdcCollateral.mint(user.address, ethers.parseUnits("10000", 6));

    return { ausdToken, usdcCollateral, usdcOracle, owner, user, collateralManager, pauser };
  }

  describe("Deployment and Role Management", function () {
    it("Should have the correct name and symbol", async function () {
      const { ausdToken } = await loadFixture(deployAusdTokenFixture);
      expect(await ausdToken.name()).to.equal("Ande USD");
      expect(await ausdToken.symbol()).to.equal("AUSD");
    });

    it("Should set the right admin and grant roles", async function () {
      const { ausdToken, owner, collateralManager, pauser } = await loadFixture(deployAusdTokenFixture);
      const DEFAULT_ADMIN_ROLE = await ausdToken.DEFAULT_ADMIN_ROLE();
      const COLLATERAL_MANAGER_ROLE = await ausdToken.COLLATERAL_MANAGER_ROLE();
      const PAUSER_ROLE = await ausdToken.PAUSER_ROLE();

      expect(await ausdToken.hasRole(DEFAULT_ADMIN_ROLE, owner.address)).to.be.true;
      expect(await ausdToken.hasRole(COLLATERAL_MANAGER_ROLE, collateralManager.address)).to.be.true;
      expect(await ausdToken.hasRole(PAUSER_ROLE, pauser.address)).to.be.true;
    });
  });

  describe("Collateral Management", function () {
    it("Should allow COLLATERAL_MANAGER to add a collateral type", async function () {
      const { ausdToken, usdcCollateral, usdcOracle, collateralManager } = await loadFixture(deployAusdTokenFixture);
      const usdcAddress = await usdcCollateral.getAddress();
      const oracleAddress = await usdcOracle.getAddress();
      
      await expect(
        ausdToken.connect(collateralManager).addCollateralType(usdcAddress, 12000, oracleAddress) // 120% ratio
      ).to.emit(ausdToken, "CollateralAdded")
        .withArgs(usdcAddress, 12000, oracleAddress);

      const collateralInfo = await ausdToken.collateralTypes(usdcAddress);
      expect(collateralInfo.isSupported).to.be.true;
      expect(collateralInfo.overCollateralizationRatio).to.equal(12000);
    });

    it("Should NOT allow a non-manager to add a collateral type", async function () {
      const { ausdToken, usdcCollateral, usdcOracle, user } = await loadFixture(deployAusdTokenFixture);
      const usdcAddress = await usdcCollateral.getAddress();
      const oracleAddress = await usdcOracle.getAddress();
      const COLLATERAL_MANAGER_ROLE = await ausdToken.COLLATERAL_MANAGER_ROLE();

      await expect(
        ausdToken.connect(user).addCollateralType(usdcAddress, 12000, oracleAddress)
      ).to.be.revertedWithCustomError(ausdToken, `AccessControlUnauthorizedAccount`)
       .withArgs(user.address, COLLATERAL_MANAGER_ROLE);
    });

    it("Should revert if collateral ratio is less than 100%", async function () {
        const { ausdToken, usdcCollateral, usdcOracle, collateralManager } = await loadFixture(deployAusdTokenFixture);
        await expect(
            ausdToken.connect(collateralManager).addCollateralType(await usdcCollateral.getAddress(), 9999, await usdcOracle.getAddress())
        ).to.be.revertedWithCustomError(ausdToken, "InvalidCollateralizationRatio");
    });
  });

  describe("Core Vault Logic: depositAndMint & burnAndWithdraw", function () {
    let ausdToken: AusdToken;
    let usdcCollateral: MockERC20;
    let user: HardhatEthersSigner;
    let usdcAddress: string;

    beforeEach(async function () {
      const fixture = await loadFixture(deployAusdTokenFixture);
      ausdToken = fixture.ausdToken;
      usdcCollateral = fixture.usdcCollateral;
      user = fixture.user;
      usdcAddress = await usdcCollateral.getAddress();

      // Add USDC as a supported collateral with 120% ratio
      await ausdToken.connect(fixture.collateralManager).addCollateralType(usdcAddress, 12000, await fixture.usdcOracle.getAddress());
    });

    it("Should allow a user to deposit collateral and mint AUSD", async function () {
      const depositAmount = ethers.parseUnits("120", 6); // 120 USDC (6 decimals)

      await usdcCollateral.connect(user).approve(await ausdToken.getAddress(), depositAmount);

      const expectedAusdAmount = ethers.parseUnits("100", 18);

      await expect(
        ausdToken.connect(user).depositAndMint(usdcAddress, depositAmount)
      ).to.emit(ausdToken, "Minted")
        .withArgs(user.address, usdcAddress, depositAmount, expectedAusdAmount);
      
      expect(await ausdToken.balanceOf(user.address)).to.equal(expectedAusdAmount);
      expect(await usdcCollateral.balanceOf(await ausdToken.getAddress())).to.equal(depositAmount);
    });

    it("Should fail to mint if collateral is not supported", async function () {
        const fakeCollateralAddress = ethers.Wallet.createRandom().address;
        await expect(
            ausdToken.connect(user).depositAndMint(fakeCollateralAddress, 100)
        ).to.be.revertedWithCustomError(ausdToken, "CollateralNotSupported");
    });

    it("Should allow a user to burn AUSD and withdraw collateral", async function () {
        const depositAmount = ethers.parseUnits("120", 6);
        const ausdToMint = ethers.parseUnits("100", 18);

        // First, deposit and mint
        await usdcCollateral.connect(user).approve(await ausdToken.getAddress(), depositAmount);
        await ausdToken.connect(user).depositAndMint(usdcAddress, depositAmount);
        expect(await ausdToken.balanceOf(user.address)).to.equal(ausdToMint);

        // Now, burn and withdraw
        const userInitialUsdc = await usdcCollateral.balanceOf(user.address);
        await expect(
            ausdToken.connect(user).burnAndWithdraw(usdcAddress, ausdToMint)
        ).to.emit(ausdToken, "Burned");

        expect(await ausdToken.balanceOf(user.address)).to.equal(0);
        expect(await usdcCollateral.balanceOf(user.address)).to.equal(userInitialUsdc + depositAmount);
    });
  });
});
