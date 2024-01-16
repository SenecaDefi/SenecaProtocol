// SPDX-License-Identifier: MIT

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";

pragma solidity >=0.5.0 <0.8.0;

    interface OracleInterface {
        function assetPriceFeed(address _asset) external view returns (IAggregatorV3);
        function getOraclePrice(address _asset) external view returns (int256); 
        function getSpotPrice(address _asset) external view returns (uint256); 
        function getAmountPriced(uint256 _amount, address _asset) external view returns (uint256); 
        function getAmountInAsset(uint256 _amount, address _asset) external view returns (uint256);
    }

    interface governanceLockInterface {
        function getUserLock(address account, uint256 index) external view returns(uint256 amount, uint256 start, bool renewed);
        function userLockCount(address account) external view returns(uint256 count);
    }

    interface IEngines {
    function s_SenUSDMinted(address user) external view returns (uint256);
    function s_SenUSD_Debt(address user) external view returns (uint256);
    function s_SenUSDMintedLastTimestamp(address user) external view returns (uint40);
    function getAccountCollateralValue(address user) external view returns (uint256);
    }

    interface IERC20 {
    function decimals() external view returns (uint8);
    function balanceOf(address account) external view returns (uint256);
    }


    interface IAggregatorV3 {
        function latestAnswer() external view returns (int256);
    }

contract RegistryContract {

    struct CollateralInfo {
        address collateralTokenAddress;
        address stableEngineAddress;
    }

    CollateralInfo[] public collateralList;
    address public owner;
    address public operator;

    constructor() public {
        owner = msg.sender;
    }

    function addCollateralInfo(address _collateralTokenAddress, address _stableEngineAddress) public {
        require(owner == msg.sender || operator == msg.sender, 'not the owner');
        CollateralInfo memory newCollateralInfo = CollateralInfo({
            collateralTokenAddress: _collateralTokenAddress,
            stableEngineAddress: _stableEngineAddress
        });

        collateralList.push(newCollateralInfo);
    }
    
    function getCollateralIndex(address _collateralTokenAddress) internal view returns (uint256) {
        uint256 listLength = collateralList.length;
        for(uint256 i = 0; i < listLength; i++) {
            if(collateralList[i].collateralTokenAddress == _collateralTokenAddress) {
                return i;
            }
        }
        revert("Collateral address not found");
    }

    function getCollateralTokens() external view returns (address[] memory, address[] memory) {
        uint256 cachedLength = collateralList.length;
        address[] memory collateralTokenAddresses = new address[](cachedLength);
        address[] memory stableEngineAddresses = new address[](cachedLength);

        for(uint256 i = 0; i < cachedLength; i++) {
            CollateralInfo storage info = collateralList[i];
            collateralTokenAddresses[i] = info.collateralTokenAddress;
            stableEngineAddresses[i] = info.stableEngineAddress;
        }
        return (collateralTokenAddresses, stableEngineAddresses);
    }
    
    function deleteCollateralInfo(address _collateralTokenAddress) public {
        require(owner == msg.sender || operator == msg.sender, 'not the owner');
        uint256 indexToDelete = getCollateralIndex(_collateralTokenAddress);

        collateralList[indexToDelete] = collateralList[collateralList.length - 1];
        collateralList.pop();
    }

    function addOperator(address operatorAddress) public {
        require(owner == msg.sender, 'not owner');
        operator = operatorAddress;
    }
}
