pragma solidity ^0.6.2;

contract SureVault {
    struct UnderlyingAsset {
        IERC20 token;
        uint256 amount;
    }

    struct AskMetadata {
        uint256 amount;
    }

    struct AskOrder {
        IERC20 lp;
        uint256 minimumPeriodOfGuarantee;
        uint256 apy;

        uint256 lpAmount;
        uint256 snapshotUsdAmount;
        address owner;
    }

    struct BidOrder {
        IERC20 lp;
        uint256 minimumPeriodOfGuarantee;
        uint256 apy;

        // IERC20 token;
        uint256 amount;
        uint256 total;
        uint256 snapshotTotal;
        address owner;
    }

    mapping(IERC20 => IStrategy) strategies;
    AskOrder[] pendingAskOrders;
    BidOrder[] pendingBidOrders;
    mapping(address => AskOrder[]) ownerToPendingAskOrders;
    mapping(address => BidOrder[]) ownerToPendingBidOrders;

    uint256 askIndex;
    uint256 bidIndex;
    mapping(uint256 => uint256) askToBid;
    mapping(uint256 => uint256) bidToAsk;
    mapping(address => uint256[]) ownerToAsks;
    mapping(address => uint256[]) ownerToBids;

    BidSure bidSure;
    AskSure askSure;
    uint liquidationLine = 15;
    uint liquidationReward = 10;
    uint PRECISION = 10000;

    constructor () public {
        bidSure = new BidSure();
        askSure = new AskSure();
    }

    // 承保中的列表
    // 挂掉中的列表

    modifier onlyGov() {
        // TODO
    }

    modifier onlyOwner() {
        // TODO
    }

    function setStrategy(IERC20 token, IStrategy strategy) onlyGov {
        strategies[token] = strategy;
    }

    function execute(AskOrder storage askOrder, BidOrder storage bidOrder) private {
        require(askOrder.lpToken == bidOrder.lpToken);
        require(askOrder.minPromiseTime == bidOrder.minPromiseTime);
        require(askOrder.apy == bidOrder.apy);

        10000.mul(bidOrder.total)
        uint256 remaingBid = bidOrder.snapshotTotal.mul(10000).mul(bidOrder.amount).div(bidOrder.total)

        AskOrder();
        // usdc.transferFrom(bidOrder.owner, address(this), bidOrder.amountPerOrder);


        // owner
        // askOrder.owner
        // validate params
        // assert 保证金-usd / asset-usd > liquidation line(0.15%)

        // transferIn asset-usd & 保证金-usd
        // convert asset-usd to target-token
        // mint 721
        // TODO
        uint256 margin = 123;
        ASK ask = ASK(ask.lpAmount);
        BID bid = BID(bidOrder.apy, USDC, margin, block,timestamp,bidOrder.minimumPeriodOfGuarantee);

        askSure.mint(askOrder.owner, ++askIndex, );
        bidSure.mint(bidOrder.owner, ++bidIndex, );
    }

    function liquidate(uint256 askId, uint256 bidId) onlyOwner(pos) {
        require(askToBid[askId] == bidId);
        require(bidToAsk[bidId] == askId);

        ASK ask = askSure.asks(askId);
        BID bid = bidSure.bids(bidId);
        Strategy strategy = strategies[ask.lpAddress];

        require(strategy != Strategy(address(0)));
        uint256 snapshotUsdAmount = ask.amount;
        uint256 currentUsd = strategy.getunderlying(ask.lpAddress, ask.lpAmount);
        uint256 marginAmount = ask.marginAmount;

        uint256 minLiquidationAmount = snapshotUsdAmount.mul(PRECISION).mul(liquidationLine + PRECISION).div(PRECISION);
        require(minLiquidationAmount >= marginAmount.mul(PRECISION).add(currentUsd.mul(PRECISION)));

        uint256 beforeAmount = usdc.balanceOf(address(this));
        strategy.toUsd(ask.lpAddress, ask.lpAmount);
        uint256 afterAmount = usdc.balanceOf(address(this));

        require(afterAmount >= beforeAmount);
        uint256 inAmount = afterAmount - beforeAmount;
        uint256 total = inAmount.add(marginAmount);

        // TODO
        if (total > snapshotUsdAmount) {
            uint256 remaining = total - snapshotUsdAmount;
            uint256 reward = remaining.mul(liquidationReward).div(PRECISION);
            usdc.transfer(ask.owner, snapshotUsdAmount);
            usdc.transfer(msg.sender, reward);
            usdc.transfer(bid.owner, remaining - reward);
        } else if (total == snapshotUsdAmount) {
            usdc.transfer(ask.owner, snapshotUsdAmount);
        } else {
            usdc.transfer(ask.owner, total);
        }

        askSure.burnWithContract(askId);
        bidSure.burnWithContract(bidId);
    }

    function settle(uint256 askId, uint256 bidId)  {
        require(askToBid[askId] == bidId);
        require(bidToAsk[bidId] == askId);

        ASK ask = askSure.asks(askId);
        BID bid = bidSure.bids(bidId);
        Strategy strategy = strategies[ask.lpAddress];

        require(strategy != Strategy(address(0)));
        require(ask.owner == msg.sender || bid.owner == msg.sender);
        uint256 snapshotUsdAmount = ask.amount;
        uint256 currentUsd = strategy.getUnderling(ask.lpAddress, ask.lpAmount);
        uint256 marginAmount = ask.marginAmount;

        uint256 beforeAmount = usdc.balanceOf(address(this));
        strategy.toUsd(ask.lpAddress, ask.lpAmount);
        uint256 afterAmount = usdc.balanceOf(address(this));

        require(afterAmount >= beforeAmount);
        uint256 inAmount = afterAmount - beforeAmount;
        uint256 total = inAmount.add(marginAmount);

        // TODO
        if (total > snapshotUsdAmount) {
            usdc.transfer(ask.owner, snapshotUsdAmount);
            usdc.transfer(bid.owner, total - snapshotUsdAmount);
        } else if (total == snapshotUsdAmount) {
            usdc.transfer(ask.owner, snapshotUsdAmount);
        } else {
            usdc.transfer(ask.owner, total);
        }

        askSure.burnWithContract(askId);
        bidSure.burnWithContract(bidId);
    }
}
