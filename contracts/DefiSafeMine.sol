pragma solidity 0.6.0;
import "./DefiSafeTokenInterface.sol";
import "./SafeMath.sol";

contract DefiSafeMine {

    using SafeMath for uint256;

    address payable owner;

    struct LockedAccountsStruct {
        uint256 totalAmount;
        mapping(uint256 => address) lockAccounts;
    }
    //Control difficulty account management
    LockedAccountsStruct private lockAccountsManager;

    address public defiSafeTokenAddress;
    uint256 constant private C1 = 5;
    uint256 constant private C2 = 14;
    uint256 constant private DSE_TOKEN_INIT_TOTAL = 1000000000 * 1e18;

    struct MineManagerStruct {
        uint256 totalMinersCount;
        uint256 mineTotalTokens;
        //10:Have authority to mine
        mapping(address => uint256) minersPermissions;
    }

    address private communityAccount;
    address public communityRatio;

    struct MineManagerStruct {
        uint256 totalMinersCount;
        uint256 mineTotalTokens;
        //10:Have authority to mine
        mapping(address => uint256) minersPermissions;
    }
    MineManagerStruct private mineManager;

    event MineTokensEvent(address miner,address user,uint256 mineTokens);

    constructor() public {
        owner = msg.sender;
        mineManager = MineManagerStruct({totalMinersCount: 0,mineTotalTokens:0});
        lockAccountsManager = LockedAccountsStruct({totalAmount : 1});
        lockAccountsManager.lockAccounts[0] = address(this);
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function setCommunityRatio(uint256 _ratio)public onlyOwner{
        require(_ratio <= 100,"_ratio error !");
        communityRatio = _ratio;
    }

    function setCommunityAccount(address _communityAddress)public onlyOwner{
        require(_communityAddress != address(0),"communityAddress error !");
        communityAccount = _communityAddress;
    }

    function setLockAccountsManager(uint256 accountID,address accountAddress)public onlyOwner{
        require(accountAddress != address(0),"accountAddress error !");
        require(lockAccountsManager.lockAccounts[accountID] == address(0),"accountAddress is already supported.");
        require(lockAccountsManager.totalAmount == accountID,"accountID error.");

        lockAccountsManager.lockAccounts[accountID] = accountAddress;
        lockAccountsManager.totalAmount = lockAccountsManager.totalAmount+1;
    }

    function setDefiSafeMineAddress(address _addr)public onlyOwner {
        require(_addr != address(0),"DefiSafeMineAddress error .");
        uint256 authority = mineManager.minersPermissions[_addr];
        require(authority != 10,"Has authorized .");
        mineManager.minersPermissions[_addr] = 10;
        mineManager.totalMinersCount = mineManager.totalMinersCount.add(1);
    }

    function removeDefiSafeMineAddress(address _addr)public onlyOwner {
        require(_addr != address(0),"DefiSafeMineAddress error .");
        uint256 authority = mineManager.minersPermissions[_addr];
        require(authority == 10,"No Authority .");
        mineManager.minersPermissions[_addr] = 0;
        mineManager.totalMinersCount = mineManager.totalMinersCount.sub(1);
    }

    function setDefiSafeTokenAddress(address _addr)public onlyOwner {
        require(_addr != address(0),"DefiSafeTokenAddress error .");
        defiSafeTokenAddress = _addr;
    }

    function getMinerPermission(address miner) private returns(bool){
        uint256 authority = mineManager.minersPermissions[miner];
        if(authority == 10){
            return true;
        }else{
            return false;
        }
    }


    function startMine(uint256 userTotalAssets,address receiveAddress) public{
        require(getMinerPermission(msg.sender),"No permission .");
        require(receiveAddress != address(0),"rec address error .");
        require(defiSafeTokenAddress != address(0),"DefiSafeTokenAddress no init .");
        require(lockAccountsManager.totalAmount > 2,"lockAccountsManager no set .");
        require(communityAccount != address(0),"communityAccount error !");

        DefiSafeTokenInterface defiSafeToken = DefiSafeTokenInterface(defiSafeTokenAddress);
        uint256 tokenAssertRatio = mulDiv(userTotalAssets,C1,C2);
        uint256 tokenSurplusBalance = 0;
        uint256 tokenMineBalance = defiSafeToken.balanceOf(address(this));
        for(uint i = 0;i<(lockAccountsManager.totalAmount);i++){
            address lockAccount = lockAccountsManager.lockAccounts[i];
            uint256 lockAccountTokenBalance = defiSafeToken.balanceOf(lockAccount);
            tokenSurplusBalance = tokenSurplusBalance.add(lockAccountTokenBalance);
        }
        uint256 tokenFree = DSE_TOKEN_INIT_TOTAL.sub(tokenSurplusBalance);
        uint256 tokenFreeRatio = tokenFree.div(1e18);
        uint256 tokenTotalRatio = DSE_TOKEN_INIT_TOTAL.div(1e18);
        uint256 tokenDifficulty = mulDiv(tokenAssertRatio,tokenFreeRatio,tokenTotalRatio);
        uint256 mineTokens = tokenAssertRatio.sub(tokenDifficulty);

        if(mineManager.mineTotalTokens <= (10000000 * 1e18)){
            mineTokens = mineTokens.mul(5);
        }else if(mineManager.mineTotalTokens <= (40000000 * 1e18)){
            mineTokens = mineTokens.mul(2);
        }else if(mineManager.mineTotalTokens <= (100000000 * 1e18)){
            mineTokens = mulDiv(mineTokens,15,10);
        }

        if(tokenMineBalance >0 && mineTokens > 0){
            uint256 realMineTokens = 0;
            if(tokenMineBalance > mineTokens){
                realMineTokens = mineTokens;
            }else{
                realMineTokens = tokenMineBalance;
            }

            uint256 communityTokens = mulDiv(realMineTokens,communityRatio,100);
            uint256 userTokens = realMineTokens.sub(communityTokens);

            require(defiSafeToken.transfer(receiveAddress,userTokens),"user receive tokens error !");
            require(defiSafeToken.transfer(communityAccount,communityTokens),"community receive tokens error !");
            mineManager.mineTotalTokens = mineManager.mineTotalTokens.add(userTokens);
            mineManager.mineTotalTokens = mineManager.mineTotalTokens.add(communityTokens);
        }
    }

    function getTotalTokensOfMine()public view returns(uint256){
        return mineManager.mineTotalTokens;
    }

    function getTotalTokensOfFree()public view returns(uint256){
        DefiSafeTokenInterface defiSafeToken = DefiSafeTokenInterface(defiSafeTokenAddress);
        uint256 tokenSurplusBalance = 0;
        for(uint i = 0;i<(lockAccountsManager.totalAmount);i++){
            address lockAccount = lockAccountsManager.lockAccounts[i];
            uint256 lockAccountTokenBalance = defiSafeToken.balanceOf(lockAccount);
            tokenSurplusBalance = tokenSurplusBalance.add(lockAccountTokenBalance);
        }
        uint256 tokenFree = DSE_TOKEN_INIT_TOTAL.sub(tokenSurplusBalance);
        return tokenFrees;
    }


    function getLockAccount(uint256 accountID)public view returns(address){
        require(accountID < lockAccountsManager.totalAmount,"accountID error .");
        return lockAccountsManager.lockAccounts[accountID];
    }


     function mulDiv (uint256 _x, uint256 _y, uint256 _z) public pure returns (uint256) {
        uint256 temp = _x.mul(_y);
        return temp.div(_z);
    }
}