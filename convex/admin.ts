import { query } from "./_generated/server";

export const getStats = query({
  handler: async (ctx) => {
    const totalDeposits = await ctx.db.query("deposits").collect();
    const totalWithdrawals = await ctx.db.query("withdrawals").collect();
    
    const pendingWithdrawals = await ctx.db
      .query("withdrawals")
      .filter((q) => q.eq(q.field("status"), "pending"))
      .collect();

    const pendingSweeps = await ctx.db
      .query("deposits")
      .filter((q) => q.eq(q.field("status"), "confirmed"))
      .collect();

    return {
      depositCount: totalDeposits.length,
      withdrawalCount: totalWithdrawals.length,
      pendingWithdrawals: pendingWithdrawals.length,
      pendingSweeps: pendingSweeps.length,
      totalVolume: totalDeposits.reduce((acc, d) => acc + parseFloat(d.amount), 0),
    };
  },
});

export const getPendingWithdrawals = query({
  handler: async (ctx) => {
    return await ctx.db
      .query("withdrawals")
      .filter((q) => q.eq(q.field("status"), "pending"))
      .collect();
  },
});
