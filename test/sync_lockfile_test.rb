# frozen_string_literal: true

# Run with: ruby test/sync_lockfile_test.rb
# The sync tests run `bundle lock` against rubygems.org; set
# SYNC_LOCKFILE_OFFLINE=1 to skip them.
require 'minitest/autorun'
require 'stringio'
require 'tmpdir'
load File.expand_path('../bin/sync-lockfile', __dir__)

class SyncLockfileTest < Minitest::Test
  PLATFORMS = ['arm64-darwin', 'x86_64-linux'].freeze

  # Builds Gemfile.lock text. +specs+ maps "name (version)" to its dependency
  # lines; a version with a platform suffix is a platform variant.
  def lock(specs:, platforms: PLATFORMS, bundler: '4.0.23', dependencies: nil, checksums: true)
    spec_lines = specs.sort.flat_map { |head, deps| ["    #{head}", *deps.map { |d| "      #{d}" }] }
    dependencies ||= specs.keys.map { |head| head[/\A\S+/] }.uniq.sort
    text = +"GEM\n  remote: https://rubygems.org/\n  specs:\n#{spec_lines.join("\n")}\n\n"
    text << "PLATFORMS\n#{platforms.map { |p| "  #{p}" }.join("\n")}\n\n"
    text << "DEPENDENCIES\n#{dependencies.map { |d| "  #{d}" }.join("\n")}\n\n"
    text << "CHECKSUMS\n#{specs.keys.sort.map { |head| "  #{head} sha256=#{head.sum.to_s.rjust(64, '0')}" }.join("\n")}\n\n" if checksums
    text << "BUNDLED WITH\n  #{bundler}\n"
  end

  def snap(text, ruby = '4.0.9')
    LockfileSync::Snapshot.new(text, ruby)
  end

  def reference_lock(**opts)
    lock(specs: {
      'rake (13.4.2)'                 => [],
      'ffi (1.17.4)'                  => [],
      'ffi (1.17.4-x86_64-linux-gnu)' => [],
      'json (3.1.0)'                  => [],
      'ox (2.14.29)'                  => ['bigdecimal (>= 3.0)'],
      'bigdecimal (4.1.3)'            => []
    }, **opts)
  end

  def target_lock(json: '3.1.0', **opts)
    lock(specs: {
      'rake (13.4.2)'                 => [],
      'ffi (1.17.4)'                  => [],
      'ffi (1.17.4-x86_64-linux-gnu)' => [],
      "json (#{json})"                => [],
      'yard (0.9.45)'                 => []
    }, **opts)
  end

  def keys(drift)
    drift.map(&:key)
  end

  # --- drift ---

  def test_aligned_lockfiles_have_no_drift
    assert_empty LockfileSync.drift(snap(target_lock), snap(reference_lock))
  end

  def test_gems_on_only_one_side_do_not_count
    # yard is target-only; ox and bigdecimal are reference-only.
    assert_empty LockfileSync.drift(snap(target_lock), snap(reference_lock))
  end

  def test_platform_variants_fold_into_one_version
    # The target lacks the linux variant but locks the same version.
    target = lock(specs: { 'ffi (1.17.4)' => [] })
    assert_empty keys(LockfileSync.drift(snap(target), snap(reference_lock))) - ['PLATFORMS']
  end

  def test_shared_gem_version_difference_is_drift
    drift = LockfileSync.drift(snap(target_lock(json: '3.0.9')), snap(reference_lock))
    assert_equal ['gem json'], keys(drift)
    assert_equal '3.0.9', drift.first.value
    assert_equal '3.1.0', drift.first.reference_value
  end

  def test_shared_gem_ahead_of_the_reference_is_drift
    assert_equal ['gem json'], keys(LockfileSync.drift(snap(target_lock(json: '3.2.0')), snap(reference_lock)))
  end

  def test_ruby_version_difference_is_drift
    drift = LockfileSync.drift(snap(target_lock, '4.0.5'), snap(reference_lock))
    assert_equal ['.ruby-version'], keys(drift)
  end

  def test_missing_ruby_version_is_drift
    assert_equal ['.ruby-version'], keys(LockfileSync.drift(snap(target_lock, nil), snap(reference_lock)))
  end

  def test_bundler_version_difference_is_drift
    assert_equal ['BUNDLED WITH'], keys(LockfileSync.drift(snap(target_lock(bundler: '4.0.8')), snap(reference_lock)))
  end

  def test_extra_platform_is_drift
    drift = LockfileSync.drift(snap(target_lock(platforms: PLATFORMS + ['ruby'])), snap(reference_lock))
    assert_equal ['PLATFORMS'], keys(drift)
  end

  def test_platform_order_does_not_matter
    assert_empty LockfileSync.drift(snap(target_lock(platforms: PLATFORMS.reverse)), snap(reference_lock))
  end

  def test_missing_target_lockfile_is_drift
    assert_equal ['Gemfile.lock'], keys(LockfileSync.drift(snap(nil), snap(reference_lock)))
  end

  def test_missing_reference_lockfile_raises
    assert_raises(LockfileSync::Error) { LockfileSync.drift(snap(target_lock), snap(nil)) }
  end

  def test_every_kind_of_drift_is_reported_together
    target = snap(target_lock(json: '3.0.9', bundler: '4.0.8', platforms: ['ruby']), '4.0.5')
    assert_equal ['.ruby-version', 'BUNDLED WITH', 'PLATFORMS', 'gem json'], keys(LockfileSync.drift(target, snap(reference_lock)))
  end

  # --- new_drift (--baseline) ---

  def test_drift_already_on_the_base_is_not_new
    behind = snap(target_lock(json: '3.0.9'))
    assert_empty LockfileSync.new_drift(behind, behind, snap(reference_lock))
  end

  def test_change_that_fixes_drift_has_no_new_drift
    assert_empty LockfileSync.new_drift(snap(target_lock), snap(target_lock(json: '3.0.9')), snap(reference_lock))
  end

  def test_change_that_adds_drift_fails
    assert_equal ['gem json'], keys(LockfileSync.new_drift(snap(target_lock(json: '3.2.0')), snap(target_lock), snap(reference_lock)))
  end

  def test_change_that_moves_drifted_gem_to_another_wrong_version_fails
    new = LockfileSync.new_drift(snap(target_lock(json: '3.2.0')), snap(target_lock(json: '3.0.9')), snap(reference_lock))
    assert_equal ['gem json'], keys(new)
  end

  def test_unrelated_drift_on_the_base_does_not_hide_new_drift
    base = snap(target_lock, '4.0.5')
    head = snap(target_lock(json: '3.2.0'), '4.0.5')
    assert_equal ['gem json'], keys(LockfileSync.new_drift(head, base, snap(reference_lock)))
  end

  def test_base_without_a_lockfile_makes_all_drift_new
    assert_equal ['gem json'], keys(LockfileSync.new_drift(snap(target_lock(json: '3.0.9')), snap(nil, nil), snap(reference_lock)))
  end

  # --- merge ---

  def merged(target = target_lock(json: '3.0.9', bundler: '4.0.8', platforms: ['ruby']), reference = reference_lock)
    LockfileSync.merge(target, reference)
  end

  def test_merge_takes_the_reference_versions_platforms_and_bundler
    result = snap(merged)
    assert_equal ['3.1.0'], result.gem_versions['json']
    assert_equal PLATFORMS, result.platforms
    assert_equal '4.0.23', result.bundler_version
  end

  def test_merge_keeps_the_target_only_gems
    assert_includes merged, "    yard (0.9.45)\n"
  end

  def test_merge_leaves_out_dependencies_so_bundle_lock_resolves_again
    assert_nil LockfileSync.section(merged, 'DEPENDENCIES')
  end

  def test_merge_keeps_dependency_lines_of_reference_specs
    assert_includes merged, "    ox (2.14.29)\n      bigdecimal (>= 3.0)\n"
  end

  def test_merge_keeps_dependency_lines_of_target_only_specs
    target = lock(specs: { 'json (3.1.0)' => [], 'webmock (3.34.0)' => ['crack (>= 0.3.2)'], 'crack (1.0.1)' => [] })
    assert_includes merged(target), "    webmock (3.34.0)\n      crack (>= 0.3.2)\n"
  end

  def test_merge_takes_shared_checksums_from_the_reference_and_keeps_own
    sums = LockfileSync.section(merged, 'CHECKSUMS')
    assert(sums.any? { |l| l.start_with?('  json (3.1.0) ') })
    refute(sums.any? { |l| l.start_with?('  json (3.0.9) ') })
    assert(sums.any? { |l| l.start_with?('  yard (0.9.45) ') })
  end

  def test_merge_without_checksums_on_either_side_writes_none
    result = LockfileSync.merge(target_lock(checksums: false), reference_lock(checksums: false))
    assert_nil LockfileSync.section(result, 'CHECKSUMS')
  end

  def test_merge_keeps_the_target_ruby_version_section
    target = target_lock.sub("BUNDLED WITH", "RUBY VERSION\n  ruby 4.0.9\n\nBUNDLED WITH")
    assert_equal ['  ruby 4.0.9'], LockfileSync.section(merged(target), 'RUBY VERSION')
  end

  def test_merge_handles_a_crlf_target_and_keeps_its_own_checksums
    result = LockfileSync.merge(merged_target_crlf, reference_lock)
    refute_includes result, "\r"
    assert(LockfileSync.section(result, 'CHECKSUMS').any? { |l| l.start_with?('  yard (0.9.45) ') })
    assert_equal PLATFORMS, snap(result).platforms
  end

  def merged_target_crlf
    target_lock(platforms: ['ruby']).gsub("\n", "\r\n")
  end

  def test_merge_result_parses
    parsed = Bundler::LockfileParser.new(merged)
    assert_includes parsed.specs.map(&:name), 'yard'
  end

  def test_merge_refuses_git_sources
    git = "GIT\n  remote: https://github.com/x/y\n  revision: abc\n  specs:\n    y (1.0)\n\n#{target_lock}"
    error = assert_raises(LockfileSync::Error) { LockfileSync.merge(git, reference_lock) }
    assert_match(/GIT/, error.message)
  end

  # --- command line ---

  def write_repo(dir, lockfile, ruby = '4.0.9')
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, 'Gemfile.lock'), lockfile) if lockfile
    File.write(File.join(dir, '.ruby-version'), "#{ruby}\n") if ruby
    dir
  end

  def run_main(*argv)
    out = StringIO.new
    err = StringIO.new
    $stdout = out
    $stderr = err
    code = LockfileSync.main(argv)
    [code, out.string, err.string]
  ensure
    $stdout = STDOUT
    $stderr = STDERR
  end

  def test_check_exits_0_when_aligned
    Dir.mktmpdir do |d|
      code, out, = run_main('--check', '--reference', write_repo("#{d}/ref", reference_lock), write_repo("#{d}/t", target_lock))
      assert_equal 0, code
      assert_match(/aligned/, out)
    end
  end

  def test_check_exits_1_and_names_the_drift
    Dir.mktmpdir do |d|
      code, out, = run_main('--check', '--reference', write_repo("#{d}/ref", reference_lock), write_repo("#{d}/t", target_lock(json: '3.0.9')))
      assert_equal 1, code
      assert_match(/drift: gem json: 3\.0\.9 here, 3\.1\.0 in the reference/, out)
    end
  end

  def test_check_with_baseline_passes_drift_the_base_already_has
    Dir.mktmpdir do |d|
      ref = write_repo("#{d}/ref", reference_lock)
      base = write_repo("#{d}/base", target_lock(json: '3.0.9'))
      head = write_repo("#{d}/head", target_lock(json: '3.0.9'))
      code, out, = run_main('--check', '--reference', ref, '--baseline', base, head)
      assert_equal 0, code
      assert_match(/already on the base branch/, out)
    end
  end

  def test_check_with_baseline_fails_new_drift
    Dir.mktmpdir do |d|
      ref = write_repo("#{d}/ref", reference_lock)
      code, = run_main('--check', '--reference', ref, '--baseline', write_repo("#{d}/base", target_lock), write_repo("#{d}/head", target_lock(json: '3.2.0')))
      assert_equal 1, code
    end
  end

  def test_baseline_without_check_is_a_usage_error
    Dir.mktmpdir do |d|
      code, _, err = run_main('--reference', write_repo("#{d}/ref", reference_lock), '--baseline', d, d)
      assert_equal 2, code
      assert_match(/--baseline only applies with --check/, err)
    end
  end

  def test_malformed_reference_is_a_usage_error
    code, _, err = run_main('--check', '--reference', 'not a repo', '.')
    assert_equal 2, code
    assert_match(/OWNER\/REPO/, err)
  end

  def test_unknown_option_is_a_usage_error
    assert_equal 2, run_main('--frobnicate').first
  end

  # --- sync against rubygems.org (runs a real `bundle lock`) ---

  def installed_bundler
    Gem::Specification.find_all_by_name('bundler').select { |s| File.exist?(s.bin_file('bundle')) }.max_by(&:version).version.to_s
  end

  def test_sync_aligns_shared_gems_prunes_reference_only_gems_and_keeps_own_versions
    skip 'needs rubygems.org; SYNC_LOCKFILE_OFFLINE is set' if ENV['SYNC_LOCKFILE_OFFLINE']
    bundler = installed_bundler
    Dir.mktmpdir do |d|
      reference = lock(specs: { 'rake (13.4.2)' => [], 'ox (2.14.29)' => ['bigdecimal (>= 3.0)'], 'bigdecimal (4.1.3)' => [] },
                       platforms: ['arm64-darwin', 'x86_64-linux'], bundler: bundler, checksums: false)
      ref = write_repo("#{d}/ref", reference, '4.0.9')
      # rake is behind the reference; yard is the target's own gem and must
      # stay at 0.9.37 even though newer releases exist.
      target = write_repo("#{d}/t", lock(specs: { 'rake (13.3.0)' => [], 'yard (0.9.37)' => [] },
                                         platforms: ['ruby'], bundler: bundler, checksums: false), '4.0.5')
      File.write("#{target}/Gemfile", "source 'https://rubygems.org'\ngem 'rake'\ngem 'yard'\n")

      code, _, err = run_main('--reference', ref, target)
      assert_equal 0, code, err
      result = LockfileSync::Snapshot.read(target)
      assert_equal({ 'rake' => ['13.4.2'], 'yard' => ['0.9.37'] }, result.gem_versions)
      assert_equal ['arm64-darwin', 'x86_64-linux'], result.platforms
      assert_equal '4.0.9', result.ruby_version
      assert_equal ['rake', 'yard'], LockfileSync.section(result.lockfile_text, 'DEPENDENCIES').map(&:strip)
      assert_empty LockfileSync.drift(result, LockfileSync::Snapshot.read(ref))
    end
  end

  def test_sync_reports_a_shared_gem_the_target_gemfile_cannot_take
    skip 'needs rubygems.org; SYNC_LOCKFILE_OFFLINE is set' if ENV['SYNC_LOCKFILE_OFFLINE']
    bundler = installed_bundler
    Dir.mktmpdir do |d|
      ref = write_repo("#{d}/ref", lock(specs: { 'rake (13.4.2)' => [] }, platforms: ['x86_64-linux'], bundler: bundler, checksums: false))
      target = write_repo("#{d}/t", lock(specs: { 'rake (13.3.0)' => [] }, platforms: ['x86_64-linux'], bundler: bundler, checksums: false))
      File.write("#{target}/Gemfile", "source 'https://rubygems.org'\ngem 'rake', '13.3.0'\n")

      code, _, err = run_main('--reference', ref, target)
      assert_equal 1, code
      assert_match(/still differs: gem rake: 13\.3\.0 here, 13\.4\.2/, err)
    end
  end

  def test_sync_refuses_a_bundler_that_is_not_installed
    Dir.mktmpdir do |d|
      ref = write_repo("#{d}/ref", reference_lock(bundler: '0.0.1'))
      target = write_repo("#{d}/t", target_lock)
      code, _, err = run_main('--reference', ref, target)
      assert_equal 2, code
      assert_match(/gem install bundler -v 0\.0\.1/, err)
      assert_equal target_lock, File.read("#{target}/Gemfile.lock"), 'the target must be left untouched'
    end
  end
end
