use core::result::ResultTrait;
use snforge_std::{
    declare, ContractClassTrait, ContractClass, EventSpy,
    spy_events, load, cheatcodes::storage::load_felt252, 
};
use core::starknet::{ContractAddress, contract_address_const};
use reclaim::reclaim::{IReclaimDispatcher, IReclaimSafeDispatcher, IReclaimDispatcherTrait};
use reclaim::reclaim::{ReclaimContract, Epoch, Proof, ClaimInfo, SignedClaim, CompleteClaimData};

fn deploy_reclaim() -> (IReclaimDispatcher, ContractAddress) {
    let contract = declare("ReclaimContract").unwrap();
    let mut constructor_calldata = array![];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    let dispatcher = IReclaimDispatcher { contract_address };

    (dispatcher, contract_address)
}

#[test]
fn test_valid_proof_verification() {
    let (reclaim_factory, _reclaim_factory_address) = deploy_reclaim();

    // Set up ClaimInfo
    let claim_info = reclaim_factory.create_claim_info(
        "http",
        "{\"body\":\"\",\"geoLocation\":\"in\",\"method\":\"GET\",\"responseMatches\":[{\"type\":\"regex\",\"value\":\"_steamid\\\">Steam ID: (?<CLAIM_DATA>.*)</div>\"}],\"responseRedactions\":[{\"jsonPath\":\"\",\"regex\":\"_steamid\\\">Steam ID: (?<CLAIM_DATA>.*)</div>\",\"xPath\":\"id(\\\"responsive_page_template_content\\\")/div[@class=\\\"page_header_ctn\\\"]/div[@class=\\\"page_content\\\"]/div[@class=\\\"youraccount_steamid\\\"]\"}],\"url\":\"https://store.steampowered.com/account/\"}",
        "{\"contextAddress\":\"user's address\",\"contextMessage\":\"for acmecorp.com on 1st january\",\"extractedParameters\":{\"CLAIM_DATA\":\"76561199601812329\"},\"providerHash\":\"0xffd5f761e0fb207368d9ebf9689f077352ab5d20ae0a2c23584c2cd90fc1b1bf\"}"
    );

    // Set up CompleteClaimData
    let complete_claim_data = reclaim_factory.create_claim_data(
        0xd1dcfc5338cb588396e44e6449e8c750bd4d76332c7e9440c92383382fced0fd,
        "0xd1dcfc5338cb588396e44e6449e8c750bd4d76332c7e9440c92383382fced0fd",
        "0x13239fc6bf3847dfedaf067968141ec0363ca42f",
        "1",
        "1712174155"
    );

    // Set up signatures
    let mut signatures = array![];
    let r: u256 = 0x2888485f650f8ed02d18e32dd9a1512ca05feb83fc2cbf2df72fd8aa4246c5ee;
    let s: u256 = 0x541fa53875c70eb64d3de9143446229a250c7a762202b7cc289ed31b74b31c81;
    let v: u32 = 28;

    let signature = reclaim_factory.create_reclaim_signature(r, s, v);
    signatures.append(signature);

    // Create SignedClaim
    let signed_claim = reclaim_factory.create_signed_claim(complete_claim_data, signatures);

    // Create Proof
    let proof = Proof {
        id: 0,
        claim_info: claim_info,
        signed_claim: signed_claim,
    };

    // Add witnesses and create a new epoch
    let witnesses: Array<u256> = array![0x244897572368eadf65bfbc5aec98d8e5443a9072];
    let number: u32 = 1;
    reclaim_factory.add_new_epoch(witnesses, number);

    // Verify proof - should pass without issues
    reclaim_factory.verify_proof(proof);
}

#[test]
#[should_panic(expected : "No signatures in the proof")]
fn test_no_signatures_in_proof() {
    let (reclaim_factory, _reclaim_factory_address) = deploy_reclaim();

    // Set up ClaimInfo
    let claim_info = reclaim_factory.create_claim_info(
        "http",
        "{\"body\":\"\",\"geoLocation\":\"in\",\"method\":\"GET\",\"responseMatches\":[{\"type\":\"regex\",\"value\":\"_steamid\\\">Steam ID: (?<CLAIM_DATA>.*)</div>\"}],\"responseRedactions\":[{\"jsonPath\":\"\",\"regex\":\"_steamid\\\">Steam ID: (?<CLAIM_DATA>.*)</div>\",\"xPath\":\"id(\\\"responsive_page_template_content\\\")/div[@class=\\\"page_header_ctn\\\"]/div[@class=\\\"page_content\\\"]/div[@class=\\\"youraccount_steamid\\\"]\"}],\"url\":\"https://store.steampowered.com/account/\"}",
        "{\"contextAddress\":\"user's address\",\"contextMessage\":\"for acmecorp.com on 1st january\",\"extractedParameters\":{\"CLAIM_DATA\":\"76561199601812329\"},\"providerHash\":\"0xffd5f761e0fb207368d9ebf9689f077352ab5d20ae0a2c23584c2cd90fc1b1bf\"}"
    );

    // Set up CompleteClaimData
    let complete_claim_data = reclaim_factory.create_claim_data(
        0xd1dcfc5338cb588396e44e6449e8c750bd4d76332c7e9440c92383382fced0fd,
        "0xd1dcfc5338cb588396e44e6449e8c750bd4d76332c7e9440c92383382fced0fd",
        "0x13239fc6bf3847dfedaf067968141ec0363ca42f",
        "1",
        "1712174155"
    );

    // No signatures added
    let signatures = array![];

    // Create SignedClaim
    let signed_claim = reclaim_factory.create_signed_claim(complete_claim_data, signatures);

    // Create Proof
    let proof = Proof {
        id: 0,
        claim_info: claim_info,
        signed_claim: signed_claim,
    };

    // Add witnesses and create a new epoch
    let witnesses: Array<u256> = array![0x244897572368eadf65bfbc5aec98d8e5443a9072];
    let number: u32 = 1;
    reclaim_factory.add_new_epoch(witnesses, number);

    // Verify proof - should panic with "No signatures in the proof"
    reclaim_factory.verify_proof(proof);
}

#[test]
#[should_panic(expected : "Hashed Claim info doesn't match the Identifier")]
fn test_corrupted_identifier() {
    let (reclaim_factory, _reclaim_factory_address) = deploy_reclaim();

    // Set up ClaimInfo
    let claim_info = reclaim_factory.create_claim_info(
        "http",
        "{\"body\":\"\",\"geoLocation\":\"in\",\"method\":\"GET\",\"responseMatches\":[{\"type\":\"regex\",\"value\":\"_steamid\\\">Steam ID: (?<CLAIM_DATA>.*)</div>\"}],\"responseRedactions\":[{\"jsonPath\":\"\",\"regex\":\"_steamid\\\">Steam ID: (?<CLAIM_DATA>.*)</div>\",\"xPath\":\"id(\\\"responsive_page_template_content\\\")/div[@class=\\\"page_header_ctn\\\"]/div[@class=\\\"page_content\\\"]/div[@class=\\\"youraccount_steamid\\\"]\"}],\"url\":\"https://store.steampowered.com/account/\"}",
        "{\"contextAddress\":\"user's address\",\"contextMessage\":\"for acmecorp.com on 1st january\",\"extractedParameters\":{\"CLAIM_DATA\":\"76561199601812329\"},\"providerHash\":\"0xffd5f761e0fb207368d9ebf9689f077352ab5d20ae0a2c23584c2cd90fc1b1bf\"}"
    );

    // Set up CompleteClaimData with corrupted identifier
    let complete_claim_data = reclaim_factory.create_claim_data(
        0x0000000000000000000000000000000000000000000000000000000000000000, // Corrupted identifier
        "0xd1dcfc5338cb588396e44e6449e8c750bd4d76332c7e9440c92383382fced0fd",
        "0x13239fc6bf3847dfedaf067968141ec0363ca42f",
        "1",
        "1712174155"
    );

    // Set up signatures
    let mut signatures = array![];
    let r: u256 = 0x2888485f650f8ed02d18e32dd9a1512ca05feb83fc2cbf2df72fd8aa4246c5ee;
    let s: u256 = 0x541fa53875c70eb64d3de9143446229a250c7a762202b7cc289ed31b74b31c81;
    let v: u32 = 28;

    let signature = reclaim_factory.create_reclaim_signature(r, s, v);
    signatures.append(signature);

    // Create SignedClaim
    let signed_claim = reclaim_factory.create_signed_claim(complete_claim_data, signatures);

    // Create Proof
    let proof = Proof {
        id: 0,
        claim_info: claim_info,
        signed_claim: signed_claim,
    };

    // Add witnesses and create a new epoch
    let witnesses: Array<u256> = array![0x244897572368eadf65bfbc5aec98d8e5443a9072];
    let number: u32 = 1;
    reclaim_factory.add_new_epoch(witnesses, number);

    // Verify proof - should panic with "Hashed Claim info doesn't match the Identifier"
    reclaim_factory.verify_proof(proof);
}

#[test]
#[should_panic(expected : "Duplicate signatures found")]
fn test_duplicate_signatures() {
    let (reclaim_factory, _reclaim_factory_address) = deploy_reclaim();

    // Set up ClaimInfo
    let claim_info = reclaim_factory.create_claim_info(
        "http",
        "{\"body\":\"\",\"geoLocation\":\"in\",\"method\":\"GET\",\"responseMatches\":[{\"type\":\"regex\",\"value\":\"_steamid\\\">Steam ID: (?<CLAIM_DATA>.*)</div>\"}],\"responseRedactions\":[{\"jsonPath\":\"\",\"regex\":\"_steamid\\\">Steam ID: (?<CLAIM_DATA>.*)</div>\",\"xPath\":\"id(\\\"responsive_page_template_content\\\")/div[@class=\\\"page_header_ctn\\\"]/div[@class=\\\"page_content\\\"]/div[@class=\\\"youraccount_steamid\\\"]\"}],\"url\":\"https://store.steampowered.com/account/\"}",
        "{\"contextAddress\":\"user's address\",\"contextMessage\":\"for acmecorp.com on 1st january\",\"extractedParameters\":{\"CLAIM_DATA\":\"76561199601812329\"},\"providerHash\":\"0xffd5f761e0fb207368d9ebf9689f077352ab5d20ae0a2c23584c2cd90fc1b1bf\"}"
    );

    // Set up CompleteClaimData
    let complete_claim_data = reclaim_factory.create_claim_data(
        0xd1dcfc5338cb588396e44e6449e8c750bd4d76332c7e9440c92383382fced0fd,
        "0xd1dcfc5338cb588396e44e6449e8c750bd4d76332c7e9440c92383382fced0fd",
        "0x13239fc6bf3847dfedaf067968141ec0363ca42f",
        "1",
        "1712174155"
    );

    // Set up duplicate signatures
    let mut signatures = array![];
    let r: u256 = 0x2888485f650f8ed02d18e32dd9a1512ca05feb83fc2cbf2df72fd8aa4246c5ee;
    let s: u256 = 0x541fa53875c70eb64d3de9143446229a250c7a762202b7cc289ed31b74b31c81;
    let v: u32 = 28;

    let signature1 = reclaim_factory.create_reclaim_signature(r, s, v);
    let signature2 = reclaim_factory.create_reclaim_signature(r, s, v);

    signatures.append(signature1);
    signatures.append(signature2); // Duplicate

    // Create SignedClaim
    let signed_claim = reclaim_factory.create_signed_claim(complete_claim_data, signatures);

    // Create Proof
    let proof = Proof {
        id: 0,
        claim_info: claim_info,
        signed_claim: signed_claim,
    };

    // Add witnesses and create a new epoch
    let witnesses: Array<u256> = array![0x244897572368eadf65bfbc5aec98d8e5443a9072];
    let number: u32 = 1;
    reclaim_factory.add_new_epoch(witnesses, number);

    // Verify proof - should panic with "Duplicate signatures found"
    reclaim_factory.verify_proof(proof);
}

#[test]
#[should_panic(expected : 'Signature verification failed')]
fn test_invalid_signature() {
    let (reclaim_factory, _reclaim_factory_address) = deploy_reclaim();

    // Set up ClaimInfo
    let claim_info = reclaim_factory.create_claim_info(
        "http",
        "{\"body\":\"\",\"geoLocation\":\"in\",\"method\":\"GET\",\"responseMatches\":[{\"type\":\"regex\",\"value\":\"_steamid\\\">Steam ID: (?<CLAIM_DATA>.*)</div>\"}],\"responseRedactions\":[{\"jsonPath\":\"\",\"regex\":\"_steamid\\\">Steam ID: (?<CLAIM_DATA>.*)</div>\",\"xPath\":\"id(\\\"responsive_page_template_content\\\")/div[@class=\\\"page_header_ctn\\\"]/div[@class=\\\"page_content\\\"]/div[@class=\\\"youraccount_steamid\\\"]\"}],\"url\":\"https://store.steampowered.com/account/\"}",
        "{\"contextAddress\":\"user's address\",\"contextMessage\":\"for acmecorp.com on 1st january\",\"extractedParameters\":{\"CLAIM_DATA\":\"76561199601812329\"},\"providerHash\":\"0xffd5f761e0fb207368d9ebf9689f077352ab5d20ae0a2c23584c2cd90fc1b1bf\"}"
    );

    // Set up CompleteClaimData
    let complete_claim_data = reclaim_factory.create_claim_data(
        0xd1dcfc5338cb588396e44e6449e8c750bd4d76332c7e9440c92383382fced0fd,
        "0xd1dcfc5338cb588396e44e6449e8c750bd4d76332c7e9440c92383382fced0fd",
        "0x13239fc6bf3847dfedaf067968141ec0363ca42f",
        "1",
        "1712174155"
    );

    // Set up invalid signatures
    let mut signatures = array![];
    let r: u256 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF; // Invalid r
    let s: u256 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF; // Invalid s
    let v: u32 = 28;

    let signature = reclaim_factory.create_reclaim_signature(r, s, v);
    signatures.append(signature);

    // Create SignedClaim
    let signed_claim = reclaim_factory.create_signed_claim(complete_claim_data, signatures);

    // Create Proof
    let proof = Proof {
        id: 0,
        claim_info: claim_info,
        signed_claim: signed_claim,
    };

    // Add witnesses and create a new epoch
    let witnesses: Array<u256> = array![0x244897572368eadf65bfbc5aec98d8e5443a9072];
    let number: u32 = 1;
    reclaim_factory.add_new_epoch(witnesses, number);

    // Verify proof - should panic with "Signature verification failed"
    reclaim_factory.verify_proof(proof);
}
