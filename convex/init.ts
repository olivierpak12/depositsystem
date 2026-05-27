import { mutation } from "./_generated/server";

export const initializeNetworks = mutation({
  handler: async (ctx) => {
    const networks = [
      {
        chainId: 1,
        name: "Ethereum Mainnet",
        rpcUrl: "ETH_MAINNET_RPC",
        defaultRpc: "https://eth.llamarpc.com",
        usdtContractEnv: "ETH_MAINNET_USDT",
        usdtContract: "0xdAC17F958D2ee523a2206206994597C13D831ec7",
        usdcContractEnv: "ETH_MAINNET_USDC",
        usdcContract: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        symbol: "ETH",
        isActive: true,
      },
      {
        chainId: 137,
        name: "Polygon Mainnet",
        rpcUrl: "POLYGON_MAINNET_RPC",
        defaultRpc: "https://polygon-rpc.com",
        usdtContractEnv: "POLYGON_MAINNET_USDT",
        usdtContract: "0xc2132D05D31c914a87C6611C10748AEb04B58e8F",
        usdcContractEnv: "POLYGON_MAINNET_USDC",
        usdcContract: "0x3c499c512c03178468b2074E05174094002669f1",
        symbol: "MATIC",
        isActive: true,
      },
      {
        chainId: 11155111,
        name: "Ethereum Sepolia",
        rpcUrl: "ETH_SEPOLIA_RPC",
        defaultRpc: "https://ethereum-sepolia-rpc.publicnode.com",
        usdtContractEnv: "ETH_SEPOLIA_USDT",
        usdtContract: "0xf723597ce23ed1e7eeb87736beebc895bb599c34",
        usdcContractEnv: "ETH_SEPOLIA_USDC",
        usdcContract: "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238",
        symbol: "ETH",
        isActive: true,
      },
      {
        chainId: 80002,
        name: "Polygon Amoy",
        rpcUrl: "POLYGON_AMOY_RPC",
        defaultRpc: "https://rpc-amoy.polygon.technology",
        usdtContractEnv: "POLYGON_AMOY_USDT",
        usdtContract: "0x41e94eb019c0762f9bfcf9fb1e58725bfb0e7582",
        usdcContractEnv: "POLYGON_AMOY_USDC",
        usdcContract: "0x41e94eb019c0762f9bfcf9fb1e58725bfb0e7582",
        symbol: "MATIC",
        isActive: true,
      },
      {
        chainId: 97,
        name: "BSC Testnet",
        rpcUrl: "BSC_TESTNET_RPC",
        defaultRpc: "https://bsc-testnet-rpc.publicnode.com",
        usdtContractEnv: "BSC_TESTNET_USDT",
        usdtContract: "0x337610d27c242501939206584221d8b6308e05be",
        usdcContractEnv: "BSC_TESTNET_USDC",
        usdcContract: "0x64544969ed7EBf5f083679233325356EbE738930",
        symbol: "BNB",
        isActive: true,
      },
      {
        chainId: 42161,
        name: "Arbitrum Mainnet",
        rpcUrl: "ARBITRUM_MAINNET_RPC",
        defaultRpc: "https://arb1.arbitrum.io/rpc",
        usdtContractEnv: "ARBITRUM_MAINNET_USDT",
        usdtContract: "0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9",
        symbol: "ETH",
        isActive: true,
      }
    ];

    for (const network of networks) {
      const existing = await ctx.db
        .query("supported_networks")
        .filter((q) => q.eq(q.field("chainId"), network.chainId))
        .first();
      if (!existing) {
        await ctx.db.insert("supported_networks", network as any);
      } else {
        await ctx.db.patch(existing._id, network as any);
      }
    }

    const allStored = await ctx.db.query("supported_networks").collect();
    for (const stored of allStored) {
      if (!networks.find(n => n.chainId === stored.chainId)) {
        await ctx.db.patch(stored._id, { isActive: false });
      }
    }
  },
});
