use starknet::ContractAddress;
use starknet::class_hash::ClassHash;

#[starknet::interface]
pub trait IUpgradeableContract<TContractState> {
    fn upgrade(ref self: TContractState, impl_hash: ClassHash);
    fn version(self: @TContractState) -> u8;
}

#[starknet::interface]
pub trait IHelloStarknet<TContractState> {
    fn increase_balance(ref self: TContractState, amount: felt252);
    fn get_balance(self: @TContractState) -> felt252;
    fn add_user(ref self: TContractState, username: felt252);
    fn get_user(self: @TContractState, useraddress: ContractAddress) -> felt252;
    fn get_owner(self: @TContractState) -> ContractAddress;
    fn get_right_owner(self: @TContractState) -> ContractAddress;
}

#[starknet::contract]
mod HelloStarknet {
    use super::{IHelloStarknet, ClassHash};
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use starknet::SyscallResultTrait;
    use core::num::traits::Zero;

    #[storage]
    struct Storage {
        balance: felt252,
        users: LegacyMap<ContractAddress, felt252>,
        owner: ContractAddress,
        version: u8,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Upgraded: Upgraded
    }

    #[derive(Drop, starknet::Event)]
    struct Upgraded {
        implementation: ClassHash
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
    }

    #[abi(embed_v0)]
    impl HelloStarknetImpl of IHelloStarknet<ContractState> {
        fn increase_balance(ref self: ContractState, amount: felt252) {
            assert(amount != 0, 'Amount cannot be 0');
            self.balance.write(self.balance.read() + amount);
        }

        fn get_balance(self: @ContractState) -> felt252 {
            self.balance.read()
        }

        fn add_user(ref self: ContractState, username: felt252) {
            let user_address = get_caller_address();
            self.users.write(user_address, username);
        }

        fn get_user(self: @ContractState, useraddress: ContractAddress) -> felt252 {
            self.users.read(useraddress)
        }

        fn get_owner(self: @ContractState) -> ContractAddress {
            self.owner.read()
        }

        fn get_right_owner(self: @ContractState) -> ContractAddress {
            self.owner.read()
        }
    }

    #[abi(embed_v0)]
    impl UpgradeableContract of super::IUpgradeableContract<ContractState> {
        fn upgrade(ref self: ContractState, impl_hash: ClassHash) {
            assert(impl_hash.is_non_zero(), 'Class hash cannot be zero');
            assert(get_caller_address() == self.get_right_owner(), 'Not owner');
            starknet::syscalls::replace_class_syscall(impl_hash).unwrap_syscall();
            self.version.write(self.version.read() + 1);
            self.emit(Event::Upgraded(Upgraded { implementation: impl_hash }))
        }

        fn version(self: @ContractState) -> u8 {
            self.version.read()
        }
    }
}
