.PHONY: build clean test test-gas

build    	:; DAPP_BUILD_OPTIMIZE=0 DAPP_BUILD_OPTIMIZE_RUNS=0 dapp --use solc:0.8.13 build
clean    	:; dapp clean
test     	:; DAPP_BUILD_OPTIMIZE=0 DAPP_BUILD_OPTIMIZE_RUNS=0 DAPP_TEST_ADDRESS=0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B dapp --use solc:0.8.13 test -v ${TEST_FLAGS}
test-gas 	: build
			  LANG=C.UTF-8 hevm dapp-test --rpc="${ETH_RPC_URL}" --json-file=out/dapp.sol.json --dapp-root=. --verbose 2 --match "test_gas"
certora-vat	:;certoraRun --solc ~/.solc-select/artifacts/solc-0.8.13 --rule_sanity basic src/Vat.sol --verify Vat:certora/Vat.spec --settings -mediumTimeout=300 --staging$(if $(short), --short_output,)$(if $(rule), --rule $(rule),)$(if $(multi), --multi_assert_check,)
