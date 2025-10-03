import { ethers, upgrades } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Desplegando contratos con la cuenta:", deployer.address);
  console.log("Balance de la cuenta:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)));

  // ==============================================
  // CAPA 0: CIMIENTOS (Tokens Base + Oráculo)
  // ==============================================
  
  console.log("\n📦 CAPA 0: Desplegando Cimientos...\n");

  // 1. Desplegar ANDEToken
  console.log("1️⃣  Desplegando ANDEToken...");
  const ANDEToken = await ethers.getContractFactory("ANDEToken");
  const andeToken = await upgrades.deployProxy(
    ANDEToken,
    [deployer.address, deployer.address], // admin, minter
    { kind: "uups" }
  );
  await andeToken.waitForDeployment();
  const andeAddress = await andeToken.getAddress();
  console.log("   ✅ ANDEToken desplegado en:", andeAddress);

  // 2. Mint inicial de ANDE para pruebas (100,000 tokens)
  console.log("   💰 Mintando supply inicial de ANDE...");
  await andeToken.mint(deployer.address, ethers.parseEther("100000"));

  // 3. Desplegar P2POracleV2
  console.log("\n2️⃣  Desplegando P2POracleV2...");
  const P2POracle = await ethers.getContractFactory("P2POracleV2");
  const minStake = ethers.parseEther("1000"); // 1000 ANDE mínimo
  const epochDuration = 3600; // 1 hora
  
  const p2pOracle = await upgrades.deployProxy(
    P2POracle,
    [deployer.address, andeAddress, minStake, epochDuration],
    { kind: "uups" }
  );
  await p2pOracle.waitForDeployment();
  const oracleAddress = await p2pOracle.getAddress();
  console.log("   ✅ P2POracleV2 desplegado en:", oracleAddress);

  // 4. Desplegar AusdToken (con mock oracle para USDC)
  console.log("\n3️⃣  Desplegando AusdToken...");
  
  const MockOracle = await ethers.getContractFactory("MockOracle");
  const usdcOracle = await MockOracle.deploy();
  await usdcOracle.waitForDeployment();
  await usdcOracle.setPrice(ethers.parseUnits("1", 8));
  console.log("   📊 MockOracle (USDC) desplegado en:", await usdcOracle.getAddress());

  const MockERC20 = await ethers.getContractFactory("MockERC20");
  const mockUsdc = await MockERC20.deploy("Mock USDC", "USDC", 6);
  await mockUsdc.waitForDeployment();
  const usdcAddress = await mockUsdc.getAddress();
  console.log("   💵 Mock USDC desplegado en:", usdcAddress);

  await mockUsdc.mint(deployer.address, ethers.parseUnits("1000000", 6));

  const AusdToken = await ethers.getContractFactory("AusdToken");
  const ausdToken = await upgrades.deployProxy(
    AusdToken,
    [deployer.address],
    { kind: "uups" }
  );
  await ausdToken.waitForDeployment();
  const ausdAddress = await ausdToken.getAddress();
  console.log("   ✅ AusdToken desplegado en:", ausdAddress);

  await ausdToken.addCollateralType(
    usdcAddress,
    15000,
    await usdcOracle.getAddress()
  );

  // ==============================================
  // CAPA 1: MOTOR (AbobToken + StabilityEngine)
  // ==============================================
  
  console.log("\n\n🏗️  CAPA 1: Desplegando Motor...\n");

  // 5. Desplegar AbobToken
  console.log("4️⃣  Desplegando AbobToken...");
  const AbobToken = await ethers.getContractFactory("AbobToken");
  const abobToken = await upgrades.deployProxy(
    AbobToken,
    [deployer.address, deployer.address], // admin, minter temporal
    { kind: "uups" }
  );
  await abobToken.waitForDeployment();
  const abobAddress = await abobToken.getAddress();
  console.log("   ✅ AbobToken desplegado en:", abobAddress);

  // 6. Desplegar StabilityEngine
  console.log("\n5️⃣  Desplegando StabilityEngine...");
  const StabilityEngine = await ethers.getContractFactory("StabilityEngine");
  const stabilityEngine = await upgrades.deployProxy(
    StabilityEngine,
    [deployer.address, abobAddress, ausdAddress, andeAddress, oracleAddress],
    { kind: "uups" }
  );
  await stabilityEngine.waitForDeployment();
  const engineAddress = await stabilityEngine.getAddress();
  console.log("   ✅ StabilityEngine desplegado en:", engineAddress);

  // 7. Otorgar rol MINTER_ROLE a StabilityEngine en AbobToken
  console.log("\n   🔐 Configurando permisos...");
  const MINTER_ROLE = await abobToken.MINTER_ROLE();
  await abobToken.grantRole(MINTER_ROLE, engineAddress);
  await abobToken.revokeRole(MINTER_ROLE, deployer.address);
  console.log("   ✅ StabilityEngine ahora puede mintear ABOB");

  // ==============================================
  // CAPA 2: RENDIMIENTO (sAbobToken)
  // ==============================================
  
  console.log("\n\n💰 CAPA 2: Desplegando Generador de Rendimiento...\n");

  // 8. Desplegar sAbobToken
  console.log("6️⃣  Desplegando sAbobToken...");
  const SAbobToken = await ethers.getContractFactory("sAbobToken");
  const sAbobToken = await upgrades.deployProxy(
    SAbobToken,
    [deployer.address, abobAddress],
    { kind: "uups" }
  );
  await sAbobToken.waitForDeployment();
  const sAbobAddress = await sAbobToken.getAddress();
  console.log("   ✅ sAbobToken desplegado en:", sAbobAddress);

  // ==============================================
  // CONFIGURACIÓN INICIAL DEL ORÁCULO
  // ==============================================
  
  console.log("\n\n📊 Configurando Oráculo P2P...\n");

  console.log("7️⃣  Estableciendo precio inicial de ANDE...");
  
  await andeToken.approve(oracleAddress, minStake);
  
  await p2pOracle.register();
  console.log("   ✅ Deployer registrado como reporter en P2POracle");

  const initialAndePrice = ethers.parseEther("2");
  await p2pOracle.reportPrice(initialAndePrice);
  console.log("   ✅ Precio inicial de ANDE reportado: $2.00");

  // ==============================================
  // RESUMEN FINAL
  // ==============================================
  
  console.log("\n\n" + "=".repeat(60));
  console.log("🎉 DESPLIEGUE COMPLETO - RESUMEN DE DIRECCIONES");
  console.log("=".repeat(60));
  console.log("\n📍 CAPA 0 - CIMIENTOS:");
  console.log("   ANDEToken:        ", andeAddress);
  console.log("   P2POracleV2:      ", oracleAddress);
  console.log("   AusdToken:        ", ausdAddress);
  console.log("   Mock USDC:        ", usdcAddress);
  console.log("\n📍 CAPA 1 - MOTOR:");
  console.log("   AbobToken:        ", abobAddress);
  console.log("   StabilityEngine:  ", engineAddress);
  console.log("\n📍 CAPA 2 - RENDIMIENTO:");
  console.log("   sAbobToken:       ", sAbobAddress);
  console.log("\n" + "=".repeat(60));

  const addresses = {
    network: (await ethers.provider.getNetwork()).name,
    deployer: deployer.address,
    layer0: {
      andeToken: andeAddress,
      p2pOracle: oracleAddress,
      ausdToken: ausdAddress,
      mockUsdc: usdcAddress,
    },
    layer1: {
      abobToken: abobAddress,
      stabilityEngine: engineAddress,
    },
    layer2: {
      sAbobToken: sAbobAddress,
    },
  };

  const fs = require("fs");
  fs.writeFileSync(
    "deployed-addresses.json",
    JSON.stringify(addresses, null, 2)
  );
  console.log("\n💾 Direcciones guardadas en: deployed-addresses.json");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
