import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const recordSweepTx = mutation({
  args: {
    depositId: v.id("deposits"),
    txHash: v.string(),
    status: v.union(v.literal("gas_funding"), v.literal("sweeping"), v.literal("completed"), v.literal("failed")),
    gasFundTxHash: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    return await ctx.db.insert("sweep_transactions", {
      ...args,
      createdAt: Date.now(),
    });
  },
});

export const updateSweepStatus = mutation({
  args: {
    sweepId: v.id("sweep_transactions"),
    status: v.union(v.literal("gas_funding"), v.literal("sweeping"), v.literal("completed"), v.literal("failed")),
  },
  handler: async (ctx, args) => {
    await ctx.db.patch(args.sweepId, { status: args.status });
  },
});
