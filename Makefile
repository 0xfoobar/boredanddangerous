test-all:
	forge test --fork-url https://eth.llamarpc.com -vvv

test-azurian:
	forge test --match-contract AzurianTest --fork-url https://eth.llamarpc.com -vvv