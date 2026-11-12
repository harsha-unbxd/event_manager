# frozen_string_literal: true

require_relative "lib/event_manager/version"

Gem::Specification.new do |spec|
  spec.name = "event_manager"
  spec.version = EventManager::VERSION
  spec.authors = ["harsha"]
  spec.email = ["pullela.reddy@netcoreunbxd.com"]

  spec.summary = "Unified event query and send layer for multiple backends"
  spec.description = "Query and publish events through a single API; destinations such as Toucan are pluggable."
  repo = "https://github.com/harsha-unbxd/event_manager"

  spec.homepage = repo
  spec.required_ruby_version = ">= 2.7.8"
  spec.metadata["homepage_uri"] = repo
  spec.metadata["source_code_uri"] = repo
  spec.metadata["changelog_uri"] = "#{repo}/blob/main/CHANGELOG.md"

  # Uncomment the line below to require MFA for gem pushes.
  # This helps protect your gem from supply chain attacks by ensuring
  # no one can publish a new version without multi-factor authentication.
  # See: https://guides.rubygems.org/mfa-requirement-opt-in/
  # spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rubocop-rspec", "~> 3.0"
  spec.add_development_dependency "webmock", "~> 3.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://guides.rubygems.org/make-your-own-gem/
end
