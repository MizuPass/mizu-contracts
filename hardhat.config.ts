import { HardhatUserConfig, task, vars } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-contract-sizer";
import "@nomicfoundation/hardhat-verify";

const PRIVATE_KEY = vars.get("PRIVATE_KEY");
const ETHERSCAN_API_KEY = vars.get("ETHERSCAN_API_KEY");

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
    }
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY,
    customChains: [
      {
        network: "jscTestnet",
        chainId: 5278000,
        urls: {
          apiURL: "https://api-testnet.jscscan.com/api",
          browserURL: "https://explorer.kaigan.jsc.dev",
        },
      },
    ],
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