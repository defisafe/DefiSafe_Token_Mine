pragma solidity 0.6.0;
import "./DefiSafeTokenInterface.sol";
import "./SafeMath.sol";

contract DefiSafeMine {

    using SafeMath for uint256;

    address payable owner;

    address public defiSafeTokenAddress;
    address public defiSafeTokenProjectAddress;
    address public defiSafeTokenOperateAccount;
    uint256 constant private C1 = 7;
    uint256 constant private C2 = 200;
    uint256 constant private DSE_TOKEN_INIT_TOTAL = 1000000000 * 1e18;

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
    }


    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
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

     function setDefiSafeTokenProjectAddress(address _addr)public onlyOwner {
        require(_addr != address(0),"defiSafeTokenProjectAddress error .");
        defiSafeTokenProjectAddress = _addr;
    }

    function setDefiSafeTokenOperateAccount(address _addr)public onlyOwner {
        require(_addr != address(0),"defiSafeTokenOperateAccount error .");
        defiSafeTokenOperateAccount = _addr;
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
        require(defiSafeTokenProjectAddress != address(0),"defiSafeTokenProjectAddress no init .");
        require(defiSafeTokenOperateAccount != address(0),"defiSafeTokenOperateAccount no init .");
        
        DefiSafeTokenInterface defiSafeToken = DefiSafeTokenInterface(defiSafeTokenAddress);
        uint256 tokenAssertRatio = mulDiv(userTotalAssets,C1,C2);
        uint256 tokenAdminBalance = defiSafeToken.balanceOf(defiSafeTokenProjectAddress);
        uint256 tokenOperateBalance = defiSafeToken.balanceOf(defiSafeTokenOperateAccount);
        uint256 tokenMineBalance = defiSafeToken.balanceOf(address(this));
        uint256 tokenSurplusBalance = tokenAdminBalance + tokenOperateBalance + tokenMineBalance;
        uint256 tokenFree = DSE_TOKEN_INIT_TOTAL.sub(tokenSurplusBalance);
        uint256 tokenFreeRatio = tokenFree.div(1e18);
        uint256 tokenTotalRatio = DSE_TOKEN_INIT_TOTAL.div(1e18);
        uint256 tokenDifficulty = mulDiv(tokenAssertRatio,tokenFreeRatio,tokenTotalRatio);
        uint256 mineTokens = tokenAssertRatio.sub(tokenDifficulty);

        if(mineTokens <= (10000000 * 1e18)){
            mineTokens = mineTokens.mul(5);
        }else if(mineTokens <= (40000000 * 1e18)){
            mineTokens = mineTokens.mul(2);
        }else if(mineTokens <= (100000000 * 1e18)){
            mineTokens = mulDiv(mineTokens,15,10);
        }

        if(tokenMineBalance >0 && mineTokens > 0){
            uint256 realMineTokens = 0;
            if(tokenMineBalance > mineTokens){
                realMineTokens = mineTokens;
            }else{
                realMineTokens = tokenMineBalance;
            }
            if(defiSafeToken.transfer(receiveAddress,realMineTokens)){
                mineManager.mineTotalTokens = mineManager.mineTotalTokens.add(realMineTokens);
                emit MineTokensEvent(msg.sender,receiveAddress,realMineTokens);
            }
        }
    }

    function getTotalTokensOfMine()public view returns(uint256){
        return mineManager.mineTotalTokens;
    }

    function getTotalTokensOfFree()public view returns(uint256){
        DefiSafeTokenInterface defiSafeToken = DefiSafeTokenInterface(defiSafeTokenAddress);
        uint256 tokenProjectBalance = defiSafeToken.balanceOf(defiSafeTokenProjectAddress);
        uint256 tokenOperateBalance = defiSafeToken.balanceOf(defiSafeTokenOperateAccount);
        uint256 tokenMineBalance = defiSafeToken.balanceOf(address(this));
        uint256 tokenSurplusBalance = tokenProjectBalance + tokenOperateBalance + tokenMineBalance;
        uint256 tokenFrees = DSE_TOKEN_INIT_TOTAL.sub(tokenSurplusBalance);
        return tokenFrees;
    }



     function mulDiv (uint256 _x, uint256 _y, uint256 _z) public pure returns (uint256) {
        uint256 temp = _x.mul(_y);
        return temp.div(_z);
    }
}