pragma solidity ^0.6.2;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./BidSure.sol";
import "./AskSure.sol";


interface IStrategy {
    function getUnderlying(IERC20, uint256) external view returns (uint256);

    function ilp2usd(IERC20, IERC20, uint256) external returns (uint256);

    function usd2ilp(IERC20, IERC20, uint256) external returns (uint256);
}

contract Sure {
    using SafeMath for uint256;

    struct AskOrder {
        bytes32 hash;
        IERC20 lp;
        uint256 minimumPeriodOfGuarantee;
        uint256 apy;

        uint256 amount;
        address owner;
        bytes32 salt;
    }

    struct BidOrder {
        bytes32 hash;
        IERC20 lp;
        uint256 minimumPeriodOfGuarantee;
        uint256 apy;

        // IERC20 token;
        uint256 remainingMarginAmount;
        uint256 marginAmount;
        uint256 marginTotal;
        address owner;
        bytes32 salt;
    }

    mapping(address => IStrategy) strategies;

    /* --- 挂单 --- */
    // TODO 维护成本太高，移到链下维护
    AskOrder[] public pendingAskOrders;
    BidOrder[] public pendingBidOrders;
    mapping(address => AskOrder[]) public ownerToPendingAskOrders;
    mapping(address => BidOrder[]) public ownerToPendingBidOrders;
    mapping(bytes32 => AskOrder) public pendingAskOrderMap;
    mapping(bytes32 => BidOrder) public pendingBidOrderMap;

    /* --- 保单 --- */
    // FIXME remove
    uint256 askIndex;
    uint256 bidIndex;
    mapping(uint256 => uint256) askToBid;
    mapping(uint256 => uint256) bidToAsk;
    mapping(address => uint256[]) ownerToAsks;
    mapping(address => uint256[]) ownerToBids;

    IERC20 usdc = IERC20(0xd76bb6fdd24aA5f85ef614Ab3008190cB279953F);

    BidSure public bidSure;
    AskSure public askSure;
    uint liquidationLine = 15;
    uint liquidationReward = 10;
    uint PRECISION = 10000;

    constructor () public {
        bidSure = new BidSure();
        askSure = new AskSure();
        strategies[0x499164394eDda8CF59dE497BA3788842A2e0A8c1] = IStrategy(address(0x581739DC3794d8B46712ff1cdc833eF24aD0612b));
    }
    function add_ask() public{
        ask(IERC20(address(0x499164394eDda8CF59dE497BA3788842A2e0A8c1)),60,10,1000000000000000000,0xfffffffffffffffffffffffffffffffffffff1ffffffffffffffffffffffffff);
    }

    modifier onlyGov() {
        // TODO
        _;
    }


    function setStrategy(IERC20 token, IStrategy strategy) public onlyGov {
        strategies[address(token)] = strategy;
    }

    /* --- 挂单 --- */
    function ask(IERC20 lp, uint256 minimumPeriodOfGuarantee, uint256 apy, uint256 amount, bytes32 salt) public {
        require(lp != IERC20(0x0));
        require(minimumPeriodOfGuarantee > 0);
        require(apy > 0 && apy <= PRECISION);
        require(amount > 0);

        require(pendingAskOrderMap[salt].hash == bytes32(0x0));
        usdc.transferFrom(msg.sender, address(this), amount);
        // FIXME 防止恶意front-running-hash
        AskOrder memory order = AskOrder(salt, lp, minimumPeriodOfGuarantee, apy, amount, msg.sender, salt);

        pendingAskOrders.push(order);
        ownerToPendingAskOrders[msg.sender].push(order);
        pendingAskOrderMap[order.hash] = order;
    }

    function bid(IERC20 lp, uint256 minimumPeriodOfGuarantee, uint256 apy, uint256 marginAmount, uint256 marginTotal, bytes32 salt) public {
        require(lp != IERC20(0x0));
        require(minimumPeriodOfGuarantee > 0);
        require(apy > 0 && apy <= PRECISION);
        // require(amount > 0);
        require(marginAmount > 0);
        require(marginTotal > 0);

        require(pendingAskOrderMap[salt].hash == bytes32(0x0));
        usdc.transferFrom(msg.sender, address(this), marginTotal);

        // FIXME 防止恶意front-running-hash
        BidOrder memory order = BidOrder(salt, lp, minimumPeriodOfGuarantee, apy, marginTotal, marginAmount, marginTotal, msg.sender, salt);

        pendingBidOrders.push(order);
        ownerToPendingBidOrders[msg.sender].push(order);
        pendingBidOrderMap[order.hash] = order;
    }

    /* --- Core --- */
    function executeAsk(bytes32 hash, uint amount, uint256 marginAmount) public {
        AskOrder storage askOrder = pendingAskOrderMap[hash];
        require(askOrder.hash != bytes32(0x0), 'Not exists');
        require(askOrder.amount >= amount, 'Invalid amount');
        uint256 assetAmount = amount;
        uint256 currentMargin = marginAmount;
        askOrder.amount -= assetAmount;

        uint256 minLiquidationAmount = assetAmount.mul(PRECISION).mul(liquidationLine + PRECISION).div(PRECISION);
        require(minLiquidationAmount < currentMargin.mul(PRECISION).add(assetAmount.mul(PRECISION)), 'must be gte min liquidation');
        usdc.transferFrom(msg.sender, address(this), marginAmount);

        IStrategy strategy = strategies[address(askOrder.lp)];
        require(strategy != IStrategy(address(0)), 'empty strategy');

        uint256 beforeLpAmount = askOrder.lp.balanceOf(address(this));
        usdc.transfer(address(strategy),assetAmount);
        strategy.usd2ilp(usdc, askOrder.lp, assetAmount);
        uint256 afterLpAmount = askOrder.lp.balanceOf(address(this));
        require(afterLpAmount >= beforeLpAmount, 'Invalid lp amount');

        AskSure.ASK memory ask = AskSure.ASK(afterLpAmount - beforeLpAmount, askOrder.apy, address(askOrder.lp), amount, block.timestamp, askOrder.minimumPeriodOfGuarantee);
        BidSure.BID memory bid = BidSure.BID(askOrder.apy, currentMargin, block.timestamp, askOrder.minimumPeriodOfGuarantee);

        uint256 askId = ++askIndex;
        uint256 bidId = ++bidIndex;
        askSure.mint(askOrder.owner, askId, ask);
        bidSure.mint(msg.sender, bidId, bid);

        if (askOrder.amount == 0) {
            removeAskItemInPendingAskOrders(askOrder);
            removeAskItemInOwnerToPendingAskOrders(askOrder);
            delete pendingAskOrderMap[askOrder.hash];
        }

        askToBid[askId] = bidId;
        bidToAsk[bidId] = askId;
        ownerToAsks[askOrder.owner].push(askId);
        ownerToBids[msg.sender].push(bidId);
    }

    function executeBid(bytes32 hash, uint256 amount) public {
        BidOrder storage bidOrder = pendingBidOrderMap[hash];
        require(bidOrder.hash != bytes32(0x0), 'Not exists');

        uint256 maxMargin = amount.mul(bidOrder.marginAmount).div(bidOrder.marginTotal);
        require(bidOrder.remainingMarginAmount >= maxMargin);
        uint256 assetAmount = amount;
        uint256 currentMargin = maxMargin;

        bidOrder.remainingMarginAmount -= currentMargin;

        uint256 minLiquidationAmount = assetAmount.mul(PRECISION).mul(liquidationLine + PRECISION).div(PRECISION);
        require(minLiquidationAmount < currentMargin.mul(PRECISION).add(assetAmount.mul(PRECISION)));
        usdc.transferFrom(msg.sender, address(this), amount);

        IStrategy strategy = strategies[address(bidOrder.lp)];
        require(strategy != IStrategy(address(0)));

        uint256 beforeLpAmount = bidOrder.lp.balanceOf(address(this));
        usdc.transfer(address(strategy), assetAmount);
        strategy.usd2ilp(usdc, bidOrder.lp, assetAmount);
        uint256 afterLpAmount = bidOrder.lp.balanceOf(address(this));
        require(afterLpAmount >= beforeLpAmount);

        AskSure.ASK memory ask = AskSure.ASK(afterLpAmount - beforeLpAmount, bidOrder.apy, address(bidOrder.lp), amount, block.timestamp, bidOrder.minimumPeriodOfGuarantee);
        BidSure.BID memory bid = BidSure.BID(bidOrder.apy, currentMargin, block.timestamp, bidOrder.minimumPeriodOfGuarantee);

        uint256 askId = ++askIndex;
        uint256 bidId = ++bidIndex;
        askSure.mint(msg.sender, askId, ask);
        bidSure.mint(bidOrder.owner, bidId, bid);

        if (bidOrder.remainingMarginAmount == 0) {
            removeBidItemInPendingBidOrders(bidOrder);
            removeBidItemInOwnerToPendingBidOrders(bidOrder);
            delete pendingBidOrderMap[bidOrder.hash];
        }

        askToBid[askId] = bidId;
        bidToAsk[bidId] = askId;
        ownerToAsks[msg.sender].push(askId);
        ownerToBids[bidOrder.owner].push(bidId);
    }

    function liquidate(uint256 askId, uint256 bidId) public {
        require(askToBid[askId] == bidId);
        require(bidToAsk[bidId] == askId);

        (AskSure.ASK memory ask, address askOwner) = askSure.asks(askId);
        (BidSure.BID memory bid, address bidOwner) = bidSure.bids(bidId);
        IStrategy strategy = strategies[ask.lpAddress];

        require(strategy != IStrategy(address(0)));

        // int256 snapshotUsdAmount = ask.amount;
        // uint256 currentUsd = strategy.getUnderlying(IERC20(ask.lpAddress), ask.lpAmount) ;
        // uint256 marginAmount = bid.marginAmount;

        uint256 minLiquidationAmount = ask.amount.mul(PRECISION).mul(liquidationLine + PRECISION).div(PRECISION);
        require(minLiquidationAmount >= bid.marginAmount.mul(PRECISION).add(
            strategy.getUnderlying(IERC20(ask.lpAddress), ask.lpAmount).mul(PRECISION))
        );

        uint256 inAmount;
        {
            uint256 beforeAmount = usdc.balanceOf(address(this));
            IERC20(ask.lpAddress).transfer(address(strategy), ask.lpAmount);
            strategy.ilp2usd(usdc, IERC20(ask.lpAddress), ask.lpAmount);
            uint256 afterAmount = usdc.balanceOf(address(this));

            require(afterAmount >= beforeAmount);
            inAmount = afterAmount - beforeAmount;
        }

        transferOut(ask, bid, askOwner, bidOwner, inAmount);

        askSure.burnWithContract(askId);
        bidSure.burnWithContract(bidId);
        delete askToBid[askId];
        delete bidToAsk[bidId];
        removeUintInAsks(askOwner, askId);
        removeUintInBids(bidOwner, bidId);
    }

    function settle(uint256 askId, uint256 bidId) public {
        require(askToBid[askId] == bidId);
        require(bidToAsk[bidId] == askId);

        (AskSure.ASK memory ask, address askOwner) = askSure.asks(askId);
        (BidSure.BID memory bid, address bidOwner) = bidSure.bids(bidId);
        IStrategy strategy = strategies[ask.lpAddress];

        require(strategy != IStrategy(address(0)));
        require(askOwner == msg.sender || askOwner == msg.sender);
        uint256 snapshotUsdAmount = ask.amount;
        // uint256 currentUsd = strategy.getUnderlying(IERC20(ask.lpAddress), ask.lpAmount);
        uint256 marginAmount = bid.marginAmount;

        uint256 inAmount;
        {
            uint256 beforeAmount = usdc.balanceOf(address(this));
            IERC20(ask.lpAddress).transfer(address(strategy), ask.lpAmount);
            strategy.ilp2usd(usdc, IERC20(ask.lpAddress), ask.lpAmount);
            uint256 afterAmount = usdc.balanceOf(address(this));

            require(afterAmount >= beforeAmount);
            inAmount = afterAmount - beforeAmount;
        }
        uint256 total = inAmount.add(marginAmount);

        if (total > snapshotUsdAmount) {
            {
                uint256 remaining = total - snapshotUsdAmount;
                uint256 profit = remaining > marginAmount ? remaining - marginAmount : 0;
                uint256 bidProfit = profit.mul(ask.apy).div(PRECISION);
                uint256 askProfit = profit - bidProfit;

                uint256 bidRefund = marginAmount + bidProfit;

                usdc.transfer(askOwner, snapshotUsdAmount.add(askProfit));
                usdc.transfer(bidOwner, bidRefund);
            }
        } else if (total == snapshotUsdAmount) {
            usdc.transfer(askOwner, snapshotUsdAmount);
        } else {
            usdc.transfer(askOwner, total);
        }

        askSure.burnWithContract(askId);
        bidSure.burnWithContract(bidId);
        delete askToBid[askId];
        delete bidToAsk[bidId];
        removeUintInAsks(askOwner, askId);
        removeUintInBids(bidOwner, bidId);
    }

    function transferOut(AskSure.ASK memory ask, BidSure.BID memory bid, address askOwner, address bidOwner, uint inAmount) private {
        uint256 total = inAmount.add(bid.marginAmount);
        if (total > ask.amount) {
            // uint256 remaining = total - ask.amount;
            uint256 profit = total - ask.amount > bid.marginAmount ? total - ask.amount - bid.marginAmount : 0;
            uint256 bidProfit = profit.mul(ask.apy).div(PRECISION);
            uint256 askProfit = profit - bidProfit;

            uint256 bidRefund = bid.marginAmount + bidProfit;
            uint256 reward = bidRefund.mul(liquidationReward).div(PRECISION);
            bidRefund -= reward;

            usdc.transfer(askOwner, ask.amount.add(askProfit));
            usdc.transfer(msg.sender, reward);
            usdc.transfer(bidOwner, bidRefund);
        } else if (total == ask.amount) {
            usdc.transfer(askOwner, ask.amount);
        } else {
            usdc.transfer(askOwner, total);
        }
    }

    /* --- External --- */
    function removeAskItemInPendingAskOrders(AskOrder memory item) private {
        uint size = pendingAskOrders.length;
        uint lastIndex = size - 1;
        for (uint256 i = 0; i < size; i++) {
            if (pendingAskOrders[i].hash == item.hash) {
                if (i < lastIndex) {
                    pendingAskOrders[i] = pendingAskOrders[lastIndex];
                    pendingAskOrders.pop();
                } else {
                    // delete pendingAskOrders[i];
                    pendingAskOrders.pop();
                }
            }
        }
    }

    function removeAskItemInOwnerToPendingAskOrders(AskOrder memory item) private {
        AskOrder[] storage pendingAskOrders = ownerToPendingAskOrders[item.owner];
        uint size = pendingAskOrders.length;
        uint lastIndex = size - 1;

        for (uint256 i = 0; i < size; i++) {
            if (pendingAskOrders[i].hash == item.hash) {
                if (i < lastIndex) {
                    pendingAskOrders[i] = pendingAskOrders[lastIndex];
                    pendingAskOrders.pop();
                } else {
                    // delete pendingAskOrders[i];
                    pendingAskOrders.pop();
                }
            }
        }
    }


    function removeBidItemInPendingBidOrders(BidOrder memory item) private {
        uint size = pendingBidOrders.length;
        uint lastIndex = size - 1;

        for (uint256 i = 0; i < size; i++) {
            if (pendingBidOrders[i].hash == item.hash) {
                if (i < lastIndex) {
                    pendingBidOrders[i] = pendingBidOrders[lastIndex];
                    pendingBidOrders.pop();
                } else {
                    // delete pendingBidOrders[i];
                    pendingBidOrders.pop();
                }
            }
        }
    }

    function removeBidItemInOwnerToPendingBidOrders(BidOrder memory item) private {
        BidOrder[] storage pendingBidOrders = ownerToPendingBidOrders[item.owner];
        uint size = pendingBidOrders.length;
        uint lastIndex = size - 1;

        for (uint256 i = 0; i < size; i++) {
            if (pendingBidOrders[i].hash == item.hash) {
                if (i < lastIndex) {
                    pendingBidOrders[i] = pendingBidOrders[lastIndex];
                    pendingBidOrders.pop();
                } else {
                    // delete pendingBidOrders[i];
                    pendingBidOrders.pop();
                }
            }
        }
    }

    function removeUintInAsks(address askOwner, uint256 item) private {
        uint256[] storage items = ownerToAsks[askOwner];

        uint size = items.length;
        uint lastIndex = size - 1;
        for (uint256 i = 0; i < size; i++) {
            if (items[i] == item) {
                if (i < lastIndex) {
                    items[i] = items[lastIndex];
                    items.pop();
                } else {
                    // delete items[i];
                    items.pop();
                }
            }
        }
    }

    function removeUintInBids(address bidOwner, uint256 item) private {
        uint256[] storage items = ownerToBids[bidOwner];

        uint size = items.length;
        uint lastIndex = size - 1;
        for (uint256 i = 0; i < size; i++) {
            if (items[i] == item) {
                if (i < lastIndex) {
                    items[i] = items[lastIndex];
                    items.pop();
                } else {
                    // delete items[i];
                    items.pop();
                }
            }
        }
    }


    function allPendingAskOrders() public view returns (AskOrder[] memory) {
        return pendingAskOrders;
    }

    function allOwnerToPendingAskOrders(address owner) public view returns (AskOrder[] memory) {
        return ownerToPendingAskOrders[owner];
    }

    function allPendingBidOrders() public view returns (BidOrder[] memory) {
        return pendingBidOrders;
    }

    function allOwnerToPendingBidOrders(address owner) public view returns (BidOrder[] memory) {
        return ownerToPendingBidOrders[owner];
    }

    function allOwnerToAsks(address owner) public view returns (AskSure.ASK[] memory) {
        uint256[] memory ids = ownerToAsks[owner];
        AskSure.ASK[] memory asks = new AskSure.ASK[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            (AskSure.ASK memory ask,) = askSure.asks(i);
            asks[i] = ask;
        }
        return asks;
    }

    function allOwnerToBids(address owner) public view returns (BidSure.BID[] memory)  {
        uint256[] memory ids = ownerToAsks[owner];
        BidSure.BID[] memory bids = new BidSure.BID[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            (BidSure.BID memory bid,) = bidSure.bids(i);
            bids[i] = bid;
        }
        return bids;
    }
}
