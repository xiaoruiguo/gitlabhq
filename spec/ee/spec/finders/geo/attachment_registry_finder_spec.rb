require 'spec_helper'

# Disable transactions via :truncate method because a foreign table
# can't see changes inside a transaction of a different connection.
describe Geo::AttachmentRegistryFinder, :geo, :truncate do
  include ::EE::GeoHelpers

  let(:secondary) { create(:geo_node) }

  let(:synced_group) { create(:group) }
  let(:unsynced_group) { create(:group) }
  let(:synced_project) { create(:project, group: synced_group) }
  let(:unsynced_project) { create(:project, group: unsynced_group) }

  let(:upload_1) { create(:upload, model: synced_group) }
  let(:upload_2) { create(:upload, model: unsynced_group) }
  let(:upload_3) { create(:upload, :issuable_upload, model: synced_project) }
  let(:upload_4) { create(:upload, model: unsynced_project) }
  let(:upload_5) { create(:upload, model: synced_project) }
  let(:upload_6) { create(:upload, :personal_snippet) }
  let(:lfs_object) { create(:lfs_object) }

  subject { described_class.new(current_node: secondary) }

  before do
    stub_current_geo_node(secondary)
  end

  context 'FDW' do
    before do
      skip('FDW is not configured') if Gitlab::Database.postgresql? && !Gitlab::Geo.fdw?
    end

    describe '#find_synced_attachments' do
      it 'delegates to #fdw_find_synced_attachments' do
        expect(subject).to receive(:fdw_find_synced_attachments).and_call_original

        subject.find_synced_attachments
      end

      it 'returns synced avatars, attachment, personal snippets and files' do
        create(:geo_file_registry, :avatar, file_id: upload_1.id)
        create(:geo_file_registry, :avatar, file_id: upload_2.id)
        create(:geo_file_registry, :avatar, file_id: upload_3.id, success: false)
        create(:geo_file_registry, :avatar, file_id: upload_6.id)
        create(:geo_file_registry, :lfs, file_id: lfs_object.id)

        synced_attachments = subject.find_synced_attachments

        expect(synced_attachments.pluck(:id)).to match_array([upload_1.id, upload_2.id, upload_6.id])
      end

      context 'with selective sync' do
        it 'returns synced avatars, attachment, personal snippets and files' do
          create(:geo_file_registry, :avatar, file_id: upload_1.id)
          create(:geo_file_registry, :avatar, file_id: upload_2.id)
          create(:geo_file_registry, :avatar, file_id: upload_3.id)
          create(:geo_file_registry, :avatar, file_id: upload_4.id)
          create(:geo_file_registry, :avatar, file_id: upload_5.id, success: false)
          create(:geo_file_registry, :avatar, file_id: upload_6.id)
          create(:geo_file_registry, :lfs, file_id: lfs_object.id)

          secondary.update_attribute(:namespaces, [synced_group])

          synced_attachments = subject.find_synced_attachments

          expect(synced_attachments.pluck(:id)).to match_array([upload_1.id, upload_3.id, upload_6.id])
        end
      end
    end

    describe '#find_failed_attachments' do
      it 'delegates to #fdw_find_failed_attachments' do
        expect(subject).to receive(:fdw_find_failed_attachments).and_call_original

        subject.find_failed_attachments
      end

      it 'returns failed avatars, attachment, personal snippets and files' do
        create(:geo_file_registry, :avatar, file_id: upload_1.id)
        create(:geo_file_registry, :avatar, file_id: upload_2.id)
        create(:geo_file_registry, :avatar, file_id: upload_3.id, success: false)
        create(:geo_file_registry, :avatar, file_id: upload_6.id, success: false)
        create(:geo_file_registry, :lfs, file_id: lfs_object.id, success: false)

        failed_attachments = subject.find_failed_attachments

        expect(failed_attachments.pluck(:id)).to match_array([upload_3.id, upload_6.id])
      end

      context 'with selective sync' do
        it 'returns failed avatars, attachment, personal snippets and files' do
          create(:geo_file_registry, :avatar, file_id: upload_1.id, success: false)
          create(:geo_file_registry, :avatar, file_id: upload_2.id)
          create(:geo_file_registry, :avatar, file_id: upload_3.id, success: false)
          create(:geo_file_registry, :avatar, file_id: upload_4.id)
          create(:geo_file_registry, :avatar, file_id: upload_5.id)
          create(:geo_file_registry, :avatar, file_id: upload_6.id, success: false)
          create(:geo_file_registry, :lfs, file_id: lfs_object.id, success: false)

          secondary.update_attribute(:namespaces, [synced_group])

          failed_attachments = subject.find_failed_attachments

          expect(failed_attachments.pluck(:id)).to match_array([upload_1.id, upload_3.id, upload_6.id])
        end
      end
    end
  end

  context 'Legacy' do
    before do
      allow(Gitlab::Geo).to receive(:fdw?).and_return(false)
    end

    describe '#find_synced_attachments' do
      it 'delegates to #legacy_find_synced_attachments' do
        expect(subject).to receive(:legacy_find_synced_attachments).and_call_original

        subject.find_synced_attachments
      end

      it 'returns synced avatars, attachment, personal snippets and files' do
        create(:geo_file_registry, :avatar, file_id: upload_1.id)
        create(:geo_file_registry, :avatar, file_id: upload_2.id)
        create(:geo_file_registry, :avatar, file_id: upload_3.id, success: false)
        create(:geo_file_registry, :avatar, file_id: upload_6.id)
        create(:geo_file_registry, :lfs, file_id: lfs_object.id)

        synced_attachments = subject.find_synced_attachments

        expect(synced_attachments).to match_array([upload_1, upload_2, upload_6])
      end

      context 'with selective sync' do
        it 'returns synced avatars, attachment, personal snippets and files' do
          create(:geo_file_registry, :avatar, file_id: upload_1.id)
          create(:geo_file_registry, :avatar, file_id: upload_2.id)
          create(:geo_file_registry, :avatar, file_id: upload_3.id)
          create(:geo_file_registry, :avatar, file_id: upload_4.id)
          create(:geo_file_registry, :avatar, file_id: upload_5.id, success: false)
          create(:geo_file_registry, :avatar, file_id: upload_6.id)
          create(:geo_file_registry, :lfs, file_id: lfs_object.id)

          secondary.update_attribute(:namespaces, [synced_group])

          synced_attachments = subject.find_synced_attachments

          expect(synced_attachments).to match_array([upload_1, upload_3, upload_6])
        end
      end
    end

    describe '#find_failed_attachments' do
      it 'delegates to #legacy_find_failed_attachments' do
        expect(subject).to receive(:legacy_find_failed_attachments).and_call_original

        subject.find_failed_attachments
      end

      it 'returns failed avatars, attachment, personal snippets and files' do
        create(:geo_file_registry, :avatar, file_id: upload_1.id)
        create(:geo_file_registry, :avatar, file_id: upload_2.id)
        create(:geo_file_registry, :avatar, file_id: upload_3.id, success: false)
        create(:geo_file_registry, :avatar, file_id: upload_6.id, success: false)
        create(:geo_file_registry, :lfs, file_id: lfs_object.id, success: false)

        failed_attachments = subject.find_failed_attachments

        expect(failed_attachments).to match_array([upload_3, upload_6])
      end

      context 'with selective sync' do
        it 'returns failed avatars, attachment, personal snippets and files' do
          create(:geo_file_registry, :avatar, file_id: upload_1.id, success: false)
          create(:geo_file_registry, :avatar, file_id: upload_2.id)
          create(:geo_file_registry, :avatar, file_id: upload_3.id, success: false)
          create(:geo_file_registry, :avatar, file_id: upload_4.id)
          create(:geo_file_registry, :avatar, file_id: upload_5.id)
          create(:geo_file_registry, :avatar, file_id: upload_6.id, success: false)
          create(:geo_file_registry, :lfs, file_id: lfs_object.id, success: false)

          secondary.update_attribute(:namespaces, [synced_group])

          failed_attachments = subject.find_failed_attachments

          expect(failed_attachments).to match_array([upload_1, upload_3, upload_6])
        end
      end
    end
  end
end
