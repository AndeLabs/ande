import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const ANDETokenModule = buildModule("ANDETokenModule", (m) => {
  const tokenName = m.getParameter("name", "ANDE Token");
  const tokenSymbol = m.getParameter("symbol", "ANDE");

  const andeToken = m.contract("ANDEToken", [tokenName, tokenSymbol]);

  return { andeToken };
});

export default ANDETokenModule;
