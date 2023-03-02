//const priceOracle = require('./Utilities/Uniswap Scripts/onChainPriceOracle.js');
//const priceOracle2 = require('./Utilities/Uniswap Scripts/dynamicPool.js');
const priceOracle3 = require('./Utilities/Uniswap Scripts/uniTickPrice.js')
const poolTable = require('./Utilities/allPools.json');
const printer = require('./Utilities/Uniswap Scripts/printer.js')
var ethers = require('ethers');
const https = require('axios');
const { Http2ServerRequest } = require('http2');
require('dotenv').config();
const provider = new ethers.providers.JsonRpcProvider(process.env.infuraURL);
const wallet = new ethers.Wallet(process.env.pKey, provider)
const etherscan = process.env.etherscanAPIKey

var coinSwap = [];
let profitRatio = 1.01;
let maxRat = 0;
let finalIndex = 0;
let flashAmount = 1;

async function comparison(){

    //Main loop to begin checking each entry in provided pool list.
    for (let j = 0; j < (poolTable.length); j++) {   
        var tokenArray = [];

        //Adding information from pool list and fetching prices.
        for (let i = 0; i < (poolTable[j].length); i++) {
            let quotePool = await priceOracle3.priceQuery(
                poolTable[j][i].poolAddress,
                poolTable[j][i].token0Decimals,
                poolTable[j][i].token1Decimals,
                poolTable[j][i].inv
                )
            tokenArray.push({
                "token" : (poolTable[j][i].inv == -1) ? poolTable[j][i].token0 : poolTable[j][i].token1,
                "symbol" : (poolTable[j][i].inv == -1) ? poolTable[j][i].token0Symbol : poolTable[j][i].token1Symbol,
                "val" : (quotePool.tickPrice)*(1 - (poolTable[j][i].poolFee)),
                "fee" : ((poolTable[j][i].poolFee)*1000000)
            })
        }

        //Calculations if swaps are profitable in forward or reverse direction.
        forwardSwap = tokenArray[0].val*tokenArray[1].val
        ratioForward = forwardSwap / tokenArray[2].val
        ratioBackward = ratioForward

    //Checks for a potential swap
        if (ratioForward > profitRatio) {
            console.log('Forward ' + ratioForward + ' ' + tokenArray[0].symbol + ' to ' + tokenArray[2].symbol)
            coinSwap.push({
                "from" : tokenArray[0].token,
                "to" : tokenArray[2].token,
                "ratio" : ratioForward,
                "fee12" : tokenArray[0].fee,
                "fee23" : tokenArray[1].fee,
                "fee31" : tokenArray[2].fee
            })
        }
        if (ratioBackward > profitRatio) {
            console.log('Backward ' + ratioBackward + ' ' + tokenArray[2].symbol + ' to ' + tokenArray[0].symbol)
            coinSwap.push({
                "from" : tokenArray[2].token,
                "to" : tokenArray[0].token,
                "ratio" : ratioBackward,
                "fee12" : tokenArray[2].fee,
                "fee23" : tokenArray[1].fee,
                "fee31" : tokenArray[0].fee
            })
        }
    }

    if (coinSwap.length > 1) {
        for (let i = 0; i != coinSwap.length; i++ )
        if (coinSwap[i].ratio > maxRat) {
            maxRat = coinSwap[i].ratio
            finalIndex = i
        }
    }
}
//Running Script on every block.

let k = 0
let taken = 0
provider.on('block', async ()=> {
    const gas = await https.get(`https://api.etherscan.io/api?module=gastracker&action=gasoracle&apikey=${etherscan}`)
    const fastGasPlus = Number(gas.data.result.FastGasPrice)+2
    check = comparison()
    k += 1
    
    if (coinSwap.length > 0 && gas.data.result.FastGasPrice < 20 && taken == 0) {
        printerCheck = printer.initPrint(
            coinSwap[finalIndex].from,
            coinSwap[finalIndex].to,
            coinSwap[finalIndex].fee12,
            coinSwap[finalIndex].fee23,
            coinSwap[finalIndex].fee31,
            flashAmount,
            wallet,
            fastGasPlus,
            650000
        );
        taken = 1
        console.log(coinSwap[finalIndex].from)
        console.log(coinSwap[finalIndex].to)
        console.log(coinSwap[finalIndex].fee12)
        console.log(coinSwap[finalIndex].fee23)
        console.log(coinSwap[finalIndex].fee31)
        console.log(flashAmount)
        console.log(wallet)
        console.log(fastGasPlus)
        console.log('Printed')
        console.log(JSON.stringify(coinSwap, 2, 2))

    }
    console.log(k)
})