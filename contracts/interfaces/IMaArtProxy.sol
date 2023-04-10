// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;



interface IMaArtProxy {
    struct maGauge {
      bool active;
      bool stablePair;
      address pair;
      address token0;
      address token1;
      address maGaugeAddress;
      string name;
      string symbol;
    }
    function _tokenURI(uint _tokenId, maGauge memory _maGauge) external pure returns (string memory output);
}
