# frozen_string_literal: true

module Ci
  class BuildReportResultService
    include Gitlab::Utils::UsageData

    EVENT_NAME = 'i_testing_test_case_parsed'

    def execute(build)
      return unless build.has_test_reports?

      test_suite = generate_test_suite_report(build)

      track_test_cases(build, test_suite)

      build.report_results.create!(
        project_id: build.project_id,
        data: tests_params(test_suite)
      )
    end

    private

    def generate_test_suite_report(build)
      build.collect_test_reports!(Gitlab::Ci::Reports::TestReports.new)
    end

    def tests_params(test_suite)
      {
        tests: {
          name: test_suite.name,
          duration: test_suite.total_time,
          failed: test_suite.failed_count,
          errored: test_suite.error_count,
          skipped: test_suite.skipped_count,
          success: test_suite.success_count
        }
      }
    end

    def track_test_cases(build, test_suite)
      return if Feature.disabled?(:track_unique_test_cases_parsed, build.project)

      track_usage_event(EVENT_NAME, test_case_hashes(build, test_suite))
    end

    def test_case_hashes(build, test_suite)
      [].tap do |hashes|
        test_suite.each_test_case do |test_case|
          key = "#{build.project_id}-#{test_suite.name}-#{test_case.key}"
          hashes << Digest::SHA256.hexdigest(key)
        end
      end
    end
  end
end
