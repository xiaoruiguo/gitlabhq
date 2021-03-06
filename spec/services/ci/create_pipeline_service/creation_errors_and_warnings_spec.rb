# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::CreatePipelineService do
  describe 'creation errors and warnings' do
    let_it_be(:user)    { create(:admin) }
    let_it_be(:project) { create(:project, :repository, creator: user) }

    let(:ref)      { 'refs/heads/master' }
    let(:source)   { :push }
    let(:service)  { described_class.new(project, user, { ref: ref }) }
    let(:pipeline) { service.execute(source) }

    before do
      stub_ci_pipeline_yaml_file(config)
      stub_feature_flags(ci_raise_job_rules_without_workflow_rules_warning: true)
    end

    context 'when created successfully' do
      context 'when warnings are raised' do
        let(:config) do
          <<~YAML
            test:
              script: rspec
              rules:
                - when: always
          YAML
        end

        it 'contains only warnings' do
          expect(pipeline.error_messages.map(&:content)).to be_empty

          expect(pipeline.warning_messages.map(&:content)).to contain_exactly(
            /jobs:test may allow multiple pipelines to run/
          )
        end

        context 'when feature flag is disabled for the particular warning' do
          before do
            stub_feature_flags(ci_raise_job_rules_without_workflow_rules_warning: false)
          end

          it 'does not contain warnings' do
            expect(pipeline.error_messages.map(&:content)).to be_empty

            expect(pipeline.warning_messages.map(&:content)).to be_empty
          end
        end
      end

      context 'when no warnings are raised' do
        let(:config) do
          <<~YAML
            test:
              script: rspec
          YAML
        end

        it 'contains no warnings' do
          expect(pipeline.error_messages).to be_empty

          expect(pipeline.warning_messages).to be_empty
        end
      end
    end

    context 'when failed to create the pipeline' do
      context 'when warnings are raised' do
        let(:config) do
          <<~YAML
            build:
              stage: build
              script: echo
              needs: [test]
            test:
              stage: test
              script: echo
              rules:
                - when: on_success
          YAML
        end

        it 'contains both errors and warnings' do
          error_message = 'build job: need test is not defined in prior stages'
          warning_message = /jobs:test may allow multiple pipelines to run/

          expect(pipeline.yaml_errors).to eq(error_message)
          expect(pipeline.error_messages.map(&:content)).to contain_exactly(error_message)
          expect(pipeline.errors.full_messages).to contain_exactly(error_message)

          expect(pipeline.warning_messages.map(&:content)).to contain_exactly(warning_message)
        end
      end

      context 'when no warnings are raised' do
        let(:config) do
          <<~YAML
            invalid: yaml
          YAML
        end

        it 'contains only errors' do
          error_message = 'jobs invalid config should implement a script: or a trigger: keyword'
          expect(pipeline.yaml_errors).to eq(error_message)
          expect(pipeline.error_messages.map(&:content)).to contain_exactly(error_message)
          expect(pipeline.errors.full_messages).to contain_exactly(error_message)

          expect(pipeline.warning_messages).to be_empty
        end
      end
    end
  end
end
