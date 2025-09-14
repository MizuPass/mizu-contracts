import { HardhatUserConfig, task, vars } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-contract-sizer";
import "@nomicfoundation/hardhat-verify";

const PRIVATE_KEY = vars.get("PRIVATE_KEY");

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true
    },
  },
  paths: {
    sources: "./contracts",
  },
  networks: {
    jscTestnet: {
      url: "https://rpc.kaigan.jsc.dev/rpc?token=zQao1Ji99KLxVeb7r2ofb2naaRxCaM5V7BY-JiwBtB0",
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : [],
      chainId: 5278000,
    },
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: true,
    disambiguatePaths: false,
  },
};

task(
  "contract-size",
  "Outputs the size of compiled contracts in bytes"
).setAction(async (_, { run }) => {
  await run("compile");
  await run("size-contracts");
});

export default config;