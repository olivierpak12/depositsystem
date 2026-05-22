import { ethers } from "ethers";
import { ConvexHttpClient } from "convex/browser";
import * as dotenv from "dotenv";
import { api } from "../convex/_generated/api";

dotenv.config();

const convex = new ConvexHttpClient(process.env.CONVEX_URL!);

const NETWORKS: any = {
  11155111: {
    rpc: process.env.ETH_SEPOLIA_RPC,
    tokens: {
      USDT: process.env.ETH_SEPOLIA_USDT,
      USDC: process.env.ETH_SEPOLIA_USDC
    }
  },
  80002: {
    rpc: process.env.POLYGON_AMOY_RPC,
    tokens: {
      USDT: process.env.POLYGON_AMOY_USDT,
      USDC: process.env.POLYGON_AMOY_USDC
    }
  },
  97: {
    rpc: process.env.BSC_TESTNET_RPC,
    tokens: {
      USDT: process.env.BSC_TESTNET_USDT,
      USDC: process.env.BSC_TESTNET_USDC
    }
  }
};

export async function processWithdrawals() {
  console.log("--- CryptoVault Multi-Token Withdrawal Processor Starting ---");

  while (true) {
    try {
      const pending = await convex.query(api.admin.getPendingWithdrawals);
      for (const tx of pending) {
        await executeWithdrawal(tx);
      }
    } catch (e) {
      console.error("Processor Loop Error:", e);
    }
    await new Promise(r => setTimeout(r, 15000));
  }
}

async function executeWithdrawal(tx: any) {
  const network = NETWORKS[tx.chainId];
  if (!network || !network.rpc) return;

  const tokenAddress = network.tokens[tx.token];
  if (!tokenAddress) {
    console.error(`Unsupported token ${tx.token} on chain ${tx.chainId}`);
    return;
  }

  try {
    const provider = new ethers.JsonRpcProvider(network.rpc);
    const hotWallet = new ethers.Wallet(process.env.HOT_WALLET_PRIVATE_KEY!, provider);
    const tokenContract = new ethers.Contract(tokenAddress, [
      "function transfer(address to, uint256 value) public returns (bool)",
      "function decimals() view returns (uint8)"
    ], hotWallet);

    await convex.mutation(api.withdrawals.updateWithdrawalStatus, {
      withdrawalId: tx._id,
      status: "processing"
    });

    const decimals = await tokenContract.decimals();
    const amount = ethers.parseUnits(tx.amount, decimals);
    
    const response = await tokenContract.transfer(tx.toAddress, amount);
    const receipt = await response.wait();
    
    if (receipt && receipt.status === 1) {
      await convex.mutation(api.withdrawals.updateWithdrawalStatus, {
        withdrawalId: tx._id,
        status: "completed",
        txHash: response.hash
      });
    } else {
      throw new Error("Transaction reverted");
    }
  } catch (error) {
    console.error(`Withdrawal failed for ${tx._id}:`, error);
    await convex.mutation(api.withdrawals.updateWithdrawalStatus, {
      withdrawalId: tx._id,
      status: "failed"
    });
  }
}

processWithdrawals().catch(console.error);
