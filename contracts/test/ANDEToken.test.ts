import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { ANDEToken } from "../typechain-types";

describe("ANDEToken", function () {
  let andeToken: ANDEToken;
  let owner: HardhatEthersSigner,
    minter: HardhatEthersSigner,
    otherAccount: HardhatEthersSigner;

  beforeEach(async function () {
    [owner, minter, otherAccount] = await ethers.getSigners();

    const ANDETokenFactory = await ethers.getContractFactory(
      "ANDEToken",
      owner,
    );

    // Deploy the proxy
    andeToken = (await upgrades.deployProxy(
      ANDETokenFactory,
      [owner.address, minter.address],
      {
        initializer: "initialize",
        kind: "uups",
      },
    )) as unknown as ANDEToken;

    await andeToken.waitForDeployment();
  });

  describe("Deployment and Initialization", function () {
    it("Should set the right admin and minter", async function () {
      const ADMIN_ROLE = await andeToken.DEFAULT_ADMIN_ROLE();
      const MINTER_ROLE = await andeToken.MINTER_ROLE();

      expect(await andeToken.hasRole(ADMIN_ROLE, owner.address)).to.be.true;
      expect(await andeToken.hasRole(MINTER_ROLE, minter.address)).to.be.true;
    });

    it("Should have the correct name and symbol", async function () {
      expect(await andeToken.name()).to.equal("ANDE Token");
      expect(await andeToken.symbol()).to.equal("ANDE");
    });
  });

  describe("Minting", function () {
    it("Should allow the minter to mint tokens", async function () {
      const mintAmount = ethers.parseUnits("1000", 18);
      await andeToken.connect(minter).mint(otherAccount.address, mintAmount);
      expect(await andeToken.balanceOf(otherAccount.address)).to.equal(
        mintAmount,
      );
    });

    it("Should NOT allow a non-minter to mint tokens", async function () {
      const mintAmount = ethers.parseUnits("1000", 18);
      const MINTER_ROLE = await andeToken.MINTER_ROLE();

      await expect(
        andeToken.connect(otherAccount).mint(otherAccount.address, mintAmount),
      )
        .to.be.revertedWithCustomError(
          andeToken,
          "AccessControlUnauthorizedAccount",
        )
        .withArgs(otherAccount.address, MINTER_ROLE);
    });

    it("Should NOT allow the admin to mint tokens if they don't have the minter role", async function () {
      const mintAmount = ethers.parseUnits("1000", 18);
      const MINTER_ROLE = await andeToken.MINTER_ROLE();

      // Granting admin role but not minter role to `owner`
      await expect(
        andeToken.connect(owner).mint(otherAccount.address, mintAmount),
      )
        .to.be.revertedWithCustomError(
          andeToken,
          "AccessControlUnauthorizedAccount",
        )
        .withArgs(owner.address, MINTER_ROLE);
    });
  });

  describe("Burning", function () {
    it("Should allow a token holder to burn their own tokens", async function () {
      const mintAmount = ethers.parseUnits("1000", 18);
      await andeToken.connect(minter).mint(otherAccount.address, mintAmount);

      const initialBalance = await andeToken.balanceOf(otherAccount.address);
      const initialTotalSupply = await andeToken.totalSupply();

      const burnAmount = ethers.parseUnits("100", 18);
      await andeToken.connect(otherAccount).burn(burnAmount);

      const finalBalance = await andeToken.balanceOf(otherAccount.address);
      const finalTotalSupply = await andeToken.totalSupply();

      expect(finalBalance).to.equal(initialBalance - burnAmount);
      expect(finalTotalSupply).to.equal(initialTotalSupply - burnAmount);
    });
  });

  describe("Votes and Governance", function () {
    it("Should allow a user to delegate their votes", async function () {
      await andeToken.connect(owner).delegate(otherAccount.address);
      expect(await andeToken.delegates(owner.address)).to.equal(
        otherAccount.address,
      );
    });
  });
});
