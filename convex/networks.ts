import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const getAllNetworks = query({
  args: {},
  handler: async (ctx) => {
    return await ctx.db.query("supported_networks").collect();
  },
});

export const getActiveNetworks = query({
  args: {},
  handler: async (ctx) => {
    return await ctx.db
      .query("supported_networks")
      .filter((q) => q.eq(q.field("isActive"), true))
      .collect();
  },
});

export const getNetworkInfo = query({
  args: { chainId: v.number() },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("supported_networks")
      .filter((q) => q.eq(q.field("chainId"), args.chainId))
      .first();
  },
});

export const setNetworkActive = mutation({
  args: { chainId: v.number(), isActive: v.boolean() },
  handler: async (ctx, args) => {
    const network = await ctx.db
      .query("supported_networks")
      .filter((q) => q.eq(q.field("chainId"), args.chainId))
      .first();
    if (network) {
      await ctx.db.patch(network._id, { isActive: args.isActive });
    }
  },
});
