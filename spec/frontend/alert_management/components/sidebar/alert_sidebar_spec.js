import { shallowMount, mount } from '@vue/test-utils';
import axios from 'axios';
import MockAdapter from 'axios-mock-adapter';
import AlertSidebar from '~/alert_management/components/alert_sidebar.vue';
import SidebarAssignees from '~/alert_management/components/sidebar/sidebar_assignees.vue';
import mockAlerts from '../../mocks/alerts.json';

const mockAlert = mockAlerts[0];

describe('Alert Details Sidebar', () => {
  let wrapper;
  let mock;

  function mountComponent({ mountMethod = shallowMount, stubs = {}, alert = {} } = {}) {
    wrapper = mountMethod(AlertSidebar, {
      data() {
        return {
          sidebarStatus: false,
        };
      },
      propsData: {
        alert,
      },
      provide: {
        projectPath: 'projectPath',
        projectId: '1',
      },
      stubs,
      mocks: {
        $apollo: {
          queries: {
            sidebarStatus: {},
          },
        },
      },
    });
  }

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
    }
    mock.restore();
  });

  describe('the sidebar renders', () => {
    beforeEach(() => {
      mock = new MockAdapter(axios);
      mountComponent();
    });

    it('open as default', () => {
      expect(wrapper.classes('right-sidebar-expanded')).toBe(true);
    });

    it('should render side bar assignee dropdown', () => {
      mountComponent({
        mountMethod: mount,
        alert: mockAlert,
      });
      expect(wrapper.find(SidebarAssignees).exists()).toBe(true);
    });
  });
});
