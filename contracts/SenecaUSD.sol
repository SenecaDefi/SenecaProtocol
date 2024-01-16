/**
    SenUSD
    
    Website: https://senecaprotocol.com/
    Twitter: twitter.com/SenecaUSD
    Telegram: t.me/seneca_protocol
    Linktree: https://linktr.ee/senecaprotocol
**/

// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "./token/oft/v2/fee/OFTWithFee.sol";

/**
 * @title SenecaUSD
 * @notice SenUSD inherits from OFT, which enables senUSD to create a Layer Zero bridge to other chains for the senUSD token in the future
 */

interface IBentoBoxV1 {
    event LogDeposit(address indexed token, address indexed from, address indexed to, uint256 amount, uint256 share);

    function deposit(
        IERC20 token_,
        address from,
        address to,
        uint256 amount,
        uint256 share
    ) external payable returns (uint256 amountOut, uint256 shareOut);
}

contract SenecaUSD is OFTWithFee {
    error SenecaUSD__AmountMustBeMoreThanZero();
    error SenecaUSD__BurnAmountExceedsBalance();
    error SenecaUSD__NotZeroAddress();
    
    address public admin;

    struct Minting {
        uint128 time;
        uint128 amount;
    }

    Minting public lastMint;
    uint256 private constant MINTING_PERIOD = 24 hours;
    uint256 private constant MINTING_INCREASE = 15000;
    uint256 private constant MINTING_PRECISION = 1e5;
    uint256 public supply;
    
    constructor(address _lzEndpoint) OFTWithFee("Seneca USD", "senUSD", 8, _lzEndpoint) {
        admin = msg.sender;
        supply = totalSupply();
    }

    function burn(uint256 _amount) public {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert SenecaUSD__AmountMustBeMoreThanZero();
        }
        if (balance < _amount) {
            revert SenecaUSD__BurnAmountExceedsBalance();
        }
        supply = totalSupply() - _amount;
        _burn(msg.sender, _amount);
    }

    function mint(address _to, uint256 _amount) public onlyOwner {
        require(_to != address(0), "SENUSD: no mint to zero address");

        uint256 totalMintedAmount = uint256(lastMint.time < block.timestamp - MINTING_PERIOD ? 0 : lastMint.amount) + _amount;
        uint256 tempSupply = totalSupply() * MINTING_INCREASE / MINTING_PRECISION;
        require(totalSupply() == 0 || tempSupply >= totalMintedAmount);

        lastMint.time = uint128(block.timestamp);
        lastMint.amount = uint128(totalMintedAmount);

        supply = totalSupply() + _amount;
        _mint(_to, _amount);
    }

    function mintToBentoBox(
        address clone,
        uint256 amount,
        IBentoBoxV1 bentoBox
    ) public onlyOwner {
        mint(address(bentoBox), amount);
        bentoBox.deposit(IERC20(address(this)), address(bentoBox), clone, amount, 0);
    }
}
