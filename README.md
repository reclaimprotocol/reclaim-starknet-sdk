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

## Add New Epoch
```
starkli invoke \                                                                                                 
    <CONTRACT ADDRESS> \
    add_new_epoch \
   <Array Length> <Low Value> <High Value> 1\
    --network=sepolia
```

## Deployments

### Sepolia Testnet

https://sepolia.starkscan.co/contract/0x0765f3f940f7c59288b522a44ac0eeba82f8bf71dd03e265d2c9ba3521466b4e