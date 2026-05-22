import { query } from "./_generated/server";
import { v } from "convex/values";

export const getBalances = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("balances")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .collect();
  },
});

export const getTotalUsdtBalance = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    const balances = await ctx.db
      .query("balances")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .collect();
    
    // Sum up balances (stored as strings to avoid precision issues)
    const total = balances.reduce((acc, curr) => acc + BigInt(curr.amount), 0n);
    return total.toString();
  },
});
