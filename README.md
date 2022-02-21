# HwmWorker

This gem is intended to use on https://heroeswm.ru flash game. <br>
This is made for automation of boring captcha in game scenario.
So you pass your credentials in specific file, buy a captcha resolver at rucaptacha.com and watch you are going rich.

Also it can now make auto-hunt, you just need to buy an item which allows you to do this, and bot will press this buttons

## Warning

Some of my characters was banned due to use of the app, be careful and do not set your chars to work 24h per day.

## Note

You will need to install selenium and selenium driver.
You can specify prefered selenium driver in `config/initializers.rb`. Here I use `:selenium_chrome`.

For further information use this http://chromedriver.chromium.org/getting-started

## Installation

Download repo

    $ git clone git@github.com:zhisme/hwm_worker.git

And then execute:

    $ bundle install # or bin/setup

Create config files based on samples:

    $ cp .hwm_credentials.sample.yml  .hwm_credentials.yml
    $ cp secrets.sample.yml secrets.yml # can be omitted if ran `bin/setup` command

Fill in with your own game credentials.

## Usage

    $ RACK_ENV=development bin/run
    $ RACK_ENV=development bin/hunt

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ezhdanov/hwm_worker. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the HwmWorker project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/ezhdanov/hwm_worker/blob/master/CODE_OF_CONDUCT.md).
