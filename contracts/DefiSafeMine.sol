pragma solidity 0.6.0;
import "./DefiSafeTokenInterface.sol";


contract DefiSafeMine {

    address payable owner;

    address public defiSafeTokenAddress;
    address public defiSafeTokenOwnerAddress;
    address public defiSafeTokenOperateAccount;
    uint256 constant private C1 = 5;
    uint256 constant private C2 = 14;
    uint256 constant private DSE_TOKEN_INIT_TOTAL = 1000000000 * 1e18;

    address public mineAddress;

    event MineTokensEvent(address name,uint256 mineTokens);

    constructor() public {
        owner = msg.sender;
    }


    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier onlyMine() {
        require(msg.sender == mineAddress);
        _;
    }

    function setDefiSafeMineAddress(address _addr)public onlyOwner {
        require(_addr != address(0),"DefiSafeMineAddress error .");
        mineAddress = _addr;
    }

    function setDefiSafeTokenAddress(address _addr)public onlyOwner {
        require(_addr != address(0),"DefiSafeTokenAddress error .");
        defiSafeTokenAddress = _addr;
    }

     function setDefiSafeTokenOwnerAddress(address _addr)public onlyOwner {
        require(_addr != address(0),"defiSafeTokenOwnerAddress error .");
        defiSafeTokenOwnerAddress = _addr;
    }

    function setDefiSafeTokenOperateAccount(address _addr)public onlyOwner {
        require(_addr != address(0),"defiSafeTokenOperateAccount error .");
        defiSafeTokenOperateAccount = _addr;
    }
 
    function startMine(uint256 userTotalAssets,address receiveAddress) public onlyMine {
        require(defiSafeTokenAddress != address(0),"DefiSafeTokenAddress no init .");
        require(defiSafeTokenOwnerAddress != address(0),"defiSafeTokenOwnerAddress no init .");
        require(defiSafeTokenOperateAccount != address(0),"defiSafeTokenOperateAccount no init .");
        
        DefiSafeTokenInterface defiSafeToken = DefiSafeTokenInterface(defiSafeTokenAddress);
        uint256 tokenAssertRatio = mulDiv(userTotalAssets,C1,C2);
        uint256 tokenAdminBalance = defiSafeToken.getAdminBalance();
        uint256 tokenOperateBalance = defiSafeToken.balanceOf(defiSafeTokenOperateAccount);
        uint256 tokenMineBalance = defiSafeToken.balanceOf(address(this));
        uint256 tokenSurplusBalance = tokenAdminBalance + tokenOperateBalance + tokenMineBalance;
        uint256 tokenFree = DSE_TOKEN_INIT_TOTAL.sub(tokenSurplusBalance);
        uint256 tokenFreeRatio = tokenFree.div(1e18);
        uint256 tokenTotalRatio = DSE_TOKEN_INIT_TOTAL.div(1e18);
        uint256 tokenDifficulty = mulDiv(tokenAssertRatio,tokenFreeRatio,tokenTotalRatio);
        uint256 mineTokens = tokenAssertRatio.sub(tokenDifficulty);
        if(tokenMineBalance >0 && mineTokens > 0){
            uint256 realMineTokens = 0;
            if(tokenMineBalance > mineTokens){
                realMineTokens = mineTokens;
            }else{
                realMineTokens = tokenMineBalance;
            }
            if(defiSafeToken.transfer(receiveAddress,realMineTokens)){
                dataStatistics.mineTotalTokens = dataStatistics.mineTotalTokens.add(realMineTokens);
                emit MineTokensEvent(receiveAddress,realMineTokens);
            }
        }
    }

}