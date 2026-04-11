from dotenv import load_dotenv
from web3 import Web3
import os

load_dotenv()

w3 = Web3(Web3.HTTPProvider(os.getenv("ARBITRUM_RPC_URL")))

def decode_tx(tx_hash):
 tx = w3.eth.get_transaction(tx_hash)
 receipt = w3.eth.get_transaction_receipt(tx_hash)
 print(f"To: {tx['to']}")
 print(f"Value: {w3.from_wei(tx['value'], 'ether')} ETH")
 print(f"Input selector: {tx['input'][:10].hex()}")
 print(f"Status: {'Success' if receipt['status'] == 1 else 'Failed'}")
 print(f"Gas used: {receipt['gasUsed']}")
 print(f"Logs emitted: {len(receipt['logs'])}")
 
decode_tx("0x2a6f23af1d327d14d9b37a7fa52c5eefc2b7ff1340938bdc9d374eaea4d02cc0")
