// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IOracle {
    /// @notice Get the latest exchange rate.
    /// @param data Usually abi encoded, implementation specific data that contains information and arguments to & about the oracle.
    /// For example:
    /// (string memory collateralSymbol, string memory assetSymbol, uint256 division) = abi.decode(data, (string, string, uint256));
    /// @return success if no valid (recent) rate is available, return false else true.
    /// @return rate The rate of the requested asset / pair / pool.
    function get(bytes calldata data) external returns (bool success, uint256 rate);

    /// @notice Check the last exchange rate without any state changes.
    /// @param data Usually abi encoded, implementation specific data that contains information and arguments to & about the oracle.
    /// For example:
    /// (string memory collateralSymbol, string memory assetSymbol, uint256 division) = abi.decode(data, (string, string, uint256));
    /// @return success if no valid (recent) rate is available, return false else true.
    /// @return rate The rate of the requested asset / pair / pool.
    function peek(bytes calldata data) external view returns (bool success, uint256 rate);

    /// @notice Check the current spot exchange rate without any state changes. For oracles like TWAP this will be different from peek().
    /// @param data Usually abi encoded, implementation specific data that contains information and arguments to & about the oracle.
    /// For example:
    /// (string memory collateralSymbol, string memory assetSymbol, uint256 division) = abi.decode(data, (string, string, uint256));
    /// @return rate The rate of the requested asset / pair / pool.
    function peekSpot(bytes calldata data) external view returns (uint256 rate);

    /// @notice Returns a human readable (short) name about this oracle.
    /// @param data Usually abi encoded, implementation specific data that contains information and arguments to & about the oracle.
    /// For example:
    /// (string memory collateralSymbol, string memory assetSymbol, uint256 division) = abi.decode(data, (string, string, uint256));
    /// @return (string) A human readable symbol name about this oracle.
    function symbol(bytes calldata data) external view returns (string memory);

    /// @notice Returns a human readable name about this oracle.
    /// @param data Usually abi encoded, implementation specific data that contains information and arguments to & about the oracle.
    /// For example:
    /// (string memory collateralSymbol, string memory assetSymbol, uint256 division) = abi.decode(data, (string, string, uint256));
    /// @return (string) A human readable name about this oracle.
    function name(bytes calldata data) external view returns (string memory);

    function aggregator() external view returns (address);
}

// DIA Oracle Price Aggregator
interface IAggregator {
    function getValue(string memory key) external view returns (uint256, uint256);
}

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);
}

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";


contract SenecaOracleRETH is IOracle {

    string public oraclename = 'rETH Oracle';
    IAggregator public iaggregator;
    address public aggregator;
    string public key;

    AggregatorV3Interface public wethFeed;
    AggregatorV2V3Interface public ratioFeed;


    AggregatorV2V3Interface internal sequencerUptimeFeed;

    address private owner;
    uint256 private constant GRACE_PERIOD_TIME = 3600;

    constructor(address oracle, string memory _key, address _sequencerUptimeFeed, address _ratioFeed) {
        iaggregator = IAggregator(oracle);
        aggregator = oracle;
        key = _key;

        wethFeed = AggregatorV3Interface(
            aggregator
        );

        sequencerUptimeFeed = AggregatorV2V3Interface(_sequencerUptimeFeed);
        ratioFeed = AggregatorV2V3Interface(_ratioFeed);

        owner = msg.sender;
    }

    // Calculates the lastest exchange rate
    // Uses both divide and multiply only for tokens not supported directly by Chainlink, for example MKR/USD
    function _get() internal view returns (uint256) {
             // prettier-ignore
        (int256 uptimeAnswer, uint256 feedStartedAt ) = getSequencerUptime();
        bool isSequencerUp = uptimeAnswer == 0;
        require(isSequencerUp, "Sequencer Down");
        uint256 timeSinceUp = block.timestamp - feedStartedAt;
        require(timeSinceUp > GRACE_PERIOD_TIME, "Grace Period Not Over");

        uint256 fullAnswer = uint256(getEthPrice()) * uint256(getRatioFeed()) / 1e18 ;

        return 1e26 / fullAnswer;

    }

    // Get the latest exchange rate
    /// @inheritdoc IOracle
    function get(bytes calldata) public view override returns (bool, uint256) {
        return (true, _get());
    }

    // Check the last exchange rate without any state changes
    /// @inheritdoc IOracle
    function peek(bytes calldata) public view override returns (bool, uint256) {
        return (true, _get());
    }

    // Check the current spot exchange rate without any state changes
    /// @inheritdoc IOracle
    function peekSpot(bytes calldata data) external view override returns (uint256 rate) {
        (, rate) = peek(data);
    }

    /// @inheritdoc IOracle
    function name(bytes calldata) public view returns (string memory) {
        return key;
    }

    function getRatioFeed() public view returns(int256) {
            (
            /* uint80 roundID */,
            int answer,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = ratioFeed.latestRoundData();

        return answer;
    }

    function getSequencerUptime() public view returns(int256,uint256) {
        (
            /*uint80 roundID*/,
            int256 answer,
            uint256 startedAt,
            /*uint256 updatedAt*/,
            /*uint80 answeredInRound*/
        ) = sequencerUptimeFeed.latestRoundData();

        return (answer, startedAt);
    }

    /// @inheritdoc IOracle
    function symbol(bytes calldata) public view returns (string memory) {
        return key;
    }

    function getEthPrice() public view returns(int256){
            (
            /* uint80 roundID */,
            int answer,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = wethFeed.latestRoundData();

        return answer;
    }
}
