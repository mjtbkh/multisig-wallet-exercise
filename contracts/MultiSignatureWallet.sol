pragma solidity ^0.5.0;

contract MultiSignatureWallet {
    address[] public owners;
    uint public required;
    uint public transactionCount;
    mapping (address => bool) public isOwner;
    mapping (uint => Transaction) public transactions;
    mapping (uint => mapping (address => bool)) public confirmations;


    struct Transaction {
      bool executed;
      address destination;
      uint value;
      bytes data;
    }

    event Confirmation(address indexed sender, uint indexed transactionId);
    event Deposit(address indexed sender, uint value);
    event Execution(uint indexed transactionId);
    event ExecutionFailure(uint indexed transactionId);
    event Submission (uint indexed transactionId);

    /// @dev Fallback function allows to deposit ether.
    function() external payable {
        if (msg.value > 0) emit Deposit(msg.sender, msg.value);
    }

    modifier onlyOwners() {
        require(isOwner[msg.sender]);
        _;
    }
    modifier validRequirement(uint _ownerCount, uint _required) {
        if (_required > _ownerCount || _required == 0 || _ownerCount == 0) revert();
        _;
    }

    /*
     * Public functions
     */
    /// @dev Contract constructor sets initial owners and required number of confirmations.
    /// @param _owners List of initial owners.
    /// @param _required Number of required confirmations.
    constructor(address[] memory _owners, uint _required) public validRequirement(_owners.length, _required) {
        for (uint256 i = 0; i < _owners.length; i++) {
            isOwner[_owners[i]] = true;
        }
        owners = _owners;
        required = _required;
    }

    /// @dev Allows an owner to submit and confirm a transaction.
    /// @param destination Transaction target address.
    /// @param value Transaction ether value.
    /// @param data Transaction data payload.
    /// @return Returns transaction ID.
    function submitTransaction(address destination, uint value, bytes memory data) public onlyOwners returns (uint transactionId) {
        transactionId = addTransaction(destination, value, data);
        confirmTransaction(transactionId);
    }

    /// @dev Allows an owner to confirm a transaction.
    /// @param transactionId Transaction ID.
    function confirmTransaction(uint transactionId) public onlyOwners {
        require(transactions[transactionId].destination != address(0));
        require(confirmations[transactionId][msg.sender] == false);

        confirmations[transactionId][msg.sender] = true;
        emit Confirmation(msg.sender, transactionId);

        executeTransaction(transactionId);
    }

    /// @dev Allows an owner to revoke a confirmation for a transaction.
    /// @param transactionId Transaction ID.
    function revokeConfirmation(uint transactionId) public {}

    /// @dev Allows anyone to execute a confirmed transaction.
    /// @param transactionId Transaction ID.
    function executeTransaction(uint transactionId) public {
        require(transactions[transactionId].executed == false);

        if (isConfirmed(transactionId)) {
            Transaction storage tx = transactions[transactionId];
            tx.executed = true;
            (bool success, bytes memory returnedData) = tx.destination.call.value(tx.value)(tx.data);
            if (success) emit Execution(transactionId);
            else {
                emit ExecutionFailure(transactionId);
                tx.executed = false;
            }
        }
    }

		/*
		 * (Possible) Helper Functions
		 */
    /// @dev Returns the confirmation status of a transaction.
    /// @param transactionId Transaction ID.
    /// @return Confirmation status.
    function isConfirmed(uint transactionId) internal view returns (bool) {
        uint count = 0;
        for (uint i = 0; i < owners.length; i++) {
            if (confirmations[transactionId][owners[i]]) count ++;
            if (count == required) return true;
        }
    }

    /// @dev Adds a new transaction to the transaction mapping, if transaction does not exist yet.
    /// @param destination Transaction target address.
    /// @param value Transaction ether value.
    /// @param data Transaction data payload.
    /// @return Returns transaction ID.
    function addTransaction(address destination, uint value, bytes memory data) internal returns (uint transactionId) {
        transactionId = transactionCount;
        transactions[transactionId] = Transaction({
            destination: destination,
            value: value,
            data: data,
            executed: false
        });
        transactionCount++;
        emit Submission(transactionId);
    }
}
