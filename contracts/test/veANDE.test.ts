import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { VeANDE, ANDEToken } from "../typechain-types";
import { time } from "@nomicfoundation/hardhat-network-helpers";

describe("VeANDE", function () {
  let veANDEContract: VeANDE;
  let andeToken: ANDEToken;
  let owner: HardhatEthersSigner, otherAccount: HardhatEthersSigner;

  beforeEach(async function () {
    [owner, otherAccount] = await ethers.getSigners();

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

    const VeANDEFactory = await ethers.getContractFactory("VeANDE", owner);

    veANDEContract = (await upgrades.deployProxy(
      VeANDEFactory,
      [owner.address, await andeToken.getAddress()],
      {
        initializer: "initialize",
        kind: "uups",
      },
    )) as unknown as VeANDE;

    await veANDEContract.waitForDeployment();
  });

  describe("Deployment", function () {
    it("Should set the right admin and token address", async function () {
      const ADMIN_ROLE = await veANDEContract.DEFAULT_ADMIN_ROLE();
      expect(await veANDEContract.hasRole(ADMIN_ROLE, owner.address)).to.be
        .true;
      expect(await veANDEContract.andeToken()).to.equal(
        await andeToken.getAddress(),
      );
    });
  });

  describe("Locking", function () {
    const lockAmount = ethers.parseUnits("1000", 18);

    beforeEach(async function () {
      // Mint and approve tokens for otherAccount
      await andeToken.mint(otherAccount.address, lockAmount * 2n); // Mint more for increase tests
      await andeToken
        .connect(otherAccount)
        .approve(await veANDEContract.getAddress(), lockAmount * 2n);
    });

    it("Should allow a user to create a lock", async function () {
      const unlockTime = (await time.latest()) + 365 * 24 * 60 * 60; // 1 year

      await veANDEContract
        .connect(otherAccount)
        .createLock(lockAmount, unlockTime);

      const userLock = await veANDEContract.lockedBalances(
        otherAccount.address,
      );
      expect(userLock.amount).to.equal(lockAmount);
      expect(userLock.end).to.equal(unlockTime);

      expect(
        await andeToken.balanceOf(await veANDEContract.getAddress()),
      ).to.equal(lockAmount);
    });

    it("Should allow a user to increase their lock amount", async function () {
      const unlockTime = (await time.latest()) + 365 * 24 * 60 * 60;
      await veANDEContract
        .connect(otherAccount)
        .createLock(lockAmount, unlockTime);

      const additionalAmount = ethers.parseUnits("500", 18);
      await veANDEContract
        .connect(otherAccount)
        .createLock(additionalAmount, unlockTime);

      const userLock = await veANDEContract.lockedBalances(
        otherAccount.address,
      );
      expect(userLock.amount).to.equal(lockAmount + additionalAmount);
    });

    it("Should allow a user to extend their lock time", async function () {
      const initialUnlockTime = (await time.latest()) + 365 * 24 * 60 * 60;
      await veANDEContract
        .connect(otherAccount)
        .createLock(lockAmount, initialUnlockTime);

      const extendedUnlockTime = initialUnlockTime + 365 * 24 * 60 * 60; // Extend by 1 year
      await veANDEContract
        .connect(otherAccount)
        .createLock(0, extendedUnlockTime); // Increase amount by 0

      const userLock = await veANDEContract.lockedBalances(
        otherAccount.address,
      );
      expect(userLock.end).to.equal(extendedUnlockTime);
    });

        it("Should not allow shortening the lock time", async function () {
            const initialUnlockTime = (await time.latest()) + 2 * 365 * 24 * 60 * 60; // 2 years
            await veANDEContract.connect(otherAccount).createLock(lockAmount, initialUnlockTime);
    
            const shorterUnlockTime = initialUnlockTime - 365 * 24 * 60 * 60; // 1 year
            await expect(veANDEContract.connect(otherAccount).createLock(0, shorterUnlockTime))
                .to.be.revertedWithCustomError(veANDEContract, "CannotShortenLockTime");
        });
    
        it("Should allow increasing amount and extending duration simultaneously", async function () {
            const initialUnlockTime = (await time.latest()) + 365 * 24 * 60 * 60;
            await veANDEContract.connect(otherAccount).createLock(lockAmount, initialUnlockTime);
    
            const additionalAmount = ethers.parseUnits("500", 18);
            const extendedUnlockTime = initialUnlockTime + 365 * 24 * 60 * 60;
    
            await veANDEContract.connect(otherAccount).createLock(additionalAmount, extendedUnlockTime);
    
            const userLock = await veANDEContract.lockedBalances(otherAccount.address);
            expect(userLock.amount).to.equal(lockAmount + additionalAmount);
            expect(userLock.end).to.equal(extendedUnlockTime);
        });
    
        it("Should not allow locking for more than 4 years", async function () {
            const fourYears = 4 * 365 * 24 * 60 * 60;
            const oneDay = 24 * 60 * 60;
            const invalidUnlockTime = (await time.latest()) + fourYears + oneDay;
    
            await expect(veANDEContract.connect(otherAccount).createLock(lockAmount, invalidUnlockTime))
                .to.be.revertedWithCustomError(veANDEContract, "LockDurationExceedsMax");
        });
    
        it("Should not allow locking 0 amount if no lock exists", async function () {
            const unlockTime = (await time.latest()) + 365 * 24 * 60 * 60;
            await expect(veANDEContract.connect(otherAccount).createLock(0, unlockTime))
                .to.be.revertedWithCustomError(veANDEContract, "AmountNotPositive");
        });
      });
    
      describe("Withdrawing", function () {
        const lockAmount = ethers.parseUnits("1000", 18);
        let unlockTime: number;
    
        beforeEach(async function () {
            unlockTime = (await time.latest()) + 365 * 24 * 60 * 60; // 1 year
            await andeToken.mint(otherAccount.address, lockAmount);
            await andeToken.connect(otherAccount).approve(await veANDEContract.getAddress(), lockAmount);
            await veANDEContract.connect(otherAccount).createLock(lockAmount, unlockTime);
        });
    
        it("Should not allow withdrawing before lock expires", async function () {
            await expect(veANDEContract.connect(otherAccount).withdraw())
                .to.be.revertedWithCustomError(veANDEContract, "LockNotExpired");
        });
    
        it("Should allow withdrawing after lock expires", async function () {
            await time.increaseTo(unlockTime);
    
            await veANDEContract.connect(otherAccount).withdraw();
    
            expect(await andeToken.balanceOf(otherAccount.address)).to.equal(lockAmount);
            expect(await andeToken.balanceOf(await veANDEContract.getAddress())).to.equal(0);
        });
    
        it("Should reset lock information after withdrawing", async function () {
            await time.increaseTo(unlockTime);
            await veANDEContract.connect(otherAccount).withdraw();
    
            const userLock = await veANDEContract.lockedBalances(otherAccount.address);
            expect(userLock.amount).to.equal(0);
            expect(userLock.end).to.equal(0);
        });
    
        it("Should fail if trying to withdraw with no lock", async function () {
            await expect(veANDEContract.connect(owner).withdraw())
                .to.be.revertedWithCustomError(veANDEContract, "NoLockFound");
        });  });

  describe("Voting Power", function () {
    const lockAmount = ethers.parseUnits("1000", 18);
    const fourYears = 4 * 365 * 24 * 60 * 60;

    it("Should have max voting power for a max-time lock", async function () {
      const unlockTime = (await time.latest()) + fourYears;
      await andeToken.mint(otherAccount.address, lockAmount);
      await andeToken
        .connect(otherAccount)
        .approve(await veANDEContract.getAddress(), lockAmount);
      await veANDEContract
        .connect(otherAccount)
        .createLock(lockAmount, unlockTime);

      const votingPower = await veANDEContract.balanceOf(otherAccount.address);
      // Due to block timestamp progression, voting power will be slightly less than lockAmount
      expect(votingPower).to.be.closeTo(lockAmount, ethers.parseUnits("1", 18));
    });

    it("Should have zero voting power when lock expires", async function () {
      const unlockTime = (await time.latest()) + 365 * 24 * 60 * 60; // 1 year
      await andeToken.mint(otherAccount.address, lockAmount);
      await andeToken
        .connect(otherAccount)
        .approve(await veANDEContract.getAddress(), lockAmount);
      await veANDEContract
        .connect(otherAccount)
        .createLock(lockAmount, unlockTime);

      await time.increaseTo(unlockTime);

      const votingPower = await veANDEContract.balanceOf(otherAccount.address);
      expect(votingPower).to.equal(0);
    });

    it("Should have about half voting power at the halfway point", async function () {
      const unlockTime = (await time.latest()) + fourYears;
      await andeToken.mint(otherAccount.address, lockAmount);
      await andeToken
        .connect(otherAccount)
        .approve(await veANDEContract.getAddress(), lockAmount);
      await veANDEContract
        .connect(otherAccount)
        .createLock(lockAmount, unlockTime);

      await time.increase(fourYears / 2);

      const votingPower = await veANDEContract.balanceOf(otherAccount.address);
      const expectedPower = lockAmount / 2n;

      expect(votingPower).to.be.closeTo(
        expectedPower,
        ethers.parseUnits("1", 18),
      );
    });
  });
});
