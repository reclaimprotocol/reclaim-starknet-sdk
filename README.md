# Reclaim Starknet SDK

## Build
```bash
scarb build
```

## Test
```bash
scarb test 
```

## Declaring the smart contrac
```bash
starkli declare target/dev/<NAME>.json --network=sepolia --compiler-version=2.7.1
```
## Deploying the smart contrac
```
starkli deploy \
    <CLASS_HASH> \
    <CONSTRUCTOR_INPUTS> \
    --network=sepolia
```

## Deployments

### Sepolia Testnet

https://sepolia.starkscan.co/contract/0x07007b55205428193dfef8863ceea31edfb64e4d3ba6af74a5d4b70907c44de6