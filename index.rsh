"reach 0.1";
"use strict";

const ROSTERSIZE = 10;

const CommonInterface = {
  // show the address of the winner
  showOutcome: Fun([Address], Null),
};

const AliceInterface = {
  ...CommonInterface,
  getRoster: Fun([], Array(Address, ROSTERSIZE)),
  roster: Array(Address, ROSTERSIZE),
  payUser: Fun([Address], Null),
  getParams: Fun([], Object({
    deadline: UInt,
    signupFee: UInt,
  })),
  getTokenParams: Fun([], Object({
    name: Bytes(32), symbol: Bytes(8),
    url: Bytes(96), metadata: Bytes(32),
    supply: UInt,
    amt: UInt,
  })),
  didTransfer: Fun([Bool, UInt], Null),
  showToken: Fun(true, Null),
};

const BobInterface = {
  ...CommonInterface,
  addToRoster: Fun([Address], Null),
  isMember: Fun([Address], Bool),
  shouldGetMembership: Fun([Address, UInt], Bool),
  wasPaidToday: Fun([Address], Bool),
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
      const { name, symbol, url, metadata, supply, amt } = declassify(interact.getTokenParams());
      assume(4 * amt <= supply);
      assume(4 * amt <= UInt.max);
    });
    Alice.publish(name, symbol, url, metadata, supply, amt);
    require(4 * amt <= supply);
    require(4 * amt <= UInt.max);

    const md1 = {name, symbol, url, metadata, supply};
    const tok1 = new Token(md1);
    Alice.interact.showToken(tok1, md1);
    commit();

    const doTransfer = (who, tokX) => {
      transfer(2 * amt, tokX).to(who);
      who.interact.didTransfer(true, amt);
    };

    // 0.5 Send the tokens to Alice
    Alice.publish();
    doTransfer(Alice, tok1);
    commit();

    // // 1. Alice publishes the ticket price and deadline
    // Alice.only(() => {
    //   const [currentRoster] = declassify([interact.getRoster()]);
    //   const {signupFee, deadline} = declassify(interact.getParams());
    // });
    // Alice.publish(currentRoster, signupFee, deadline);
    
    // // 2. Until timeout, allow Bobs to purchase tickets
    // const [keepGoing, funder, totalSignedUp] = parallelReduce([ true, Alice, 0 ])
    //   .invariant(balance() == totalSignedUp * signupFee)
    //   .while(keepGoing)
    //   .case(Bob,
    //     (() => ({
    //       //  when: declassify(interact.shouldGetMembership(signupFee)),
    //        when: declassify(interact.shouldGetMembership(Bob, signupFee)),
    //       //  when: declassify(interact.isMember(Bob)),
    //     })),
    //     ((_) => signupFee),
    //     ((_) => {
    //       const buyer = this;
    //       Bob.only(() => interact.addToRoster(buyer));
    //       return [ true, funder, totalSignedUp+1 ];
    //     }))
    //    .timeout(deadline, () => {
    //      Anybody.publish();
    //      return [false, funder, totalSignedUp];
    //    });

    //    // 3. Transfer the balance to the last person who bought a ticket
    //    transfer(balance()).to(funder);
    //    commit();
       showOutcome(Alice);

       // 4. burn the tokens correctly
       Alice.pay([[2*amt, tok1]]);
       tok1.burn(supply);
       tok1.destroy();
       commit();
  }

);
