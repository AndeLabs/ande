import { expect } from "chai";


describe("ANDEToken - Simple Test", function () {
  it("Should deploy and have the correct name and symbol", async function () {
    // 1. Obtener la cuenta del desplegador
    const [owner] = await viem.getWalletClients();

    // 2. Desplegar el contrato
    const andeToken = await viem.deployContract("ANDEToken", [owner.account.address]);

    // 3. Verificar (Assert)
    expect(await andeToken.read.name()).to.equal("Ande Token");
    expect(await andeToken.read.symbol()).to.equal("ANDE");
  });
});
