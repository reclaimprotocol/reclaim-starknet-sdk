# Reclaim - Starknet SDK

## Build
```bash
scarb build
```

## Test
```bash
scarb test 
```

## Declaring the smart contract
```bash
starkli declare target/dev/<NAME>.json --network=sepolia --compiler-version=2.7.1
```

## Deploying the smart contract
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

## Contributing to Our Project

We're excited that you're interested in contributing to our project! Before you get started, please take a moment to review the following guidelines.

## Code of Conduct

Please read and follow our [Code of Conduct](https://github.com/reclaimprotocol/.github/blob/main/Code-of-Conduct.md) to ensure a positive and inclusive environment for all contributors.

## Security

If you discover any security-related issues, please refer to our [Security Policy](https://github.com/reclaimprotocol/.github/blob/main/SECURITY.md) for information on how to responsibly disclose vulnerabilities.

## Contributor License Agreement

Before contributing to this project, please read and sign our [Contributor License Agreement (CLA)](https://github.com/reclaimprotocol/.github/blob/main/CLA.md).

## Indie Hackers

For Indie Hackers: [Check out our guidelines and potential grant opportunities](https://github.com/reclaimprotocol/.github/blob/main/Indie-Hackers.md)

## License

This project is licensed under a [custom license](https://github.com/reclaimprotocol/.github/blob/main/LICENSE). By contributing to this project, you agree that your contributions will be licensed under its terms.

Thank you for your contributions!
