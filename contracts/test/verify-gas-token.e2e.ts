import { ethers } from "hardhat";
import { expect } from "chai";
import "dotenv/config";

describe("Gas Token Verification", function () {
  it("should use the native 'aande' token for gas fees", async function () {
    // 1. Setup Provider and Wallet
    // The RPC endpoint is exposed on localhost:8545 by our docker-compose setup
    const provider = new ethers.JsonRpcProvider(
      "http://ev-reth-sequencer:8545",
    );

    // The private key is loaded from the .env file in the `andechain/infra` directory
    // Make sure it is present and has the 0x prefix.
    const privateKey = process.env.PRIVATE_KEY;
    if (!privateKey) {
      throw new Error(
        "PRIVATE_KEY not found in environment variables. Please check your setup.",
      );
    }
    const wallet = new ethers.Wallet(privateKey, provider);
    console.log(`🧪 Testing with wallet address: ${wallet.address}`);

    // 2. Check Initial Balance
    const initialBalance = await provider.getBalance(wallet.address);
    console.log(
      `💰 Initial balance: ${ethers.formatEther(initialBalance)} aande`,
    );

    // We expect the genesis account to be funded.
    expect(initialBalance).to.be.gt(
      0,
      "Wallet has no initial balance. Check genesis funding.",
    );

    // 3. Send a Transaction
    console.log("💸 Sending a simple transaction (0 aande to self)...");
    const tx = await wallet.sendTransaction({
      to: wallet.address,
      value: 0,
    });
    const receipt = await tx.wait();
    expect(receipt).to.not.be.null;
    console.log(`✅ Transaction successful. Tx Hash: ${receipt!.hash}`);

    // 4. Check Final Balance
    const finalBalance = await provider.getBalance(wallet.address);
    console.log(`💰 Final balance: ${ethers.formatEther(finalBalance)} aande`);

    // 5. Verify Gas Was Spent
    const gasUsed = receipt!.gasUsed;
    const gasPrice = receipt!.gasPrice;
    const gasCost = gasUsed * gasPrice;

    console.log(`🔥 Gas used: ${gasUsed.toString()}`);
    console.log(`⛽ Gas price: ${ethers.formatUnits(gasPrice, "gwei")} gwei`);
    console.log(`💸 Total gas cost: ${ethers.formatEther(gasCost)} aande`);

    // The final balance should be the initial balance minus the gas cost.
    expect(finalBalance).to.equal(initialBalance - gasCost);
    expect(finalBalance).to.be.lt(
      initialBalance,
      "Final balance should be less than initial balance after paying for gas.",
    );

    console.log(
      "\n🎉 Verification successful! The network correctly uses 'aande' for gas fees.",
    );
  });
});
