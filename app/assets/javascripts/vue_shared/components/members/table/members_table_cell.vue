<script>
import { mapState } from 'vuex';
import { MEMBER_TYPES } from '../constants';

export default {
  name: 'MembersTableCell',
  props: {
    member: {
      type: Object,
      required: true,
    },
  },
  computed: {
    ...mapState(['sourceId', 'currentUserId']),
    isGroup() {
      return Boolean(this.member.sharedWithGroup);
    },
    isInvite() {
      return Boolean(this.member.invite);
    },
    isAccessRequest() {
      return Boolean(this.member.requestedAt);
    },
    memberType() {
      if (this.isGroup) {
        return MEMBER_TYPES.group;
      } else if (this.isInvite) {
        return MEMBER_TYPES.invite;
      } else if (this.isAccessRequest) {
        return MEMBER_TYPES.accessRequest;
      }

      return MEMBER_TYPES.user;
    },
    isDirectMember() {
      return this.member.source?.id === this.sourceId;
    },
    isCurrentUser() {
      return this.member.user?.id === this.currentUserId;
    },
  },
  render() {
    return this.$scopedSlots.default({
      memberType: this.memberType,
      isDirectMember: this.isDirectMember,
      isCurrentUser: this.isCurrentUser,
    });
  },
};
</script>
