var ethers = require('ethers')
require('dotenv').config();

const addressTWAP = '0x6AE0F2E176B80A5e799Cc0898b863a0966424496';
const abiTWAP = ["function getTWAP(address token0, address token1, uint24 fee, uint128 amountIn) external view returns (uint256 amountOut)"]
const provider = new ethers.providers.JsonRpcProvider(process.env.infuraURL);
const priceContract = new ethers.Contract(addressTWAP, abiTWAP, provider);

async function priceQuery(token0, token1, fee, token0decimal, token1decimal, amountIn) {

    const amount = ethers.utils.parseUnits(amountIn.toString(), token0decimal)
    let priceOracle = await priceContract.getTWAP(token0, token1, fee, amount);
    amountOut = ethers.utils.formatUnits((priceOracle).toString(), token1decimal)
    return { 'val' : amountOut }
}

module.exports = { priceQuery };