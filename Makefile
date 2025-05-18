# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

.PHONY: test clean

# Build & test
build                   :; forge build
coverage                :; forge coverage
coverage-export         :; forge coverage --report lcov && genhtml lcov.info -o report --rc derive_function_end_line=0
gas                     :; forge test --gas-report
gas-check               :; forge snapshot --check --tolerance 1
snapshot                :; forge snapshot
clean                   :; forge clean
fmt                     :; forge fmt
test                    :; forge test -vvvv --gas-report

# Deploy
deploy-core-tenderly		:; forge script script/Core.s.sol:CoreDeploy --force --rpc-url tenderly --account ${DEPLOYER_ACCOUNT_NAME} --slow --broadcast -vvvv --verify  
deploy-periphery-tenderly	:; forge script script/Periphery.s.sol:PeripheryDeploy --force --rpc-url tenderly --account ${DEPLOYER_ACCOUNT_NAME} --slow --broadcast -vvvv --verify
deploy-create-leverage-token-tenderly	:; forge script script/CreateLeverageToken.s.sol:CreateLeverageToken --force --rpc-url tenderly --account ${DEPLOYER_ACCOUNT_NAME} --slow --broadcast -vvvv --verify

deploy-core-base		:; forge script script/Core.s.sol:CoreDeploy --force --rpc-url base --account ${DEPLOYER_ACCOUNT_NAME} --slow --broadcast -vvvv --verify  
deploy-periphery-base	:; forge script script/Periphery.s.sol:PeripheryDeploy --force --rpc-url base --account ${DEPLOYER_ACCOUNT_NAME} --slow --broadcast -vvvv --verify
deploy-create-leverage-token-base	:; forge script script/CreateLeverageToken.s.sol:CreateLeverageToken --force --rpc-url base --account ${DEPLOYER_ACCOUNT_NAME} --slow --broadcast -vvvv --verify