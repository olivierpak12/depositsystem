import { query } from "./_generated/server";
import { v } from "convex/values";

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
