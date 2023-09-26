const ethers = require('ethers');
const axios = require('axios');
const abiDecoder = require('abi-decoder');
const contractABIList = require('./JSON/contractABI.json')
require('dotenv').config();

/**
Checks and returns the data within a transaction based on the ABI.
Only works with verified contracts
@param txInfo hash from ethereum
@param uniswapRouterOverride Flag to use hard coded Uniswap router abi or not. Contract at 0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD
@return {boolean} validRequest: determine a whether a request is good 
@return {string} response: attribute carrying request data
@return {string} contractABI: pass contract abi onto different functions
*/
export async function checkData(txInfo:any, uniswapRouterOverride:boolean = false) {
    
    let contractABI:string = ""
    let valid:boolean = false
    let decodedData:any  
    let contractABIRequest
    
    if (txInfo != null) {
        
        if (uniswapRouterOverride == false) {
            const etherscanRequestURL = `https://api.etherscan.io/api?module=contract&action=getabi&address=${txInfo.to}&apikey=${process.env.etherscanAPIKey}`
            contractABIRequest = await axios.get(etherscanRequestURL)
        } else {
            contractABIRequest = contractABIList.uniswapRouter
        }
    
        // console.log("REQUEST PRE JSON PARSE")
        // console.log("Type of Object: ", typeof(contractABIRequest.data.result))
        // console.log(contractABIRequest.data.result)
    
        try {
            contractABI = await JSON.parse(contractABIRequest.data.result)
            abiDecoder.addABI(contractABI)
            decodedData = abiDecoder.decodeMethod(txInfo.data)
            valid = true
        } 
        catch(e) {
            valid = false
            decodedData = 'Bad Request'
        }
    }

    return {
        "validRequest" : valid,
        "response" : decodedData,
        "contractABI" : contractABI
    }
    
}

const uniRouterCommands:{[index:string]: any}= {
    "00" : [["function V3_SWAP_EXACT_IN(address, uint256, uint256, bytes, bool)"],["address", "uint256", "uint256", "bytes", "bool"]],
    "01" : [["function V3_SWAP_EXACT_OUT(address, uint256, uint256, bytes, bool)"],["address", "uint256", "uint256", "bytes", "bool"]],
    "08" : [["function V2_SWAP_EXACT_IN(address, uint256, uint256, address[], bool)"],["address", "uint256", "uint256", "address[]", "bool"]],
    "09" : [["function V2_SWAP_EXACT_OUT(address, uint256, uint256, address[], bool)"],["address", "uint256", "uint256", "address[]", "bool"]],
    "0b" : [["function WRAP_ETH(address, uint256)"],["address", "uint256"]],
    "0c" : [["function UNWRAP_ETH(address, uint256)"],["address", "uint256"]]
}

/**
Decodes data nested further within object.
Can only work if checkData works
@param contractABI Relies on ABI from checkData
@param params Inner contract data 
@param commands Uniswap router commands. ex: 0x0a080c
@return Decoded transaction data
*/
export function uniUniversalRouterDecode(commands:string, dataArray:any) {
    let decodedData:any[] = []
    let commandArray:string[] = []
    let dataIndex:number[] = []
    let amountSwapped:number[] = []
    let swapAddresses:string[] = []
    let v3poolFee:string[] = []
    let v3:boolean = false
    let v2:boolean = false

    const newVal = commands.slice(2)
    for (let i = 0; i < newVal.length; i+=2) {
        commandArray.push(newVal[i] + newVal[i+1])
    }

    for (let i = 0; i < commandArray.length; i++) {
        commandArray[i] = commandArray[i].padStart(2,"0")
    }

    for (let i = 0; i < commandArray.length; i++) {
        if (commandArray[i] in uniRouterCommands) {
            const abiArray = uniRouterCommands[commandArray[i]][0][0]
            const typesArray = uniRouterCommands[commandArray[i]][1]
            const ethersArray = new ethers.Interface([abiArray])
            decodedData = ethersArray._decodeParams(typesArray, dataArray[i])
            dataIndex.push(i)
        }

        if (commandArray[i] === ('00' || '01')) {

            amountSwapped.push(decodedData[1])
            amountSwapped.push(decodedData[2])
            let tempData:string = decodedData[3].slice(2)

            for (let i:number =0; ; i++) {
                if (tempData.length > 46) {
                    swapAddresses.push(tempData.substring(0,40))
                    v3poolFee.push(parseInt(tempData.substring(41,46), 16).toString())
                    tempData = tempData.slice(46)
                } else if (tempData.length == 40) {
                    swapAddresses.push(tempData.substring(0,40))
                    break
                }
            }
            v3 = true

        } else if (commandArray[i] === ("08" || '09')) {

            amountSwapped.push(decodedData[1])
            amountSwapped.push(decodedData[2])

            let recData:string[] = []
            for(let i =0; i < decodedData[3].length; i++) {
                recData[i] = decodedData[3][i].slice(2)
                swapAddresses.push(recData[i])
            }

            v2 = true
        }
    }

    for (let i = 0; i<swapAddresses.length; i++) {
        swapAddresses[i] = "0x" + swapAddresses[i]
    }

    return { 
        v2,
        v3,
        amountSwapped,
        swapAddresses,
        v3poolFee
    }
}

