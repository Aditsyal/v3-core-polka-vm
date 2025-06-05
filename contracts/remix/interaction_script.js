// Remix IDE Interaction Script for PolkaVM AMM
// Copy and paste this into Remix IDE's JavaScript VM console

const AMM_FACTORY_ABI = [
    "function owner() view returns (address)",
    "function feeAmountTickSpacing(uint24) view returns (int24)",
    "function getPool(address,address,uint24) view returns (address)",
    "function createPool(address,address,uint24) returns (address)",
    "function setOwner(address)",
    "function enableFeeAmount(uint24,int24)"
];

const ERC20_ABI = [
    "function name() view returns (string)",
    "function symbol() view returns (string)",
    "function decimals() view returns (uint8)",
    "function totalSupply() view returns (uint256)",
    "function balanceOf(address) view returns (uint256)",
    "function allowance(address,address) view returns (uint256)",
    "function transfer(address,uint256) returns (bool)",
    "function approve(address,uint256) returns (bool)",
    "function transferFrom(address,address,uint256) returns (bool)",
    "function mint(address,uint256)"
];

const SIMPLE_AMM_ABI = [
    "function token0() view returns (address)",
    "function token1() view returns (address)",
    "function fee() view returns (uint24)",
    "function reserve0() view returns (uint256)",
    "function reserve1() view returns (uint256)",
    "function totalSupply() view returns (uint256)",
    "function balanceOf(address) view returns (uint256)",
    "function addLiquidity(uint256,uint256,address) returns (uint256)",
    "function removeLiquidity(uint256,address) returns (uint256,uint256)",
    "function swap(uint256,uint256,address)",
    "function getReserves() view returns (uint256,uint256)"
];

// Replace these with your deployed contract addresses
const FACTORY_ADDRESS = "0x..."; // Replace with your factory address
const TOKEN_A_ADDRESS = "0x..."; // Replace with Token A address
const TOKEN_B_ADDRESS = "0x..."; // Replace with Token B address
const POOL_ADDRESS = "0x..."; // Replace with pool address (after creation)

// Helper function to format Wei to Ether
function formatEther(wei) {
    return ethers.utils.formatEther(wei);
}

// Helper function to parse Ether to Wei
function parseEther(ether) {
    return ethers.utils.parseEther(ether.toString());
}

// Complete deployment and testing script
async function deployAndTest() {
    console.log("🚀 Starting PolkaVM AMM Deployment and Testing...");
    
    // Get signer
    const [signer] = await ethers.getSigners();
    console.log("📝 Using account:", signer.address);
    
    try {
        // Step 1: Deploy Test Tokens
        console.log("\n1️⃣ Deploying Test Tokens...");
        
        const TestERC20 = await ethers.getContractFactory("TestERC20");
        
        const tokenA = await TestERC20.deploy(
            "Token A",
            "TKNA", 
            18,
            parseEther("1000000") // 1M tokens
        );
        await tokenA.deployed();
        console.log("✅ Token A deployed at:", tokenA.address);
        
        const tokenB = await TestERC20.deploy(
            "Token B",
            "TKNB",
            18, 
            parseEther("1000000") // 1M tokens
        );
        await tokenB.deployed();
        console.log("✅ Token B deployed at:", tokenB.address);
        
        // Step 2: Deploy Factory
        console.log("\n2️⃣ Deploying AMM Factory...");
        
        const UniswapV3Factory = await ethers.getContractFactory("UniswapV3Factory");
        const factory = await UniswapV3Factory.deploy();
        await factory.deployed();
        console.log("✅ Factory deployed at:", factory.address);
        
        // Step 3: Create Pool
        console.log("\n3️⃣ Creating Pool...");
        
        const createPoolTx = await factory.createPool(
            tokenA.address,
            tokenB.address,
            3000 // 0.3% fee
        );
        await createPoolTx.wait();
        
        const poolAddress = await factory.getPool(tokenA.address, tokenB.address, 3000);
        console.log("✅ Pool created at:", poolAddress);
        
        // Get pool contract instance
        const pool = new ethers.Contract(poolAddress, SIMPLE_AMM_ABI, signer);
        
        // Step 4: Add Liquidity
        console.log("\n4️⃣ Adding Liquidity...");
        
        const liquidityAmount = parseEther("1000"); // 1000 tokens each
        
        // Approve tokens
        await tokenA.approve(poolAddress, liquidityAmount);
        await tokenB.approve(poolAddress, liquidityAmount);
        console.log("✅ Tokens approved");
        
        // Add liquidity
        const addLiquidityTx = await pool.addLiquidity(
            liquidityAmount,
            liquidityAmount,
            signer.address
        );
        await addLiquidityTx.wait();
        console.log("✅ Liquidity added");
        
        // Check reserves
        const [reserve0, reserve1] = await pool.getReserves();
        console.log("📊 Pool Reserves:");
        console.log("   Reserve 0:", formatEther(reserve0));
        console.log("   Reserve 1:", formatEther(reserve1));
        
        // Step 5: Test Swap
        console.log("\n5️⃣ Testing Swap...");
        
        const swapAmount = parseEther("100"); // Swap 100 tokens
        
        // Approve token A for swap
        await tokenA.approve(poolAddress, swapAmount);
        
        // Calculate expected output (simplified)
        const expectedOutput = reserve1.mul(swapAmount).div(reserve0.add(swapAmount));
        console.log("📈 Expected output:", formatEther(expectedOutput));
        
        // Execute swap (swap token A for token B)
        const swapTx = await pool.swap(
            0, // amount0Out
            expectedOutput.mul(997).div(1000), // amount1Out (with slippage)
            signer.address
        );
        await swapTx.wait();
        console.log("✅ Swap completed");
        
        // Check final reserves
        const [finalReserve0, finalReserve1] = await pool.getReserves();
        console.log("📊 Final Pool Reserves:");
        console.log("   Reserve 0:", formatEther(finalReserve0));
        console.log("   Reserve 1:", formatEther(finalReserve1));
        
        // Check user balances
        const balanceA = await tokenA.balanceOf(signer.address);
        const balanceB = await tokenB.balanceOf(signer.address);
        console.log("💰 Your Token Balances:");
        console.log("   Token A:", formatEther(balanceA));
        console.log("   Token B:", formatEther(balanceB));
        
        console.log("\n🎉 Deployment and testing completed successfully!");
        
        return {
            factory: factory.address,
            tokenA: tokenA.address,
            tokenB: tokenB.address,
            pool: poolAddress
        };
        
    } catch (error) {
        console.error("❌ Error during deployment/testing:", error);
        throw error;
    }
}

// Individual helper functions for manual testing
async function checkPoolReserves(poolAddress) {
    const [signer] = await ethers.getSigners();
    const pool = new ethers.Contract(poolAddress, SIMPLE_AMM_ABI, signer);
    const [reserve0, reserve1] = await pool.getReserves();
    console.log("Pool Reserves:");
    console.log("Reserve 0:", formatEther(reserve0));
    console.log("Reserve 1:", formatEther(reserve1));
    return { reserve0, reserve1 };
}

async function checkTokenBalance(tokenAddress, userAddress) {
    const [signer] = await ethers.getSigners();
    const token = new ethers.Contract(tokenAddress, ERC20_ABI, signer);
    const balance = await token.balanceOf(userAddress);
    const name = await token.name();
    console.log(`${name} balance for ${userAddress}:`, formatEther(balance));
    return balance;
}

async function addLiquidityManual(poolAddress, tokenAAddress, tokenBAddress, amount0, amount1) {
    const [signer] = await ethers.getSigners();
    const pool = new ethers.Contract(poolAddress, SIMPLE_AMM_ABI, signer);
    const tokenA = new ethers.Contract(tokenAAddress, ERC20_ABI, signer);
    const tokenB = new ethers.Contract(tokenBAddress, ERC20_ABI, signer);
    
    // Approve tokens
    await tokenA.approve(poolAddress, parseEther(amount0.toString()));
    await tokenB.approve(poolAddress, parseEther(amount1.toString()));
    
    // Add liquidity
    const tx = await pool.addLiquidity(
        parseEther(amount0.toString()),
        parseEther(amount1.toString()),
        signer.address
    );
    await tx.wait();
    console.log("✅ Liquidity added successfully");
}

// Export functions for manual use
window.deployAndTest = deployAndTest;
window.checkPoolReserves = checkPoolReserves;
window.checkTokenBalance = checkTokenBalance;
window.addLiquidityManual = addLiquidityManual;

console.log("🔧 AMM Interaction Script Loaded!");
console.log("📝 Available functions:");
console.log("   - deployAndTest(): Complete deployment and testing");
console.log("   - checkPoolReserves(poolAddress): Check pool reserves");
console.log("   - checkTokenBalance(tokenAddress, userAddress): Check token balance");
console.log("   - addLiquidityManual(poolAddress, tokenAAddress, tokenBAddress, amount0, amount1): Add liquidity"); 