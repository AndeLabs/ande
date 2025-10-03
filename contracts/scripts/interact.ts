import { ethers, network } from "hardhat";
import * as fs from "fs";

async function main() {
  console.log("\n🚀 Iniciando Flujo de Usuario Completo (Versión Producción)...");

  // Cargar direcciones desplegadas
  const addresses = JSON.parse(fs.readFileSync("deployed-addresses.json", "utf-8"));
  const [user] = await ethers.getSigners();

  console.log("👤 Usuario:", user.address);
  console.log("💰 Balance inicial:", ethers.formatEther(await ethers.provider.getBalance(user.address)), "ETH\n");

  // Conectar a los contratos
  const p2pOracle = await ethers.getContractAt("P2POracleV2", addresses.layer0.p2pOracle);
  const mockUsdc = await ethers.getContractAt("MockERC20", addresses.layer0.mockUsdc);
  const ausdToken = await ethers.getContractAt("AusdToken", addresses.layer0.ausdToken);
  const andeToken = await ethers.getContractAt("ANDEToken", addresses.layer0.andeToken);
  const abobToken = await ethers.getContractAt("AbobToken", addresses.layer1.abobToken);
  const stabilityEngine = await ethers.getContractAt("StabilityEngine", addresses.layer1.stabilityEngine);
  const sAbobToken = await ethers.getContractAt("sAbobToken", addresses.layer2.sAbobToken);

  // ======================================================================
  // PASO 0: FINALIZAR LA PRIMERA ÉPOCA DEL ORÁCULO
  // ======================================================================
  console.log("=".repeat(70));
  console.log("PASO 0: Finalizar Época del Oráculo");
  console.log("=".repeat(70));

  const epochDuration = await p2pOracle.reportEpochDuration();
  console.log(`\n⏳ Duración de la época: ${epochDuration} segundos.`);

  console.log("   Avanzando tiempo en la blockchain para cerrar la época...");
  await network.provider.send("evm_increaseTime", [Number(epochDuration) + 1]);
  await network.provider.send("evm_mine");
  console.log("   ✅ Tiempo avanzado.");

  console.log("\n⚖️ Finalizando época para oficializar el precio...");
  await p2pOracle.finalizeCurrentEpoch();
  console.log("   ✅ Época finalizada.");

  const [, price, , ,] = await p2pOracle.latestRoundData();
  if (price === 0n) {
    console.error("❌ ERROR: El precio del oráculo no se finalizó correctamente.");
    return;
  }
  console.log(`   ✅ Precio de ANDE oficializado: $${ethers.formatEther(price)}\n`);


  console.log("=".repeat(70));
  console.log("PASO 1: Obtener Colateral Base (USDC → AUSD)");
  console.log("=".repeat(70));

  const usdcAmount = ethers.parseUnits("1000", 6);
  console.log("\n📤 Minteando 1,000 USDC al usuario...");
  await mockUsdc.mint(user.address, usdcAmount);
  console.log("   ✅ Balance USDC:", ethers.formatUnits(await mockUsdc.balanceOf(user.address), 6));

  console.log("\n🔓 Aprobando USDC para AusdToken...");
  await mockUsdc.approve(addresses.layer0.ausdToken, usdcAmount);
  
  console.log("💱 Depositando USDC y minteando AUSD (ratio 150%)...");
  await ausdToken.depositAndMint(addresses.layer0.mockUsdc, usdcAmount);
  
  const ausdBalance = await ausdToken.balanceOf(user.address);
  console.log("   ✅ Balance AUSD:", ethers.formatEther(ausdBalance));

  console.log("\n" + "=".repeat(70));
  console.log("PASO 2: Mintear ABOB (Stablecoin Local)");
  console.log("=".repeat(70));

  const abobToMint = ethers.parseEther("100");
  
  console.log("\n🔓 Aprobando AUSD y ANDE para StabilityEngine...");
  // Aprobar una cantidad suficiente. El contrato calculará lo exacto.
  await ausdToken.approve(addresses.layer1.stabilityEngine, ethers.parseEther("80"));
  await andeToken.approve(addresses.layer1.stabilityEngine, ethers.parseEther("20")); // Un poco extra por si acaso

  console.log("\n⚡ Minteando ABOB...");
  await stabilityEngine.mint(abobToMint);
  
  const abobBalance = await abobToken.balanceOf(user.address);
  console.log("   ✅ Balance ABOB:", ethers.formatEther(abobBalance));

  console.log("\n✨ Flujo de acuñación de ABOB exitoso!\n")
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });