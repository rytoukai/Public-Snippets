# Import Dependencies
import time
import json
import requests
import datetime
import numpy as np
import pandas as pd
import pandas_ta as ta
import backtrader as bt
import backtrader.feeds as btfeeds
import backtrader.indicators as btind
import backtrader.analyzers as btanalyzer

from dotenv import load_dotenv
from matplotlib import pyplot as plt

# Data Request


def requestData(reqAsset, reqInterval):
    reqFrom = round(time.time() - 60*reqInterval*720)
    req = requests.get(
        'https://api.kraken.com/0/public/OHLC?pair={}&since={}&interval={}'.format(reqAsset, reqFrom, reqInterval))
    dic = list(json.loads(req.text)['result'])
    dic2 = json.loads(req.text)['result'][dic[0]]
    reqData = pd.DataFrame.from_dict(dic2)
    reqData.drop([5, 7], axis=1, inplace=True)
    reqData.columns = ['date', 'open', 'high', 'low', 'close', 'volume']
    reqData.date = pd.to_datetime(reqData.date,  unit='s')
    reqData.set_index('date', inplace=True)
    reqData[['open', 'high', 'low', 'close', 'volume']] = reqData[[
        'open', 'high', 'low', 'close', 'volume']].apply(pd.to_numeric, errors='coerce', axis=1)
    return reqData

# Custom indicator implementation


class compound(bt.Indicator):
    lines = ('rsi', 'atr', 'ema')
    params = dict(
        keltnerEMA=20,
        keltnerATR=18,
        keltnerMultiplier=1,
        rsiLength=20,
    )

    def __init__(self):
        period1 = self.params.rsiLength
        period2 = self.params.keltnerEMA
        period3 = self.params.keltnerATR
        self.lines.rsi = btind.RSI(self.data, period=period1)
        self.lines.ema = btind.EMA(self.data, period=period2)
        self.lines.atr = btind.AverageTrueRange(self.data, period=period3)

# Strategy implementation


class keltnerStrat(bt.Strategy):

    params = dict(
        keltnerEMA=20,
        keltnerATR=20,
        keltnerMultiplier=2,
        rsiLength=14,
        rsiLowerBound=30,
        rsiUpperBound=70,
        stopMult=2
    )

    def __init__(self):
        self.indicator = compound(
            keltnerEMA=self.params.keltnerEMA,
            keltnerATR=self.params.keltnerATR,
            keltnerMultiplier=self.params.keltnerMultiplier,
            rsiLength=self.params.rsiLength
        )
        self.longStopLoss = 0
        self.shortStopLoss = 0

    def next(self):
        self.rsi = self.indicator.lines.rsi
        self.atr = self.indicator.lines.atr
        self.middleKC = self.indicator.lines.ema
        self.lowerKC = self.middleKC - (self.atr*self.params.keltnerMultiplier)
        self.upperKC = self.middleKC + (self.atr*self.params.keltnerMultiplier)
        self.positionSize = (0.8*cerebro.broker.getvalue()
                             ) / self.data.close[0]

        if not self.position:
            if (self.rsi > self.params.rsiLowerBound) and (self.data.close[0] > self.lowerKC) and (self.data.close[-1] < self.lowerKC):
                self.order = self.buy(
                    data=self.data,
                    size=self.positionSize,
                )
                self.side = 1
                self.longStopLoss = self.lowerKC - self.atr*self.params.stopMult
            elif (self.rsi < self.params.rsiUpperBound) and (self.data.close[0] < self.upperKC) and (self.data.close[-1] > self.upperKC):
                self.order = self.sell(
                    data=self.data,
                    size=self.positionSize,
                )
                self.side = 0
                self.shortStopLoss = self.upperKC + self.atr*self.params.stopMult
        elif self.position:
            if ((self.data.close >= self.middleKC) and self.side == 1):
                self.order = self.close(
                    exectype=bt.Order.StopTrail, trailpercent=0.001)
            elif (self.data.close <= self.longStopLoss) and self.side == 1:
                self.order = self.close()
            elif (self.data.close <= self.middleKC) and self.side == 0:
                self.order = self.close(
                    exectype=bt.Order.StopTrail, trailpercent=0.001)
            elif (self.data.close >= self.shortStopLoss) and self.side == 0:
                self.order = self.close()


# Main Execution - USES MULTITHREADING SET CPUS ACCORDINGLY
if __name__ == '__main__':
    # Backtesting Execution
    cerebro = bt.Cerebro()

    # Add data
    reqData = requestData('ADAUSD', 15)
    assetFrame = btfeeds.PandasData(dataname=reqData)
    cerebro.adddata(assetFrame)

    # Broker Params
    cerebro.broker.set_cash(10000)
    cerebro.broker.setcommission(commission=0.001)

    # Analyzer
    cerebro.addanalyzer(btanalyzer.SharpeRatio, _name='sharpe')
    cerebro.addanalyzer(btanalyzer.Returns, _name='returns')

    # Strategy and optimization
    keltnerPeriod = list(np.arange(14, 21, 1))
    atrPeriod = list(np.arange(7, 21, 1))
    keltnerMult = list(np.arange(0.5, 3, 0.5))

    cerebro.optstrategy(keltnerStrat, keltnerEMA=keltnerPeriod,
                        keltnerATR=atrPeriod, keltnerMultiplier=keltnerMult)

    test = cerebro.run(stdstats=False, maxcpus=8)

    optimizationResults = [[
        i[0].params.keltnerEMA,
        i[0].params.keltnerATR,
        i[0].params.keltnerMultiplier,
        i[0].params.rsiLength,
        i[0].analyzers.sharpe.get_analysis()['sharperatio'],
        i[0].analyzers.returns.get_analysis()['rtot'],
    ] for i in test]

    optimizationFrame = pd.DataFrame(optimizationResults, columns=[
        'keltnerEMA', 'keltnerATR', 'keltnerMultiplier', 'rsiLength', 'sharperatio', 'returns'])
    optimizationFrame.to_csv(
        './data/optimizationResultsKeltner.csv', index=False)
