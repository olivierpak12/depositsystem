import { httpRouter } from "convex/server";
import { httpAction } from "./_generated/server";
import { api } from "./_generated/api";

const http = httpRouter();

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

// --- Helper for Responses with CORS ---
const jsonResponse = (data: any, status: number = 200) => {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...CORS_HEADERS,
    },
  });
};

const corsResponse = () => new Response(null, { status: 204, headers: CORS_HEADERS });

// --- Preflight (OPTIONS) Handlers ---
http.route({ path: "/mutation/users:register", method: "OPTIONS", handler: httpAction(async () => corsResponse()) });
http.route({ path: "/run/users:login", method: "OPTIONS", handler: httpAction(async () => corsResponse()) });
http.route({ path: "/run/users:getUser", method: "OPTIONS", handler: httpAction(async () => corsResponse()) });
http.route({ path: "/run/users:listUsers", method: "OPTIONS", handler: httpAction(async () => corsResponse()) });
http.route({ path: "/mutation/users:setRole", method: "OPTIONS", handler: httpAction(async () => corsResponse()) });
http.route({ path: "/mutation/users:loginWithGoogle", method: "OPTIONS", handler: httpAction(async () => corsResponse()) });
http.route({ path: "/mutation/users:verifyEmail", method: "OPTIONS", handler: httpAction(async () => corsResponse()) });
http.route({ path: "/run/wallets:getWallet", method: "OPTIONS", handler: httpAction(async () => corsResponse()) });
http.route({ path: "/action/walletActions:generateWallet", method: "OPTIONS", handler: httpAction(async () => corsResponse()) });
http.route({ path: "/run/balances:getTotalUsdtBalance", method: "OPTIONS", handler: httpAction(async () => corsResponse()) });
http.route({ path: "/run/deposits:listDeposits", method: "OPTIONS", handler: httpAction(async () => corsResponse()) });
http.route({ path: "/mutation/withdrawals:requestWithdrawal", method: "OPTIONS", handler: httpAction(async () => corsResponse()) });
http.route({ path: "/action/etherscanActions:syncUserDeposits", method: "OPTIONS", handler: httpAction(async () => corsResponse()) });
http.route({ path: "/run/admin:getStats", method: "OPTIONS", handler: httpAction(async () => corsResponse()) });

// --- Auth Routes ---

http.route({
  path: "/mutation/users:register",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const body = await request.json();
    try {
      const result = await ctx.runMutation(api.users.register, body);
      return jsonResponse({ _id: result });
    } catch (e: any) {
      return jsonResponse(e.message, 400);
    }
  }),
});

http.route({
  path: "/run/users:login",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const body = await request.json();
    try {
      const result = await ctx.runQuery(api.users.login, body);
      return jsonResponse(result);
    } catch (e: any) {
      return jsonResponse(e.message, 401);
    }
  }),
});

http.route({
  path: "/run/users:getUser",
  method: "GET",
  handler: httpAction(async (ctx, request) => {
    const { searchParams } = new URL(request.url);
    const userId = searchParams.get("userId");
    if (!userId) return jsonResponse("Missing userId", 400);
    const result = await ctx.runQuery(api.users.getUser, { userId: userId as any });
    return jsonResponse(result);
  }),
});

http.route({
  path: "/run/users:listUsers",
  method: "GET",
  handler: httpAction(async (ctx) => {
    const result = await ctx.runQuery(api.users.listUsers);
    return jsonResponse(result);
  }),
});

http.route({
  path: "/mutation/users:setRole",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const body = await request.json();
    await ctx.runMutation(api.users.setRole, body);
    return jsonResponse({ success: true });
  }),
});

http.route({
  path: "/mutation/users:loginWithGoogle",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const body = await request.json();
    try {
      const result = await ctx.runMutation(api.users.loginWithGoogle, body);
      return jsonResponse(result);
    } catch (e: any) {
      return jsonResponse(e.message, 400);
    }
  }),
});

http.route({
  path: "/mutation/users:verifyEmail",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const body = await request.json();
    await ctx.runMutation(api.users.verifyEmail, body);
    return new Response(null, { status: 200, headers: CORS_HEADERS });
  }),
});

// --- Wallet Routes ---

http.route({
  path: "/run/wallets:getWallet",
  method: "GET",
  handler: httpAction(async (ctx, request) => {
    const { searchParams } = new URL(request.url);
    const userId = searchParams.get("userId");
    if (!userId) return jsonResponse("Missing userId", 400);

    const wallet = await ctx.runQuery(api.wallets.getWallet, { userId: userId as any });
    return jsonResponse(wallet);
  }),
});

http.route({
  path: "/action/walletActions:generateWallet",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const body = await request.json();
    try {
      const result = await ctx.runAction(api.walletActions.generateWallet, body);
      return jsonResponse(result);
    } catch (e: any) {
      return jsonResponse(e.message, 400);
    }
  }),
});

// --- Data Routes ---

http.route({
  path: "/run/balances:getTotalUsdtBalance",
  method: "GET",
  handler: httpAction(async (ctx, request) => {
    const { searchParams } = new URL(request.url);
    const userId = searchParams.get("userId");
    if (!userId) return jsonResponse("Missing userId", 400);
    
    const balance = await ctx.runQuery(api.balances.getTotalUsdtBalance, { userId: userId as any });
    return jsonResponse({ balance });
  }),
});

http.route({
  path: "/run/deposits:listDeposits",
  method: "GET",
  handler: httpAction(async (ctx, request) => {
    const { searchParams } = new URL(request.url);
    const userId = searchParams.get("userId");
    if (!userId) return jsonResponse("Missing userId", 400);

    const deposits = await ctx.runQuery(api.deposits.listDeposits, { userId: userId as any });
    return jsonResponse(deposits);
  }),
});

http.route({
  path: "/mutation/withdrawals:requestWithdrawal",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const body = await request.json();
    try {
      const result = await ctx.runMutation(api.withdrawals.requestWithdrawal, body);
      return jsonResponse({ withdrawalId: result });
    } catch (e: any) {
      return jsonResponse(e.message, 400);
    }
  }),
});

http.route({
  path: "/action/etherscanActions:syncUserDeposits",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const body = await request.json();
    try {
      const result = await ctx.runAction(api.etherscanActions.syncUserDeposits, body);
      return jsonResponse(result);
    } catch (e: any) {
      return jsonResponse(e.message, 400);
    }
  }),
});

http.route({
  path: "/run/admin:getStats",
  method: "GET",
  handler: httpAction(async (ctx) => {
    const result = await ctx.runQuery(api.admin.getStats);
    return jsonResponse(result);
  }),
});

export default http;
