// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IMaGaugeStruct {
    struct MaGauge {
        bool active;
        bool stablePair;
        address pair;
        address token0;
        address token1;
        address maGaugeAddress;
        string name;
        string symbol;
        uint maGaugeId;
    }
}
