import { ethers, upgrades } from "hardhat";
import { expect } from "chai";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { ANDEToken, veANDE } from "../typechain-types";

describe("veANDE Contract", function () {
    let andeToken: ANDEToken;
    let veANDEContract: veANDE;
    let owner: ethers.Wallet, user1: ethers.Wallet, user2: ethers.Wallet;

    const LOCK_AMOUNT = ethers.parseEther("1000");

    beforeEach(async function() {
        const provider = ethers.provider;
        // Create wallets from private keys
        owner = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);
        user1 = new ethers.Wallet(process.env.PRIVATE_KEY_USER1!, provider);
        user2 = new ethers.Wallet(process.env.PRIVATE_KEY_USER2!, provider);

        // Fund test accounts with gas
        await (await owner.sendTransaction({ to: user1.address, value: ethers.parseEther("1.0") })).wait();
        await (await owner.sendTransaction({ to: user2.address, value: ethers.parseEther("1.0") })).wait();

        // Deploy ANDEToken
        const ANDETokenFactory = await ethers.getContractFactory("ANDEToken", owner);
        andeToken = (await upgrades.deployProxy(ANDETokenFactory, [owner.address, owner.address], {
            kind: "uups",
        })) as unknown as ANDEToken;
        await andeToken.waitForDeployment();

        // Deploy veANDEContract
        const veANDEFactory = await ethers.getContractFactory("veANDE", owner);
        veANDEContract = (await upgrades.deployProxy(veANDEFactory, [await andeToken.getAddress(), owner.address], {
            kind: "uups",
        })) as unknown as veANDE;
        await veANDEContract.waitForDeployment();

        // Mint tokens to user1 and approve veANDE contract
        await andeToken.connect(owner).mint(user1.address, LOCK_AMOUNT);
        await (await andeToken.connect(user1).approve(await veANDEContract.getAddress(), LOCK_AMOUNT)).wait();
    });

    describe("createLock", function () {
        it("should allow a user to lock tokens", async function () {
            const provider = ethers.provider;
            const lockDuration = 365 * 24 * 60 * 60; // 1 year
            const block = await provider.getBlock('latest');
            const unlockTimestamp = block!.timestamp + lockDuration;

            await veANDEContract.connect(user1).createLock(LOCK_AMOUNT, unlockTimestamp);

            expect(await andeToken.balanceOf(user1.address)).to.equal(0);
            expect(await andeToken.balanceOf(await veANDEContract.getAddress())).to.equal(LOCK_AMOUNT);
        });
    });

    describe("Withdrawal Logic", function () {
        it("should NOT allow a user to withdraw before the lock has expired", async function () {
            const provider = ethers.provider;
            const lockDuration = 30 * 24 * 60 * 60; // 30 days
            const block = await provider.getBlock('latest');
            const unlockTimestamp = block!.timestamp + lockDuration;

            await veANDEContract.connect(user1).createLock(LOCK_AMOUNT, unlockTimestamp);

            await expect(veANDEContract.connect(user1).withdraw())
                .to.be.revertedWith("veANDE: Lock has not expired yet");
        });

        it("should NOT allow a user with no lock to withdraw", async function () {
            await expect(veANDEContract.connect(user2).withdraw())
                .to.be.revertedWith("veANDE: No tokens to withdraw");
        });
    });

    describe("balanceOf Logic", function() {
        it("should return 0 for a user with no lock", async function() {
            const balance = await veANDEContract.balanceOf(user2.address);
            expect(balance).to.equal(0);
        });

        it("should return a balance close to the locked amount for a fresh lock", async function() {
            const provider = ethers.provider;
            const maxLockTime = 4 * 365 * 24 * 60 * 60; // 4 years
            const block = await provider.getBlock('latest');
            const unlockTimestamp = block!.timestamp + maxLockTime;

            await veANDEContract.connect(user1).createLock(LOCK_AMOUNT, unlockTimestamp);

            const balance = await veANDEContract.balanceOf(user1.address);
            
            // The balance should be very close to the initial lock amount,
            // accounting for a few seconds of decay since the lock was created.
            const tolerance = ethers.parseEther("1"); // Allow a tolerance of 1 veANDE
            expect(balance).to.be.closeTo(LOCK_AMOUNT, tolerance);
            expect(balance).to.be.lt(LOCK_AMOUNT); // Should be slightly less
        });

        // TODO: Testing the decay over time requires time manipulation, which is not
        // possible on the 'localhost' network. This test can be run on the in-memory Hardhat Network.
        /*
        it("should return a decayed balance after time has passed", async function() {
            const provider = ethers.provider;
            const maxLockTime = 4 * 365 * 24 * 60 * 60; // 4 years
            const halfLockTime = maxLockTime / 2;
            const block = await provider.getBlock('latest');
            const unlockTimestamp = block!.timestamp + maxLockTime;

            await veANDEContract.connect(user1).createLock(LOCK_AMOUNT, unlockTimestamp);

            // Advance time by half the lock duration
            // This helper only works on Hardhat Network
            // await time.increase(halfLockTime);

            const balance = await veANDEContract.balanceOf(user1.address);
            const expectedBalance = LOCK_AMOUNT / 2n; // Using BigInt division
            const tolerance = ethers.parseEther("1");

            expect(balance).to.be.closeTo(expectedBalance, tolerance);
        });
        */
    });
});
