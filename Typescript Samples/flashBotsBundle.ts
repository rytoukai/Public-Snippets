const ethers = require('ethers');
const axios = require('axios');

const providerWSS = new ethers.WebSocketProvider("ws://127.0.0.1:8545")

const flashBotsURL = 'https://relay.flashbots.net'
// const flashBotsWallet = new ethers.Wallet(process.env.flashBotsIdKey)
const flashBotsWallet = ethers.Wallet.createRandom(process.env.infuraWSS)


export async function sendCallBundle(signedTransaction:Transaction) {
    const bundle = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "eth_callBundle",
        "params": [
            {
                txs: [signedTransaction],
                blockNumber: "0x" + ((await providerWSS.getBlockNumber()) + 10).toString(16),
                stateBlockNumber : "latest"
            }
        ]
    }

    const bundleString = JSON.stringify(bundle)
    const signedBundle = flashBotsWallet.address + ":" + await flashBotsWallet.signMessage(ethers.id(bundleString))

    const bundleHeader = {
        "Content-Type" : "application/json",
        "X-Flashbots-Signature" : signedBundle
    }

    const bundleRequest = await axios.post(flashBotsURL, bundleString, {headers: bundleHeader})

    return bundleRequest.data

}

export async function sendPrivateTransaction(signedTransaction:Transaction) {
    const bundle = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "eth_sendPrivateTransaction",
        "params": [
            {
                tx: signedTransaction,
                maxBlockNumber: "0x" + ((await providerWSS.getBlockNumber()) + 10).toString(16),
                preferences: {
                    fast: true,
                    privacy: {
                        hints: ["contract_address", "transaction_hash"],
                        builders: ["default"]
                    }
                }
            }
        ]
    }

    const bundleString = JSON.stringify(bundle)
    const signedBundle = flashBotsWallet.address + ":" + await flashBotsWallet.signMessage(ethers.id(bundleString))

    const bundleHeader = {
        "Content-Type" : "application/json",
        "X-Flashbots-Signature" : signedBundle
    }

    const bundleRequest = await axios.post(flashBotsURL, bundleString, {headers: bundleHeader})

    return bundleRequest.data

}

export async function sendBundle(signedTransaction:Transaction) {
    const bundle = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "eth_sendBundle",
        "params": [
            {
                txs: [signedTransaction],
                blockNumber: "0x" + ((await providerWSS.getBlockNumber()) + 10).toString(16),
                stateBlockNumber : "latest"
            }
        ]
    }

    const bundleString = JSON.stringify(bundle)
    const signedBundle = flashBotsWallet.address + ":" + await flashBotsWallet.signMessage(ethers.id(bundleString))

    const bundleHeader = {
        "Content-Type" : "application/json",
        "X-Flashbots-Signature" : signedBundle
    }

    const bundleRequest = await axios.post(flashBotsURL, bundleString, {headers: bundleHeader})

    return bundleRequest.data

}