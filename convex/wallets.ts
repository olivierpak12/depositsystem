import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const getWallet = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("wallets")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .first();
  },
});

export const getWalletByAddress = query({
  args: { address: v.string() },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("wallets")
      .withIndex("by_address", (q) => q.eq("address", args.address))
      .first();
  },
});

export const createWallet = mutation({
  args: {
    userId: v.id("users"),
    address: v.string(),
    encryptedPrivateKey: v.string(),
    iv: v.string(),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("wallets")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .first();
    
    if (existing) return existing._id;

    return await ctx.db.insert("wallets", {
      userId: args.userId,
      address: args.address,
      encryptedPrivateKey: args.encryptedPrivateKey,
      iv: args.iv,
      createdAt: Date.now(),
    });
  },
});
