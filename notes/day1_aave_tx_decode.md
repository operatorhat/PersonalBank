# Day 1: Aave Transaction Decoding Notes

## Overview
This document contains notes on manually decoding a transaction using a blockchain explorer.

## Steps for Decoding

1. **Access Blockchain Explorer**  
    Open a blockchain explorer (e.g., Arbiscan) and input the transaction hash.

2. **Identify Key Fields**  
    Observe the following fields in the transaction details:  
    - **To**  
    - **Txn Action Field**  
    - **Input Data**  
    - **Logs**

3. **Find the 4-Byte Fingerprint**  
    Use the following Python command in the CLI to compute the 4-byte fingerprint:  
    ```bash
    python3 -c "from web3 import Web3; print(Web3.keccak(text='depositETH(address,address,uint16)').hex()[:8])"
    ```

4. **Decode Input Data**  
    Decode the data in the "Input Data" field to extract parameter values.

5. **Analyze Logs**  
    - Check the logs to identify events emitted during the transaction execution.  
    - Focus on the **topics** and **data** fields.

6. **Decode Events**  
    Use the following Python command to decode specific events (e.g., `Transfer`):  
    ```bash
    python3 -c "from web3 import Web3; print(Web3.keccak(text='Transfer(address,address,uint256)').hex())"
    ```  
    Map the entire event log to understand the transaction flow.

## Conclusion
By following these steps, the transaction is fully decoded.  