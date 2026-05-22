import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const requestWithdrawal = mutation({
  args: {
    userId: v.id("users"),
    toAddress: v.string(),
    amount: v.string(),
    chainId: v.number(),
    network: v.string(),
    token: v.string(),
    transactionPassword: v.string(), // Added for security
  },
  handler: async (ctx, args) => {
    // 1. Verify Transaction Password
    const user = await ctx.db.get(args.userId);
    if (!user || user.transactionPassword !== args.transactionPassword) {
      throw new Error("Invalid transaction password");
    }

    // 2. Check user balance
    const balance = await ctx.db
      .query("balances")
      .withIndex("by_user_chain_token", (q) =>
        q.eq("userId", args.userId).eq("chainId", args.chainId).eq("tokenSymbol", args.token)
      )
      .first();

    if (!balance || BigInt(balance.amount) < BigInt(args.amount)) {
      throw new Error("Insufficient balance");
    }

    // 3. Deduct balance (Lock funds)
    const newAmount = (BigInt(balance.amount) - BigInt(args.amount)).toString();
    await ctx.db.patch(balance._id, { amount: newAmount, updatedAt: Date.now() });

    // 4. Create withdrawal record
    const withdrawalId = await ctx.db.insert("withdrawals", {
      userId: args.userId,
      toAddress: args.toAddress,
      amount: args.amount,
      chainId: args.chainId,
      network: args.network,
      token: args.token,
      status: "pending",
      createdAt: Date.now(),
    });

    return withdrawalId;
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

export const updateWithdrawalStatus = mutation({
  args: {
    withdrawalId: v.id("withdrawals"),
    status: v.union(v.literal("processing"), v.literal("completed"), v.literal("failed")),
    txHash: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    await ctx.db.patch(args.withdrawalId, {
      status: args.status,
      txHash: args.txHash,
    });
  },
});
