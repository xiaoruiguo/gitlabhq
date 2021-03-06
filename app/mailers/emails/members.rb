# frozen_string_literal: true

module Emails
  module Members
    extend ActiveSupport::Concern
    include MembersHelper

    included do
      helper_method :member_source, :member
    end

    def member_access_requested_email(member_source_type, member_id, recipient_id)
      @member_source_type = member_source_type
      @member_id = member_id

      return unless member_exists?

      user = User.find(recipient_id)

      member_email_with_layout(
        to: user.notification_email_for(notification_group),
        subject: subject("Request to join the #{member_source.human_name} #{member_source.model_name.singular}"))
    end

    def member_access_granted_email(member_source_type, member_id)
      @member_source_type = member_source_type
      @member_id = member_id

      return unless member_exists?

      member_email_with_layout(
        to: member.user.notification_email_for(notification_group),
        subject: subject("Access to the #{member_source.human_name} #{member_source.model_name.singular} was granted"))
    end

    def member_access_denied_email(member_source_type, source_id, user_id)
      @member_source_type = member_source_type
      @member_source = member_source_class.find(source_id)

      user = User.find(user_id)

      member_email_with_layout(
        to: user.notification_email_for(notification_group),
        subject: subject("Access to the #{member_source.human_name} #{member_source.model_name.singular} was denied"))
    end

    def member_invited_email(member_source_type, member_id, token)
      @member_source_type = member_source_type
      @member_id = member_id
      @token = token

      return unless member_exists?

      subject_line = subject("Invitation to join the #{member_source.human_name} #{member_source.model_name.singular}")

      if member.invite_to_unknown_user? && Feature.enabled?(:invite_email_experiment)
        subject_line = subject("#{member.created_by.name} invited you to join GitLab") if member.created_by
        @invite_url_params = { new_user_invite: 'experiment' }

        member_email_with_layout(
          to: member.invite_email,
          subject: subject_line,
          template: 'member_invited_email_experiment',
          layout: 'experiment_mailer'
        )

        Gitlab::Tracking.event(Gitlab::Experimentation::EXPERIMENTS[:invite_email][:tracking_category], 'sent', property: 'experiment_group')
      else
        @invite_url_params = member.invite_to_unknown_user? ? { new_user_invite: 'control' } : {}

        member_email_with_layout(
          to: member.invite_email,
          subject: subject_line
        )

        if member.invite_to_unknown_user?
          Gitlab::Tracking.event(Gitlab::Experimentation::EXPERIMENTS[:invite_email][:tracking_category], 'sent', property: 'control_group')
        end
      end

      if member.invite_to_unknown_user? && Gitlab::Experimentation.enabled?(:invitation_reminders)
        Gitlab::Tracking.event(
          Gitlab::Experimentation.experiment(:invitation_reminders).tracking_category,
          'sent',
          property: Gitlab::Experimentation.enabled_for_attribute?(:invitation_reminders, member.invite_email) ? 'experimental_group' : 'control_group',
          label: Digest::MD5.hexdigest(member.to_global_id.to_s)
        )
      end
    end

    def member_invite_accepted_email(member_source_type, member_id)
      @member_source_type = member_source_type
      @member_id = member_id

      return unless member_exists?
      return unless member.created_by

      member_email_with_layout(
        to: member.created_by.notification_email_for(notification_group),
        subject: subject('Invitation accepted'))
    end

    def member_invite_declined_email(member_source_type, source_id, invite_email, created_by_id)
      return unless created_by_id

      @member_source_type = member_source_type
      @member_source = member_source_class.find(source_id)
      @invite_email = invite_email

      user = User.find(created_by_id)

      member_email_with_layout(
        to: user.notification_email_for(notification_group),
        subject: subject('Invitation declined'))
    end

    # rubocop: disable CodeReuse/ActiveRecord
    def member
      @member ||= Member.find_by(id: @member_id)
    end
    # rubocop: enable CodeReuse/ActiveRecord

    def member_source
      @member_source ||= member.source
    end

    def notification_group
      @member_source_type.casecmp?('project') ? member_source.group : member_source
    end

    private

    def member_exists?
      Gitlab::AppLogger.info("Tried to send an email invitation for a deleted group. Member id: #{@member_id}") if member.blank?
      member.present?
    end

    def member_source_class
      @member_source_type.classify.constantize
    end

    def member_email_with_layout(to:, subject:, template: nil, layout: 'mailer')
      mail(to: to, subject: subject) do |format|
        if template
          format.html { render template, layout: layout }
          format.text { render template, layout: layout }
        else
          format.html { render layout: layout }
          format.text { render layout: layout }
        end
      end
    end
  end
end
