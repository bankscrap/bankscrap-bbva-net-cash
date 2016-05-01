# Bankscrap::BBVANetCash

Bankscrap adapter for the API behind BBVA's [Net Cash mobile app](https://play.google.com/store/apps/details?id=com.bbva.netcash).

This adapter is only valid for **company accounts** (the ones that have access to Net Cash). For personal accounts 
you should use [bankscrap-bbva](https://github.com/bankscrap/bankscrap-bbva).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'bankscrap-bbva-net-cash'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install bankscrap-bbva-net-cash

## Usage

### From terminal
#### Bank account balance

    $ bankscrap balance BBVANetCash --user YOUR_USER --password YOUR_PASSWORD --extra=company_code:YOUR_COMPANY_CODE


#### Transactions

    $ bankscrap transactions BBVANetCash --user YOUR_USER --password YOUR_PASSWORD --extra=company_code:YOUR_COMPANY_CODE

---

For more details on usage instructions please read [Bankscrap readme](https://github.com/bankscrap/bankscrap/#usage).

### From Ruby code


```ruby
require 'bankscrap-bbva-net-cash'
bbva_net_cash = Bankscrap::BBVANetCash::Bank.new(YOUR_USER, YOUR_PASSWORD, extra_args: {company_code: YOUR_COMPANY_CODE})
```


## Contributing

1. Fork it ( https://github.com/bankscrap/bankscrap-bbva-net-cash/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
