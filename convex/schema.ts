import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  users: defineTable({
    username: v.optional(v.string()),
    email: v.string(),
    password: v.string(),
    transactionPassword: v.string(),
    referralCode: v.optional(v.string()), 
    referralLink: v.optional(v.string()),
    referredBy: v.optional(v.id("users")),
    referralBalance: v.optional(v.number()), 
    totalReferralEarnings: v.optional(v.number()), 
    teamSize: v.optional(v.number()), 
    role: v.optional(v.union(v.literal("user"), v.literal("admin"))),
    emailVerified: v.boolean(),
    externalId: v.optional(v.string()), 
    createdAt: v.number(),
    invitationCode: v.optional(v.string()), 
  })
    .index("by_email", ["email"])
    .index("by_externalId", ["externalId"])
    .index("by_referralCode", ["referralCode"])
    .index("by_referredBy", ["referredBy"])
    .index("by_totalReferralEarnings", ["totalReferralEarnings"]),

  wallets: defineTable({
    userId: v.id("users"),
    address: v.string(),
    encryptedPrivateKey: v.string(),
    iv: v.string(),
    createdAt: v.number(),
  }).index("by_userId", ["userId"]).index("by_address", ["address"]),

  balances: defineTable({
    userId: v.id("users"),
    chainId: v.number(),
    tokenSymbol: v.string(),
    amount: v.string(),
    updatedAt: v.number(),
  })
    .index("by_userId", ["userId"])
    .index("by_user_chain_token", ["userId", "chainId", "tokenSymbol"]),

  deposits: defineTable({
    userId: v.id("users"),
    txHash: v.string(),
    chainId: v.number(),
    network: v.string(),
    amount: v.string(),
    token: v.string(),
    tokenContract: v.optional(v.string()),
    sweepTxHash: v.optional(v.string()), 
    confirmations: v.number(),
    status: v.union(v.literal("pending"), v.literal("confirmed"), v.literal("failed"), v.literal("swept")),
    createdAt: v.number(),
  }).index("by_txHash", ["txHash"]).index("by_userId", ["userId"]),

  withdrawals: defineTable({
    userId: v.id("users"),
    toAddress: v.string(),
    txHash: v.optional(v.string()),
    chainId: v.number(),
    network: v.string(),
    amount: v.string(),
    token: v.string(),
    status: v.union(v.literal("pending"), v.literal("processing"), v.literal("completed"), v.literal("failed")),
    error: v.optional(v.string()),
    createdAt: v.number(),
  }).index("by_userId", ["userId"]),

  referralCommissions: defineTable({
    fromUserId: v.id("users"),
    toUserId: v.id("users"),
    level: v.number(),
    percent: v.number(),
    depositAmount: v.number(),
    commissionAmount: v.number(),
    depositId: v.id("deposits"),
    createdAt: v.number(),
  })
    .index("by_toUserId", ["toUserId"])
    .index("by_fromUserId", ["fromUserId"])
    .index("by_depositId", ["depositId"])
    .index("by_toUserId_createdAt", ["toUserId", "createdAt"]),

  referralTree: defineTable({
    userId: v.id("users"),
    parentId: v.id("users"),
    level: v.number(),
    createdAt: v.number(),
  })
    .index("by_userId", ["userId"])
    .index("by_parentId", ["parentId"])
    .index("by_parentId_level", ["parentId", "level"]),

  sweep_transactions: defineTable({
    depositId: v.id("deposits"),
    txHash: v.string(),
    status: v.union(v.literal("gas_funding"), v.literal("sweeping"), v.literal("completed"), v.literal("failed")),
    gasFundTxHash: v.optional(v.string()),
    createdAt: v.number(),
  }),

  supported_networks: defineTable({
    chainId: v.number(),
    name: v.string(),
    rpcUrl: v.string(),
    defaultRpc: v.optional(v.string()),
    usdtContract: v.string(),
    usdtContractEnv: v.optional(v.string()),
    usdcContract: v.optional(v.string()),
    usdcContractEnv: v.optional(v.string()),
    symbol: v.string(),
    isActive: v.boolean(),
  }),

  admin_settings: defineTable({
    key: v.string(),
    value: v.string(),
  }).index("by_key", ["key"]),
});
