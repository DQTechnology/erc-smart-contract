pragma solidity ^0.5.0;

library SafeMath {
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;
        return c;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);
        return c;
    }
    
}



contract PRC20 {
    using SafeMath for uint256;

    // 转移余额触发的事件
    event Transfer(address indexed from, address indexed to, uint256 value);

    // 添加管理员
    event AddManager(address manager);
    // 删除管理员
    event RemoveManager(address manager);
    // 添加铸币者
    event AddMinter(address manager, address minter);
    // 删除铸币者
    event RemoveMinter(address manager, address minter);
    // 允许消费触发的事件
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    // 余额
    mapping(address => uint256) private _balanceMap;
    // 可用余额
    mapping(address => mapping(address => uint256)) private _allowedMap;

    // 总供给量
    uint256 private _totalSupply;

    address private _contractOwner;

    // 合约管理员
    mapping(address => bool) private _managerMap;

    // 铸币的人
    mapping(address => bool) private _minterMap;
    string private _name;

    string private _symbol;

    uint8 private _decimal;

    constructor() public {
        _contractOwner = msg.sender;
        _managerMap[msg.sender] = true;
        _name = "点宽积分";
        _symbol = "DQC";
        _decimal = 0;
    }

    modifier onlyContractOwner() {
        require(msg.sender == _contractOwner, "不是合约拥有者");
        _;
    }

    modifier onlyMinter() {
        require(isMinter(msg.sender), "不是铸币者");
        _;
    }

    modifier onlyManager() {
        require(isManager(msg.sender), "不是管理员");
        _;
    }

    /**
     * @dev 获取合约的名字
     */
    function name() external view returns (string memory) {
        return _name;
    }

    /**
     * @dev 获取合约的符号
     */
    function symbol() external view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev 获取精度
     */
    function decimals() public view returns (uint8) {
        return _decimal;
    }

    /**
     * @dev 判断是否是合约管理员
     * @param account 指定地址
     * @return true 或者 false
     */
    function isManager(address account) public view returns (bool) {
        return _managerMap[account];
    }

    /**
     * @dev 增加管理员
     * @param account 指定地址
     * @return true 或者 false
     */
    function addManager(address account)
        public
        onlyContractOwner
        returns (bool)
    {
        _managerMap[account] = true;
        emit AddManager(account);
        return true;
    }

    /**
     * @dev 删除管理员
     * @param account 指定地址
     * @return true 或者 false
     */
    function removeManager(address account)
        public
        onlyContractOwner
        returns (bool)
    {
        // 如果移除的账号是合约部署者则跳过
        if (account != _contractOwner) {
            return false;
        }
        _managerMap[account] = false;

        emit RemoveManager(account);
        return true;
    }

    /**
     * @dev 是不是铸币者
     * @param account 铸币者地址
     * @return true 或者 false
     */
    function isMinter(address account) public view returns (bool) {
        return _minterMap[account];
    }

    /**
     * @dev 增加铸币者
     * @param account 铸币者地址
     */
    function addMinter(address account) public onlyManager {
        // 智能是管理员添加
        _minterMap[account] = true;

         emit AddMinter(msg.sender, account);
    }

    /**
     * @dev 删除铸币者
     * @param account 铸币者地址
     */
    function removeMinter(address account) public onlyManager {
        _minterMap[account] = false;

          emit RemoveMinter(msg.sender, account);
    }

    /**
     * @dev 现存的token数量
     */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev 获取指定地址余额
     * @param owner  指定查询余额的地址
     * @return 返回指定地址类型为 uint256 的余额
     */
    function balanceOf(address owner) public view returns (uint256) {
        return _balanceMap[owner];
    }

    /**
     * @dev 获取token拥有者 指定地址可以消费的余额
     * @param owner token拥有者
     * @param spender token消费者
     * @return 返回消费者可以消费的余额
     */
    function allowance(address owner, address spender)
        public
        view
        returns (uint256)
    {
        return _allowedMap[owner][spender];
    }

    /**
     * @dev 转移token到指定的地址
     * @param to 接收余额的地址
     * @param value 转移的余额
     * @return 转移成功返回true,否则为false
     */
    function transfer(address to, uint256 value) public returns (bool) {
        require(value <= _balanceMap[msg.sender], "余额不足");

        require(to != address(0), "接收转账的地址不能为空");

        _balanceMap[msg.sender] = _balanceMap[msg.sender].sub(value);

        _balanceMap[to] = _balanceMap[to].add(value);

        emit Transfer(msg.sender, to, value);
        return true;
    }

    /**
     * @dev 给指定消费者分配可以消费的余额
     * @param spender 消费者的地址
     * @param value 允许消费的余额
     * @return 分配成功返回true, 否则失败
     */
    function approve(address spender, uint256 value) public returns (bool) {
        require(spender != address(0), "被授权地址不能为空!");
        _allowedMap[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev 转移指定地址的余额到另外地址
     * @param from 余额的地址
     * @param to 接受余额的地址
     * @param value 转移的余额数量
     * @return 转移成功返回true, 否则失败
     */
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public returns (bool) {
        require(value <= _balanceMap[from], "余额不足");
        // 判断当前调用者可以消费的余额
        require(value <= _allowedMap[from][msg.sender], "可消费的余额不足");

        require(to != address(0), "接收转账的地址不能为空");

        _balanceMap[from] = _balanceMap[from].sub(value);
        _balanceMap[to] = _balanceMap[to].add(value);
        _allowedMap[from][msg.sender] = _allowedMap[from][msg.sender].sub(
            value
        );
        emit Transfer(from, to, value);
        return true;
    }

    /**
     * @dev 铸币, 内部函数
     * @param account 接收余额的地址
     * @param amount 余额的数量
     */
    function mint(address account, uint256 amount)
        public
        returns (bool, string memory)
    {
        if (!isMinter(account)) {
            return (false, "铸币失败: 无权限!");
        }

        if (account == address(0)) {
            return (false, "铸币失败: 接受者地址不能为空!");
        }

        _totalSupply = _totalSupply.add(amount);

        _balanceMap[account] = _balanceMap[account].add(amount);

        emit Transfer(address(0), account, amount);

        return (true, "");
    }

    /**
     * @dev 销毁币, 内部函数
     * @param account 销毁指定的地址
     * @param amount 余额的数量
     */
    function burn(address account, uint256 amount)
        public
        returns (bool, string memory)
    {
        if (!isMinter(account)) {
            return (false, "销毁失败: 无权限!");
        }

        if (account == address(0)) {
            return (false, "销毁失败: 销毁地址不能为空!");
        }

        if (amount > _balanceMap[account]) {
            return (false, "销毁失败: 销毁的数量大于地址的余额!");
        }

        _totalSupply = _totalSupply.sub(amount);

        _balanceMap[account] = _balanceMap[account].sub(amount);

        emit Transfer(account, address(0), amount);

        return (true, "");
    }
}
