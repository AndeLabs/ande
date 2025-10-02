import { ethers, upgrades } from "hardhat";
import { expect } from "chai";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { ANDEToken, veANDE } from "../typechain-types";

describe("veANDE Contract", function () {
    let andeToken: ANDEToken;
    let veANDEContract: veANDE;
    let owner: HardhatEthersSigner;
    let user1: HardhatEthersSigner;

    const LOCK_AMOUNT = ethers.parseEther("1000");

    async function deployContracts() {
        [owner, user1] = await ethers.getSigners();

        // Fund user1 with 1 aande for gas fees FIRST, and wait for it to be mined.
        const tx = await owner.sendTransaction({ to: user1.address, value: ethers.parseEther("1.0") });
        await tx.wait();

        const ANDETokenFactory = await ethers.getContractFactory("ANDEToken");
        andeToken = (await upgrades.deployProxy(ANDETokenFactory, [owner.address, owner.address], {
            kind: "uups",
        })) as unknown as ANDEToken;
        await andeToken.waitForDeployment();

        const veANDEFactory = await ethers.getContractFactory("veANDE");
        veANDEContract = (await upgrades.deployProxy(veANDEFactory, [await andeToken.getAddress(), owner.address], {
            kind: "uups",
        })) as unknown as veANDE;
        await veANDEContract.waitForDeployment();

        // Now that contracts are deployed, mint the ERC20 tokens to user1
        await andeToken.connect(owner).mint(user1.address, LOCK_AMOUNT);
        // And have user1 approve the veANDE contract to spend them, then wait for confirmation
        const approveTx = await andeToken.connect(user1).approve(await veANDEContract.getAddress(), LOCK_AMOUNT);
        await approveTx.wait();
    }

    describe("createLock", function () {
        beforeEach(async function () {
            await deployContracts();
        });

        it("should allow a user to lock tokens and update balances correctly", async function () {
            const lockDuration = 365 * 24 * 60 * 60; // 1 year
            const latestTimestamp = (await ethers.provider.getBlock("latest"))!.timestamp;
            const unlockTimestamp = latestTimestamp + lockDuration;

            // Diagnostic: Check the allowance right before the call
            const allowance = await andeToken.allowance(user1.address, await veANDEContract.getAddress());
            console.log(`\t🔎 Allowance: ${ethers.formatEther(allowance)} ANDE`);
            expect(allowance).to.equal(LOCK_AMOUNT);

            try {
                const tx = await veANDEContract.connect(user1).createLock(LOCK_AMOUNT, unlockTimestamp);
                await tx.wait();
            } catch (error) {
                console.log("\n\n❌ Transaction reverted with error:", error);
                // Re-throw the error to still fail the test, but after logging the details
                throw error;
            }

            // User1's balance of ERC20 ANDE should be 0
            expect(await andeToken.balanceOf(user1.address)).to.equal(0);
            // The veANDE contract should now hold the locked tokens
            expect(await andeToken.balanceOf(await veANDEContract.getAddress())).to.equal(LOCK_AMOUNT);

            const userLock = await veANDEContract.lockedBalances(user1.address);
            const WEEK = 7 * 24 * 60 * 60;
            const expectedRoundedUnlockTime = Math.floor(unlockTimestamp / WEEK) * WEEK;

            expect(userLock.amount).to.equal(LOCK_AMOUNT);
            expect(userLock.unlockTime).to.equal(expectedRoundedUnlockTime);
        });

        it("should fail if amount is zero", async function () {
            const latestTimestamp = (await ethers.provider.getBlock("latest"))!.timestamp;
            const unlockTimestamp = latestTimestamp + (365 * 24 * 60 * 60);
            await expect(veANDEContract.connect(user1).createLock(0, unlockTimestamp))
                .to.be.revertedWith("veANDE: Cannot lock 0 tokens");
        });

        it("should fail if unlock time is in the past", async function () {
            const latestTimestamp = (await ethers.provider.getBlock("latest"))!.timestamp;
            const unlockTimestamp = latestTimestamp - 1;
            await expect(veANDEContract.connect(user1).createLock(LOCK_AMOUNT, unlockTimestamp))
                .to.be.revertedWith("veANDE: Unlock time must be in the future");
        });

        it("should fail if trying to lock again without withdrawing", async function () {
            const latestTimestamp = (await ethers.provider.getBlock("latest"))!.timestamp;
            const unlockTimestamp = latestTimestamp + (365 * 24 * 60 * 60);
            
            // First lock
            const tx1 = await veANDEContract.connect(user1).createLock(LOCK_AMOUNT, unlockTimestamp);
            await tx1.wait();

            // Diagnostic: Check state after first lock, within the same test
            const userLockAfterFirst = await veANDEContract.lockedBalances(user1.address);
            console.log(`\n\t🔎 Lock amount after first call: ${ethers.formatEther(userLockAfterFirst.amount)} ANDE`);

            // Prepare for second lock
            await andeToken.connect(owner).mint(user1.address, LOCK_AMOUNT);
            const approveTx = await andeToken.connect(user1).approve(await veANDEContract.getAddress(), LOCK_AMOUNT);
            await approveTx.wait();

            // Second lock attempt
            await expect(veANDEContract.connect(user1).createLock(LOCK_AMOUNT, unlockTimestamp))
                .to.be.revertedWith("veANDE: Withdraw old lock first");
        });
    });
});
