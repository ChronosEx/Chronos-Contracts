// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import '../interfaces/IGaugeFactoryV2.sol';
import '../MaGauge.sol';

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface IGauge{
    function setDistribution(address _distro) external;

}
contract GaugeFactoryV2 is IGaugeFactory, OwnableUpgradeable {
    
    uint256[50] __gap;
    
    address public last_gauge;

    

    function initialize() initializer  public {
        __Ownable_init();
    }

    function createGaugeV2(address _rewardToken,address _ve,address _token,address _distribution, address _internal_bribe, address _external_bribe, bool _isPair, address _maNFTs, uint _maGaugeId) external returns (address) {
        last_gauge = address(new MaGauge(_rewardToken,_ve,_token,_distribution,_internal_bribe,_external_bribe,_isPair, _maNFTs, _maGaugeId) );
        return last_gauge;
    }

    function setDistribution(address _gauge, address _newDistribution) external onlyOwner {
        IGauge(_gauge).setDistribution(_newDistribution);
    }

}
