# TokenSigner

Like Rails cookie signing, but allows a custom secret

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'token_signer', VERSION_CONSTRAINT, git: 'https://github.com/buildoutinc/token_signer.git', ref: SOME_REF
```

And then execute:

    $ bundle

## Usage

### Instantiation

Create an instance using your custom secret.

    TokenSigner.new(secret)

When validating a payload, you can also pass in a `max_age` keyword arg, so that signed payloads become invalid when they exceed that age.

### Generating a signed payload

`TokenSigner.generate` can be used to created a signed cookie value, using a secret different from `cookies.signed`.
Make sure to add cookie options `{domain: :all, tld_length: 2}` if needed.
`payload` can be any serializable value, but be mindful of cookie size limits.

    cookies[cookie_name] = {
      value: TokenSigner.generate(payload),
      httponly: true
    }

### Validating a signed payload

Apps in the same domain can validate a token stored in the cookie, using the same secret as was used for `generate`.

    TokenSigner.from_signed_string(cookie_value)
      .when_invalid {
        ...
      }.when_valid do |payload, _|
        ...
      end

### Global instance

If you want a global `TokenSigner` instance for your app, because you have a single global secret, you can store that in `TokenSigner.instance`. It's an `attr_accessor`, initially assigned to a dummy instance.

## Development

### Note on Gemfile.lock

`Gemfile.lock` is in `.gitignore`, but the latest good `Gemfile.lock` is committed as `Gemfile.lock.snapshot`. After you clone the repo, create `Gemfile.lock` as a symlink: `ln -s Gemfile.lock.snapshot Gemfile.lock`.

This is an attempt to strike a balance between the pros & cons outlined by jrochkind in 2019 on this thread: https://www.reddit.com/r/ruby/comments/cr5vwn/gems_should_you_add_gemfilelock_to_git/

### Basic Instructions

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

Make sure to test this gem on ruby & rails versions used by all your apps.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, and push git commits and tags.
