import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

/**
 * Verifies a Google ID Token using Google's TokenInfo API
 */
async function verifyGoogleToken(idToken: string) {
  const response = await fetch(`https://oauth2.googleapis.com/tokeninfo?id_token=${idToken}`);
  if (!response.ok) {
    throw new Error("Invalid Google Token");
  }
  return await response.json();
}

export const loginWithGoogle = mutation({
  args: { 
    idToken: v.string(),
  },
  handler: async (ctx, args) => {
    const payload = await verifyGoogleToken(args.idToken);
    const email = payload.email;
    const googleId = payload.sub;

    const user = await ctx.db
      .query("users")
      .withIndex("by_email", (q) => q.eq("email", email))
      .unique();

    if (user) {
      if (!user.externalId) {
        await ctx.db.patch(user._id, { externalId: googleId, emailVerified: true });
      }
      return { 
        _id: user._id, 
        email: user.email, 
        emailVerified: true,
        role: user.role ?? "user" 
      };
    }

    return { 
      isNewUser: true, 
      email: email, 
      googleId: googleId 
    };
  },
});

export const register = mutation({
  args: { 
    email: v.string(), 
    password: v.optional(v.string()),
    transactionPassword: v.string(),
    invitationCode: v.string(),
    googleId: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("users")
      .withIndex("by_email", (q) => q.eq("email", args.email))
      .unique();

    if (existing) throw new Error("User already exists");

    const userId = await ctx.db.insert("users", {
      email: args.email,
      password: args.password ?? "GOOGLE_AUTH",
      transactionPassword: args.transactionPassword,
      invitationCode: args.invitationCode,
      role: "user", 
      externalId: args.googleId,
      emailVerified: args.googleId ? true : false,
      createdAt: Date.now(),
    });

    return userId;
  },
});

export const login = query({
  args: { email: v.string(), password: v.string() },
  handler: async (ctx, args) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_email", (q) => q.eq("email", args.email))
      .unique();

    if (!user || user.password !== args.password) {
      throw new Error("Invalid credentials");
    }

    return { 
      _id: user._id, 
      email: user.email, 
      emailVerified: user.emailVerified,
      role: user.role ?? "user" 
    };
  },
});

export const getUser = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) return null;
    return {
      _id: user._id,
      email: user.email,
      role: user.role ?? "user",
      emailVerified: user.emailVerified
    };
  },
});

export const listUsers = query({
  handler: async (ctx) => {
    const users = await ctx.db.query("users").collect();
    return users.map(({ password, transactionPassword, ...u }) => ({
      ...u, 
      role: u.role ?? "user"
    }));
  },
});

export const setRole = mutation({
  args: { userId: v.id("users"), role: v.union(v.literal("user"), v.literal("admin")) },
  handler: async (ctx, args) => {
    await ctx.db.patch(args.userId, { role: args.role });
  },
});

export const makeAdmin = mutation({
  args: { email: v.string() },
  handler: async (ctx, args) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_email", (q) => q.eq("email", args.email))
      .unique();
    if (!user) throw new Error("User not found");
    await ctx.db.patch(user._id, { role: "admin" });
    return "User is now an admin";
  },
});
