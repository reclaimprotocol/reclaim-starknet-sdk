use starknet::ContractAddress;
use core::starknet::eth_address::EthAddress;
use starknet::secp256_trait::{Signature};


#[derive(Serde, Drop, Debug, starknet::Store)]
pub struct Epoch {
    epoch_number: u8,  // Current epoch number.
    timestamp_start: u64,  // Start time of the epoch.
    timestamp_end: u64,  // End time of the epoch.
    minimum_witnesses_for_claim_creation: u32,  // Minimum witnesses required to create a claim.
}

#[derive(Serde, Drop, Debug)]
pub struct ClaimInfo {
    pub provider: ByteArray,  // Provider of the claim.
    pub parameters: ByteArray,  // Claim parameters.
    pub context: ByteArray,  // Context of the claim.
}

#[derive(Serde, Drop, Debug)]
pub struct SignedClaim {
    pub claim: CompleteClaimData,  // Complete claim data.
    pub signatures: Array<ReclaimSignature>,  // Array of signatures.
}

#[derive(Serde, Drop, Debug)]
pub struct CompleteClaimData {
    pub identifier: u256,  // Claim identifier.
    pub byte_identifier: ByteArray,  // Byte array representation of the identifier.
    pub owner: ByteArray,  // Owner of the claim.
    pub epoch: ByteArray,  // Epoch associated with the claim.
    pub timestamp_s: ByteArray,  // Timestamp of the claim.
}

#[derive(Serde, Drop, Debug)]
pub struct ReclaimSignature {
    pub r: u256,  // 'r' value of the signature.
    pub s: u256,  // 's' value of the signature.
    pub v: u32,  // 'v' value of the signature.
}

#[derive(Serde, Drop, Debug)]
pub struct Proof {
    pub id: felt252,  // Proof identifier.
    pub claim_info: ClaimInfo,  // Information about the claim.
    pub signed_claim: SignedClaim,  // Signed claim details.
}

#[derive(Serde, Drop, Debug, starknet::Store)]  
struct ReclaimManager {
    id: felt252,  // Manager ID.
    owner: ContractAddress,  // Owner of the contract.
    current_epoch: u8,  // Current epoch number.
    epoch_count: u64,  // Total number of epochs.
}

#[starknet::interface]
pub trait IReclaim<TContractState> {
    fn add_new_epoch(ref self: TContractState, witnesses: Array<u256>, requisite_witnesses_for_claim_create: u32);
    fn get_epoch(ref self: TContractState, epoch_index: felt252) -> Epoch;
    fn verify_proof(ref self: TContractState ,proof: Proof);
    fn create_claim_info(ref self: TContractState, provider: ByteArray, parameters: ByteArray, context: ByteArray) -> ClaimInfo;
    fn create_claim_data(ref self: TContractState, identifier: u256, byte_identifier: ByteArray, owner: ByteArray, epoch: ByteArray, timestamp_s: ByteArray) -> CompleteClaimData;
    fn create_signed_claim(ref self: TContractState, claim: CompleteClaimData, signatures: Array<ReclaimSignature>) -> SignedClaim;
    fn create_claim_info_data(ref self: TContractState, claim_info: ClaimInfo) -> ByteArray;
    fn create_reclaim_signature(ref self: TContractState, r: u256, s:u256, v:u32) -> ReclaimSignature;
    fn process_identifier(ref self: TContractState, input: u256) -> u256;
    fn get_current_witnesses(ref self: TContractState) -> Array<u256>;
    fn u256_to_array_u32(ref self: TContractState,value: u256) -> Array<u32>;
    fn get_signature(self: @TContractState, r: u256, s: u256, v: u32,) -> Signature;
    fn verify_eth_signature(
        self: @TContractState, eth_address: EthAddress, msg_hash: u256, r: u256, s: u256, v: u32,
    );

}

#[starknet::contract]
pub mod ReclaimContract {
    use core::circuit::CircuitInputs;
use core::byte_array::ByteArrayTrait;
    use core::array::ArrayTrait;
    use core::serde::Serde;
    use super::{Epoch, ClaimInfo, SignedClaim, CompleteClaimData, Proof, ReclaimManager, ReclaimSignature, EthAddress, Signature};
    use starknet::ContractAddress;
    use core::starknet::{get_caller_address, get_block_timestamp};
    use super::IReclaim;
    use core::keccak::{compute_keccak_byte_array, keccak_u256s_be_inputs};
    use alexandria_storage::{List, ListTrait};
    use alexandria_math::fast_power::fast_power;
    use starknet::storage::Map;
    use starknet::eth_signature::{verify_eth_signature, public_key_point_to_eth_address, is_eth_signature_valid};
    use starknet::secp256_trait::signature_from_vrs;

    #[storage]
    struct Storage {
        owner: ContractAddress,
        current_epoch: u8,
        reclaim_manager: ReclaimManager,
        epochs: Map::<felt252, Epoch>,
        witnesses: List<u256>,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        let manager = ReclaimManager {
            id: 0,  
            owner: get_caller_address(),
            current_epoch: 0,
            epoch_count: 0,
        };
        self.reclaim_manager.write(manager);
    }


    #[abi(embed_v0)]
    impl Reclaimimpl of super::IReclaim<ContractState> {

        fn add_new_epoch(
            ref self: ContractState,
            witnesses: Array<u256>,
            requisite_witnesses_for_claim_create: u32
        ) {
            // Read the current reclaim manager state
            let mut manager = self.reclaim_manager.read();
            // Get the address of the caller and ensure it's the owner
            let caller_address = get_caller_address();
            assert(caller_address == manager.owner, 'Caller is not the owner');

            // Calculate the new epoch number and timestamps
            let epoch_number = self.current_epoch.read() + 1;
            let timestamp_start = get_block_timestamp();
            let timestamp_end = timestamp_start ;

            // Create a new epoch with the calculated values
            let new_epoch = Epoch{
                epoch_number,
                timestamp_start,
                timestamp_end,
                minimum_witnesses_for_claim_creation: requisite_witnesses_for_claim_create,
            };

            // Determine the index for the new epoch``
            let epoch_index: felt252 = (manager.epoch_count + 1).into();

            // Write the new epoch to storage
            self.epochs.write(epoch_index, new_epoch);
            // Read the current list of witnesses from storage
            let mut witnesses_list = self.witnesses.read();
            let witnesses_len = witnesses_list.len();

            // Clear the existing witnesses list
            let mut count: u32 = 0;
            while count < witnesses_len{
                let _ = witnesses_list.pop_front();
                count += 1;
            };

            // Append the new witnesses to the list
            let witnesses_array_len = witnesses.len();
            let mut i: u32 = 0;
            while i < witnesses_array_len{
                match witnesses.get(i) {
                    Option::Some(element) => {
                        let _ = witnesses_list.append(*element.unbox()); 
                    },
                    Option::None => {}
                };
                i += 1;
            };

            // Update the epoch count and current epoch in the manager state
            manager.epoch_count += 1;
            manager.current_epoch = epoch_number;
            self.reclaim_manager.write(manager);
            self.witnesses.write(witnesses_list);

        }

        //Get the current epoch from contract storage
        fn get_epoch(ref self: ContractState, epoch_index: felt252) -> Epoch {
            self.epochs.read(epoch_index)
        }

        //Get the current witnesses list from contract storage
        fn get_current_witnesses(ref self: ContractState) -> Array<u256> {
            let mut witnesses_list = self.witnesses.read();
            let witnesses_array: Array<u256> = (@witnesses_list).array().expect('syscallresult error');
            witnesses_array
        }

        fn verify_proof(ref self: ContractState, proof: Proof) {

            // Ensure proof has signatures
            assert!(proof.signed_claim.signatures.len() > 0, "No signatures in the proof");
            let claim_info_data = self.create_claim_info_data(proof.claim_info);
            // Hash Claim info Data
            let hash = compute_keccak_byte_array(@claim_info_data);
            // Format the identifier
            let formated_identifier = self.process_identifier(proof.signed_claim.claim.identifier);
            // Ensure the Hashed Claim Data matches the identifier
            assert!(hash == formated_identifier, "Hashed Claim info doesn't match the Identifier");
            // Fetch expected witnesses from the epoch
            let expected_witnesses = self.fetch_witnesses_for_claim(proof.signed_claim.claim.identifier, 1);
            // Recover the signers from the signed claim
            let signed_witnesses = self.recover_signers_of_signed_claim(proof.signed_claim);
            // Check for duplicate signatures
            assert!(!self.contains_duplicates(@signed_witnesses), "Duplicate signatures found");
            // Compare the list of signed witnesses to the expected witnesses
            assert!(signed_witnesses.len() == expected_witnesses.len(), "Mismatch in number of witnesses");
            // Compare the list of signed witnesses to the expected witnesses using the helper function
            assert!(
                self.are_all_signed_witnesses_valid(signed_witnesses, expected_witnesses),
                "Invalid witness found in signed witnesses"
            );
    

        }

        fn create_claim_info(ref self: ContractState, provider: ByteArray, parameters: ByteArray, context: ByteArray) -> ClaimInfo {
            ClaimInfo { provider, parameters, context }
        }
    
        fn create_claim_data(ref self: ContractState, identifier: u256, byte_identifier: ByteArray, owner: ByteArray, epoch: ByteArray, timestamp_s: ByteArray) -> CompleteClaimData {
            CompleteClaimData { identifier, byte_identifier, owner, epoch, timestamp_s }
        }
    
        fn create_signed_claim(ref self: ContractState, claim: CompleteClaimData, signatures: Array<ReclaimSignature>) -> SignedClaim {
            SignedClaim { claim, signatures }
        }

        fn create_reclaim_signature(ref self: ContractState, r: u256, s:u256, v:u32) -> ReclaimSignature {
            ReclaimSignature{ r, s, v}
        }


        // Format the Claim info data
        fn create_claim_info_data(ref self: ContractState,claim_info: ClaimInfo) -> ByteArray{
            let mut claim_info_data = claim_info.provider;
            claim_info_data.append(@"\n");
            claim_info_data.append(@claim_info.parameters);
            claim_info_data.append(@"\n");
            claim_info_data.append(@claim_info.context);

            claim_info_data
        }

        // Format the identifier to be suitable with little endian u256
        fn process_identifier(ref self: ContractState, input: u256) -> u256 {
            let mut result: u256 = 0;
            let mut temp = input;
            // Loop to extract each two-character chunk and reverse the order
            while temp > 0 {
                let chunk = temp % (256_u128).into(); // Extract the last two characters (in hexadecimal)
                result = result * (256_u128).into() + chunk; // Append the chunk to the result
                temp = temp / (256_u128).into(); // Shift the input to the right by two characters (8 bits)
            };
            result
        }

        fn u256_to_array_u32(ref self: ContractState,value: u256) -> Array<u32> {
            let high_high: u32 = (value.high / (fast_power(2_u128,96))).try_into().unwrap();
            let high_mid: u32 = ((value.high / (fast_power(2_u128, 64))) % (fast_power(2_u128,32))).try_into().unwrap();
            let low_mid: u32 = ((value.high / (fast_power(2_u128, 32))) % (fast_power(2_u128, 32))).try_into().unwrap();
            let high_low: u32 = (value.high % (fast_power(2_u128,32))).try_into().unwrap();
            let low_high: u32 = (value.low / (fast_power(2_u128,96))).try_into().unwrap();
            let low_mid_high: u32 = ((value.low / (fast_power(2_u128, 64))) % (fast_power( 2_u128,32))).try_into().unwrap();
            let low_mid_low: u32 = ((value.low / (fast_power( 2_u128, 32))) % (fast_power(2_u128, 32))).try_into().unwrap();
            let low_low: u32 = (value.low % (fast_power( 2_u128, 32))).try_into().unwrap();
        
            array![high_high, high_mid, low_mid, high_low, low_high, low_mid_high, low_mid_low, low_low]
        }


        fn verify_eth_signature(
            self: @ContractState, eth_address: EthAddress, msg_hash: u256, r: u256, s: u256, v: u32
        ) {
            // Get the signature object by combining r, s, and v components.
            let signature = self.get_signature(r, s, v);
            // Verify the Ethereum signature by comparing the message hash, signature, and Ethereum address.
            // If the signature is invalid, this will trigger an error and halt execution.
            verify_eth_signature(:msg_hash, :signature, :eth_address);
        }

        fn get_signature(self: @ContractState, r: u256, s: u256, v: u32,) -> Signature {
            // Create a Signature object from the given v, r, and s values.
            let signature: Signature = signature_from_vrs(v, r, s);
            signature
        }
    }

    #[generate_trait]
    impl Private of PrivateTrait {
        fn fetch_witnesses_for_claim(ref self: ContractState, identifier: u256, epoch_id: felt252) -> Array<u256> {
            // Initialize the list to hold selected witnesses
            let mut selected_witnesses = ArrayTrait::new();
            // Read the witnesses from storage
            let mut witnesses_left_ = self.witnesses.read();
            // Convert stored witnesses to an array
            let mut witnesses_left_list: Array<u256> = (@witnesses_left_).array().expect('syscallresult error');
            let witnesses_left = witnesses_left_list.len();

            // Compute the keccak256 hash of the identifier to use as a seed
            let mut identifier_array = ArrayTrait::new();
            identifier_array.append(identifier);
            let identifier_span = identifier_array.span();
            let complete_hash = keccak_u256s_be_inputs(identifier_span);

        
            // Set up variables for witness selection
            let minimum_witnesses: u32 = (self.epochs.read(epoch_id).minimum_witnesses_for_claim_creation).into();
            let mut byte_offset = 0;
            let complete_hash_array = self.u256_to_array_u32(complete_hash);
            let complete_hash_len = complete_hash_array.len();
            let mut i: u32 = 0;
        
            // Loop to select the required number of witnesses
            while i < minimum_witnesses  {
                // Generate a random seed using a segment of the complete hash
                let mut random_seed: u64 = 0;
                let mut j: u32 = 0;
        
                while j < 4 {
                    let byte_index = (byte_offset + j) % complete_hash_len;
                    let byte: u64 = (*complete_hash_array.at(byte_index)).into();
                    random_seed = (random_seed * 256) + byte;
                    j += 1;
                };

                // Select a witness index based on the random seed
                let witness_index: u32 = (random_seed % witnesses_left.into()).try_into().unwrap();
                let witness = witnesses_left_list[witness_index];
                let _ = selected_witnesses.append(*witness); // Add the selected witness to the list
                
        
                // Swap and remove the selected witness to avoid duplicates
                let last_index = witnesses_left - 1;
                if witness_index != last_index.into() {
                    let last_witness = witnesses_left_list.pop_front().unwrap(); // Assuming pop_front removes from the back
                    let _ = witnesses_left_list.append(last_witness);
                } else {
                    let _ = witnesses_left_list.pop_front();
                }
        
                byte_offset = (byte_offset + 4) % complete_hash_len;
                i += 1;
            };
        
            selected_witnesses
        }

        fn recover_signers_of_signed_claim(ref self: ContractState, signed_claim: SignedClaim) -> Array<u256> {
            let mut recovered_signers = array![];
        
            // Define the Ethereum Signed Message prefix
            let eth_msg_prefix: ByteArray = "\x19Ethereum Signed Message:\n";

            // Concatenate the claim data to form the message
            let mut message = signed_claim.claim.byte_identifier;
            let witnesses = self.get_current_witnesses();
            message.append(@"\n");
            message.append(@signed_claim.claim.owner);
            message.append(@"\n");
            message.append(@signed_claim.claim.timestamp_s);
            message.append(@"\n");
            message.append(@signed_claim.claim.epoch);
        
            // Combine the Ethereum message prefix and the claim message
            let message_length: ByteArray = "122";
            let mut eth_msg = eth_msg_prefix.into();
            eth_msg.append(@message_length);
            eth_msg.append(@message);


            // Compute the hash of the formatted message
            let message_hash = (compute_keccak_byte_array(@eth_msg));
            let formated_message_hash = self.process_identifier(message_hash);


            // // Loop through each signature in the signed claim
            let signatures_len = signed_claim.signatures.len();
            let mut i = 0;
            let witness = *witnesses[0];
            while i < signatures_len {
                let eth_witness: EthAddress = witness.into();
                // Extract r, s, and v components from the signature
                let reclaim_signature = signed_claim.signatures.at(i);
                let signature_r = reclaim_signature.r;
                let signature_s = reclaim_signature.s;
                let signature_v = reclaim_signature.v;
                
                // Create a Signature object from r, s, and v
                let signature: Signature = signature_from_vrs(*signature_v, *signature_r, *signature_s);

                // Check if the signature is valid
                let is_valid = match is_eth_signature_valid(formated_message_hash, signature, eth_witness) {
                    Result::Ok(()) => true,
                    Result::Err(_) => false,
                };

                // Append valid witness to recovered_signers or panic if verification fails
                if is_valid {
                    recovered_signers.append(witness);
                }
                else{
                    core::panic_with_felt252('Signature verification failed');
                }
        
                i += 1;
            };

            recovered_signers
        }

        fn contains_duplicates(ref self: ContractState, array: @Array<u256>) -> bool {
            let mut seen = array![];  // Array to keep track of seen elements
            let mut res: bool = false;
            let len = array.len();
            let mut i = 0;
        
            // Loop through each element in the input array
            while i < len {
                let mut element = array[i];
                // Check if the element is already in the `seen` array
                let mut j = 0;
                while j < seen.len() {
                    if *seen.at(j) == element {
                        res = true;  // Duplicate found
                        break;
                    }
                    j += 1;
                };
                // If no duplicate, add the element to the `seen` array
                seen.append(element);
                i += 1;
            };
        
            res  // No duplicates found
        }

        fn are_all_signed_witnesses_valid(
            ref self: ContractState,
            signed_witnesses: Array<u256>,
            expected_witnesses: Array<u256>
        ) -> bool {
            let mut i = 0;
            let signed_len = signed_witnesses.len();
            let expected_len = expected_witnesses.len();
            let mut result = true;
            // Loop through each signed witness
            while i < signed_len {
                let mut is_valid = false;
                let signed_witness = signed_witnesses.at(i); 
                // Check if the signed witness is in the expected witnesses
                let mut j = 0;
                while j < expected_len {
                    let expected_witness = expected_witnesses.at(j);
                    if *signed_witness == *expected_witness {
                        is_valid = true;
                        break; // No need to continue if we found a match
                    }
                    j += 1;
                };
        
                if !is_valid {
                    result = false;  // If any witness is invalid, set result to false and break
                    break;
                }
                i += 1;
            };
        
            result  // Return the final result of validation
        }
            
    }
}