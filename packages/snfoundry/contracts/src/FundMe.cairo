use starknet::ContractAddress;

#[starknet::interface]
trait IFundMe<TContractState> {
    fn fund(ref self: TContractState, value: u256);
    fn funder(self: @TContractState, position: u256) -> ContractAddress;
    fn funders_length(self: @TContractState) -> u256;
    fn address_to_amount_funded(self: @TContractState, address: ContractAddress) -> u256;
    fn withdraw(ref self: TContractState);
    fn owner(self: @TContractState) -> ContractAddress;
}

#[starknet::contract]
mod FundMe {
    use core::num::traits::zero::Zero;
    use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
    use starknet::{get_caller_address, get_contract_address};
    use super::{ContractAddress, IFundMe};

    const NOT_OWNER: felt252 = 'not owner';
    const ZERO_ADDRESS_CALLER: felt252 = 'Caller is the zero address';

    const MINIMUM_USD: u256 = 5000000000000000000; // ONE_ETH_IN_WEI: 5 * 10 ^ 18;
    const ETH_CONTRACT_ADDRESS: felt252 =
        0x49D36570D4E46F48E99674BD3FCC84644DDD6B96F7C741B1562B82F9E004DC7;

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        GreetingChanged: GreetingChanged
    }

    #[derive(Drop, starknet::Event)]
    struct GreetingChanged {
        #[key]
        greeting_setter: ContractAddress,
        #[key]
        new_greeting: ByteArray,
        premium: bool,
        value: u256,
    }

    #[storage]
    struct Storage {
        eth_token: IERC20CamelDispatcher,
        funders: LegacyMap<u256, ContractAddress>,
        funders_length: u256,
        address_to_amount_funded: LegacyMap<ContractAddress, u256>,
        owner: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        let eth_contract_address = ETH_CONTRACT_ADDRESS.try_into().unwrap();
        self.eth_token.write(IERC20CamelDispatcher { contract_address: eth_contract_address });
        self.owner.write(owner);
    }

    #[abi(embed_v0)]
    impl FundMeImpl of IFundMe<ContractState> {
        fn fund(ref self: ContractState, value: u256) {
            let eth_contract = self.eth_token.read();
            assert(value >= MINIMUM_USD, 'You need to spend more ETH');
            let caller = get_caller_address();
            eth_contract.transferFrom(caller, get_contract_address(), value);
            let previous_funding = self.address_to_amount_funded.read(caller);
            self.address_to_amount_funded.write(caller, previous_funding + value);
            self.funders.write(self.funders_length.read(), caller);
            self.funders_length.write(self.funders_length.read() + 1);
        }
        fn funder(self: @ContractState, position: u256) -> ContractAddress {
            self.funders.read(position)
        }
        fn funders_length(self: @ContractState) -> u256 {
            self.funders_length.read()
        }
        fn address_to_amount_funded(self: @ContractState, address: ContractAddress) -> u256 {
            self.address_to_amount_funded.read(address)
        }
        fn withdraw(ref self: ContractState) {
            // withdraw all the funds to the owner
            self.only_owner();
            let mut index = 0;
            let mut total_amount = 0;
            let funders_length = self.funders_length.read();
            while index < funders_length {
                let funder = self.funders.read(index);
                let amount = self.address_to_amount_funded.read(funder);
                self.address_to_amount_funded.write(funder, 0);
                self.funders.write(index, Zero::zero());
                total_amount += amount;
                index += 1;
            };
            let eth_contract = self.eth_token.read();
            let owner = self.owner.read();
            eth_contract.transfer(owner, total_amount);
        }
        fn owner(self: @ContractState) -> ContractAddress {
            self.owner.read()
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn only_owner(self: @ContractState) {
            let owner = self.owner.read();
            let caller = get_caller_address();
            assert(!caller.is_zero(), ZERO_ADDRESS_CALLER);
            assert(caller == owner, NOT_OWNER);
        }
    }
}
