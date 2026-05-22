"use node";

import { action } from "./_generated/server";
import { v } from "convex/values";
import { api } from "./_generated/api";
import { Wallet } from "ethers";
import * as crypto from "crypto";

export const generateWallet = action({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    // 1. Check if wallet already exists
    const existing = await ctx.runQuery(api.wallets.getWallet, { userId: args.userId });
    if (existing) return existing;

    // 2. Generate new wallet using ethers
    const wallet = Wallet.createRandom();
    
    // 3. Encrypt private key using ENCRYPTION_KEY from environment
    const encryptionKey = process.env.ENCRYPTION_KEY;
    if (!encryptionKey || encryptionKey.length !== 32) {
      throw new Error("ENCRYPTION_KEY must be a 32-character string set in Convex environment variables");
    }

    const iv = crypto.randomBytes(16);
    const cipher = crypto.createCipheriv(
      "aes-256-cbc", 
      Buffer.from(encryptionKey, "utf-8"), 
      iv
    );
    
    let encrypted = cipher.update(wallet.privateKey, "utf8", "hex");
    encrypted += cipher.final("hex");

    // 4. Store in DB via mutation
    const walletId = await ctx.runMutation(api.wallets.createWallet, {
      userId: args.userId,
      address: wallet.address,
      encryptedPrivateKey: encrypted,
      iv: iv.toString("hex"),
    });

    return {
      _id: walletId,
      address: wallet.address,
    };
  },
});
