"use node";

import { action } from "./_generated/server";
import { v } from "convex/values";
import { api } from "./_generated/api";

export const syncUserDeposits = action({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    const wallet = await ctx.runQuery(api.wallets.getWallet, { userId: args.userId });
    if (!wallet) return { success: false, message: "No wallet found" };

    const networks = await ctx.runQuery(api.networks.getActiveNetworks);
    const walletAddress = wallet.address.toLowerCase();
    const apiKey = process.env.ETHERSCAN_V2_API_KEY;

    if (!apiKey) {
      console.error("[Sync] ❌ Missing ETHERSCAN_V2_API_KEY");
      return { success: false, message: "API Key not configured" };
    }

    console.log(`[Sync] 🔎 Scanning address: ${walletAddress}`);
    let totalFound = 0;

    const useMainnet = (process.env.USE_MAINNET || "false") === "true";

    for (const network of networks) {
      const chainId = (network as any).chainId || (network as any).chainid;
      const networkName = network.name;

      try {
        console.log(`[Sync] 🌐 Network: ${networkName} (ChainID: ${chainId})`);

        const usdtEnv = (network as any).usdtContractEnv;
        const usdcEnv = (network as any).usdcContractEnv;
        
        const targetUsdt = (process.env[usdtEnv] || (network as any).usdtContract || "").toLowerCase();
        const targetUsdc = (process.env[usdcEnv] || (network as any).usdcContract || "").toLowerCase();

        const tokenUrl = `https://api.etherscan.io/v2/api?chainid=${chainId}&module=account&action=tokentx&address=${walletAddress}&startblock=0&endblock=99999999&sort=desc&apikey=${apiKey}`;
        const tokenRes = await fetch(tokenUrl);
        const tokenData = await tokenRes.json();

        if (tokenData.status === "1" && Array.isArray(tokenData.result)) {
          for (const tx of tokenData.result) {
            if (tx.to.toLowerCase() !== walletAddress) continue;

            const symbol = (tx.tokenSymbol || "").toUpperCase();
            const contract = (tx.contractAddress || "").toLowerCase();

            let matchedToken = "";
            
            // Prioritize Symbol matching to resolve address collisions on testnets
            if (symbol.includes("USDC")) {
              matchedToken = "USDC";
            } else if (symbol.includes("USDT")) {
              matchedToken = "USDT";
            } else if (contract === targetUsdc && targetUsdc !== "") {
              matchedToken = "USDC";
            } else if (contract === targetUsdt && targetUsdt !== "") {
              matchedToken = "USDT";
            }

            if (matchedToken) {
              console.log(`[Sync] ✅ MATCHED ${matchedToken}: ${tx.hash} on ${networkName}`);
              
              const depositRecord = await ctx.runMutation(api.deposits.recordDeposit, {
                userId: args.userId,
                txHash: tx.hash,
                chainId: chainId,
                network: networkName,
                amount: tx.value,
                token: matchedToken,
                tokenContract: contract,
              });

              if (depositRecord.status === "confirmed" || depositRecord.status === "swept") continue;

              if (parseInt(tx.confirmations || "0") >= 1) {
                await ctx.runMutation(api.deposits.updateStatus, {
                  depositId: depositRecord.id as any,
                  status: "confirmed"
                });
                
                try {
                  await ctx.runAction(api.sweepActions.processAutoSweep, { depositId: depositRecord.id as any });
                } catch (e) {
                   console.error(`[Sync] Sweep error:`, e);
                }
                totalFound++;
              }
            }
          }
        }
        await new Promise(r => setTimeout(r, 500)); 
      } catch (e) {
        console.error(`[Sync] ❌ Error on ${networkName}:`, e);
      }
    }
    return { success: true, foundNew: totalFound };
  },
});

export const syncDepositByHash = action({
  args: { userId: v.id("users"), txHash: v.string(), chainId: v.number() },
  handler: async (ctx, args): Promise<{ success: boolean; foundNew?: number; message?: string }> => {
    return await ctx.runAction(api.etherscanActions.syncUserDeposits, { userId: args.userId });
  }
});
