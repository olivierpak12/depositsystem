import { mutation, query } from "./_generated/server";
import { v } from "convex/values";
import { api } from "./_generated/api";

const MIN_WITHDRAWAL_AMOUNT = 2000000n; // $2.00 (Gross)
const WITHDRAWAL_FEE = 250000n; // $0.25 

export const requestWithdrawal = mutation({
  args: {
    userId: v.id("users"),
    toAddress: v.string(),
    amount: v.string(), 
    chainId: v.number(),
    network: v.string(),
    token: v.string(),
    transactionPassword: v.string(),
  },
  handler: async (ctx, args) => {
    const totalToDeduct = BigInt(args.amount);
    
    if (totalToDeduct < MIN_WITHDRAWAL_AMOUNT) {
      throw new Error("Minimum withdrawal amount is $2.00");
    }

    const amountToReceive = totalToDeduct - WITHDRAWAL_FEE;
    if (amountToReceive <= 0n) {
        throw new Error("Withdrawal amount after fees must be greater than zero.");
    }

    if (!args.toAddress.startsWith("0x") || args.toAddress.length < 40) {
      throw new Error("Invalid recipient address.");
    }

    const user = await ctx.db.get(args.userId);
    if (!user) throw new Error("User not found");
    if (user.transactionPassword !== args.transactionPassword) {
      throw new Error("Invalid transaction password.");
    }

    const balances = await ctx.db
      .query("balances")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .collect();
    
    const tokenBalances = balances.filter(b => b.tokenSymbol === args.token);
    const totalBalance = tokenBalances.reduce((acc, curr) => acc + BigInt(curr.amount), 0n);

    if (totalBalance < totalToDeduct) {
      throw new Error(`Insufficient balance. You need $${(Number(totalToDeduct) / 1000000).toFixed(2)}.`);
    }

    let remainingToDeduct = totalToDeduct;
    const targetChainBalance = tokenBalances.find(b => b.chainId === args.chainId);
    if (targetChainBalance) {
      const amountOnTarget = BigInt(targetChainBalance.amount);
      const toDeduct = amountOnTarget > remainingToDeduct ? remainingToDeduct : amountOnTarget;
      await ctx.db.patch(targetChainBalance._id, { 
        amount: (amountOnTarget - toDeduct).toString(),
        updatedAt: Date.now() 
      });
      remainingToDeduct -= toDeduct;
    }

    if (remainingToDeduct > 0n) {
      for (const bal of tokenBalances) {
        if (bal.chainId === args.chainId) continue;
        if (remainingToDeduct <= 0n) break;
        const amountOnChain = BigInt(bal.amount);
        const toDeduct = amountOnChain > remainingToDeduct ? remainingToDeduct : amountOnChain;
        await ctx.db.patch(bal._id, { 
          amount: (amountOnChain - toDeduct).toString(),
          updatedAt: Date.now() 
        });
        remainingToDeduct -= toDeduct;
      }
    }

    const withdrawalId = await ctx.db.insert("withdrawals", {
      userId: args.userId,
      toAddress: args.toAddress,
      amount: amountToReceive.toString(),
      chainId: args.chainId,
      network: args.network,
      token: args.token,
      status: "pending",
      createdAt: Date.now(),
    });

    // Automatically trigger the blockchain processing action
    await ctx.scheduler.runAfter(0, api.withdrawalActions.processWithdrawal, { 
      withdrawalId 
    });

    return withdrawalId;
  },
});

export const updateWithdrawalStatus = mutation({
  args: {
    withdrawalId: v.id("withdrawals"),
    status: v.union(v.literal("processing"), v.literal("completed"), v.literal("failed")),
    txHash: v.optional(v.string()),
    error: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const withdrawal = await ctx.db.get(args.withdrawalId);
    if (!withdrawal) return;

    if (args.status === "failed" && withdrawal.status !== "failed") {
      const refundAmount = BigInt(withdrawal.amount) + WITHDRAWAL_FEE;
      const balance = await ctx.db
        .query("balances")
        .withIndex("by_user_chain_token", (q) => 
          q.eq("userId", withdrawal.userId)
           .eq("chainId", withdrawal.chainId)
           .eq("tokenSymbol", withdrawal.token)
        )
        .unique();

      if (balance) {
        const newAmount = (BigInt(balance.amount) + refundAmount).toString();
        await ctx.db.patch(balance._id, { amount: newAmount, updatedAt: Date.now() });
      } else {
        await ctx.db.insert("balances", {
          userId: withdrawal.userId,
          chainId: withdrawal.chainId,
          tokenSymbol: withdrawal.token,
          amount: refundAmount.toString(),
          updatedAt: Date.now(),
        });
      }
    }

    await ctx.db.patch(args.withdrawalId, {
      status: args.status,
      txHash: args.txHash,
      error: args.error,
    });
  },
});

export const getWithdrawals = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("withdrawals")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .order("desc")
      .collect();
  },
});

export const getWithdrawal = query({
  args: { withdrawalId: v.id("withdrawals") },
  handler: async (ctx, args) => {
    return await ctx.db.get(args.withdrawalId);
  },
});
