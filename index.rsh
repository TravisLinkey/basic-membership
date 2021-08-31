"reach 0.1";
"use strict";

const CommonInterface = {
  // show the address of the winner
  showOutcome: Fun([Address], Null),
  didTransfer: Fun([Bool, UInt], Null),
};

const AliceInterface = {
  ...CommonInterface,
  payUser: Fun([Address], Null),
  getParams: Fun([], Object({
    deadline: UInt,
    signupFee: UInt,
  })),
  getTokenParams: Fun([], Object({
    name: Bytes(32), symbol: Bytes(8),
    url: Bytes(96), metadata: Bytes(32),
    supply: UInt,
  })),
  showToken: Fun(true, Null),
};

const BobInterface = {
  ...CommonInterface,
  addToRoster: Fun([Address], Null),
  returnAmount: Fun([Address], UInt),
  isMember: Fun([Address], Bool),
  shouldGetMembership: Fun([Address, UInt], Bool),
};

export const main = Reach.App(
  { },
  [
    Participant("Alice", AliceInterface),
    ParticipantClass("Bob", BobInterface),
  ],
  (Alice, Bob) => {

    // Helper to display results to everyone
    const showOutcome = (who) =>
      each([Alice, Bob], () => {
        interact.showOutcome(who);
      });

    // 0. Mint new token
    Alice.only(() => {
      const { name, symbol, url, metadata, supply } = declassify(interact.getTokenParams());
      assume(supply == 1000);
    });
    Alice.publish(name, symbol, url, metadata, supply);
    require(supply == 1000);

    const md1 = {name, symbol, url, metadata, supply};
    const tok1 = new Token(md1);
    Alice.interact.showToken(tok1, md1);
    commit();
    
    // 1. Alice publishes the signup fee and deadline
    Alice.only(() => {
      const {signupFee, deadline} = declassify(interact.getParams());
    });
    Alice.publish(signupFee, deadline);

    // 2. Until timeout, allow Bobs to purchase membership
    const [keepGoing, funder, totalSignedUp] = parallelReduce([ true, Alice, 0 ])
      .invariant(balance() == totalSignedUp * signupFee)
      .while(keepGoing)
      .case(Bob,
        (() => ({
           when: balance(tok1) > 0 && declassify(interact.shouldGetMembership(Bob, signupFee)),
        })),
        ((_) => signupFee),
        ((_) => {
          // check: no more tokens
          const buyer = this;
          Bob.only(() => {
            interact.addToRoster(buyer);
          });
          require(balance(tok1) > 0);
          transfer(1, tok1).to(buyer);
          return [ true, funder, totalSignedUp+1 ];
        }))
       .timeout(deadline, () => {
         Anybody.publish();
         return [ false, funder, totalSignedUp ];
       });

      // 3. Transfer the balance to the funder of the contract
      showOutcome(Alice);
      transfer(balance()).to(funder);
       
      //  4. Loop to return Bob's tokens
      var [] = [];
      invariant(balance() == 0);
      while (balance(tok1) !=  tok1.supply()) {
        commit();
        Bob.only(() => {
          const userTokens = declassify(interact.returnAmount(this));
        })
        Bob.publish(userTokens).pay([[userTokens, tok1]]);
        continue;
      }
        
      tok1.burn();
      require(tok1.destroyed() == false);
      tok1.destroy();
      commit();
  }

);
