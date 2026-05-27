import { action } from "./_generated/server";
import { api } from "./_generated/api";

export const processAllPending = action({
  args: {},
  handler: async (ctx): Promise<{ message: string }> => {
    const pending = await ctx.runQuery(api.admin.getPendingWithdrawals);
    console.log(`[Withdraw] 🤖 Auto-processing ${pending.length} pending withdrawals`);
    
    let successCount = 0;
    for (const w of pending) {
      const res: any = await ctx.runAction(api.withdrawalActions.processWithdrawal, { withdrawalId: w._id });
      if (res.success) successCount++;
    }
    return { message: `Processed ${successCount} out of ${pending.length} withdrawals.` };
  },
});
