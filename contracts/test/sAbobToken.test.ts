import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { sAbobToken, AbobToken } from "../typechain-types";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

describe("sAbobToken (ERC4626 Vault)", function () {

  async function deployVaultFixture() {
    const [owner, user, yieldDepositor] = await ethers.getSigners();

    // Deploy underlying asset: AbobToken
    const AbobTokenFactory = await ethers.getContractFactory("AbobToken");
    const abobToken = await upgrades.deployProxy(AbobTokenFactory, [owner.address, owner.address]) as unknown as AbobToken;
    await abobToken.waitForDeployment();

    // Deploy the vault: sAbobToken
    const sAbobTokenFactory = await ethers.getContractFactory("sAbobToken");
    const vault = await upgrades.deployProxy(sAbobTokenFactory, [owner.address, await abobToken.getAddress()]) as unknown as sAbobToken;
    await vault.waitForDeployment();

    // Grant YIELD_DEPOSITOR_ROLE
    const YIELD_DEPOSITOR_ROLE = await vault.YIELD_DEPOSITOR_ROLE();
    await vault.grantRole(YIELD_DEPOSITOR_ROLE, yieldDepositor.address);

    // Fund user and yield depositor with AbobToken
    await abobToken.grantRole(await abobToken.MINTER_ROLE(), owner.address); // Ensure owner can mint
    await abobToken.mint(user.address, ethers.parseUnits("1000", 18));
    await abobToken.mint(yieldDepositor.address, ethers.parseUnits("100", 18));

    return { vault, abobToken, owner, user, yieldDepositor };
  }

  describe("Deployment", function () {
    it("Should set the correct underlying asset", async function () {
      const { vault, abobToken } = await loadFixture(deployVaultFixture);
      expect(await vault.asset()).to.equal(await abobToken.getAddress());
    });

    it("Should have correct name and symbol", async function () {
        const { vault } = await loadFixture(deployVaultFixture);
        expect(await vault.name()).to.equal("Staked ABOB");
        expect(await vault.symbol()).to.equal("sABOB");
    });
  });

  describe("Core ERC4626 Functions", function () {
    it("Should allow a user to deposit assets and receive shares", async function () {
        const { vault, abobToken, user } = await loadFixture(deployVaultFixture);
        const depositAmount = ethers.parseUnits("100", 18);

        await abobToken.connect(user).approve(await vault.getAddress(), depositAmount);

        // Initially, shares should be 1:1 with assets
        await expect(vault.connect(user).deposit(depositAmount, user.address))
            .to.emit(vault, "Deposit");

        expect(await vault.balanceOf(user.address)).to.equal(depositAmount);
        expect(await vault.totalAssets()).to.equal(depositAmount);
    });

    it("Should allow a user to redeem shares and receive assets", async function () {
        const { vault, abobToken, user } = await loadFixture(deployVaultFixture);
        const depositAmount = ethers.parseUnits("100", 18);

        await abobToken.connect(user).approve(await vault.getAddress(), depositAmount);
        await vault.connect(user).deposit(depositAmount, user.address);

        const shares = await vault.balanceOf(user.address);
        const userInitialAbob = await abobToken.balanceOf(user.address);

        await expect(vault.connect(user).redeem(shares, user.address, user.address))
            .to.emit(vault, "Withdraw");

        expect(await vault.balanceOf(user.address)).to.equal(0);
        expect(await abobToken.balanceOf(user.address)).to.equal(userInitialAbob + depositAmount);
    });
  });

  describe("Yield Accrual", function () {
    it("Should increase the value of shares when yield is deposited", async function () {
        const { vault, abobToken, user, yieldDepositor } = await loadFixture(deployVaultFixture);
        const userDeposit = ethers.parseUnits("100", 18);
        const yieldAmount = ethers.parseUnits("10", 18);

        // 1. User deposits 100 ABOB, gets 100 sABOB shares
        await abobToken.connect(user).approve(await vault.getAddress(), userDeposit);
        await vault.connect(user).deposit(userDeposit, user.address);
        const userShares = await vault.balanceOf(user.address);
        expect(userShares).to.equal(userDeposit);

        // 2. Yield depositor adds 10 ABOB as yield
        await abobToken.connect(yieldDepositor).approve(await vault.getAddress(), yieldAmount);
        await vault.connect(yieldDepositor).depositYield(yieldAmount);

        // 3. Total assets in vault are now 110 ABOB
        expect(await vault.totalAssets()).to.equal(userDeposit + yieldAmount);

        // 4. User redeems their 100 shares and should get back 110 ABOB
        const userInitialAbob = await abobToken.balanceOf(user.address);
        await vault.connect(user).redeem(userShares, user.address, user.address);
        
        expect(await abobToken.balanceOf(user.address)).to.be.closeTo(userInitialAbob + userDeposit + yieldAmount, 2);
    });

    it("Should only allow YIELD_DEPOSITOR_ROLE to deposit yield", async function () {
        const { vault, abobToken, user } = await loadFixture(deployVaultFixture);
        const yieldAmount = ethers.parseUnits("10", 18);

        await abobToken.connect(user).approve(await vault.getAddress(), yieldAmount);
        const YIELD_DEPOSITOR_ROLE = await vault.YIELD_DEPOSITOR_ROLE();

        await expect(vault.connect(user).depositYield(yieldAmount))
            .to.be.revertedWithCustomError(vault, `AccessControlUnauthorizedAccount`)
            .withArgs(user.address, YIELD_DEPOSITOR_ROLE);
    });
  });

});
